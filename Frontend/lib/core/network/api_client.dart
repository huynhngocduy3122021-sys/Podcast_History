import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_endpoints.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic details;

  ApiException({
    required this.statusCode,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'ApiException [$statusCode]: $message';
}

class ApiClient {
  String _baseUrl;
  String? _accessToken;
  final http.Client _client;

  ApiClient({
    String? baseUrl,
    String? initialToken,
    http.Client? client,
  })  : _baseUrl = baseUrl ?? _resolveDefaultBaseUrl(),
        _accessToken = initialToken,
        _client = client ?? http.Client();

  static String _resolveDefaultBaseUrl() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return ApiEndpoints.emulatorBaseUrl;
    }
    return ApiEndpoints.defaultBaseUrl;
  }

  String get baseUrl => _baseUrl;
  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  String? get accessToken => _accessToken;
  void setToken(String? token) {
    _accessToken = token;
  }

  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;

  Map<String, String> _buildHeaders([Map<String, String>? extra]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': '1',
    };
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  Uri _buildUri(String endpoint, [Map<String, dynamic>? queryParams]) {
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final fullUrl = '$_baseUrl$cleanEndpoint';
    final baseUri = Uri.parse(fullUrl);
    if (queryParams != null && queryParams.isNotEmpty) {
      final stringParams = queryParams.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );
      return baseUri.replace(queryParameters: stringParams);
    }
    return baseUri;
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint, queryParams);
    _log('GET $uri');
    try {
      final response = await _client.get(uri, headers: _buildHeaders(headers));
      return _handleResponse(response);
    } catch (e) {
      _logError('GET $uri', e);
      rethrow;
    }
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint);
    _log('POST $uri body: $body');
    try {
      final response = await _client.post(
        uri,
        headers: _buildHeaders(headers),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      _logError('POST $uri', e);
      rethrow;
    }
  }

  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint);
    _log('PUT $uri body: $body');
    try {
      final response = await _client.put(
        uri,
        headers: _buildHeaders(headers),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      _logError('PUT $uri', e);
      rethrow;
    }
  }

  Future<dynamic> delete(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint);
    _log('DELETE $uri');
    try {
      final response = await _client.delete(uri, headers: _buildHeaders(headers));
      return _handleResponse(response);
    } catch (e) {
      _logError('DELETE $uri', e);
      rethrow;
    }
  }

  Future<dynamic> uploadMultipart(
    String endpoint, {
    required String fileFieldName,
    required String filename,
    List<int>? fileBytes,
    String? mimeType,
    Map<String, String>? fields,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint, queryParams);
    _log('MULTIPART POST $uri with file: $filename ($fileFieldName)');
    try {
      final request = http.MultipartRequest('POST', uri);
      final requestHeaders = _buildHeaders(headers);
      requestHeaders.remove('Content-Type'); // MultipartRequest sets boundary automatically
      request.headers.addAll(requestHeaders);

      if (fields != null) {
        request.fields.addAll(fields);
      }

      if (fileBytes != null && fileBytes.isNotEmpty) {
        MediaType? parsedMediaType;
        if (mimeType != null && mimeType.contains('/')) {
          final parts = mimeType.split('/');
          parsedMediaType = MediaType(parts[0], parts[1]);
        }
        request.files.add(
          http.MultipartFile.fromBytes(
            fileFieldName,
            fileBytes,
            filename: filename,
            contentType: parsedMediaType,
          ),
        );
      }

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } catch (e) {
      _logError('MULTIPART POST $uri', e);
      rethrow;
    }
  }

  dynamic _handleResponse(http.Response response) {
    _log('Status: ${response.statusCode}, Body: ${response.body}');
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return const <String, dynamic>{'success': true};
      }
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        // Check if standard wrapper format { success: true, data: ... }
        if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          return decoded['data'];
        }
        return decoded;
      } catch (_) {
        return response.body;
      }
    }

    String errorMessage = 'Yêu cầu không thành công (${response.statusCode})';
    dynamic errorDetails;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        errorMessage = decoded['message'] ?? decoded['error'] ?? decoded['detail'] ?? errorMessage;
        errorDetails = decoded;
      }
    } catch (_) {
      errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: errorMessage,
      details: errorDetails,
    );
  }

  void _log(String message) {
    if (kDebugMode) {
      dev.log('[ApiClient] $message');
    }
  }

  void _logError(String context, Object error) {
    if (kDebugMode) {
      dev.log('[ApiClient ERROR] $context -> $error');
    }
  }
}
