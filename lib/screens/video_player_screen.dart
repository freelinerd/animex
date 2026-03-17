import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/anime_episode.dart';
import '../services/history_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl; // Este es el .m3u8 extraído
  final AnimeEpisode episode;

  const VideoPlayerScreen({
    Key? key,
    required this.videoUrl,
    required this.episode,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  final HistoryService _historyService = HistoryService();

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    // 1. Configuramos las orientaciones para pantalla completa
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // 2. Inicializamos el controlador de video (HLS compatible)
    _videoPlayerController = VideoPlayerController.networkUrl(
  Uri.parse(widget.videoUrl),
  // ✨ Esto obliga al reproductor a tratarlo como HLS (.m3u8)
  videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  formatHint: VideoFormat.hls, 
);

    await _videoPlayerController.initialize();

    // 3. Configuramos Chewie para los controles de usuario
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: false,
      aspectRatio: _videoPlayerController.value.aspectRatio,
      allowFullScreen: true,
      fullScreenByDefault: true,
      deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
      placeholder: Container(color: Colors.black),
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            'Error al reproducir video: $errorMessage',
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );

    setState(() {});
    
    // Guardamos en el historial tras unos segundos de reproducción
    _historyService.addToHistory(widget.episode);
  }

  @override
  void dispose() {
    // Restauramos la orientación original al salir
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _chewieController != null &&
              _chewieController!.videoPlayerController.value.isInitialized
          ? Chewie(controller: _chewieController!)
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 20),
                  Text("Cargando video nativo...", 
                       style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
    );
  }
}