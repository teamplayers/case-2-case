import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

String apiBase() {
  const fromEnv = String.fromEnvironment('API_BASE');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8765';
  }
  return 'http://127.0.0.1:8765';
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Api {
  Api();

  String? token;

  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    if (token != null && token!.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${apiBase()}$path').replace(queryParameters: query);
  }

  dynamic _decode(http.Response res) {
    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (_) {
      data = {'detail': res.body};
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_detail(data) ?? 'Request failed (${res.statusCode})');
    }
    return data;
  }

  String? _detail(dynamic data) {
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) return d;
      if (d is List && d.isNotEmpty) {
        final first = d.first;
        if (first is Map && first['msg'] != null) return first['msg'].toString();
        return first.toString();
      }
    }
    return null;
  }

  Future<dynamic> get(String path, [Map<String, String>? query]) async {
    final res = await http.get(_uri(path, query), headers: _headers(json: false));
    return _decode(res);
  }

  Future<dynamic> post(String path, [Object? body]) async {
    final res = await http.post(
      _uri(path),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Future<dynamic> patch(String path, Object body) async {
    final res = await http.patch(_uri(path), headers: _headers(), body: jsonEncode(body));
    return _decode(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await http.delete(_uri(path), headers: _headers(json: false));
    return _decode(res);
  }

  Future<dynamic> upload(String path, PlatformFile file) async {
    final req = http.MultipartRequest('POST', _uri(path));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (file.bytes != null) {
      req.files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));
    } else if (file.path != null) {
      req.files.add(await http.MultipartFile.fromPath('file', file.path!, filename: file.name));
    } else {
      throw ApiException('Could not read the selected file');
    }
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  }
}
