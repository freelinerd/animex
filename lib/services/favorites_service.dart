import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/anime.dart';

class FavoritesService {
  static const String _key = 'favorite_animes';

  // Obtener lista de favoritos
  Future<List<Anime>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favsJson = prefs.getStringList(_key) ?? [];
    return favsJson.map((item) {
      var map = jsonDecode(item);
      return Anime(
        title: map['title'],
        imageUrl: map['imageUrl'],
        link: map['link'],
      );
    }).toList();
  }

  // Comprobar si un anime ya es favorito
  Future<bool> isFavorite(String link) async {
    List<Anime> favs = await getFavorites();
    return favs.any((element) => element.link == link);
  }

  // ✨ EL MÉTODO QUE FALTA: Toggle (Añadir/Quitar)
  Future<void> toggleFavorite(Anime anime) async {
    final prefs = await SharedPreferences.getInstance();
    List<Anime> favs = await getFavorites();
    
    bool exists = favs.any((element) => element.link == anime.link);

    if (exists) {
      // Si ya existe, lo quitamos
      favs.removeWhere((element) => element.link == anime.link);
    } else {
      // Si no existe, lo añadimos
      favs.add(anime);
    }

    // Guardamos la lista actualizada
    List<String> favsJson = favs.map((item) => jsonEncode({
      'title': item.title,
      'imageUrl': item.imageUrl,
      'link': item.link,
    })).toList();

    await prefs.setStringList(_key, favsJson);
  }
}