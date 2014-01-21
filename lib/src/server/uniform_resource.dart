part of restlib.server;

class _UniformResource<T> implements Resource<T> {
  static bool _unmodified(final Request request, final Response response) {
    // Not a conditional request
    if (request.preconditions.ifNoneMatch.isEmpty && 
        request.preconditions.ifModifiedSince.isEmpty) {
      return false;
    }
    
    bool matchingTag =   
        response.entityTag.expand((final EntityTag responseTag) => 
            firstWhere(request.preconditions.ifNoneMatch, (final EntityTag preconditionTag) {
              EntityTag strong = (!responseTag.isWeak) ? 
                  responseTag : new EntityTag.strong(responseTag.value);
            
              return (responseTag == preconditionTag) || (responseTag == strong);
            })).isEmpty;

    bool unmodifiedSince = 
        (!request.preconditions.ifModifiedSince.isEmpty && 
         !response.lastModified.isEmpty) ?
            request.preconditions
              .ifModifiedSince.value.compareTo(response.lastModified.value) >= 0 :
              false;

    
    return matchingTag || unmodifiedSince;
  }
  
  final ImmutableSet<Method> _allowedMethods;
  final UniformResourceDelegate<T> _delegate;
  final Future<Response> _methodNotAllowedResponse;
  final Future<Response> _optionsResponse;
  
  _UniformResource._internal(final UniformResourceDelegate<T> delegate, final ImmutableSet<Method> allowedMethods) :
    _delegate = delegate,
    _allowedMethods = allowedMethods,
    _methodNotAllowedResponse = 
      new Future.value(
           new Response(
            Status.CLIENT_ERROR_METHOD_NOT_ALLOWED,
            allowedMethods : allowedMethods)),
   _optionsResponse = 
     new Future.value(
         new Response(
            Status.SUCCESS_OK,
            allowedMethods : allowedMethods,
            entity : Status.SUCCESS_OK.message
          ));
  
  Route get route {
    return _delegate.route;
  }
  
  Future<Response> acceptMessage(final Request request) {
    if (request.method == Method.POST) {
      return _delegate.post(request);
    } else if (request.method == Method.PUT) {
      return _delegate.put(request);
    } else if (request.method == Method.PATCH) {
      return _delegate.patch(request);
    } else {
      throw new ArgumentError("Request method: " + request.method.toString() + " is not a valid argument to UniformResource.acceptMessage().");
    }
  }
  
  Future<Response> _checkUpdateConditions(final Request request) {
    return _delegate.get(request)
        .then((final Response response) {
          if (response.status.statusClass != StatusClass.SUCCESS) {
            return response;
          } 
          
          if (_delegate.requireETagForUpdate && !response.entityTag.isEmpty) {
            if (request.preconditions.ifMatch.isEmpty) {
              return CLIENT_ERROR_FORBIDDEN;
            } 
            
            if ((!response.entityTag.value.isWeak) &&
                request.preconditions.ifNoneMatch.contains(response.entityTag.value)) {
              return INFORMATIONAL_CONTINUE;
            } 
            
            final EntityTag strong = new EntityTag.strong(response.entityTag.value.value);
            if (request.preconditions.ifMatch.contains(response.entityTag.value) ||
                request.preconditions.ifMatch.contains(strong)) {
              return INFORMATIONAL_CONTINUE;
            } 
            
            return CLIENT_ERROR_PRECONDITION_FAILED;
          } 
          
          if (_delegate.requireIfUnmodifiedSinceForUpdate && 
              !response.lastModified.isEmpty) {
            if (!request.preconditions.ifUnmodifiedSince.isEmpty) {
              return CLIENT_ERROR_FORBIDDEN;
            } 
            
            if (request.preconditions.ifUnmodifiedSince.value.compareTo(response.lastModified.value) >= 0) {                 
              return INFORMATIONAL_CONTINUE;
            } 
            
            return CLIENT_ERROR_PRECONDITION_FAILED;
          } 
          
          return INFORMATIONAL_CONTINUE;
        });   
  }
  
  Future<Response> _conditionalGet(final Request request) {
    return _delegate.get(request)
        .then((final Response response){
          final Status responseStatus = response.status;

          if (responseStatus.statusClass != StatusClass.SUCCESS) {
            return response;
          } else if (_unmodified(request, response)) {
            return REDIRECTION_NOT_MODIFIED;
          } else {
            return response;
          }
        });
  }
  
  Request filterRequest(final Request request) =>
      request;
  
  Response filterResponse(final Response response) =>
      response;
  
  Future<Response<T>> handle(final Request request) {
    
    // Check if the method is supported by this resource
    if (!_allowedMethods.contains(request.method)) {
      return _methodNotAllowedResponse;
    }

    if ((request.method == Method.GET) || 
        (request.method == Method.HEAD)) {
      return _conditionalGet(request);
      
    } else if (request.method == Method.POST) {
      return _delegate.get(request)
                .then((final Response response) => 
                    (response.status.statusClass != StatusClass.SUCCESS) ?
                        response : INFORMATIONAL_CONTINUE);
      
    } else if ((request.method == Method.PUT) || 
        (request.method == Method.PATCH)) {
      return _checkUpdateConditions(request);
      
    } else if (request.method == Method.DELETE) {
      return _delegate.get(request)
              .then((final Response response) => 
                  (response.status.statusClass != StatusClass.SUCCESS) ?
                      response : _delegate.delete(request));
    } else if (request.method == Method.OPTIONS) {
      return this._optionsResponse;
    } else {
      // This should never happen
      throw new FallThroughError();
    }
  }
}

abstract class UniformResourceDelegate<T> {
  static ImmutableSet<Method> _getImplementedMethods(final UniformResourceDelegate delegate) {
    final MutableSet<Method> set = 
        new MutableSet.hash(elements:
            [Method.GET, Method.HEAD, 
             Method.OPTIONS, Method.DELETE,
             Method.PATCH, Method.POST, Method.PUT]);
    
    void testMethod(final Method methodName, method) {
      try {
        method(null);
      } on UnimplementedError {
        set.remove(methodName);
      } catch (e) {
      }
    }
    
    testMethod(Method.DELETE, delegate.delete);
    testMethod(Method.GET, delegate.get);
    testMethod(Method.HEAD, delegate.get);
    testMethod(Method.PATCH, delegate.patch);
    testMethod(Method.POST, delegate.post);
    testMethod(Method.PUT, delegate.put);

    return Persistent.EMPTY_SET.addAll(set);
  }
  
  bool get requireETagForUpdate;
  
  bool get requireIfUnmodifiedSinceForUpdate;
  
  Route get route;
  
  Future<Response> delete(Request request) =>
      throw new UnimplementedError();
  
  Future<Response> get(Request request) =>
      throw new UnimplementedError();
  
  Future<Response> patch(Request<T> request) =>
      throw new UnimplementedError();
  
  Future<Response> post(Request<T> request) =>
      throw new UnimplementedError();
  
  Future<Response> put(Request<T> request) =>
      throw new UnimplementedError();
}

