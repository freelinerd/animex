import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/favorites_service.dart';
import '../services/history_service.dart';
import '../models/anime.dart';
import '../models/anime_episode.dart';
import 'anime_details_screen.dart';
import 'episode_screen.dart';

class MyListScreen extends StatefulWidget {
  const MyListScreen({Key? key}) : super(key: key);

  @override
  State<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends State<MyListScreen>
    with SingleTickerProviderStateMixin {
  final FavoritesService _favoritesService = FavoritesService();
  final HistoryService _historyService = HistoryService();

  late final TabController _tabController;

  List<Anime> _favorites = [];
  List<AnimeEpisode> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final favs = await _favoritesService.getFavorites();
    final hist = await _historyService.getHistory();
    if (mounted) {
      setState(() {
        _favorites = favs;
        _history = hist;
        _loading = false;
      });
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.8),
        ),
        title: const Text('¿Limpiar historial?',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text('Se eliminarán todos los episodios vistos.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('LIMPIAR',
                style: TextStyle(
                    color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _historyService.clearHistory();
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Mi Lista',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        // Botón limpiar historial — solo visible en la pestaña historial
        actions: [
          AnimatedBuilder(
            animation: _tabController,
            builder: (_, __) {
              if (_tabController.index != 1 || _history.isEmpty) {
                return const SizedBox.shrink();
              }
              return TextButton(
                onPressed: _clearHistory,
                child: const Text(
                  'LIMPIAR',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ],
        shape: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.8),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          indicatorWeight: 2,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          tabs: const [
            Tab(text: 'FAVORITOS'),
            Tab(text: 'HISTORIAL'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orange))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFavoritesTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  // ── Pestaña Favoritos ─────────────────────────────────────────────────────
  Widget _buildFavoritesTab() {
    if (_favorites.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bookmarks_outlined,
        message: 'Aún no tienes favoritos',
        sub: 'Guarda animes desde su página de detalles',
      );
    }

    final isTablet = MediaQuery.of(context).size.width > 600;
    final crossAxis = isTablet ? 4 : 3;

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(14),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxis,
        childAspectRatio: 0.65,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _favorites.length,
      itemBuilder: (context, index) =>
          _buildFavoriteCard(_favorites[index]),
    );
  }

  // ── Pestaña Historial ─────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history_rounded,
        message: 'Sin episodios vistos',
        sub: 'Los episodios que veas aparecerán aquí',
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      itemCount: _history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildHistoryItem(_history[index]),
    );
  }

  // ── Card de favorito (grid) ───────────────────────────────────────────────
  Widget _buildFavoriteCard(Anime anime) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => AnimeDetailsScreen(anime: anime)),
        );
        _loadData();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.orange.withOpacity(0.2), width: 0.8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: CachedNetworkImage(
                  imageUrl: anime.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.white10,
                    child: const Icon(Icons.broken_image,
                        color: Colors.white24),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            anime.title,
            style: const TextStyle(
                color: Colors.white70, fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Item de historial (lista horizontal con imagen) ───────────────────────
  Widget _buildHistoryItem(AnimeEpisode ep) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EpisodeScreen(episode: ep)),
        );
        _loadData();
      },
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.white.withOpacity(0.06), width: 0.8),
        ),
        child: Row(
          children: [
            // Imagen
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(11)),
              child: SizedBox(
                width: 120,
                height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: ep.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          Container(color: Colors.white10),
                    ),
                    // Badge episodio
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ep.episodeNumber,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ep.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Toca para continuar',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
            const Icon(Icons.play_arrow_rounded,
                color: Colors.white24, size: 20),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  // ── Estado vacío genérico ─────────────────────────────────────────────────
  Widget _buildEmptyState(
      {required IconData icon,
      required String message,
      required String sub}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white12, size: 52),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(sub,
              style:
                  const TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }
}
