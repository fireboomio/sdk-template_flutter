import 'dart:convert';

import 'package:dio/dio.dart';

import 'interface.dart';

class TransformedResponse<T> {
  final T? data;
  final String? error;
  TransformedResponse(this.data, this.error);
}

typedef Headers = Map<String, String>;

class BaseClientOptions {
  String? baseURL;
  Headers? extraHeaders;
  OperationMetadata? operationMetadata;
  bool? csrfEnabled;
  BaseClientOptions(
      {this.extraHeaders,
      this.operationMetadata,
      this.csrfEnabled,
      this.baseURL});
}

class BaseClient {
  late final Dio _dio;
  late final BaseClientOptions _options;
  String? _csrfToken;

  isAuthenticatedOperation(String operationName) {
    return _options.operationMetadata?.metadata[operationName]
            ?.requiresAuthentication ??
        false;
  }

  Future<TransformedResponse> _wrapRequest<T>(
      Future<Response<T>> Function() fn) async {
    try {
      var resp = await fn();
      return TransformedResponse(resp.data!, null);
    } on DioError catch (e) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx and is also not 304.
      if (e.response != null) {
        return TransformedResponse(null, e.response!.data);
      } else {
        return TransformedResponse(null, e.message);
      }
    }
  }

  BaseClient(BaseClientOptions options) {
    this._options = options;
    this._dio = Dio(BaseOptions(baseUrl: options.baseURL!));
  }

  setExtraHeaders(Headers headers) {
    _options.extraHeaders = {...?_options.extraHeaders, ...headers};
  }

  /// setAuthorizationToken is a shorthand method for setting up the
  /// required headers for token authentication.
  ///
  /// @param token Bearer token
  setAuthorizationToken(String token) {
    setExtraHeaders({'Authorization': 'Bearer $token'});
  }

  /// unsetAuthorization removes any previously set authorization credentials
  /// (e.g. via setAuthorizationToken or via setExtraHeaders).
  /// If there was no authorization set, it does nothing.
  unsetAuthorization() {
    _options.extraHeaders?.remove('Authorization');
  }

  /// Query makes a GET request to the server.
  /// The method only throws an error if the request fails to reach the server or
  /// the server returns a non-200 status code. Application errors are returned as part of the response.
  Future<TransformedResponse> query(QueryRequestOptions options) async {
    if (options.subscribeOnce ?? false) {
      options.input = {
        ...?options.input,
        ...{'wg_subscribe_once': 'true'}
      };
    }
    return _wrapRequest(() => _dio.get("/operations/${options.operationName}",
        queryParameters: options.input,
        cancelToken: options.cancelToken,
        options: Options(headers: {...?_options.extraHeaders})));
  }

  Future<String> _getCSRFToken() async {
    // request a new CSRF token if we don't have one
    if (_csrfToken == null || _csrfToken!.isEmpty) {
      Response resp = await _dio.get("/auth/cookie/csrf",
          options: Options(headers: {
            ...?_options.extraHeaders,
            'Accept': 'text/plain',
          }, responseType: ResponseType.plain));
      _csrfToken = resp.data;
      if (_csrfToken == null || _csrfToken!.isEmpty) {
        return Future.error(
            'Failed to get CSRF token. Please make sure you are authenticated.');
      }
    }
    return _csrfToken!;
  }

  Future<TransformedResponse> mutate(OperationRequestOptions options) async {
    Headers headers = {};

    if (isAuthenticatedOperation(options.operationName) &&
        _options.csrfEnabled!) {
      headers['X-CSRF-Token'] = await _getCSRFToken();
    }
    return _wrapRequest(() => _dio.post(
          "/operations/${options.operationName}",
          data: options.input,
          cancelToken: options.cancelToken,
          options: Options(headers: {...?_options.extraHeaders, ...headers}),
        ));
  }

  Future<void> subscribe(String operationName, Map<String, dynamic>? input,
      void Function(TransformedResponse) cb) {
    input = input ?? {};
    input['useSSE'] = true;
    return _wrapRequest(() => _dio.get(
          "/operations/$operationName",
          queryParameters: input,
        ));
  }

  bool _validateFiles() {
    // TODO
    return true;
  }

  Future<UploadResponse> uploadFiles(
      UploadRequestOptions config, UploadValidationOptions? validation) async {
    _validateFiles();
    var formData = FormData.fromMap({"files": config.files});
    Headers headers = {};
    if (validation?.requireAuthentication == true && _options.csrfEnabled!) {
      headers['X-CSRF-Token'] = await _getCSRFToken();
    }

    if (config.profile != null) {
      headers['X-Upload-Profile'] = config.profile!;
    }

    if (config.meta != null) {
      headers['X-Metadata'] = jsonEncode(config.meta!);
    }

    var resp = await _wrapRequest(
        () => _dio.post("/s3/${config.provider}/upload", data: formData));

    if (resp.error != null) {
      return Future.error(resp.error!);
    }
    return UploadResponse.fromJson(resp.data);
  }

  Future<bool> login(String authProviderID, username, password) {
    // TODO
    return Future.value(true);
  }

  logout(bool logoutOpenidConnectProvider) {
    unsetAuthorization();
  }

  Future<User> fetchUser(FetchUserRequestOptions options) async {
    var resp = await _wrapRequest(() => _dio.get("/auth/user",
        queryParameters:
            options.revalidate ?? false ? {'revalidate': 'true'} : {},
        cancelToken: options.cancelToken,
        options: Options(headers: {...?_options.extraHeaders})));
    if (resp.error != null) {
      return Future.error(resp.error!);
    }
    return User.fromJson(resp.data!);
  }
}

Dio createClient(String baseUrl) {
  BaseOptions options = BaseOptions(baseUrl: baseUrl);
  return Dio(options);
}
