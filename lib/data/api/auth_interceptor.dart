import 'package:dio/dio.dart';

import 'backend_results.dart';
import 'device_token_store.dart';

/// Sentinel carried in a [DioException.error] when a quota-protected request
/// cannot be authorized, so the client can surface the precise reason without
/// the interceptor needing to know about each endpoint's failure type.
class AuthFailure {
  const AuthFailure(this.reason);

  final BackendFailureReason reason;
}

/// Attaches the device token to quota-protected requests and recovers from a
/// rejected one: on a 403 it re-registers **once** (single-flight across
/// concurrent calls) and retries the request exactly once. Registration
/// requests pass through untouched (they authenticate with the device id).
///
/// Why an interceptor (rather than recovery in each client method): the token
/// lifecycle — attach, detect rejection, refresh, retry — is identical for
/// every quota endpoint, so centralising it here keeps `WraitBackendClient`'s
/// methods free of auth plumbing and guarantees uniform behaviour.
///
/// Single-flight: a burst of concurrent 403s must trigger only one
/// re-registration. The first caller into [_reRegisterOnce] stores its future
/// in [_inFlight]; the rest await that same future instead of registering
/// again. The slot is cleared when the originating future settles, so the next
/// burst re-registers afresh.
///
/// Separate registrar Dio: [reRegister] runs on an interceptor-free Dio (see
/// `deviceRegistrarProvider`). That both avoids re-entering this interceptor
/// (which would deadlock on the in-flight request) and breaks the Riverpod
/// provider cycle backendDio -> wraitBackendClient -> generatedClient ->
/// backendDio that would otherwise be created the moment re-registration ran.
///
/// Retrying a [FormData] body: a multipart body is single-use (the first send
/// finalises its stream), so the retry carries a fresh clone — see
/// [_rewindBody].
///
/// The token value is never logged (enforced by device_token_log_audit_test).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.deviceTokenStore,
    required this.reRegister,
  });

  static const _retriedKey = 'authRetried';
  static const _tokenHeader = 'X-Device-Token';
  static const _registerPath = '/api/register';

  final Dio dio;
  final DeviceTokenStore deviceTokenStore;

  /// Re-registers and (on success) persists a fresh token to [deviceTokenStore].
  /// Runs on a separate, interceptor-free Dio so it never deadlocks on this one.
  final Future<RegistrationResult> Function() reRegister;

  Future<RegistrationResult>? _inFlight;

  bool _skip(RequestOptions options) => options.path.endsWith(_registerPath);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // The retried request already carries its fresh token.
    if (_skip(options) || options.extra[_retriedKey] == true) {
      return handler.next(options);
    }

    final (token, reason) = await _ensureToken();
    if (token == null) {
      return handler.reject(_authError(options, reason), true);
    }
    options.headers[_tokenHeader] = token;
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final options = response.requestOptions;
    if (_skip(options) ||
        response.statusCode != 403 ||
        options.extra[_retriedKey] == true) {
      return handler.next(response);
    }

    final (token, reason) = await _ensureToken(forceReRegister: true);
    if (token == null) {
      return handler.reject(_authError(options, reason), true);
    }

    options
      ..extra[_retriedKey] = true
      ..headers[_tokenHeader] = token
      // A FormData body is single-use: the first send finalized it, so the
      // retry must carry a fresh clone or Dio throws "already finalized".
      ..data = _rewindBody(options.data);
    try {
      handler.resolve(await dio.fetch<dynamic>(options));
    } on DioException catch (error) {
      handler.reject(error, true);
    }
  }

  /// Returns a usable token, re-registering when needed. On failure the token is
  /// null and the second element is the reason to surface.
  Future<(String? token, BackendFailureReason reason)> _ensureToken({
    bool forceReRegister = false,
  }) async {
    if (!forceReRegister) {
      final stored = await deviceTokenStore.read();
      if (stored != null) {
        return (stored, BackendFailureReason.credentialRejected);
      }
    }

    final failure = await _reRegisterOnce();
    if (failure != null) {
      return (null, failure);
    }
    final fresh = await deviceTokenStore.read();
    return (fresh, BackendFailureReason.credentialRejected);
  }

  /// Re-registers at most once per concurrent burst; null on success, else the
  /// mapped failure reason.
  Future<BackendFailureReason?> _reRegisterOnce() async {
    final future = _inFlight ??= reRegister();
    try {
      return switch (await future) {
        RegistrationSuccess() => null,
        RegistrationFailure(reason: final reason) => switch (reason) {
          RegistrationFailureReason.rateLimited =>
            BackendFailureReason.rateLimited,
          RegistrationFailureReason.proxyAuthFailed =>
            BackendFailureReason.proxyAuthFailed,
          RegistrationFailureReason.transient =>
            BackendFailureReason.backendUnavailable,
          RegistrationFailureReason.apiError => BackendFailureReason.apiError,
        },
      };
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  /// A [FormData] body can only be streamed once, so return a clone for the
  /// retry; any other body is immutable here and reused as-is.
  dynamic _rewindBody(dynamic data) =>
      data is FormData ? data.clone() : data;

  DioException _authError(RequestOptions options, BackendFailureReason reason) =>
      DioException(
        requestOptions: options,
        error: AuthFailure(reason),
        type: DioExceptionType.unknown,
      );
}
