import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/anime_episode.dart';
import '../models/anime.dart';
import '../services/scraper_service.dart';
import '../services/history_service.dart';
import '../services/video_extractor_service.dart';
import '../screens/video_player_screen.dart';
import 'anime_details_screen.dart';

class EpisodeScreen extends StatefulWidget {
  final AnimeEpisode episode;
  const EpisodeScreen({Key? key, required this.episode}) : super(key: key);

  @override
  _EpisodeScreenState createState() => _EpisodeScreenState();
}

class _EpisodeScreenState extends State<EpisodeScreen>
    with SingleTickerProviderStateMixin {
  final ScraperService        _scraperService = ScraperService();
  final HistoryService        _historyService = HistoryService();
  final VideoExtractorService _extractor      = VideoExtractorService();

  late Future<List<VideoServer>> _serversFuture;
  Timer? _historyTimer;

  // ── Navegación entre episodios ────────────────────────────────────────────
  bool _hasPrev     = false;
  bool _hasNext     = false;
  bool _checkingNav = true;

  // ── Estado del player embebido ────────────────────────────────────────────
  VideoPlayerController? _videoController;
  ChewieController?      _chewieController;
  bool   _playerReady   = false;   // true cuando Chewie está listo
  bool   _playerLoading = false;   // spinner mientras extrae/inicializa
  String _playerStatus  = '';      // texto bajo el thumbnail

  // ── Estado de carga por servidor ─────────────────────────────────────────
  int    _loadingServerIndex = -1;
  bool   _isAutoPlaying      = false;
  String _autoPlayStatus     = '';

  // ── Prioridad de servidores ───────────────────────────────────────────────
  static const _priority = ['STAPE', 'NETU', 'SW', 'YOURUPLOAD', 'FEMBED', 'OKRU'];

  @override
  void initState() {
    super.initState();
    _serversFuture = _scraperService.getEpisodeServers(widget.episode.link);
    _checkNavigation();
  }

  @override
  void dispose() {
    _historyTimer?.cancel();
    _disposePlayer();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // ── Navegación ────────────────────────────────────────────────────────────
  Future<void> _checkNavigation() async {
    final n = _currentEpisodeNumber();
    if (n == null) { if (mounted) setState(() => _checkingNav = false); return; }
    final r = await Future.wait([
      n > 1 ? _checkEpisodeExists(n - 1) : Future.value(false),
      _checkEpisodeExists(n + 1),
    ]);
    if (mounted) setState(() { _hasPrev = r[0]; _hasNext = r[1]; _checkingNav = false; });
  }

  Future<bool> _checkEpisodeExists(int n) async {
    try {
      final r = await http.head(Uri.parse(_buildEpisodeUrl(n)))
          .timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  int? _currentEpisodeNumber() {
    try { return int.parse(widget.episode.link.split('-').last); }
    catch (_) { return null; }
  }

  String _buildEpisodeUrl(int n) {
    final p = widget.episode.link.split('-');
    p.last = n.toString();
    return p.join('-');
  }

  void _goToEpisode(int n) {
    _historyTimer?.cancel();
    _disposePlayer();
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => EpisodeScreen(
        episode: AnimeEpisode(
          title:         widget.episode.title,
          episodeNumber: 'Episodio $n',
          imageUrl:      widget.episode.imageUrl,
          link:          _buildEpisodeUrl(n),
          animeLink:     widget.episode.animeLink,
        ),
      ),
    ));
  }

  void _goToAnimeDetails() {
    if (widget.episode.animeLink == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => AnimeDetailsScreen(
        anime: Anime(
          title:    widget.episode.title,
          imageUrl: widget.episode.imageUrl,
          link:     widget.episode.animeLink!,
        ),
      ),
    ));
  }

  // ── Historial ─────────────────────────────────────────────────────────────
  void _triggerHistoryTimer() {
    _historyTimer?.cancel();
    _historyTimer = Timer(const Duration(minutes: 18), () async {
      if (mounted) {
        await _historyService.addToHistory(widget.episode);
        debugPrint('FREELINE: episodio marcado como visto.');
      }
    });
  }

  // ── Player embebido ───────────────────────────────────────────────────────
  void _disposePlayer() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _videoController  = null;
    _chewieController = null;
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

  Future<void> _loadPlayerWithLink(String url) async {
    _disposePlayer();
    final uri     = Uri.parse(url);
    final referer = _refererFor(uri.host);

    debugPrint('FREELINE EmbeddedPlayer: $url  Referer: $referer');

    final ctrl = VideoPlayerController.networkUrl(uri, httpHeaders: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
      'Referer': referer,
    });

    try {
      await ctrl.initialize();

      final chewie = ChewieController(
        videoPlayerController: ctrl,
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
        placeholder:   const _PlayerPlaceholder(),
        errorBuilder: (_, msg) => _PlayerError(message: msg),
      );

      if (mounted) {
        setState(() {
          _videoController  = ctrl;
          _chewieController = chewie;
          _playerReady      = true;
          _playerLoading    = false;
          _playerStatus     = '';
        });
      } else {
        ctrl.dispose();
        chewie.dispose();
      }
    } catch (e) {
      debugPrint('FREELINE EmbeddedPlayer error: $e');
      ctrl.dispose();
      if (mounted) setState(() {
        _playerLoading = false;
        _playerStatus  = 'Error al cargar el video';
      });
    }
  }

  // ── Reproducción automática ───────────────────────────────────────────────
  Future<void> _autoPlay(List<VideoServer> servers) async {
    if (_isAutoPlaying || _playerLoading) return;
    setState(() {
      _isAutoPlaying  = true;
      _autoPlayStatus = 'Buscando mejor fuente...';
      _playerReady    = false;
      _playerLoading  = true;
      _playerStatus   = 'Buscando mejor fuente...';
    });
    _triggerHistoryTimer();

    final sorted = [
      ...servers.where((s) => _priority.contains(s.serverName.toUpperCase())),
      ...servers.where((s) => !_priority.contains(s.serverName.toUpperCase())),
    ];

    for (final server in sorted) {
      if (!mounted) break;
      setState(() {
        _autoPlayStatus = 'Probando ${server.serverName}...';
        _playerStatus   = 'Probando ${server.serverName}...';
      });

      try {
        final link = await _extractor
            .getDirectLink(server.url)
            .timeout(const Duration(seconds: 10), onTimeout: () => null);

        if (link != null && link.isNotEmpty) {
          debugPrint('FREELINE AutoPlay OK: ${server.serverName} → $link');
          if (!mounted) return;
          setState(() { _isAutoPlaying = false; _autoPlayStatus = ''; });
          await _loadPlayerWithLink(link);
          return;
        }
      } catch (e) {
        debugPrint('FREELINE AutoPlay ${server.serverName} falló: $e');
      }
    }

    // Fallback → WebView
    if (mounted) {
      setState(() {
        _isAutoPlaying = false; _autoPlayStatus = '';
        _playerLoading = false; _playerStatus   = '';
      });
      debugPrint('FREELINE AutoPlay: sin link directo, usando WebView');
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(videoUrl: sorted.first.url, episode: widget.episode),
      ));
    }
  }

  // ── Tap servidor individual ───────────────────────────────────────────────
  Future<void> _onServerTap(int index, VideoServer server) async {
    if (_loadingServerIndex != -1 || _isAutoPlaying || _playerLoading) return;
    setState(() {
      _loadingServerIndex = index;
      _playerReady        = false;
      _playerLoading      = true;
      _playerStatus       = 'Conectando con ${server.serverName}...';
    });
    _triggerHistoryTimer();

    try {
      final link = await _extractor
          .getDirectLink(server.url)
          .timeout(const Duration(seconds: 10), onTimeout: () => null);

      if (link != null && link.isNotEmpty) {
        await _loadPlayerWithLink(link);
      } else {
        if (mounted) setState(() { _playerLoading = false; _playerStatus = ''; });
        if (!mounted) return;
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(videoUrl: server.url, episode: widget.episode),
        ));
      }
    } catch (e) {
      debugPrint('FREELINE ServerTap error: $e');
      if (mounted) setState(() { _playerLoading = false; _playerStatus = 'Error al conectar'; });
    } finally {
      if (mounted) setState(() => _loadingServerIndex = -1);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // AppBar solo cuando el player no está activo
      appBar: _playerReady ? null : AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        shape: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.8),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.episode.title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                overflow: TextOverflow.ellipsis),
            Text(widget.episode.episodeNumber,
                style: const TextStyle(
                    fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: FutureBuilder<List<VideoServer>>(
        future: _serversFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildErrorState();
          }

          final servers    = snapshot.data!;
          final anyLoading = _loadingServerIndex != -1 || _isAutoPlaying || _playerLoading;

          return Column(
            children: [
              // ── ZONA DEL PLAYER (fija arriba, no scrollea) ────────────
              _buildPlayerZone(servers),

              // ── CONTENIDO SCROLLABLE ──────────────────────────────────
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    _buildNavModule(),
                    _buildAutoPlayButton(servers),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
                      child: Text(
                        'O SELECCIONA UN SERVIDOR',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5),
                      ),
                    ),
                    ...List.generate(servers.length, (i) {
                      final s         = servers[i];
                      final isThisLoad = _loadingServerIndex == i;
                      final isDisabled = anyLoading && !isThisLoad;
                      return Padding(
                        padding: EdgeInsets.fromLTRB(12, i == 0 ? 0 : 4, 12, 4),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isDisabled ? 0.35 : 1.0,
                          child: _ServerTile(
                            server:    s,
                            isLoading: isThisLoad,
                            isDisabled: isDisabled,
                            onTap: isDisabled ? null : () => _onServerTap(i, s),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Zona del player: thumbnail → loading → chewie ────────────────────────
  Widget _buildPlayerZone(List<VideoServer> servers) {
    // Player activo
    if (_playerReady && _chewieController != null) {
      return _EmbeddedPlayer(
        chewie:  _chewieController!,
        episode: widget.episode,
        onClose: () {
          setState(() { _playerReady = false; _playerStatus = ''; });
          _disposePlayer();
        },
      );
    }

    // Thumbnail + estado de carga
    return _ThumbnailHero(
      episode:    widget.episode,
      isLoading:  _playerLoading,
      statusText: _playerStatus,
      onPlay:     _playerLoading ? null : () => _autoPlay(servers),
    );
  }

  // ── Nav module ────────────────────────────────────────────────────────────
  Widget _buildNavModule() {
    if (_checkingNav) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.07), width: 0.8),
          ),
          child: const Center(
            child: SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 1.5)),
          ),
        ),
      );
    }

    final buttons = <_NavBtn>[
      if (_hasPrev) _NavBtn(icon: Icons.skip_previous_rounded, label: 'Anterior',
          onTap: () => _goToEpisode(_currentEpisodeNumber()! - 1), accent: true),
      if (widget.episode.animeLink != null) _NavBtn(icon: Icons.view_list_rounded,
          label: 'Episodios', onTap: _goToAnimeDetails, accent: false),
      if (_hasNext) _NavBtn(icon: Icons.skip_next_rounded, label: 'Siguiente',
          onTap: () => _goToEpisode(_currentEpisodeNumber()! + 1), accent: true),
    ];

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.07), width: 0.8),
        ),
        child: IntrinsicHeight(
          child: Row(children: [
            for (int i = 0; i < buttons.length; i++) ...[
              Expanded(child: _NavBtnWidget(btn: buttons[i])),
              if (i < buttons.length - 1)
                VerticalDivider(width: 1, thickness: 0.8,
                    color: Colors.white.withOpacity(0.07)),
            ],
          ]),
        ),
      ),
    );
  }

  // ── AutoPlay button ───────────────────────────────────────────────────────
  Widget _buildAutoPlayButton(List<VideoServer> servers) {
    final busy = _isAutoPlaying || _playerLoading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: GestureDetector(
        onTap: busy ? null : () => _autoPlay(servers),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(busy ? 0.08 : 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: Colors.orange.withOpacity(busy ? 0.2 : 0.35), width: 0.8),
          ),
          child: Row(children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: busy
                  ? const SizedBox(key: ValueKey('sp'), width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2))
                  : const Icon(key: ValueKey('ic'),
                      Icons.auto_awesome_rounded, color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Reproducción automática',
                    style: TextStyle(color: Colors.orange, fontSize: 13,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    key: ValueKey(_autoPlayStatus),
                    busy ? _autoPlayStatus : 'Encuentra el mejor servidor automáticamente',
                    style: TextStyle(
                        color: busy ? Colors.orange.withOpacity(0.7) : Colors.white38,
                        fontSize: 10),
                  ),
                ),
              ]),
            ),
            if (!busy)
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.orange, size: 12),
          ]),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white24, size: 50),
        const SizedBox(height: 16),
        const Text('No se encontraron servidores.',
            style: TextStyle(color: Colors.white38)),
        TextButton(
          onPressed: () => setState(() {
            _serversFuture = _scraperService.getEpisodeServers(widget.episode.link);
          }),
          child: const Text('Reintentar', style: TextStyle(color: Colors.orange)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── WIDGETS ───────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

// ── Thumbnail con botón de play y estado de carga ────────────────────────────
class _ThumbnailHero extends StatelessWidget {
  final AnimeEpisode    episode;
  final bool            isLoading;
  final String          statusText;
  final VoidCallback?   onPlay;

  const _ThumbnailHero({
    required this.episode,
    required this.isLoading,
    required this.statusText,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPlay,
      child: Container(
        width: double.infinity,
        height: 215,
        color: Colors.black,
        child: Stack(fit: StackFit.expand, children: [

          // Imagen de fondo
          Image.network(
            episode.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF111111)),
          ),

          // Gradiente
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.55, 1.0],
                colors: [
                  Colors.black.withOpacity(0.15),
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.9),
                ],
              ),
            ),
          ),

          // Centro: play o spinner
          Center(
            child: isLoading
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(width: 40, height: 40,
                      child: CircularProgressIndicator(
                          color: Colors.orange, strokeWidth: 2.5)),
                    if (statusText.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(statusText,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ])
                : _PlayButton(),
          ),

          // Info: título + episodio (abajo izquierda)
          Positioned(
            left: 16, right: 16, bottom: 14,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
              Text(episode.title,
                  style: const TextStyle(color: Colors.white, fontSize: 14,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withOpacity(0.4), width: 0.8),
                  ),
                  child: Text(episode.episodeNumber,
                      style: const TextStyle(
                          color: Colors.orange, fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Botón de play con efecto de pulso ────────────────────────────────────────
class _PlayButton extends StatefulWidget {
  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>    _scale;
  late final Animation<double>    _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _scale   = Tween(begin: 1.0, end: 1.12).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _opacity = Tween(begin: 0.5, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72, height: 72,
      child: Stack(alignment: Alignment.center, children: [
        // Anillo de pulso
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 66, height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.orange.withOpacity(_opacity.value), width: 2),
              ),
            ),
          ),
        ),
        // Círculo sólido con icono
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.orange.withOpacity(0.2),
            border: Border.all(color: Colors.orange.withOpacity(0.7), width: 1.5),
          ),
          child: const Icon(Icons.play_arrow_rounded,
              color: Colors.white, size: 30),
        ),
      ]),
    );
  }
}

// ── Player Chewie embebido ────────────────────────────────────────────────────
class _EmbeddedPlayer extends StatelessWidget {
  final ChewieController chewie;
  final AnimeEpisode     episode;
  final VoidCallback     onClose;

  const _EmbeddedPlayer({
    required this.chewie,
    required this.episode,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 230,
      color: Colors.black,
      child: Stack(children: [
        Positioned.fill(child: Chewie(controller: chewie)),

        // Botón cerrar
        Positioned(
          top: 8, right: 8,
          child: SafeArea(
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white12, width: 0.8),
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
        ),

        // Info del episodio (solo visible cuando los controles están ocultos)
        Positioned(
          left: 12, bottom: 12,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
            Text(episode.title,
                style: const TextStyle(color: Colors.white70, fontSize: 11,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Colors.black, blurRadius: 6)])),
            Text(episode.episodeNumber,
                style: const TextStyle(color: Colors.orange, fontSize: 10,
                    shadows: [Shadow(color: Colors.black, blurRadius: 6)])),
          ]),
        ),
      ]),
    );
  }
}

// ── Tile de servidor ──────────────────────────────────────────────────────────
class _ServerTile extends StatelessWidget {
  final VideoServer   server;
  final bool          isLoading;
  final bool          isDisabled;
  final VoidCallback? onTap;

  const _ServerTile({
    required this.server,
    required this.isLoading,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isLoading
            ? Colors.orange.withOpacity(0.06)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLoading
              ? Colors.orange.withOpacity(0.25)
              : Colors.white.withOpacity(0.05),
          width: 0.8,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: isLoading
              ? Colors.orange.withOpacity(0.15)
              : Colors.orange.withOpacity(0.1),
          child: isLoading
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2))
              : Icon(Icons.play_arrow_rounded,
                  color: isDisabled
                      ? Colors.orange.withOpacity(0.4)
                      : Colors.orange),
        ),
        title: Text(server.serverName,
            style: TextStyle(
              color: isDisabled ? Colors.white38 : Colors.white,
              fontSize: 14, fontWeight: FontWeight.w600,
            )),
        subtitle: Text(
          isLoading ? 'Conectando...' : 'Bloqueo de anuncios FREELINE activo',
          style: TextStyle(
              color: isLoading ? Colors.orange : Colors.green, fontSize: 10),
        ),
        trailing: isLoading
            ? null
            : Icon(Icons.arrow_forward_ios_rounded,
                color: isDisabled
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white12,
                size: 14),
        onTap: onTap,
      ),
    );
  }
}

// ── Placeholders internos del Chewie ─────────────────────────────────────────
class _PlayerPlaceholder extends StatelessWidget {
  const _PlayerPlaceholder();
  @override
  Widget build(BuildContext context) => Container(
        color: Colors.black,
        child: const Center(
            child: CircularProgressIndicator(color: Colors.orange)));
}

class _PlayerError extends StatelessWidget {
  final String message;
  const _PlayerError({required this.message});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: Colors.orange, size: 36),
          const SizedBox(height: 8),
          Text(message,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              textAlign: TextAlign.center),
        ]),
      );
}

// ── Nav button ────────────────────────────────────────────────────────────────
class _NavBtn {
  final IconData icon; final String label;
  final VoidCallback onTap; final bool accent;
  const _NavBtn({required this.icon, required this.label,
      required this.onTap, required this.accent});
}

class _NavBtnWidget extends StatelessWidget {
  final _NavBtn btn;
  const _NavBtnWidget({required this.btn});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: btn.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(btn.icon, color: btn.accent ? Colors.orange : Colors.white54, size: 22),
          const SizedBox(height: 5),
          Text(btn.label, style: TextStyle(
            color: btn.accent ? Colors.orange : Colors.white38,
            fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5,
          )),
        ]),
      ),
    );
  }
}