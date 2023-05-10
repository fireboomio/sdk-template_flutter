import 'dart:convert';

import 'package:dio/dio.dart';

import 'interface.dart';

typedef Headers = Map<String, String>;

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
      var ret = await fn();
      var resp = GraphqlResponse.fromJson(ret.data! as Map<String, dynamic>);
      if (resp.errors == null) {
        return TransformedResponse(error: false, data: resp.data);
      }
      return TransformedResponse(
          error: true, message: resp.errors!.map((e) => e.message).join("\n"));
    } on DioError catch (e) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx and is also not 304.
      var msg = '';
      if (e.response != null) {
        msg = e.response!.data ?? e.response!.statusMessage;
      }
      if (msg.isEmpty) {
        msg = e.message ?? '发生错误';
      }
      return TransformedResponse(error: true, message: msg);
    }
  }

  BaseClient(BaseClientOptions options) {
    this._options = options;
    this._dio = Dio(BaseOptions(baseUrl: options.baseURL!));
    this._dio.interceptors.add(NullParamInterceptor());
    if (options.onInit != null) {
      options.onInit!(this._dio);
    }
    // (this._dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate =
    //     (Uri) {
    //   Uri.findProxy = (url) {
    //     return 'PROXY 127.0.0.1:8888';
    //   };

    //   return null;
    // };
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
  Future<TransformedResponse> doQuery(QueryRequestOptions options) async {
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

  Future<TransformedResponse> doMutate(MutationRequestOptions options) async {
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

  Stream<String> doSubscribe(SubscriptionRequestOptions options) async* {
    var input = options.input ?? {};
    input['useSSE'] = true;
    try {
      var resp = await _dio.get<ResponseBody>(
        "/operations/${options.operationName}",
        cancelToken: options.cancelToken,
        queryParameters: input,
        options: Options(
            responseType: ResponseType.stream,
            headers: {...?_options.extraHeaders}),
      );
      var stream = resp.data!.stream;
      await for (var event in stream) {
        var eventData = String.fromCharCodes(event);
        yield eventData;
      }
    } catch (e) {
      throw e;
    }
  }

  bool _validateFiles() {
    // TODO
    return true;
  }

  Future<TransformedResponse<List<String>>> doUploadFiles(
      UploadRequestOptions config,
      {UploadValidationOptions? validation}) async {
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

    try {
      var ret = await _dio.post(
        "/s3/${config.provider}/upload",
        data: formData,
        options: Options(
          headers: {...?_options.extraHeaders, ...headers},
        ),
      );
      List<String> list = [];
      for (var i = 0; i < ret.data.length; i++) {
        list.add(ret.data[i]['key']);
      }
      return TransformedResponse(
        error: false,
        data: list,
      );
    } on DioError catch (e) {
      var msg = '';
      if (e.response != null) {
        msg = e.response!.data ?? e.response!.statusMessage;
      }
      if (msg.isEmpty) {
        msg = e.message ?? '发生错误';
      }
      return TransformedResponse(error: true, message: msg);
    }
  }

  Future<bool> login(String authProviderID, username, password) {
    // TODO
    return Future.value(true);
  }

  logout(bool logoutOpenidConnectProvider) {
    unsetAuthorization();
  }

  Future<User?> fetchUser({FetchUserRequestOptions? options}) async {
    try {
      var resp = await _dio.get(
        "/auth/user",
        queryParameters:
            options?.revalidate ?? false ? {'revalidate': 'true'} : {},
        cancelToken: options?.cancelToken,
        options: Options(
          headers: {...?_options.extraHeaders},
        ),
      );
      if (resp.data != null) {
        return User.fromJson(resp.data!);
      }
      return null;
    } on DioError catch (e) {
      print(e);
      return null;
    }
  }
}

class NullParamInterceptor extends Interceptor {
  @override
  Future onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // 移除值为null的查询参数
    options.queryParameters.removeWhere((key, value) => value == null);
    return super.onRequest(options, handler);
  }
}
