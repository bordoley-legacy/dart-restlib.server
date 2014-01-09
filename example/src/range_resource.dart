part of restlib.example;

typedef bool _SupportsRangeRequestFunc(final entity);
typedef Future<int> _EntityLengthFunc(final entity);

class ByteRangeResource<T>
    extends Object
    with ForwardingResource<T>
    implements Resource<T>, Forwarder {
  
  final Resource<T> delegate;
  final _SupportsRangeRequestFunc supportsRangeRequest;
  final _EntityLengthFunc entityLength;
 
  ByteRangeResource(this.delegate, this.supportsRangeRequest, this.entityLength);
 
  Future<Response> handle(final Request request) =>
      delegate.handle(request).then((final Response response) => 
          _rangeResponse(request, response));
 
  Future<Response> acceptMessage(final Request<T> request) =>
      delegate.acceptMessage(request).then((final Response response) => 
          _rangeResponse(request, response));
 
  Future<Response> _rangeResponse(final Request request, final Response response) {
    if (response.status.statusClass != StatusClass.SUCCESS ||
        response.entity.isEmpty ||
        request.preferences.range.isEmpty) {
      return new Future.value(response.with_(acceptedRangeUnits: [RangeUnit.BYTES]));
    }
    
    final entity = response.entity.value;
    if (!supportsRangeRequest(entity)) {
      return new Future.value(response);
    }
  
    final Range requestRange = request.preferences.range.value;
    if (requestRange is ByteRangesSpecifier) {
      return _byteRangeResponse(request, response);
    } else {
      return new Future.value(response.with_(acceptedRangeUnits: [RangeUnit.BYTES]));
    }  
  }
  
  Future<Response> _byteRangeResponse(final Request request, final Response response) {
    final ImmutableSequence<Either<ByteRange, SuffixByteRange>> ranges = 
        (request.preferences.range.value as ByteRangesSpecifier).byteRangeSet;
    final entity = response.entity.value;
    
    if (ranges.length == 1) {
      return entityLength(entity).then((final int length) =>
          _singleByteRangeResponse(response, ranges.first, length));
    } else {
      return entityLength(entity).then((final int length) => 
                  _multiByteRangeRequest(response, ranges, length));
    }
  }
  
  Response _singleByteRangeResponse(final Response response, final Either<ByteRange, SuffixByteRange> range, final int entityLength) {
    final ContentInfo contentInfo = _contentInfoForByteRangeSetItem(response.contentInfo, range, entityLength);
    if (contentInfo.range.isEmpty) {
      return response;
    }
    
    if (contentInfo.range.value is UnsatisfiedRange) {
      return (new ResponseBuilder()
        ..status = Status.CLIENT_ERROR_REQUESTED_RANGE_NOT_SATISFIABLE
        ..contentInfo = contentInfo
        ..addAcceptedRangeUnit(RangeUnit.BYTES)
      ).build();
    }
    
    if (contentInfo.range.value is BytesContentRange){
      return response.with_(
          contentInfo: contentInfo,
          status: Status.SUCCESS_PARTIAL_CONTENT);
    }
    
    return response;
  }
  
  ContentInfo _contentInfoForByteRangeSetItem(final ContentInfo responseContentInfo, final Either<ByteRange, SuffixByteRange> range, final int entityLength) =>
      range.fold(
          (final ByteRange byteRange) {
            final int firstBytePos = byteRange.firstBytePos;
            final int lastBytePos = min(byteRange.lastBytePos.orElse(entityLength), entityLength);
            
            return _contentInfoForRange(responseContentInfo, firstBytePos, lastBytePos, entityLength);
          }, 
          (final SuffixByteRange suffixByteRange){
            final int firstBytePos = max(entityLength - suffixByteRange.suffixLength, 0);
            final int lastBytePos = entityLength;
            
            return _contentInfoForRange(responseContentInfo, firstBytePos, lastBytePos, entityLength);
          });
      
  
  ContentInfo _contentInfoForRange(final ContentInfo responseContentInfo, final int firstBytePos, final int lastBytePos, final int entityLength) {
    if (firstBytePos >= lastBytePos ||
        firstBytePos > entityLength) {
      return (new ContentInfoBuilder()
            ..range = new ContentRange.unsatisfiable(entityLength)
          ).build();
    }
    
    if (firstBytePos == 0 &&
        lastBytePos == entityLength -1) {
      return responseContentInfo;
    }
    
    return responseContentInfo.with_(
        length: lastBytePos - firstBytePos,
        range: new ContentRange.byteRange(firstBytePos, lastBytePos, entityLength));
  }
  
  Response _multiByteRangeRequest(final Response response, 
                                  final ImmutableSequence<Either<ByteRange, SuffixByteRange>> ranges,
                                  final int entityLength) {
    final ImmutableSequence<ContentInfo> parts =
        Persistent.EMPTY_SEQUENCE.addAll(
            ranges
              .map((final Either<ByteRange, SuffixByteRange> range) =>
                  _contentInfoForByteRangeSetItem(response.contentInfo, range, entityLength))
              .where((final ContentInfo contentInfo) =>
                  !(contentInfo.range.nullableValue is UnsatisfiedRange)));
    
    if (parts.isEmpty) {
      final ContentInfo contentInfo = (new ContentInfoBuilder()
        ..range = new ContentRange.unsatisfiable(entityLength)
      ).build();
      
      return (new ResponseBuilder()
        ..status = Status.CLIENT_ERROR_REQUESTED_RANGE_NOT_SATISFIABLE
        ..contentInfo = contentInfo
        ..addAcceptedRangeUnit(RangeUnit.BYTES)
      ).build();
    }
    
    final String boundary = "245ui435opoFakeB0UNDarydsdfkjlajflafjksalfja";
    
    final ContentInfo contentInfo =
        response.contentInfo.with_(
            mediaRange: MediaRange.MULTIPART_BYTE_RANGE
              .with_(parameters: Persistent.EMPTY_SET_MULTIMAP.insert("boundary", boundary)));
    
    final MultipartByteRange entity =
        new MultipartByteRange(response.entity.nullableValue, boundary, parts);
    
    return response.with_(
        entity : entity,
        contentInfo: contentInfo,
        status: Status.SUCCESS_PARTIAL_CONTENT);
  }
}

Future writeMultipartByteRange(final Request request, final Response<MultipartByteRange<File>> response, final IOSink msgSink) {
  final MultipartByteRange entity = response.entity.value;
  final Iterable<ContentInfo> parts = entity.parts;
  final File file = entity.entity;
  final String boundary = entity.boundary;
  
  return parts
    .fold(new Future.value(), (final Future future, final ContentInfo contentInfo) => 
        future
          .then((_) {
            msgSink.write("--$boundary\r\n");
            msgSink.write(contentInfo);
            return msgSink
                .addStream(
                  file.openRead(
                    (contentInfo.range.value as BytesContentRange).rangeResp.left.value.firstBytePosition,
                    (contentInfo.range.value as BytesContentRange).rangeResp.left.value.lastBytePosition))
                .then((_) =>
                    msgSink.write("\r\n\r\n"));
          }))
   .then((_) =>
       msgSink.write("--$boundary--\r\n"));   
}


class MultipartByteRange<T> {
  final T entity;
  final String boundary;
  final Sequence<ContentInfo> parts;
  
  MultipartByteRange(this.entity, this.boundary, this.parts);
}