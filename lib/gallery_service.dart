import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_config.dart';

class GalleryMedia {
  final int id;
  final String mediaType;
  final String mediaUrl;
  final String author;

  const GalleryMedia({
    required this.id,
    required this.mediaType,
    required this.mediaUrl,
    required this.author,
  });

  bool get isVideo => mediaType == 'video';
  bool get isPhoto => !isVideo;

  String get thumbUrl => '${AppConfig.siteBaseUrl}/thumb.php?id=$id';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'media_type': mediaType,
        'media_url': mediaUrl,
        'author': author,
      };

  factory GalleryMedia.fromJson(Map<String, dynamic> json) {
    return GalleryMedia(
      id: (json['id'] as num).toInt(),
      mediaType: (json['media_type'] ?? 'photo').toString(),
      mediaUrl: (json['media_url'] ?? '').toString(),
      author: (json['author'] ?? '').toString(),
    );
  }
}

class GalleryService {
  static const _userAgent = 'MariageEmmanuelJennifer/1.0';

  static String encodeCache(List<GalleryMedia> items) {
    return jsonEncode(items.map((item) => item.toJson()).toList());
  }

  static List<GalleryMedia> decodeCache(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! List) return <GalleryMedia>[];
      return data
          .whereType<Map>()
          .map((entry) => GalleryMedia.fromJson(
                entry.map((key, value) => MapEntry(key.toString(), value)),
              ))
          .toList();
    } catch (_) {
      return <GalleryMedia>[];
    }
  }

  static Future<List<GalleryMedia>> fetchForGuest(String guestName) async {
    final wanted = _normalizeName(guestName);
    if (wanted.isEmpty) return <GalleryMedia>[];

    final client = http.Client();
    try {
      final firstHtml = await _fetchAlbumPage(client, 1);
      final totalPages = _pageCount(firstHtml);
      final pages = <String>[firstHtml];

      for (var page = 2; page <= totalPages; page++) {
        pages.add(await _fetchAlbumPage(client, page));
      }

      final byId = <int, GalleryMedia>{};
      for (final html in pages) {
        for (final item in _parseMedia(html)) {
          if (_normalizeName(item.author) == wanted) {
            byId[item.id] = item;
          }
        }
      }

      final result = byId.values.toList()
        ..sort((a, b) => b.id.compareTo(a.id));
      return result;
    } finally {
      client.close();
    }
  }

  static Future<String> _fetchAlbumPage(http.Client client, int page) async {
    final uri = Uri.parse('${AppConfig.siteBaseUrl}/album.php').replace(
      queryParameters: page > 1 ? <String, String>{'page': '$page'} : null,
    );
    final response = await client.get(
      uri,
      headers: const <String, String>{
        'User-Agent': _userAgent,
        'Accept': 'text/html',
        'Cache-Control': 'no-cache',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw http.ClientException(
        'Album indisponible (${response.statusCode}).',
        uri,
      );
    }
    return response.body;
  }

  static int _pageCount(String html) {
    final match = RegExp(
      r'Page\s+\d+\s+sur\s+(\d+)',
      caseSensitive: false,
    ).firstMatch(html);
    final parsed = match == null ? 1 : int.tryParse(match.group(1) ?? '') ?? 1;
    if (parsed < 1) return 1;
    if (parsed > 30) return 30;
    return parsed;
  }

  static List<GalleryMedia> _parseMedia(String html) {
    final pattern = RegExp(
      r'data-viewer-id="(\d+)"[\s\S]*?data-media-type="(photo|video)"[\s\S]*?data-media-url="([^"]+)"[\s\S]*?data-author="([^"]*)"',
      caseSensitive: false,
    );

    final result = <GalleryMedia>[];
    for (final match in pattern.allMatches(html)) {
      final id = int.tryParse(match.group(1) ?? '');
      if (id == null) continue;
      final type = (match.group(2) ?? 'photo').toLowerCase();
      final rawUrl = _decodeHtml(match.group(3) ?? '');
      final author = _decodeHtml(match.group(4) ?? '').trim();
      final resolved = Uri.parse(AppConfig.siteBaseUrl).resolve(rawUrl).toString();
      result.add(GalleryMedia(
        id: id,
        mediaType: type,
        mediaUrl: resolved,
        author: author,
      ));
    }
    return result;
  }

  static String _normalizeName(String value) {
    return _decodeHtml(value)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  static String _decodeHtml(String value) {
    var result = value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    result = result.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (match) {
        final code = int.tryParse(match.group(1) ?? '');
        return code == null ? match.group(0)! : String.fromCharCode(code);
      },
    );
    return result;
  }
}
