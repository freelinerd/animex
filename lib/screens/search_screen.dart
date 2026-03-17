import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/scraper_service.dart';
import '../models/anime.dart';
import 'anime_details_screen.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ScraperService _scraperService = ScraperService();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  // Búsqueda / género
  List<Anime> _results = [];
  bool _isLoading = false;
  String _activeGenre = '';
  Timer? _debounce;

  // Directorio con paginación
  final List<Anime> _directory = [];
  int _currentPage = 1;
  bool _loadingMore = false;
  bool _hasMore = true; // false cuando una página vuelve vacía

  static const _categories = [
    {'name': 'Acción', 'color': Color(0xFFE8115B), 'icon': Icons.flash_on},
    {'name': 'Aventura', 'color': Color(0xFF1DB954), 'icon': Icons.explore},
    {
      'name': 'Comedia',
      'color': Color(0xFFAF2896),
      'icon': Icons.sentiment_very_satisfied,
    },
    {'name': 'Drama', 'color': Color(0xFF509BF5), 'icon': Icons.theater_comedy},
    {
      'name': 'Fantasía',
      'color': Color(0xFFE13300),
      'icon': Icons.auto_fix_high,
    },
    {'name': 'Romance', 'color': Color(0xFFF59B23), 'icon': Icons.favorite},
    {'name': 'Terror', 'color': Color(0xFF777777), 'icon': Icons.visibility},
    {'name': 'Shonen', 'color': Color(0xFF8D67AB), 'icon': Icons.bolt},
    {'name': 'Seinen', 'color': Color(0xFF1E3264), 'icon': Icons.person},
    {'name': 'Escolares', 'color': Color(0xFFBA5D07), 'icon': Icons.school},
  ];

  @override
  void initState() {
    super.initState();
    _loadDirectoryPage(1);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Directorio ────────────────────────────────────────────────────────────
  Future<void> _loadDirectoryPage(int page) async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final items = await _scraperService.getAnimeDirectory(page: page);
      if (mounted) {
        setState(() {
          _directory.addAll(items);
          _currentPage = page;
          _hasMore = items.isNotEmpty;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onScroll() {
    // Cargar más cuando el usuario llega al 85% del scroll
    if (!_isSearching &&
        _hasMore &&
        !_loadingMore &&
        _scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent * 0.85) {
      _loadDirectoryPage(_currentPage + 1);
    }
  }

  // ── Búsqueda ──────────────────────────────────────────────────────────────
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _results = [];
          _isLoading = false;
          _activeGenre = '';
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _activeGenre = '';
    });
    try {
      final r = await _scraperService.searchAnimes(query);
      if (mounted)
        setState(() {
          _results = r;
          _isLoading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGenre(String genre) async {
    setState(() {
      _isLoading = true;
      _activeGenre = genre;
      _results = [];
    });
    _searchCtrl.clear();
    try {
      final r = await _scraperService.getAnimesByGenre(genre);
      if (mounted)
        setState(() {
          _results = r;
          _isLoading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _results = [];
      _isLoading = false;
      _activeGenre = '';
    });
  }

  bool get _isSearching =>
      _searchCtrl.text.isNotEmpty || _activeGenre.isNotEmpty;

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Container(
          height: 46,
          alignment: Alignment
              .centerLeft, // ✨ Asegura alineación vertical del contenido
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            cursorColor: Colors.orange,
            // ✨ Permite que el texto se centre verticalmente de forma automática
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: '¿Qué quieres ver?',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              border: InputBorder.none,
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Colors.white38,
                size: 20,
              ),
              // ✨ Ajustamos el padding: 0 en vertical deja que textAlignVertical haga el trabajo
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 0,
              ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
              onPressed: _clearSearch,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildGenrePills(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  )
                : _isSearching
                ? _buildGrid(
                    _results,
                    header: _activeGenre.isNotEmpty
                        ? _activeGenre.toUpperCase()
                        : 'RESULTADOS',
                  )
                : _buildDirectoryGrid(),
          ),
        ],
      ),
    );
  }

  // ── Pills de género ───────────────────────────────────────────────────────
  Widget _buildGenrePills() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06), width: 0.8),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final name = cat['name'] as String;
          final color = cat['color'] as Color;
          final active = _activeGenre == name;

          return GestureDetector(
            onTap: () => active ? _clearSearch() : _loadGenre(name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              // Eliminamos el padding horizontal del contenedor si vamos a usar Center
              // o mantenemos la alineación interna:
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: active ? color.withOpacity(0.18) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active
                      ? color.withOpacity(0.6)
                      : Colors.white.withOpacity(0.12),
                  width: active ? 1.0 : 0.8,
                ),
              ),
              child: Text(
                name,
                textAlign: TextAlign
                    .center, // Asegura el centrado multilínea (opcional)
                style: TextStyle(
                  color: active ? color : Colors.white54,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Grid del directorio con infinite scroll ───────────────────────────────
  Widget _buildDirectoryGrid() {
    if (_directory.isEmpty && _loadingMore) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }
    if (_directory.isEmpty) {
      return const Center(
        child: Text(
          'No se pudo cargar el directorio',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    final crossAxis = MediaQuery.of(context).size.width > 600 ? 4 : 3;

    return CustomScrollView(
      controller: _scrollCtrl,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Text(
                  'DIRECTORIO',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_directory.length}',
                  style: const TextStyle(color: Colors.white24, fontSize: 10),
                ),
                const Spacer(),
                if (_loadingMore)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      color: Colors.orange,
                      strokeWidth: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Grid
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _AnimeCard(
                anime: _directory[i],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AnimeDetailsScreen(anime: _directory[i]),
                  ),
                ),
              ),
              childCount: _directory.length,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxis,
              childAspectRatio: 0.62,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
          ),
        ),
        // Footer de carga
        if (_loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(color: Colors.orange),
              ),
            ),
          ),
        if (!_hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  '— fin del directorio —',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Grid de resultados de búsqueda / género ───────────────────────────────
  Widget _buildGrid(List<Anime> animes, {required String header}) {
    if (animes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              color: Colors.white12,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Sin resultados',
              style: TextStyle(color: Colors.white38),
            ),
          ],
        ),
      );
    }

    final crossAxis = MediaQuery.of(context).size.width > 600 ? 4 : 3;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Text(
                  header,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${animes.length}',
                  style: const TextStyle(color: Colors.white24, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _AnimeCard(
                anime: animes[i],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AnimeDetailsScreen(anime: animes[i]),
                  ),
                ),
              ),
              childCount: animes.length,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxis,
              childAspectRatio: 0.62,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tarjeta de anime ──────────────────────────────────────────────────────────
class _AnimeCard extends StatelessWidget {
  final Anime anime;
  final VoidCallback onTap;
  const _AnimeCard({required this.anime, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: anime.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (_, __) =>
                    Container(color: Colors.white.withOpacity(0.05)),
                errorWidget: (_, __, ___) => Container(color: Colors.white10),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            anime.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (anime.type != null && anime.type!.isNotEmpty)
            Text(
              anime.type!,
              style: const TextStyle(color: Colors.white38, fontSize: 9),
            ),
        ],
      ),
    );
  }
}
