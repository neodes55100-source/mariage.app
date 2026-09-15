import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'app_config.dart';

class UploadResult {
  final bool ok;
  final String message;

  const UploadResult(this.ok, this.message);
}

class _SiteSession {
  final String csrf;
  final String cookie;

  const _SiteSession({required this.csrf, required this.cookie});
}

class UploadService {
  final http.Client _client = http.Client();

  Future<_SiteSession> _openSiteSession() async {
    final uri = Uri.parse('${AppConfig.siteBaseUrl}/upload.php');
    final response = await _client.get(uri, headers: const {
      'User-Agent': 'MariageEmmanuelJennifer/1.0',
      'Accept': 'text/html',
    });

    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw HttpException('Impossible d’ouvrir la session du site (${response.statusCode}).');
    }

    final match = RegExp(
      r'''name=["']csrf["'][^>]*value=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(response.body);

    if (match == null) {
      throw const FormatException('Jeton de sécurité introuvable.');
    }

    final rawCookie = response.headers['set-cookie'];
    if (rawCookie == null || rawCookie.isEmpty) {
      throw HttpException('Cookie de session introuvable.');
    }

    final sessionCookie = rawCookie.split(';').first.trim();
    return _SiteSession(csrf: match.group(1)!, cookie: sessionCookie);
  }

  Future<UploadResult> uploadFile({
    required File file,
    required String guestName,
    String? originalName,
    String? mimeType,
    String uploadSource = 'manual',
  }) async {
    final session = await _openSiteSession();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.siteBaseUrl}/api/upload.php'),
    );

    request.headers['Cookie'] = session.cookie;
    request.headers['User-Agent'] = 'MariageEmmanuelJennifer/1.0';
    request.headers['Accept'] = 'application/json';
    request.fields['csrf'] = session.csrf;
    request.fields['guest_name'] = guestName.trim();
    request.fields['website'] = '';
    request.fields['upload_source'] = uploadSource == 'automatic' ? 'automatic' : 'manual';

    MediaType? mediaType;
    if (mimeType != null && mimeType.contains('/')) {
      final p = mimeType.split('/');
      if (p.length == 2) mediaType = MediaType(p[0], p[1]);
    }

    final filename = (originalName == null || originalName.trim().isEmpty)
        ? file.path.split(Platform.pathSeparator).last
        : originalName.trim();

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      filename: filename,
      contentType: mediaType,
    ));

    final streamed = await _client.send(request);
    final body = await streamed.stream.bytesToString();

    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final ok = data['ok'] == true;
      return UploadResult(ok, (data['message'] ?? (ok ? 'Envoyé' : 'Erreur')).toString());
    } catch (_) {
      return UploadResult(false, 'Réponse serveur invalide (${streamed.statusCode}).');
    }
  }

  void close() => _client.close();
}
