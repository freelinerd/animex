import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/anime.dart';
import '../models/anime_episode.dart';
import '../services/scraper_service.dart';
import '../services/favorites_service.dart';
import '../services/history_service.dart';
import 'episode_screen.dart';

class AnimeDetailsScreen extends StatefulWidget {
  final Anime anime;
  const AnimeDetailsScreen({Key? key, required this.anime}) : super(key: key);

  @override
  _AnimeDetailsScreenState createState() => _AnimeDetailsScreenState();
}

class _AnimeDetailsScreenState extends State<AnimeDetailsScreen> {
  final ScraperService _scraperService = ScraperService();
  final FavoritesService _favoritesService = FavoritesService();
  final HistoryService _historyService = HistoryService();

  bool _isLoading = true;
  bool _isFavorite = false;
  bool _isExpanded = false;
  String _description = '';
  String _status = '';
  String _nextEpisode = '';
  List<String> _genres = [];
  List<AnimeEpisode> _episodes = [];
  List<Anime> _relatedAnimes = [];
  List<AnimeEpisode> _history = [];
  Map<String, double> _progress = {}; // episodeLink → 0.0-1.0
  bool _sortAscending = false; // false = mayor a menor (default)

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await _scraperService.getAnimeDetails(widget.anime);
      final isFav = await _favoritesService.isFavorite(widget.anime.link);
      final hist = await _historyService.getHistory();
      final prog = await _historyService.getAllProgress();

      if (mounted)
        setState(() {
          _description = data['description'] ?? '';
          _genres = List<String>.from(data['genres'] ?? []);
          _status = data['status'] ?? '';
          _nextEpisode = data['nextEpisode'] ?? '';
          _episodes = List<AnimeEpisode>.from(data['episodes'] ?? []);
          _relatedAnimes = List<Anime>.from(data['related'] ?? []);
          _history = hist;
          _progress = prog;
          _isFavorite = isFav;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Devuelve la lista ordenada según _sortAscending
  List<AnimeEpisode> get _sortedEpisodes {
    final list = List<AnimeEpisode>.from(_episodes);
    if (_sortAscending) {
      // menor → mayor (Episodio 1 primero)
      list.sort((a, b) {
        final na =
            int.tryParse(a.episodeNumber.replaceAll(RegExp(r'[^0-9]'), '')) ??
            0;
        final nb =
            int.tryParse(b.episodeNumber.replaceAll(RegExp(r'[^0-9]'), '')) ??
            0;
        return na.compareTo(nb);
      });
    } else {
      // mayor → menor (último episodio primero — default)
      list.sort((a, b) {
        final na =
            int.tryParse(a.episodeNumber.replaceAll(RegExp(r'[^0-9]'), '')) ??
            0;
        final nb =
            int.tryParse(b.episodeNumber.replaceAll(RegExp(r'[^0-9]'), '')) ??
            0;
        return nb.compareTo(na);
      });
    }
    return list;
  }

  bool _isWatched(String link) => _history.any((h) => h.link == link);
  double _getProgress(String link) => _progress[link] ?? 0.0;

  AnimeEpisode _nextEpisodeToWatch() {
    if (_episodes.isEmpty)
      return AnimeEpisode(
        title: '',
        episodeNumber: '',
        imageUrl: '',
        link: '',
        animeLink: '',
      );
    try {
      return _episodes.reversed.firstWhere(
        (ep) => !_isWatched(ep.link),
        orElse: () => _episodes.first,
      );
    } catch (_) {
      return _episodes.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: _isLoading || _episodes.isEmpty
          ? null
          : FloatingActionButton.extended(
              elevation: 6,
              backgroundColor: Colors.orange,
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
              label: Text(
                'CONTINUAR • ${_nextEpisodeToWatch().episodeNumber}',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EpisodeScreen(episode: _nextEpisodeToWatch()),
                  ),
                );
                _loadData();
              },
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // ── SliverAppBar hero ────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 320,
                  pinned: true,
                  backgroundColor: Colors.black,
                  shape: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.08),
                      width: 0.8,
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: widget.anime.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: Colors.black),
                          errorWidget: (_, __, ___) =>
                              Container(color: Colors.grey[900]),
                        ),
                        DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: Colors.orange,
                      ),
                      onPressed: () async {
                        await _favoritesService.toggleFavorite(widget.anime);
                        setState(() => _isFavorite = !_isFavorite);
                      },
                    ),
                  ],
                ),

                // ── Info: título, estado, géneros, sinopsis ──────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título
                        Text(
                          widget.anime.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Estado
                        _StatusBadge(status: _status),
                        const SizedBox(height: 16),

                        // Géneros
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _genres
                              .map((g) => _GenreChip(genre: g))
                              .toList(),
                        ),
                        const SizedBox(height: 22),

                        // Sinopsis
                        const Text(
                          'SINOPSIS',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _isExpanded = !_isExpanded),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _description,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                                maxLines: _isExpanded ? null : 3,
                                overflow: _isExpanded
                                    ? TextOverflow.visible
                                    : TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isExpanded ? 'Ver menos' : 'Ver más...',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          color: Colors.white.withOpacity(0.1),
                          thickness: 0.8,
                          height: 32,
                        ),

                        // Relacionados
                        if (_relatedAnimes.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text(
                            'RELACIONADOS',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            height: 190,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _relatedAnimes.length,
                              itemBuilder: (context, index) {
                                var rel = _relatedAnimes[index];
                                return GestureDetector(
                                  onTap: () {
                                    // ✨ CLAVE: Pasamos el objeto 'rel' completo
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AnimeDetailsScreen(anime: rel),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 120,
                                    margin: const EdgeInsets.only(right: 15),
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: CachedNetworkImage(
                                              imageUrl: rel
                                                  .imageUrl, // 👈 Si el scraper lo envió bien, aquí se verá
                                              fit: BoxFit.cover,
                                              width: 120,
                                              // Placeholder para evitar que se quede vacío mientras carga
                                              placeholder: (context, url) =>
                                                  Container(
                                                    color: Colors.white10,
                                                  ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      const Icon(
                                                        Icons.movie,
                                                        color: Colors.white10,
                                                      ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          rel.title,
                                          maxLines: 2,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],

                        Divider(
                          color: Colors.white.withOpacity(0.15),
                          thickness: 0.8,
                        ),
                        const SizedBox(height: 15),

                        // Próximo episodio
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: _nextEpisode.isNotEmpty
                              ? Container(
                                  key: const ValueKey("nextEpisode"),
                                  margin: const EdgeInsets.only(bottom: 25),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.35),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.schedule_rounded,
                                        color: Colors.orange,
                                        size: 26,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "PRÓXIMO EPISODIO",
                                              style: TextStyle(
                                                color: Colors.orange,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              _nextEpisode,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),

                        // Encabezado de episodios + botón de orden
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'EPISODIOS (${_episodes.length})',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(
                                () => _sortAscending = !_sortAscending,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.12),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // ✨ Widget para la rotación animada
                                    AnimatedRotation(
                                      turns: _sortAscending
                                          ? 0.5
                                          : 0, // 0.5 vueltas = 180 grados
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                      child: const Icon(
                                        Icons
                                            .sort_outlined, // Mantenemos un solo icono fijo
                                        color: Colors.orange,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _sortAscending
                                          ? 'MENOR A MAYOR'
                                          : 'MAYOR A MENOR',
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Lista de episodios estilo Disney+ ────────────────────
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final ep = _sortedEpisodes[index];
                    final watched = _isWatched(ep.link);
                    final progress = _getProgress(ep.link);

                    return _EpisodeTile(
                      ep: ep,
                      watched: watched,
                      progress: progress,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EpisodeScreen(episode: ep),
                          ),
                        );
                        _loadData();
                      },
                    );
                  }, childCount: _sortedEpisodes.length),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── EPISODE TILE estilo Disney+ ───────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
class _EpisodeTile extends StatelessWidget {
  final AnimeEpisode ep;
  final bool watched;
  final double progress; // 0.0 - 1.0
  final VoidCallback onTap;

  const _EpisodeTile({
    required this.ep,
    required this.watched,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool inProgress = progress > 0.02 && progress < 0.98 && !watched;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.04),
              width: 0.8,
            ),
          ),
        ),
        child: Row(
          children: [
            // Thumbnail
            _EpisodeThumbnail(
              imageUrl: ep.imageUrl,
              watched: watched,
              progress: progress,
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Número + estado
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ep.episodeNumber,
                          style: TextStyle(
                            color: watched ? Colors.white38 : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (watched)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 14,
                        ),
                      if (inProgress)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            '${(progress * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Barra de progreso (si en curso)
                  if (inProgress) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        color: Colors.orange,
                        minHeight: 2,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Flecha
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: watched ? Colors.white.withOpacity(0.08) : Colors.white12,
              size: 12,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Thumbnail del episodio con overlay de progreso ────────────────────────────
class _EpisodeThumbnail extends StatelessWidget {
  final String imageUrl;
  final bool watched;
  final double progress;

  const _EpisodeThumbnail({
    required this.imageUrl,
    required this.watched,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final bool inProgress = progress > 0.02 && progress < 0.98 && !watched;

    return SizedBox(
      width: 100,
      height: 58,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Imagen
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  Container(color: Colors.white.withOpacity(0.05)),
              errorWidget: (_, __, ___) =>
                  Container(color: Colors.white.withOpacity(0.05)),
            ),

            // Overlay si visto
            if (watched) Container(color: Colors.black.withOpacity(0.5)),

            // Play icon
            Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(watched ? 0.3 : 0.5),
                  border: Border.all(
                    color: Colors.white.withOpacity(watched ? 0.15 : 0.3),
                    width: 1,
                  ),
                ),
                child: watched
                    ? const Icon(
                        Icons.replay_rounded,
                        color: Colors.white38,
                        size: 14,
                      )
                    : const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
              ),
            ),

            // Barra de progreso abajo
            if (inProgress)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  color: Colors.orange,
                  minHeight: 3,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    // Lógica para determinar el estado
    final isAiring = status.contains('En emision');

    // Definimos los colores base según el estado
    final Color baseColor = isAiring ? Colors.green : Colors.red;
    final Color accentColor = isAiring ? Colors.greenAccent : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        // Fondo sutil con el color correspondiente
        color: baseColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: baseColor.withOpacity(0.3), width: 0.8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: accentColor, // Verde o Rojo acentuado
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String genre;
  const _GenreChip({required this.genre});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.25), width: 0.8),
      ),
      child: Text(
        genre.toUpperCase(),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _NextEpisodeBanner extends StatelessWidget {
  final String date;
  const _NextEpisodeBanner({required this.date});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(
        key: const ValueKey('nextEpisode'),
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3), width: 0.8),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, color: Colors.orange, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PRÓXIMO EPISODIO',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    date,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
