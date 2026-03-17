import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/scraper_service.dart';
import '../services/favorites_service.dart';
import '../services/history_service.dart';
import '../models/anime_episode.dart';
import '../models/anime.dart';
import '../widgets/error_view.dart';
import '../widgets/shimmer_card.dart';
import 'episode_screen.dart';
import 'anime_details_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ScraperService _scraperService = ScraperService();
  final FavoritesService _favoritesService = FavoritesService();
  final HistoryService _historyService = HistoryService();

  List<Anime> _favoriteAnimes = [];
  List<AnimeEpisode> _history = [];

  late AnimationController _logoAnimationController;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  late Future<List<AnimeEpisode>> _recentFuture;

  @override
  void initState() {
    super.initState();
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // 1.5 segundos por barrido
    );

    _recentFuture = _scraperService.getRecentEpisodes();
    _loadLocalData();
  }

  @override
  void dispose() {
    // 3. No olvides liberar el controlador
    _logoAnimationController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    // 4. Inicia la animación (en bucle) al refrescar
    _logoAnimationController.repeat();

    setState(() {
      _recentFuture = _scraperService.getRecentEpisodes();
    });

    await Future.wait([_recentFuture, _loadLocalData()]);

    // 5. Detiene la animación cuando los datos cargan
    _logoAnimationController.stop();
    _logoAnimationController.reset(); // Vuelve a la posición original
  }

  Future<void> _loadLocalData() async {
    final favs = await _favoritesService.getFavorites();
    final hist = await _historyService.getHistory();
    if (mounted)
      setState(() {
        _favoriteAnimes = favs;
        _history = hist;
      });
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isTablet = w > 600;
    final crossAxis = isTablet ? 4 : 2;
    final historyHeight = isTablet ? 180.0 : 130.0;
    final favoriteHeight = isTablet ? 240.0 : 170.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        color: Colors.transparent,
        backgroundColor: Colors.transparent,
        onRefresh: _handleRefresh,
        child: FutureBuilder<List<AnimeEpisode>>(
          future: _recentFuture,
          builder: (context, snapshot) {
            final episodes = snapshot.data ?? [];
            final heroEp = episodes.isNotEmpty ? episodes.first : null;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── AppBar transparente que flota sobre el hero ──────────
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: false,
                  floating: true,
                  expandedHeight: 0,
                  flexibleSpace: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black, Colors.transparent],
                      ),
                    ),
                  ),
                  title: AnimatedBuilder(
                    animation: _logoAnimationController,
                    builder: (context, child) {
                      // ✅ Only apply the sweeping gradient while the animation is running
                      if (_logoAnimationController.isAnimating) {
                        return ShaderMask(
                          shaderCallback: (rect) {
                            return LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              stops: [
                                _logoAnimationController.value - 0.3,
                                _logoAnimationController.value,
                                _logoAnimationController.value + 0.3,
                              ],
                              colors: const [
                                Colors.white24, // softer at edges
                                Colors.white,
                                Colors.white24,
                              ],
                            ).createShader(rect);
                          },
                          child: Image.asset(
                            'assets/images/animex_logo.png',
                            height: 45,
                            fit: BoxFit.contain,
                            color: Colors.white,
                            colorBlendMode: BlendMode.modulate,
                            errorBuilder: (_, __, ___) => const Text(
                              'Animex',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        );
                      } else {
                        // Normal static logo (no gradient)
                        return Image.asset(
                          'assets/images/animex_logo.png',
                          height: 45,
                          fit: BoxFit.contain,
                          color: Colors.white,
                          colorBlendMode: BlendMode.modulate,
                          errorBuilder: (_, __, ___) => const Text(
                            'Animex',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 2,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white54,
                        size: 22,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AboutScreen()),
                      ),
                    ),
                  ],
                ),

                // ── Hero highlight ───────────────────────────────────────
                SliverToBoxAdapter(
                  child: heroEp != null
                      ? _HeroHighlight(
                          episode: heroEp,
                          onPlay: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EpisodeScreen(episode: heroEp),
                              ),
                            );
                            _loadLocalData();
                          },
                          onDetails: () {
                            if (heroEp.animeLink == null) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AnimeDetailsScreen(
                                  anime: Anime(
                                    title: heroEp.title,
                                    imageUrl: heroEp.imageUrl,
                                    link: heroEp.animeLink!,
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : const SizedBox(height: 240),
                ),

                // ── Continuar viendo ─────────────────────────────────────
                if (_history.isNotEmpty) ...[
                  _sectionHeader(
                    title: 'CONTINUAR VIENDO',
                    action: 'LIMPIAR',
                    onAction: () async {
                      final ok = await _confirmClear(context);
                      if (ok == true) {
                        await _historyService.clearHistory();
                        _loadLocalData();
                      }
                    },
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: historyHeight,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        itemCount: _history.length,
                        itemBuilder: (_, i) => _HistoryCard(
                          ep: _history[i],
                          isTablet: isTablet,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EpisodeScreen(episode: _history[i]),
                              ),
                            );
                            _loadLocalData();
                          },
                        ),
                      ),
                    ),
                  ),
                ],
                // ── Últimos episodios ────────────────────────────────────
                _sectionHeader(title: 'ÚLTIMOS EPISODIOS', accent: true),

                if (snapshot.connectionState == ConnectionState.waiting)
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (_, __) => ShimmerCard(),
                        childCount: 8,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxis,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                      ),
                    ),
                  )
                else if (snapshot.hasError)
                  SliverToBoxAdapter(
                    child: ErrorView(
                      message: 'Error de conexión',
                      onRetry: () => setState(() {}),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _EpisodeCard(
                          ep: episodes[i],
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EpisodeScreen(episode: episodes[i]),
                              ),
                            );
                            _loadLocalData();
                          },
                        ),
                        childCount: episodes.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxis,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Header de sección ─────────────────────────────────────────────────────
  SliverToBoxAdapter _sectionHeader({
    required String title,
    String? action,
    VoidCallback? onAction,
    bool accent = false,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: accent ? Colors.orange : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            if (action != null && onAction != null)
              GestureDetector(
                onTap: onAction,
                child: Text(
                  action,
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmClear(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.8),
      ),
      title: const Text(
        '¿Limpiar historial?',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
      content: const Text(
        'Se eliminarán todos los episodios recientes.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'CANCELAR',
            style: TextStyle(color: Colors.white38),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'LIMPIAR',
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ── HERO HIGHLIGHT ────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
class _HeroHighlight extends StatelessWidget {
  final AnimeEpisode episode;
  final VoidCallback onPlay;
  final VoidCallback onDetails;

  const _HeroHighlight({
    required this.episode,
    required this.onPlay,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 460,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Imagen de fondo
          CachedNetworkImage(
            imageUrl: episode.imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: Colors.black),
            errorWidget: (_, __, ___) =>
                Container(color: const Color(0xFF111111)),
          ),

          // Gradientes — izquierda + abajo
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.92),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 1.0],
                colors: [
                  Colors.black.withOpacity(0.55),
                  Colors.transparent,
                  Colors.black,
                ],
              ),
            ),
          ),

          // Contenido
          Positioned(
            left: 20,
            right: 20,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge "En emisión"
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.45),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.orange,
                        ),
                      ),
                      Text(
                        episode.episodeNumber.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Título
                Text(
                  episode.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),

                // Botones
                Row(
                  children: [
                    // Reproducir
                    ElevatedButton.icon(
                      onPressed: onPlay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text(
                        'Reproducir',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Más info
                    OutlinedButton.icon(
                      onPressed: onDetails,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                          width: 0.8,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.info_outline_rounded, size: 18),
                      label: const Text(
                        'Más info',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── HISTORY CARD ─────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final AnimeEpisode ep;
  final bool isTablet;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.ep,
    required this.isTablet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = isTablet ? 220.0 : 160.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: w,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: ep.imageUrl,
                      fit: BoxFit.cover,
                    ),

                    // Gradiente inferior
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.75),
                          ],
                        ),
                      ),
                    ),

                    // Badge episodio
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          ep.episodeNumber,
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Play overlay
                    Center(
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.55),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ep.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── FAVORITE CARD ────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
class _FavoriteCard extends StatelessWidget {
  final Anime anime;
  final bool isTablet;
  final VoidCallback onTap;

  const _FavoriteCard({
    required this.anime,
    required this.isTablet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = isTablet ? 150.0 : 110.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: w,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: anime.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              anime.title,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── EPISODE CARD (grid) ───────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
class _EpisodeCard extends StatelessWidget {
  final AnimeEpisode ep;
  final VoidCallback onTap;

  const _EpisodeCard({required this.ep, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                  width: 0.8,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: ep.imageUrl,
                      fit: BoxFit.cover,
                    ),
                    // Gradiente suave abajo
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            ep.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            ep.episodeNumber,
            style: const TextStyle(color: Colors.orange, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
