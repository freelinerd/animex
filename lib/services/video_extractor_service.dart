import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class VideoExtractorService {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36';

  static String _refererFor(String url) {
    if (url.contains('streamtape') || url.contains('stape'))
      return 'https://streamtape.com/';
    if (url.contains('yourupload') || url.contains('vidcache'))
      return 'https://www.yourupload.com/';
    if (url.contains('streamwish') || url.contains('wishembed') ||
        url.contains('streamhg')   || url.contains('awish') ||
        url.contains('dwish')      || url.contains('sfastwish') ||
        url.contains('niramirus')  || url.contains('medixiru') ||
        url.contains('huntrexus')  || url.contains('mountainpathventures'))
      return 'https://streamwish.to/';
    if (url.contains('hglamioz') || url.contains('netu') || url.contains('hqq'))
      return 'https://hglamioz.com/';
    return 'https://www3.animeflv.net/';
  }

  static Map<String, String> _headersFor(String url) => {
    'User-Agent': _ua,
    'Referer': _refererFor(url),
  };

  Future<String?> getDirectLink(String serverUrl) async {
    try {
      if (serverUrl.contains('streamtape') || serverUrl.contains('stape'))
        return await _extractStreamtape(serverUrl);
      if (serverUrl.contains('yourupload'))
        return await _extractYourUpload(serverUrl);
      if (serverUrl.contains('streamwish') || serverUrl.contains('wishembed') ||
          serverUrl.contains('streamhg')   || serverUrl.contains('awish') ||
          serverUrl.contains('dwish')      || serverUrl.contains('sfastwish') ||
          serverUrl.contains('niramirus')  || serverUrl.contains('medixiru'))
        return await _extractStreamwish(serverUrl);
      if (serverUrl.contains('hglamioz.com') || serverUrl.contains('netu'))
        return await _extractNetu(serverUrl);
      return null;
    } catch (e) {
      debugPrint('Error en extractor: $e');
      return null;
    }
  }

  // ── DESOFUSCADOR P.A.C.K.E.R. ─────────────────────────────────────────────
  String _unpack(String packed) {
    try {
      final regex = RegExp(
        r"}\s*\('([\s\S]+)',\s*(\d+),\s*(\d+),\s*'([\s\S]+)'\.split\('\|'\)",
      );
      final match = regex.firstMatch(packed);
      if (match == null) return packed;

      String p    = match.group(1)!;
      final a     = int.parse(match.group(2)!);
      int c       = int.parse(match.group(3)!);
      final k     = match.group(4)!.split('|');

      String toBase(int n) {
        return (n < a ? '' : toBase(n ~/ a)) +
            ((n % a) > 35
                ? String.fromCharCode((n % a) + 29)
                : (n % a).toRadixString(36));
      }

      final Map<String, String> d = {};
      while (c > 0) {
        c--;
        final key = toBase(c);
        d[key] = k[c].isEmpty ? key : k[c];
      }

      final unpacked = p.replaceAllMapped(RegExp(r'\b\w+\b'), (m) {
        return d[m.group(0)] ?? m.group(0)!;
      });

      return unpacked
          .replaceAll(RegExp(r'\\[0-7]{1,3}'), '')
          .replaceAll(r'\/', '/');
    } catch (e) {
      debugPrint('FREELINE unpack error: $e');
      return packed;
    }
  }

  // ── STREAMWISH / NIRAMIRUS ────────────────────────────────────────────────
  Future<String?> _extractStreamwish(String url) async {
    try {
      final code = Uri.tryParse(url)?.pathSegments.lastOrNull ?? '';
      if (code.isEmpty) return null;

      final targetUrl = 'https://niramirus.com/e/$code';
      final headers = {
        'User-Agent': _ua,
        'Referer': 'https://streamwish.to/',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      };

      debugPrint('FREELINE SW: fetching $targetUrl');
      final response = await http.get(Uri.parse(targetUrl), headers: headers)
          .timeout(const Duration(seconds: 12));

      debugPrint('FREELINE SW: status=${response.statusCode} bodyLen=${response.body.length}');

      if (response.statusCode != 200 || response.body.length < 500) {
        debugPrint('FREELINE SW: respuesta invalida');
        return null;
      }

      String html = response.body;

      if (html.contains('eval(function')) {
        debugPrint('FREELINE SW: desempaquetando P.A.C.K.E.R...');
        html = _unpack(html);
        debugPrint('FREELINE SW: desempaquetado len=${html.length}');
      }

      // ── Prioridad 1: hls4 — URL relativa /stream/... (el stream real) ──────
      // JWPlayer usa: links.hls4 || links.hls3 || links.hls2
      // hls4 es siempre relativo: "/stream/TOKEN/.../master.m3u8"
      final hls4Regex = RegExp(r'"hls4"\s*:\s*"(/stream/[^"]+\.m3u8[^"]*)"');
      final hls4Match = hls4Regex.firstMatch(html);
      if (hls4Match != null) {
        final path = hls4Match.group(1)!;
        final fullUrl = 'https://niramirus.com$path';
        debugPrint('FREELINE SW OK (hls4): $fullUrl');
        return fullUrl;
      }

      // ── Prioridad 2: m3u8 absolutos excluyendo señuelos ──────────────────
      final m3u8Regex = RegExp('https://[^\\s"<>]+\\.m3u8[^\\s"<>]*');
      final allFound = m3u8Regex.allMatches(html)
          .map((m) => m.group(0)!.replaceAll(r'\/', '/'))
          .toList();

      debugPrint('FREELINE SW: ${allFound.length} m3u8 absolutos:');
      for (final l in allFound) debugPrint('  -> $l');

      bool isDecoy(String link) {
        if (link.contains('premilkyway'))    return true;
        if (link.contains('venturecapital')) return true;
        if (link.contains('hls4://'))        return true;
        if (link.contains('.txt'))           return true;
        if (link.contains('audioTracks'))    return true;
        return false;
      }

      final validLinks = allFound.where((l) => !isDecoy(l)).toList();
      debugPrint('FREELINE SW: ${validLinks.length} validos:');
      for (final l in validLinks) debugPrint('  OK $l');

      if (validLinks.isEmpty) {
        debugPrint('FREELINE SW: sin links validos');
        return null;
      }

      final best = validLinks.firstWhere(
        (l) => l.contains('master'),
        orElse: () => validLinks.firstWhere(
          (l) => l.contains('/hls/') || l.contains('/stream/'),
          orElse: () => validLinks.first,
        ),
      );

      debugPrint('FREELINE SW OK: $best');
      return best;
    } catch (e) {
      debugPrint('Error extractor SW: $e');
      return null;
    }
  }

  // ── YOURUPLOAD ────────────────────────────────────────────────────────────
  Future<String?> _extractYourUpload(String url) async {
    try {
      final embedUrl = url.replaceFirst('/watch/', '/embed/');
      final response = await http.get(
        Uri.parse(embedUrl),
        headers: _headersFor(embedUrl),
      );
      if (response.statusCode != 200) return null;

      final html = response.body;
      final patterns = [
        RegExp("file\\s*:\\s*'(https://vidcache\\.net[^']+\\.mp4[^']*)'"),
        RegExp('og:video[^>]+content="(https://vidcache\\.net[^"]+)"'),
        RegExp('(https://vidcache\\.net[^\\s<>"]+\\.mp4[^\\s<>"]*)'),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(html);
        if (match != null) {
          debugPrint('FREELINE YourUpload OK: ${match.group(1)}');
          return match.group(1)!;
        }
      }
      debugPrint('FREELINE YourUpload: no encontrado');
      return null;
    } catch (e) {
      debugPrint('Error YourUpload: $e');
      return null;
    }
  }

  // ── NETU ──────────────────────────────────────────────────────────────────
  Future<String?> _extractNetu(String url) async {
    try {
      final response = await http.get(Uri.parse(url), headers: _headersFor(url));
      if (response.statusCode != 200) return null;

      final html = response.body;
      final id   = Uri.parse(url).pathSegments.lastOrNull ?? '';

      final regexFile = RegExp(r'"file"\s*:\s*"([^"]+)"');
      final matchFile = regexFile.firstMatch(html);
      if (matchFile != null) {
        String link = matchFile.group(1)!.replaceAll(r'\/', '/');
        if (link.startsWith('//')) link = 'https:$link';
        debugPrint('FREELINE Netu OK: $link');
        return link;
      }

      if (id.isNotEmpty) {
        final regexId = RegExp(
          'https?://[^\\s"<>]+$id[^\\s"<>]+(?:\\.jpg|\\.xt|\\.mp4|\\.jpeg)[^\\s"<>]*',
        );
        final matchId = regexId.firstMatch(html);
        if (matchId != null) {
          debugPrint('FREELINE Netu ID OK: ${matchId.group(0)}');
          return matchId.group(0)!;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error Netu: $e');
      return null;
    }
  }

  // ── STREAMTAPE ────────────────────────────────────────────────────────────
  Future<String?> _extractStreamtape(String url) async {
    try {
      final response = await http.get(Uri.parse(url), headers: _headersFor(url));
      final html = response.body;

      final regex = RegExp(
        r"innerHTML\s*=\s*'([^']+)'\s*\+\s*\('([^']+)'\)\.substring\((\d+)\)\.substring\((\d+)\)",
      );
      final match = regex.firstMatch(html);

      if (match != null) {
        final p1   = match.group(1)!;
        final p2   = match.group(2)!;
        final sub1 = int.parse(match.group(3)!);
        final sub2 = int.parse(match.group(4)!);

        String path = p1 + p2.substring(sub1).substring(sub2);
        String link = path.startsWith('//') ? 'https:$path' : path;
        return link.contains('?') ? '$link&stream=1' : '$link?stream=1';
      }
    } catch (e) {
      debugPrint('Error Streamtape: $e');
    }
    return null;
  }
}