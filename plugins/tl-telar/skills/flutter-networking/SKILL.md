---
name: "flutter-networking"
description: "Canonical networking patterns for Flutter: `http` for simple apps, `dio` for apps that need interceptors, retry, cancellation, or multipart. Pick one — do not mix."
source_type: "skill"
source_file: "skills/flutter-networking.md"
---

# flutter-networking

Migrated from `skills/flutter-networking.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Flutter Networking

Canonical networking patterns for Flutter: `http` for simple apps, `dio` for apps that need interceptors, retry, cancellation, or multipart. Pick one — do not mix.

## Decision: `http` vs `dio`

| Concern | `http` | `dio` |
|---|---|---|
| Simple GET/POST with JSON | ✅ Best | ✅ |
| Interceptors (auth, logging) | ❌ Manual wrappers | ✅ First-class |
| Retry / timeout / cancellation | ❌ Hand-rolled | ✅ Built-in |
| Multipart with progress | ⚠️ Awkward | ✅ First-class |
| Form data, query serialization | ⚠️ Manual | ✅ First-class |
| Bundle size | ~20KB | ~60KB |
| Official package | ✅ `package:http` (Dart team) | ❌ Community (`cfug/dio`) |

**Pick `http` if:** you have <10 endpoints, no auth refresh, no file upload progress. Keep it as a thin wrapper behind your repositories so you can swap later.

**Pick `dio` if:** you need a token-refresh interceptor, want typed error mapping, upload files with progress, or cancel in-flight requests. This covers most apps.

Cross-ref: for RN (axios) and Apollo/GraphQL patterns see the `mobile-api-integration` agent.

## `http` — the simple path

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class UserRepository {
  UserRepository(this._client, this._baseUrl);
  final http.Client _client;
  final Uri _baseUrl;

  Future<User> fetchUser(String id) async {
    final res = await _client.get(
      _baseUrl.resolve('/users/$id'),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw ApiException(res.statusCode, res.body);
    }
    return User.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
```

Inject `http.Client` so tests can swap in `MockClient`. Close it when the app shuts down (`client.close()`).

## `dio` — the default for non-trivial apps

### Base client

```dart
import 'package:dio/dio.dart';

Dio createDio({required String baseUrl}) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    sendTimeout: const Duration(seconds: 20),
    headers: {'Accept': 'application/json'},
    responseType: ResponseType.json,
  ));

  dio.interceptors.addAll([
    LoggingInterceptor(),
    AuthInterceptor(tokenStore: TokenStore.instance),
    RetryInterceptor(dio: dio),
  ]);

  return dio;
}
```

Order matters. Logging first (sees raw request), auth second (injects token), retry last (re-runs after auth refresh has already happened).

### Auth interceptor with refresh-race protection

The common bug: two requests 401 simultaneously, both trigger refresh, second refresh invalidates the first token. Guard with a single-flight `Completer`.

```dart
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.tokenStore});
  final TokenStore tokenStore;
  Completer<String?>? _refreshInFlight;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = tokenStore.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['retried'] == true;
    if (!isUnauthorized || alreadyRetried) {
      return handler.next(err);
    }

    final newToken = await _refresh();
    if (newToken == null) {
      return handler.next(err);
    }

    final opts = err.requestOptions
      ..headers['Authorization'] = 'Bearer $newToken'
      ..extra['retried'] = true;

    try {
      final response = await Dio().fetch(opts);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<String?> _refresh() {
    final existing = _refreshInFlight;
    if (existing != null) return existing.future;

    final completer = _refreshInFlight = Completer<String?>();
    tokenStore.refresh().then((token) {
      completer.complete(token);
    }).catchError((Object e) {
      completer.complete(null);
    }).whenComplete(() {
      _refreshInFlight = null;
    });
    return completer.future;
  }
}
```

### Retry interceptor with exponential backoff

```dart
class RetryInterceptor extends Interceptor {
  RetryInterceptor({required this.dio, this.maxAttempts = 3});
  final Dio dio;
  final int maxAttempts;

  static const _retriableStatus = {408, 429, 500, 502, 503, 504};

  bool _shouldRetry(DioException err) {
    if (err.type == DioExceptionType.cancel) return false;
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }
    final status = err.response?.statusCode;
    return status != null && _retriableStatus.contains(status);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final attempt = (err.requestOptions.extra['retryAttempt'] as int? ?? 0);
    if (attempt >= maxAttempts || !_shouldRetry(err)) {
      return handler.next(err);
    }

    final delay = Duration(milliseconds: 300 * (1 << attempt));
    await Future.delayed(delay);

    final opts = err.requestOptions..extra['retryAttempt'] = attempt + 1;
    try {
      final response = await dio.fetch(opts);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
```

Honour `Retry-After` when present (parse as seconds or HTTP-date). Never retry POST/PUT/PATCH blindly — only on timeouts or 5xx, never on 4xx.

### Logging interceptor

For production, use `dio`'s built-in `LogInterceptor(requestBody: true, responseBody: true)` gated behind `kDebugMode`. Never log `Authorization` headers or request bodies containing tokens.

```dart
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('→ ${options.method} ${options.uri}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('← ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }
}
```

## Typed error mapping

Map `DioException` to your domain errors at the repository boundary — UI code should never see `DioException`.

```dart
sealed class AppError implements Exception {}
class NetworkError extends AppError {}
class ServerError extends AppError {
  ServerError(this.status, this.message);
  final int status;
  final String message;
}
class UnauthorizedError extends AppError {}
class TimeoutError extends AppError {}

AppError mapDioError(DioException e) {
  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => TimeoutError(),
    DioExceptionType.connectionError => NetworkError(),
    DioExceptionType.badResponse => switch (e.response?.statusCode) {
        401 => UnauthorizedError(),
        final int s => ServerError(s, e.response?.data?.toString() ?? ''),
        null => NetworkError(),
      },
    _ => NetworkError(),
  };
}
```

## Multipart upload with progress

```dart
Future<void> uploadAvatar(File file, void Function(double) onProgress) async {
  final form = FormData.fromMap({
    'avatar': await MultipartFile.fromFile(
      file.path,
      filename: 'avatar.jpg',
      contentType: DioMediaType('image', 'jpeg'),
    ),
  });

  await dio.post(
    '/users/me/avatar',
    data: form,
    onSendProgress: (sent, total) {
      if (total > 0) onProgress(sent / total);
    },
  );
}
```

## Cancellation

Cancel in-flight requests when the user navigates away. Tie a `CancelToken` to the widget lifecycle.

```dart
class _ProductListState extends State<ProductList> {
  final _cancel = CancelToken();

  @override
  void dispose() {
    _cancel.cancel('widget disposed');
    super.dispose();
  }

  Future<List<Product>> _load() async {
    final res = await dio.get('/products', cancelToken: _cancel);
    return (res.data as List).map((e) => Product.fromJson(e)).toList();
  }
}
```

With Riverpod, pair `ref.onDispose` with `CancelToken.cancel` inside a `FutureProvider` for the same effect at the provider level.

## Testing

### `http` with `MockClient`

```dart
import 'package:http/testing.dart';

test('fetchUser parses response', () async {
  final mock = MockClient((req) async {
    expect(req.url.path, '/users/42');
    return http.Response('{"id":"42","name":"Ada"}', 200);
  });
  final repo = UserRepository(mock, Uri.parse('https://api.test'));
  final user = await repo.fetchUser('42');
  expect(user.name, 'Ada');
});
```

### `dio` with `DioAdapter` (from `http_mock_adapter`)

```dart
import 'package:http_mock_adapter/http_mock_adapter.dart';

test('retry interceptor retries 503 twice', () async {
  final dio = Dio();
  dio.interceptors.add(RetryInterceptor(dio: dio, maxAttempts: 3));
  final adapter = DioAdapter(dio: dio);

  adapter
    ..onGet('/ping', (s) => s.reply(503, 'down'), count: 2)
    ..onGet('/ping', (s) => s.reply(200, 'ok'));

  final response = await dio.get('/ping');
  expect(response.statusCode, 200);
});
```

## Best Practices

- **Pick one package** — `http` or `dio`, not both
- **Inject the client** so tests can swap it (constructor-injected `Dio`/`Client`, not a global)
- **Wrap at the repository boundary** — never let `DioException` escape into UI code
- **Guard refresh with a single-flight `Completer`** to prevent refresh-token races
- **Retry only idempotent requests** unless you have idempotency keys
- **Cancel requests on widget dispose** to avoid `setState after dispose` errors
- **Gate verbose logging behind `kDebugMode`** and redact `Authorization` headers

## Common Pitfalls

- Two concurrent 401s each triggering a refresh — fix with `_refreshInFlight` completer
- Retrying POST without idempotency — creates duplicate side effects
- Leaking `CancelToken` across screens — each screen needs its own
- `setState` after widget disposed because response arrives late — cancel on dispose
- Forgetting to close `http.Client` on app shutdown
- Mixing `http` and `dio` — two auth paths means two bugs
- Logging bearer tokens to crashlytics — redact `Authorization` and request bodies before logging
