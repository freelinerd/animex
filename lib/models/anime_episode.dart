class AnimeEpisode {
  final String  title;
  final String  episodeNumber;
  final String  imageUrl;
  final String  link;
  final String? animeLink;

  const AnimeEpisode({
    required this.title,
    required this.episodeNumber,
    required this.imageUrl,
    required this.link,
    this.animeLink,
  });

  // ── Serialización ─────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'title':         title,
        'episodeNumber': episodeNumber,
        'imageUrl':      imageUrl,
        'link':          link,
        'animeLink':     animeLink,
      };

  factory AnimeEpisode.fromJson(Map<String, dynamic> json) => AnimeEpisode(
        title:         json['title']         as String? ?? '',
        episodeNumber: json['episodeNumber'] as String? ?? '',
        imageUrl:      json['imageUrl']      as String? ?? '',
        link:          json['link']          as String? ?? '',
        animeLink:     json['animeLink']     as String?,
      );
}