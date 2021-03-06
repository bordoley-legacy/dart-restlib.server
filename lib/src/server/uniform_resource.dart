part of server;

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
            statuses.CLIENT_ERROR_METHOD_NOT_ALLOWED,
            allowedMethods : allowedMethods)),
   _optionsResponse =
     new Future.value(
         new Response(
            statuses.SUCCESS_OK,
            allowedMethods : allowedMethods,
            entity : statuses.SUCCESS_OK.message
          ));

  Route get route {
    return _delegate.route;
  }

  Future<Response> acceptMessage(final Request request) {
    if (request.method == POST) {
      return _delegate.post(request);
    } else if (request.method == PUT) {
      return _delegate.put(request);
    } else if (request.method == PATCH) {
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
          if (response.status.statusClass != StatusClass.SUCCESS) {
            return response;
          } else if (_unmodified(request, response)) {
            return REDIRECTION_NOT_MODIFIED;
          } else {
            return response;
          }
        });
  }

  Request filterRequest(final Request request) =>
      _delegate.filterRequest(request);

  Response filterResponse(final Response response) =>
      _delegate.filterResponse(response);

  Future<Response<T>> handle(final Request request) {

    // Check if the method is supported by this resource
    if (!_allowedMethods.contains(request.method)) {
      return _methodNotAllowedResponse;
    }

    if ((request.method == GET) ||
        (request.method == HEAD)) {
      return _conditionalGet(request);

    } else if (request.method == POST) {
      return _delegate.get(request)
                .then((final Response response) =>
                    (response.status.statusClass != StatusClass.SUCCESS) ?
                        response : INFORMATIONAL_CONTINUE);

    } else if ((request.method == PUT) ||
        (request.method == PATCH)) {
      return _checkUpdateConditions(request);

    } else if (request.method == DELETE) {
      return _delegate.get(request)
              .then((final Response response) =>
                  (response.status.statusClass != StatusClass.SUCCESS) ?
                      response : _delegate.delete(request));
    } else if (request.method == OPTIONS) {
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
            [GET, HEAD,
             OPTIONS, DELETE,
             PATCH, POST, PUT]);

    void testMethod(final Method methodName, method) {
      try {
        method(null);
      } on UnimplementedError {
        set.remove(methodName);
      } catch (e) {
      }
    }

    testMethod(DELETE, delegate.delete);
    testMethod(GET, delegate.get);
    testMethod(HEAD, delegate.get);
    testMethod(PATCH, delegate.patch);
    testMethod(POST, delegate.post);
    testMethod(PUT, delegate.put);

    return EMPTY_SET.addAll(set);
  }

  bool get requireETagForUpdate;

  bool get requireIfUnmodifiedSinceForUpdate;

  Route get route;

  Future<Response> delete(Request request) =>
      throw new UnimplementedError();

  Request filterRequest(Request request) =>
      request;

  Response filterResponse(Response response) =>
      response;

  Future<Response> get(Request request) =>
      throw new UnimplementedError();

  Future<Response> patch(Request<T> request) =>
      throw new UnimplementedError();

  Future<Response> post(Request<T> request) =>
      throw new UnimplementedError();

  Future<Response> put(Request<T> request) =>
      throw new UnimplementedError();
}

