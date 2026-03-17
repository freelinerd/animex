import 'dart:convert';

class Anime {
  final String title;
  final String imageUrl;
  final String link;
  final String type;

  Anime({
    required this.title,
    required this.imageUrl,
    required this.link,
    this.type = 'Anime',
  });

  // Convierte el objeto a un formato de texto (Mapa) para guardarlo
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'imageUrl': imageUrl,
      'link': link,
      'type': type,
    };
  }

  // Reconstruye el objeto a partir del texto guardado
  factory Anime.fromMap(Map<String, dynamic> map) {
    return Anime(
      title: map['title'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      link: map['link'] ?? '',
      type: map['type'] ?? 'Anime',
    );
  }

  // Ayudantes para JSON
  String toJson() => json.encode(toMap());
  factory Anime.fromJson(String source) => Anime.fromMap(json.decode(source));
}