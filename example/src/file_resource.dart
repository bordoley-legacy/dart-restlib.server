part of restlib.example;

class _FileResourceDelegate implements UniformResourceDelegate<FileSystemEntity> {
  final bool requireETagForUpdate = false;
  final bool requireIfUnmodifiedSinceForUpdate = false;
  final Route route = ROUTE.parse("/example/file/*path").value;
  final Directory _base;
  
  _FileResourceDelegate(this._base);
  
  Future<Response> get(final Request request) {
    final Dictionary<String, String> params = 
        route.parsePathParameters(new RoutableUri.wrap(request.uri));
    
    return params["path"]
      .map((final String path) {
        final String filePath = posix.join(_base.path, Uri.decodeComponent(path));
        return FileSystemEntity.type(filePath)
            .then((final FileSystemEntityType type) =>
                new PatternMatcher<FileSystemEntity>(
                    [inCaseOf(equals(FileSystemEntityType.FILE), (_) => 
                        new File(filePath)),
                     inCaseOf(equals(FileSystemEntityType.DIRECTORY), (_) => 
                         new Directory(filePath))])(type)
                  .map((final FileSystemEntity entity) =>
                      entity.stat().then((final FileStat stat) =>
                          (new ResponseBuilder()
                            ..status = Status.SUCCESS_OK
                            ..entity = entity
                            ..lastModified = stat.modified
                          ).build()))      
                  .orElse(CLIENT_ERROR_NOT_FOUND));
      }).orCompute(() => 
          new Future.error("route does not include a *path parameter"));
  }
}

Future writeFile(final Request request, final Response<File> response, final IOSink msgSink) =>
    msgSink.addStream(
        response.contentInfo.range
          // Assume the type is ByteContentRange and let the code exception with internal server error
          .map((final BytesContentRange range) {
            // Assume the range is a ByteRangeResp at this point
            final int firstBytePos = range.rangeResp.left.value.firstBytePosition;
            final int lastBytePos =  range.rangeResp.left.value.lastBytePosition;
            
            // Assume at this point that the entity is guaranteed to exist
            return response.entity.value.openRead(firstBytePos, lastBytePos);
          }).orCompute(() => 
              // Assume at this point that the entity is guaranteed to exist
              response.entity.value.openRead()));

Future writeDirectory(final Request request, final Response<Directory> response, final IOSink msgSink) {
  final StringBuffer buffer = 
      new StringBuffer("<!DOCTYPE html>\n<html><head>\n</head>\n<body>\n");
  
  // Assume at this point that the entity is guaranteed to exist
  return response.entity.value
      .list(recursive: false, followLinks: false)
        .forEach((final FileSystemEntity entity) {
          final String path = entity.path.replaceFirst(entity.parent.path, "");
          final String uriPath = path.split("/").map(Uri.encodeComponent).join("/");

          buffer.write("<a href=\"${request.uri.toString()}${uriPath}\">${path}</a><br/>\n");
        }).then((_) => 
            buffer.write("</body>\n</html>"))
        .then((_) => 
            writeString(request, response.with_(entity:buffer.toString()), msgSink));    
  }

Option<Dictionary<MediaRange, ResponseWriter>> responseWriters(final entity) {
  MediaRange mediaRange;
  ResponseEntityWriter writer;
  
  if (entity is File) {
    mediaRange = new Option(lookupMimeType(entity.path))
      .flatMap(MEDIA_RANGE.parse)
      .orElse(MediaRange.APPLICATION_OCTET_STREAM);
    writer = writeFile;
  } else if (entity is Directory) {
    mediaRange = MediaRange.TEXT_HTML;
    writer = writeDirectory;
  } else if (entity is MultipartByteStream) {
    mediaRange = 
        MediaRange.MULTIPART_BYTE_RANGE.with_(parameters :
              Persistent.EMPTY_SET_MULTIMAP.insert("boundary", entity.boundary));
    writer = writeMultipartByteStream;
  } else {
    mediaRange = MediaRange.TEXT_PLAIN;
    writer = writeString;
  }
  
  return new Option(
      Persistent.EMPTY_DICTIONARY.insert(
          mediaRange, new ResponseWriter.forContentType(mediaRange, writer)));
}

IOResource ioFileResource(final Directory directory) {  
  final Resource<FileSystemEntity> resource = 
      new UniformResource(new _FileResourceDelegate(directory));
  
  final Resource<FileSystemEntity> rangeResource =
      new RangeResource(resource, 
          (final entity) =>
              entity is File,
          (final File entity) =>
              entity.length());
  
  final ResponseWriterProvider responseWriterProvider = 
      new ResponseWriterProvider.onContentType(responseWriters);
  
  return new IOResource.conneg(rangeResource, (_) => Option.NONE, responseWriterProvider);
}