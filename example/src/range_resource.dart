part of restlib.example;

typedef bool _SupportsRangeRequestFunc(final entity);
typedef Future<int> _EntityLengthFunc(final entity);

class RangeResource<T>
    extends Object
    with ForwardingResource<T>
    implements Resource<T>, Forwarder {
  
  final Resource<T> delegate;
  final _SupportsRangeRequestFunc supportsRangeRequest;
  final _EntityLengthFunc entityLength;
 
  RangeResource(this.delegate, this.supportsRangeRequest, this.entityLength);
 
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
    final ImmutableSet<Either<ByteRange, SuffixByteRange>> ranges = 
        (request.preferences.range.value as ByteRangesSpecifier).byteRangeSet;
    final entity = response.entity.value;
    
    if (ranges.length == 1) {
      return entityLength(entity).then((final int length) =>
          _singleByteRangeRequest(response, ranges.first, length));
    } else {
      // FIXME: Return multipartByteStream response
    }
  }
  
  Response _singleByteRangeRequest(final Response response, 
                                      final Either<ByteRange, SuffixByteRange> range, 
                                      final int entityLength)  =>
      range.fold(
          (final ByteRange byteRange) {
            final int firstBytePos = byteRange.firstBytePos;
            final int lastBytePos = min(byteRange.lastBytePos.orElse(entityLength), entityLength);
            
            return _getSingleRangeResponse(response, firstBytePos, lastBytePos, entityLength);
          }, 
          (final SuffixByteRange suffixByteRange){
            final int firstBytePos = max(entityLength - suffixByteRange.suffixLength, 0);
            final int lastBytePos = entityLength;
            
            return _getSingleRangeResponse(response, firstBytePos, lastBytePos, entityLength);
          });
  
  Response _getSingleRangeResponse(final Response response, final int firstBytePos, final int lastBytePos, final int entityLength) {
    if (firstBytePos >= lastBytePos ||
        firstBytePos > entityLength) {
      final ContentInfo contentInfo =
          (new ContentInfoBuilder()
            ..range = new ContentRange.unsatisfiable(entityLength)
          ).build();
      return (new ResponseBuilder()
        ..status = Status.CLIENT_ERROR_REQUESTED_RANGE_NOT_SATISFIABLE
        ..contentInfo = contentInfo
        ..addAcceptedRangeUnit(RangeUnit.BYTES)
      ).build();
    }
    
    if (firstBytePos == 0 &&
        lastBytePos == entityLength -1) {
      return response;
    }
    
    final ContentInfo contentInfo = 
        response.contentInfo.with_(
            length: lastBytePos - firstBytePos,
            range: new ContentRange.byteRange(firstBytePos, lastBytePos, entityLength));
    
    return response.with_(
        contentInfo: contentInfo,
        status: Status.SUCCESS_PARTIAL_CONTENT);
  }
}


Future writeMultipartByteStream(final Request request, final Response<MultipartByteStream> response, final IOSink msgSink) {
  
}

class MultipartByteStream {
  final File file;
  final String boundary;
  
  MultipartByteStream(this.file, this.boundary);
}