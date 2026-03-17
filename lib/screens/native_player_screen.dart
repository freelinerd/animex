import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/anime_episode.dart';
import '../services/history_service.dart';

class NativePlayerScreen extends StatefulWidget {
  final String url;
  final AnimeEpisode episode;

  const NativePlayerScreen({
    Key? key,
    required this.url,
    required this.episode,
  }) : super(key: key);

  @override
  State<NativePlayerScreen> createState() => _NativePlayerScreenState();
}

class _NativePlayerScreenState extends State<NativePlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController?           _chewieController;
  Timer?  _historyTimer;
  Timer?  _progressTimer;   // guarda progreso cada 5s
  bool    _hasError = false;
  final HistoryService _historyService = HistoryService();

  @override
  void initState() {
    super.initState();
    _initializePlayer();

    // Historial: marcar visto tras 30s
    _historyTimer = Timer(const Duration(seconds: 30), () {
      _historyService.addToHistory(widget.episode);
    });
  }

  String _refererFor(String host) {
    if (host.contains('tapecontent') || host.contains('streamtape'))
      return 'https://streamtape.com/';
    if (host.contains('wishembed') || host.contains('streamwish') ||
        host.contains('huntrexus') || host.contains('mountainpathventures') ||
        host.contains('niramirus') || host.contains('medixiru'))
      return 'https://streamwish.to/';
    if (host.contains('hglamioz') || host.contains('netu') || host.contains('hqq'))
      return 'https://hglamioz.com/';
    if (host.contains('vidcache'))
      return 'https://www.yourupload.com/';
    return 'https://www3.animeflv.net/';
  }

  Future<void> _initializePlayer() async {
    final uri     = Uri.parse(widget.url);
    final referer = _refererFor(uri.host);

    debugPrint('FREELINE NativePlayer: ${widget.url}  referer: $referer');

    _videoController = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
        'Referer': referer,
      },
    );

    try {
      await _videoController.initialize();

      // Restaurar posición si hay progreso guardado
      final savedProgress =
          await _historyService.getProgress(widget.episode.link);
      if (savedProgress > 0.02 && savedProgress < 0.98) {
        final duration = _videoController.value.duration;
        await _videoController.seekTo(duration * savedProgress);
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping:  false,
        allowFullScreen:   true,
        allowedScreenSleep: false,
        deviceOrientationsOnEnterFullScreen: [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
        materialProgressColors: ChewieProgressColors(
          playedColor:     Colors.orange,
          handleColor:     Colors.orangeAccent,
          backgroundColor: Colors.white24,
          bufferedColor:   Colors.white54,
        ),
        placeholder: const _LoadingPlaceholder(),
        errorBuilder: (_, msg) => _ErrorView(message: msg),
      );

      // Guardar progreso cada 5 segundos
      _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        final dur = _videoController.value.duration;
        final pos = _videoController.value.position;
        if (dur.inSeconds > 0) {
          final progress = pos.inSeconds / dur.inSeconds;
          _historyService.saveProgress(widget.episode.link, progress);
        }
      });

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('FREELINE NativePlayer init error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _historyTimer?.cancel();
    _progressTimer?.cancel();
    // Guardar posición final
    final dur = _videoController.value.duration;
    final pos = _videoController.value.position;
    if (dur.inSeconds > 0) {
      _historyService.saveProgress(
          widget.episode.link, pos.inSeconds / dur.inSeconds);
    }
    _videoController.dispose();
    _chewieController?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _ErrorView(
          message: 'No se pudo inicializar el reproductor',
          onRetry: () { setState(() => _hasError = false); _initializePlayer(); },
          onBack:  () => Navigator.pop(context),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: _chewieController != null &&
              _chewieController!.videoPlayerController.value.isInitialized
          ? Chewie(controller: _chewieController!)
          : const _LoadingPlaceholder(),
    );
  }
}

// ── Placeholders ──────────────────────────────────────────────────────────────
class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 20),
            Text('Cargando video...',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String       message;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;
  const _ErrorView({required this.message, this.onRetry, this.onBack});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline_rounded, color: Colors.orange, size: 48),
            const SizedBox(height: 16),
            const Text('No se pudo reproducir el video',
                style: TextStyle(color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (onBack != null)
                TextButton(onPressed: onBack,
                    child: const Text('Volver',
                        style: TextStyle(color: Colors.white54))),
              if (onRetry != null) ...[
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Reintentar',
                      style: TextStyle(color: Colors.black)),
                ),
              ],
            ]),
          ]),
        ),
      );
}