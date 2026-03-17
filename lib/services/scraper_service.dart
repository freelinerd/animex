import 'package:http/http.dart' as http;
import 'package:html/parser.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/anime.dart';
import '../models/anime_episode.dart';

class ScraperService {
  final String baseUrl = "https://www3.animeflv.net/";

  String fixUrl(String url) {
    if (url.startsWith('http')) return url;
    return '$baseUrl$url';
  }

  // 1️⃣ Episodios recientes
  Future<List<AnimeEpisode>> getRecentEpisodes() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));

      if (response.statusCode == 200) {
        var document = parse(response.body);
        var elements = document.querySelectorAll('.ListEpisodios li');

        return elements.map((element) {
          var title = element.querySelector('.Title')?.text.trim() ?? '';
          var episodeNumber = element.querySelector('.Capi')?.text.trim() ?? '';
          var image =
              element.querySelector('.Image img')?.attributes['src'] ?? '';
          var link = element.querySelector('a')?.attributes['href'] ?? '';

          var animeLinkParts = link
              .replaceFirst('/ver/', '/anime/')
              .split('-')
              .toList();

          if (animeLinkParts.isNotEmpty) animeLinkParts.removeLast();

          return AnimeEpisode(
            title: title,
            episodeNumber: episodeNumber,
            imageUrl: fixUrl(image),
            link: fixUrl(link),
            animeLink: '$baseUrl${animeLinkParts.join('-')}',
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("Error en getRecentEpisodes: $e");
    }

    return [];
  }

  // 2️⃣ Buscador
  Future<List<Anime>> searchAnimes(String query) async {
    try {
      final response = await http.get(Uri.parse('${baseUrl}browse?q=$query'));

      if (response.statusCode == 200) {
        var document = parse(response.body);
        var elements = document.querySelectorAll('.ListAnimes li');

        return elements.map((element) {
          var title = element.querySelector('.Title')?.text.trim() ?? '';
          var image =
              element.querySelector('.Image img')?.attributes['src'] ?? '';
          var link = element.querySelector('a')?.attributes['href'] ?? '';
          var type = element.querySelector('.Type')?.text.trim() ?? 'Anime';

          return Anime(
            title: title,
            imageUrl: fixUrl(image),
            link: fixUrl(link),
            type: type,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("Error en searchAnimes: $e");
    }

    return [];
  }

  // 3️⃣ Detalles del anime (CORREGIDO)
  Future<Map<String, dynamic>> getAnimeDetails(Anime anime) async {
    try {
      final response = await http.get(Uri.parse(anime.link));

      if (response.statusCode == 200) {
        var document = parse(response.body);

        // Sinopsis
        var description =
            document.querySelector('.Description p')?.text.trim() ??
            'Sin descripción';

        // Géneros
        var genreElements = document.querySelectorAll('.Nvgnrs a, .nvgnrs a');
        List<String> genres = genreElements.map((e) => e.text.trim()).toList();

        // Estado
        var statusElement = document.querySelector('.fa-tv')?.parent;
        String status = statusElement?.text.trim() ?? 'Finalizado';
        if (status.contains('En emisión')) {
          status = 'En emisión';
        }

        // ── EXTRACCIÓN DE SCRIPTS (Próximo episodio y Lista de episodios) ──
        var allScripts = document.querySelectorAll('script');
        String nextEpisodeDate = "";
        String episodesData = "";

        for (var script in allScripts) {
          final text = script.text;

          // Extraemos anime_info usando Regex (Más seguro que split)
          if (nextEpisodeDate.isEmpty && text.contains('anime_info')) {
            final animeInfoRegex = RegExp(r'var anime_info\s*=\s*\[([^\]]+)\]');
            final animeInfoMatch = animeInfoRegex.firstMatch(text);

            if (animeInfoMatch != null) {
              final rawArray = animeInfoMatch.group(1)!;
              final dateRegex = RegExp(r'"(\d{4}-\d{2}-\d{2})"');
              final dateMatch = dateRegex.firstMatch(rawArray);
              if (dateMatch != null) {
                nextEpisodeDate = dateMatch.group(1)!;
              }
            }
          }

          // Extraemos la variable episodes para construir la lista
          if (episodesData.isEmpty && text.contains('var episodes = [')) {
            episodesData = text.split('var episodes = [')[1].split('];')[0];
          }

          if (nextEpisodeDate.isNotEmpty && episodesData.isNotEmpty) break;
        }

        // ⭐ RELACIONADOS (Lógica corregida de scraper_service1)
        List<Anime> related = [];
        var relatedElements = document.querySelectorAll('.ListAnmRel li');

        for (var element in relatedElements) {
          var a = element.querySelector('a');
          var title = a?.text.trim() ?? '';
          var link = a?.attributes['href'] ?? '';

          var relText = element.text.split('(');
          var relType = relText.length > 1 ? " (" + relText.last.trim() : "";

          if (title.isNotEmpty) {
            try {
              var searchResult = await searchAnimes(title);
              if (searchResult.isNotEmpty) {
                var found = searchResult.first;
                related.add(
                  Anime(
                    title: title + relType,
                    imageUrl: found.imageUrl,
                    link: found.link,
                    type: found.type,
                  ),
                );
              } else {
                String slug = link.split('/').last;
                related.add(
                  Anime(
                    title: title + relType,
                    imageUrl: "https://www3.animeflv.net/uploads/animes/covers/$slug.jpg",
                    link: link.startsWith('http') ? link : '$baseUrl$link',
                  ),
                );
              }
            } catch (e) {
              debugPrint("Error buscando relacionado: $e");
            }
          }
        }

        // 📺 CONSTRUCCIÓN DE EPISODIOS
        List<AnimeEpisode> episodes = [];
        if (episodesData.isNotEmpty) {
          var rawEpisodes = jsonDecode('[$episodesData]');
          String animeSlug = anime.link.split('/').last;

          for (var ep in rawEpisodes) {
            episodes.add(
              AnimeEpisode(
                title: anime.title,
                episodeNumber: 'Episodio ${ep[0]}',
                imageUrl: anime.imageUrl,
                link: '${baseUrl}ver/$animeSlug-${ep[0]}',
                animeLink: anime.link,
              ),
            );
          }
        }

        return {
          'description': description,
          'genres': genres,
          'status': status,
          'episodes': episodes,
          'related': related,
          'nextEpisode': nextEpisodeDate,
        };
      }
    } catch (e) {
      debugPrint("Error en getAnimeDetails: $e");
    }

    throw Exception('Error al cargar detalles');
  }

  // 4️⃣ Animes por género
  Future<List<Anime>> getAnimesByGenre(String genre) async {
    try {
      String formattedGenre = genre
          .toLowerCase()
          .replaceAll('ó', 'o')
          .replaceAll('á', 'a')
          .replaceAll('é', 'e')
          .replaceAll('í', 'i')
          .replaceAll('ú', 'u')
          .trim();

      final response = await http.get(Uri.parse('${baseUrl}browse?genre=$formattedGenre'));

      if (response.statusCode == 200) {
        var document = parse(response.body);
        var elements = document.querySelectorAll('.ListAnimes li');

        return elements.map((element) {
          var title = element.querySelector('.Title')?.text.trim() ?? '';
          var image = element.querySelector('.Image img')?.attributes['src'] ?? '';
          var link = element.querySelector('a')?.attributes['href'] ?? '';

          return Anime(
            title: title,
            imageUrl: fixUrl(image),
            link: fixUrl(link),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("Error en getAnimesByGenre: $e");
    }
    return [];
  }

  // 5️⃣ Servidores de video
  Future<List<VideoServer>> getEpisodeServers(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        var document = parse(response.body);
        var scripts = document.querySelectorAll('script');

        for (var script in scripts) {
          final content = script.text;
          if (content.contains('var videos = {')) {
            var jsonString = content.split('var videos = ')[1].split(';')[0];
            var data = jsonDecode(jsonString);
            List<VideoServer> servers = [];

            if (data['SUB'] != null) {
              for (var s in data['SUB']) {
                String name = s['title'].toString().toUpperCase();
                if (name == "SB" || name == "XSTOP") continue;

                servers.add(
                  VideoServer(serverName: name, url: s['code'].toString()),
                );
              }
            }
            return servers;
          }
        }
      }
    } catch (e) {
      debugPrint("Error en getEpisodeServers: $e");
    }
    return [];
  }

  // 6️⃣ Directorio de animes con paginación (orden por defecto de AnimeFlv)
  Future<List<Anime>> getAnimeDirectory({int page = 1}) async {
    try {
      final url = page == 1
          ? '${baseUrl}browse'
          : '${baseUrl}browse?page=$page';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        var document = parse(response.body);
        var elements = document.querySelectorAll('.ListAnimes li');

        return elements.map((element) {
          var title  = element.querySelector('h3.Title')?.text.trim() ?? '';
          var image  = element.querySelector('.Image img')?.attributes['src'] ?? '';
          var link   = element.querySelector('a')?.attributes['href'] ?? '';
          var type   = element.querySelector('.Type')?.text.trim() ?? 'Anime';
          var rating = element.querySelector('.Vts')?.text.trim() ?? '';

          // Las imagenes pueden venir de animeflv.net sin www3
          String fixedImage = image;
          if (image.startsWith('//')) {
            fixedImage = 'https:$image';
          } else if (image.startsWith('/')) {
            fixedImage = 'https://www3.animeflv.net$image';
          } else if (image.startsWith('https://animeflv.net')) {
            fixedImage = image.replaceFirst(
                'https://animeflv.net', 'https://www3.animeflv.net');
          }

          return Anime(
            title:    title,
            imageUrl: fixedImage.isEmpty ? fixUrl(image) : fixedImage,
            link:     fixUrl(link),
            type:     (rating.isNotEmpty && rating != '0.0')
                ? '$type  ★$rating'
                : type,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("Error en getAnimeDirectory: $e");
    }
    return [];
  }
}

class VideoServer {
  final String serverName;
  final String url;
  VideoServer({required this.serverName, required this.url});
}