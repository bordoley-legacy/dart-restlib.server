part of server;

class _ByteRangeResource<T>
    extends Object
    with ForwardingResource<T>
    implements Resource<T>, Forwarder {

  final Resource<T> delegate;

  _ByteRangeResource(this.delegate);

  Future<Response> handle(final Request request) =>
      delegate.handle(request).then(curry1(_rangeResponse, [request]));

  Future<Response> acceptMessage(final Request<T> request) =>
      delegate.acceptMessage(request).then(curry1(_rangeResponse, [request]));

  Future<Response> _rangeResponse(final Request request, final Response response) {
    if (response.status.statusClass != StatusClass.SUCCESS ||
        response.entity.isEmpty ||
        request.preferences.range.isEmpty) {
      return new Future.value(response);
    }

    final entity = response.entity.value;
    if (entity is! ByteRangeable) {
      return new Future.value(response);
    }

    final data.Range requestRange = request.preferences.range.value;
    if (requestRange is ByteRangesSpecifier) {
      return _byteRangeResponse(request, response);
    } else {
      return new Future.value(response.with_(acceptedRangeUnits: [RangeUnit.BYTES]));
    }
  }

  Future<Response> _byteRangeResponse(final Request request, final Response<ByteRangeable> response) {
    final ImmutableSequence<Either<ByteRangeSpec, SuffixByteRangeSpec>> ranges =
        (request.preferences.range.value as ByteRangesSpecifier).byteRangeSet;
    final ByteRangeable entity = response.entity.value;

    // Only lookup the length of the entity of the Response does not include it to avoid duplicate work
    return response.contentInfo.length
        .map((final int length) =>
            new Future.value(_multiByteRangeRequest(response, ranges, length)))
        .orCompute(() =>
            entity.length().then((final int length) =>
                _multiByteRangeRequest(response, ranges, length)));
  }

  ContentInfo _contentInfoForByteRangeSetItem(final ContentInfo responseContentInfo, final Either<ByteRangeSpec, SuffixByteRangeSpec> range, final int entityLength) =>
      range.fold(
          (final ByteRangeSpec byteRange) {
            final int firstBytePos = byteRange.firstBytePos;
            final int lastBytePos = min(byteRange.lastBytePos.orElse(entityLength), entityLength);

            return _contentInfoForRange(responseContentInfo, firstBytePos, lastBytePos, entityLength);
          },
          (final SuffixByteRangeSpec suffixByteRange){
            final int firstBytePos = max(entityLength - suffixByteRange.suffixLength, 0);
            final int lastBytePos = entityLength;

            return _contentInfoForRange(responseContentInfo, firstBytePos, lastBytePos, entityLength);
          });


  ContentInfo _contentInfoForRange(final ContentInfo responseContentInfo, final int firstBytePos, final int lastBytePos, final int entityLength) {
    if (firstBytePos >= lastBytePos ||
        firstBytePos > entityLength) {
      return new ContentInfo(range : new ContentRange.unsatisfiable(entityLength));
    }

    if (firstBytePos == 0 &&
        lastBytePos == entityLength -1) {
      return responseContentInfo;
    }

    return responseContentInfo.with_(
        length: lastBytePos - firstBytePos,
        range: new ContentRange.byteRange(firstBytePos, lastBytePos, entityLength));
  }

  Response _multiByteRangeRequest(final Response<ByteRangeable> response,
                                  final ImmutableSequence<Either<ByteRangeSpec, SuffixByteRangeSpec>> ranges,
                                  final int entityLength) {
    final ImmutableSequence<Part<ByteStreamable>> parts =
        EMPTY_SEQUENCE.addAll(
            ranges
              .map((final Either<ByteRangeSpec, SuffixByteRangeSpec> range) =>
                  _contentInfoForByteRangeSetItem(response.contentInfo, range, entityLength))
              .where((final ContentInfo contentInfo) =>
                  contentInfo.range.nullableValue is! UnsatisfiedRange)

    // FIXME: Add in the ability here to define rules for how to process the parsed ranges and whether
    // they should be merged. Ideally this would be a policy object passed to the class at construction time.
              .map((final ContentInfo contentInfo) =>
                  new Part(contentInfo,
                      new ByteStreamable.byteRange(response.entity.value,
                          (contentInfo.range.value as BytesContentRange).rangeResp.left.value.firstBytePosition,
                          (contentInfo.range.value as BytesContentRange).rangeResp.left.value.lastBytePosition))));

    if (parts.isEmpty) {
      final ContentInfo contentInfo =
          new ContentInfo(range : new ContentRange.unsatisfiable(entityLength));

      return new Response(
          statuses.CLIENT_ERROR_REQUESTED_RANGE_NOT_SATISFIABLE,
          contentInfo : contentInfo,
          acceptedRangeUnits : [RangeUnit.BYTES]);
    } else if (parts.length == 1) {
      final Part part = parts.single;

      // Don't send a partial content response if the only part encapsulate
      // the complete content.
      if(response.contentInfo.length == part.contentInfo.length) {
        return response;
      }

      return response.with_(
          contentInfo: parts.first.contentInfo,
          status: statuses.SUCCESS_PARTIAL_CONTENT);
    }

    // FIXME: Use a real random number
    final String boundary = "245ui435opoFakeB0UNDarydsdfkjlajflafjksalfja";

    final ContentInfo contentInfo =
        response.contentInfo
          .with_(
            mediaRange: MULTIPART_BYTE_RANGE
              .with_(parameters: EMPTY_SET_MULTIMAP.put("boundary", boundary)))
          .without(length : true);

    final ByteStreamableMultipart entity = new ByteStreamableMultipart(boundary, parts);

    return response.with_(
        entity : entity,
        contentInfo: contentInfo,
        status: statuses.SUCCESS_PARTIAL_CONTENT);
  }
}