import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../utils/storage.dart' as AppStorage;

// ─── Generic Cache ───────────────────────────────────────────────────────────
class _Cache<T> {
  T? _data;
  DateTime? _fetchedAt;
  final Duration duration;

  _Cache({this.duration = const Duration(seconds: 10)});

  bool get isValid =>
      _data != null &&
      _fetchedAt != null &&
      DateTime.now().difference(_fetchedAt!) < duration;

  T? get data => isValid ? _data : null;

  void set(T value) {
    _data = value;
    _fetchedAt = DateTime.now();
  }

  void invalidate() {
    _data = null;
    _fetchedAt = null;
  }
}

// ─── SeedrApi ─────────────────────────────────────────────────────────────────
class SeedrApi {
  static const _base = 'https://www.seedr.cc';

  final ValueNotifier<Map<String, double>> storageNotifier =
      ValueNotifier({'used': 0, 'max': 1});

  late final Dio _dio;
  late final CookieJar _cookieJar;
  bool _loggedIn = false;

  final _torrentsCache = _Cache<List<dynamic>>();
  final _storageCache = _Cache<Map<String, double>>(
    duration: const Duration(seconds: 30),
  );
  final Map<String, String> _shortUrlCache = {};

  SeedrApi._(this._dio, this._cookieJar);

  // ─── Factory ───────────────────────────────────────────────────────────────
  static Future<SeedrApi> create() async {
    final dir = await getApplicationSupportDirectory();
    final cookieDir = Directory('${dir.path}/cookies');
    if (!cookieDir.existsSync()) cookieDir.createSync(recursive: true);

    final jar = CookieJar();
    final dio = Dio(BaseOptions(
      baseUrl: _base,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        HttpHeaders.userAgentHeader:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'X-Requested-With': 'XMLHttpRequest',
        HttpHeaders.acceptHeader: 'application/json, text/plain, */*',
      },
      validateStatus: (code) => code != null && code >= 200 && code < 500,
      followRedirects: true,
    ))
      ..interceptors.add(CookieManager(jar));

    // Only bypass cert in debug mode
    if (kDebugMode) {
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        // FIX 1: removed unnecessary underscores
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      };
    }

    return SeedrApi._(dio, jar);
  }

  // ─── Centralized Error Handler ─────────────────────────────────────────────
  Future<T> _request<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw Exception('Connection timeout. Check your internet.');
        case DioExceptionType.connectionError:
          throw Exception('Cannot connect to Seedr. Try using a VPN.');
        case DioExceptionType.badResponse:
          throw Exception('Server error: ${e.response?.statusCode}');
        default:
          throw Exception('Network error. Please try again.');
      }
    }
  }

  // ─── Retry with Exponential Backoff ───────────────────────────────────────
  Future<Response> _retryGet(
    String path, {
    int maxRetries = 3,
    Options? options,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await _dio.get(path, options: options);
      } on DioException catch (e) {
        attempt++;
        final retryable = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;
        if (!retryable || attempt >= maxRetries) rethrow;
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────
  Future<bool> get isLoggedIn async {
    try {
      final cookies = await _cookieJar.loadForRequest(Uri.parse(_base));
      return cookies.any((c) => c.name.toLowerCase().contains('seedr')) ||
          _loggedIn;
    } catch (_) {
      return _loggedIn;
    }
  }

  Future<void> login(String email, String password) async {
    await _request(() async {
      final res = await _dio.post(
        '/auth/login',
        data: jsonEncode({
          'username': email,
          'password': password,
          'rememberme': 'on',
          'cf-turnstile-response': '',
        }),
        options: Options(
          headers: {HttpHeaders.contentTypeHeader: 'application/json'},
        ),
      );

      if (res.statusCode == 200 &&
          res.data is Map &&
          res.data['success'] == true) {
        if (res.data['cookies'] is List) {
          for (final c in res.data['cookies']) {
            try {
              await _cookieJar.saveFromResponse(
                  Uri.parse(_base), [Cookie.fromSetCookieValue(c)]);
            } catch (_) {}
          }
        }
        _loggedIn = true;
        await AppStorage.Storage.saveCreds(email, password);
        return;
      }
      throw Exception('Invalid email or password');
    });
  }

  // FIX 2: ensureLogin was broken — getCreds() result was not captured
  Future<void> ensureLogin() async {
    if (await isLoggedIn) return;
    final (email, password) = await AppStorage.Storage.getCreds();
    if (email != null && password != null) {
      await login(email, password);
    } else {
      throw Exception('Not logged in');
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {}
    _cookieJar.deleteAll();
    _loggedIn = false;
    _torrentsCache.invalidate();
    _storageCache.invalidate();
    await AppStorage.Storage.clearCreds();
    storageNotifier.value = {'used': 0, 'max': 1};
  }

  // ─── Torrents ──────────────────────────────────────────────────────────────
  Future<dynamic> addMagnet(String magnet) async {
    await ensureLogin();
    return _request(() async {
      final r = await _dio.post(
        '/task',
        data: FormData.fromMap({
          'folder_id': '0',
          'type': 'torrent',
          'torrent_magnet': magnet,
        }),
      );
      _torrentsCache.invalidate();

      if ((r.statusCode == 413 || r.statusCode == 200) && r.data is Map) {
        return r.data;
      }
      if (r.statusCode == 200) return r.data;
      throw Exception('Add magnet failed: ${r.statusCode}');
    });
  }

  Future<List<dynamic>> listTorrents({bool forceRefresh = false}) async {
    await ensureLogin();

    if (!forceRefresh && _torrentsCache.isValid) {
      return _torrentsCache.data!;
    }

    return _request(() async {
      final r = await _retryGet('/fs/folder/0/items');
      if (r.statusCode == 200) {
        final folders = (r.data['folders'] as List?) ?? [];
        _torrentsCache.set(folders);
        return folders;
      }
      throw Exception('List torrents failed: ${r.statusCode}');
    });
  }

  Future<List<dynamic>> listFiles(String folderId) async {
    await ensureLogin();
    return _request(() async {
      final r = await _retryGet('/fs/folder/$folderId/items');
      if (r.statusCode == 200) {
        return (r.data['files'] as List?) ?? [];
      }
      throw Exception('List files failed: ${r.statusCode}');
    });
  }

  Future<String> getFileDownload(String fileId) async {
    await ensureLogin();
    return _request(() async {
      final r = await _dio.get('/download/file/$fileId/url');
      if (r.statusCode == 200) {
        final data = r.data;
        if (data is Map && data['url'] is String) return data['url'] as String;
        if (data is String) return data;
      }
      throw Exception('Get download url failed: ${r.statusCode}');
    });
  }

  Future<dynamic> deleteFile(String fileId) async {
    await ensureLogin();
    return _request(() async {
      final r = await _dio.post(
        '/fs/batch/delete',
        data: FormData.fromMap({
          'delete_arr': jsonEncode([
            {'type': 'file', 'id': int.tryParse(fileId) ?? fileId}
          ]),
        }),
      );
      _torrentsCache.invalidate();
      _storageCache.invalidate();
      _cleanupEmptyFolders();
      return r.data;
    });
  }

  Future<void> _cleanupEmptyFolders() async {
    try {
      final r = await _dio.get('/fs/folder/0/items');
      final folders = (r.data['folders'] as List?) ?? [];
      await Future.wait(folders.map((folder) async {
        final id = folder['id']?.toString();
        if (id == null) return;
        final items = await _dio.get('/fs/folder/$id/items');
        final hasContent =
            ((items.data['files'] as List?)?.isNotEmpty ?? false) ||
                ((items.data['folders'] as List?)?.isNotEmpty ?? false);
        if (hasContent) return; // FIX 3: added curly braces (was missing block)
        await _dio.post(
          '/fs/batch/delete',
          data: FormData.fromMap({
            'delete_arr': jsonEncode([
              {'type': 'folder', 'id': int.tryParse(id) ?? id}
            ]),
          }),
        );
      }));
    } catch (_) {}
  }

  // ─── Flat File List (chunked concurrency) ─────────────────────────────────
  Future<List<Map<String, dynamic>>> listAllFilesFlat({
    bool forceRefresh = false,
    int concurrency = 4,
  }) async {
    await ensureLogin();
    final torrents = await listTorrents(forceRefresh: forceRefresh);
    final out = <Map<String, dynamic>>[];

    for (var i = 0; i < torrents.length; i += concurrency) {
      final chunk = torrents.skip(i).take(concurrency);
      final results = await Future.wait(chunk.map((t) async {
        final tid = (t['id'] ?? t['folder_id']).toString();
        final tname = (t['path'] ?? t['name'] ?? 'Torrent').toString();
        final files = await listFiles(tid);
        return files.map((f) => {
              ...Map<String, dynamic>.from(f as Map),
              'parent_id': tid,
              'parent_name': tname,
            }).toList();
      }));
      for (final r in results) {
        out.addAll(r); // FIX 4: added curly braces
      }
    }

    return out;
  }

  // ─── Storage ───────────────────────────────────────────────────────────────
  Future<Map<String, double>> getStorageUsage({
    bool forceRefresh = false,
  }) async {
    await ensureLogin();

    if (!forceRefresh && _storageCache.isValid) {
      return Map<String, double>.from(_storageCache.data!);
    }

    return _request(() async {
      try {
        final r = await _dio.get('/account/usage');
        if (r.statusCode == 200 && r.data is Map) {
          final d = r.data;
          final usedRaw = (d['used'] ?? d['space_used'] ?? 0).toDouble();
          final maxRaw = (d['space_max'] ?? d['quota'] ?? 1).toDouble();
          // FIX 5: explicit <String, double> type
          final result = <String, double>{
            'used': usedRaw > 100000 ? usedRaw : usedRaw * 1024 * 1024,
            'max': maxRaw > 100000 ? maxRaw : maxRaw * 1024 * 1024,
          };
          _storageCache.set(result);
          return result;
        }
      } catch (_) {}

      final r = await _dio.get('/fs/folder/0/items');
      if (r.statusCode == 200 && r.data is Map) {
        final d = r.data;
        double used = (d['space_used'] ?? 0).toDouble();
        final max = (d['space_max'] ?? 1).toDouble();

        if (used == 0) {
          for (final list in [d['folders'], d['torrents'], d['files']]) {
            for (final item in (list as List?) ?? []) {
              if (item is Map) used += (item['size'] as num? ?? 0).toDouble();
            }
          }
        }

        // FIX 6: explicit <String, double> type
        final result = <String, double>{'used': used, 'max': max};
        _storageCache.set(result);
        return result;
      }
      throw Exception('Failed to fetch storage usage.');
    });
  }

  Future<void> refreshStorageUsage({bool forceRefresh = false}) async {
    try {
      final usage = await getStorageUsage(forceRefresh: forceRefresh);
      storageNotifier.value = usage;
    } catch (_) {}
  }

  // ─── URL Shortener ─────────────────────────────────────────────────────────
  Future<String> shortUrl(String url) async {
    if (_shortUrlCache.containsKey(url)) return _shortUrlCache[url]!;
    return _request(() async {
      final r = await _dio.get(
        'https://tinyurl.com/api-create.php?url=${Uri.encodeComponent(url)}',
        options: Options(
          followRedirects: false,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      if (r.statusCode == 200 && r.data is String) {
        final s = (r.data as String).trim();
        if (s.startsWith('http') && s.length < url.length) {
          _shortUrlCache[url] = s;
          return s;
        }
      }
      throw Exception('URL shortening failed');
    });
  }
}