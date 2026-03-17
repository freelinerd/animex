import 'package:flutter/material.dart';
import '../models/anime.dart';
import '../services/scraper_service.dart';
import 'anime_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GenreResultsScreen extends StatefulWidget {
  final String genreName;
  const GenreResultsScreen({required this.genreName});

  @override
  _GenreResultsScreenState createState() => _GenreResultsScreenState();
}

class _GenreResultsScreenState extends State<GenreResultsScreen> {
  final ScraperService _scraperService = ScraperService();
  bool _isLoading = true;
  List<Anime> _animes = [];

  @override
  void initState() {
    super.initState();
    _loadGenreData();
  }

  void _loadGenreData() async {
    var results = await _scraperService.getAnimesByGenre(widget.genreName);
    if (mounted) {
      setState(() {
        _animes = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    int crossAxisCount = MediaQuery.of(context).size.width > 600 ? 4 : 2;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.genreName.toUpperCase(), style: const TextStyle(fontSize: 14)),
        shape: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.8)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.68,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
            ),
            itemCount: _animes.length,
            itemBuilder: (context, index) {
              var anime = _animes[index];
              return _buildAnimeCard(anime);
            },
          ),
    );
  }

  Widget _buildAnimeCard(Anime anime) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AnimeDetailsScreen(anime: anime))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(imageUrl: anime.imageUrl, fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          const SizedBox(height: 8),
          Text(anime.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}