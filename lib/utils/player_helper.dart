import 'package:flutter/material.dart';
import '../models/anime_episode.dart';
import '../services/scraper_service.dart';
import '../services/video_extractor_service.dart';
import '../screens/native_player_screen.dart';

class PlayerHelper {
  static Future<void> playSmart(
    BuildContext context,
    List<VideoServer> servers,
    AnimeEpisode episode,
  ) async {
    if (servers.isEmpty) return;

    // Mostrar diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      ),
    );

    final extractor = VideoExtractorService();
    String? directLink;

    // Orden de prioridad: STAPE primero (mejor calidad nativa),
    // YOURUPLOAD segundo (extractor confirmado), resto al final
    final sortedServers = [
      ...servers.where((s) => s.serverName == 'STAPE'),
      ...servers.where((s) => s.serverName == 'YOURUPLOAD'),
      ...servers.where((s) => s.serverName != 'STAPE' && s.serverName != 'YOURUPLOAD'),
    ];

    for (var server in sortedServers) {
      debugPrint("FREELINE: Extrayendo de ${server.serverName}...");
      try {
        directLink = await extractor.getDirectLink(server.url);
        if (directLink != null) break;
      } catch (e) {
        debugPrint("Error extrayendo de ${server.serverName}: $e");
      }
    }

    // Quitar diálogo de carga
    if (context.mounted) Navigator.pop(context);

    if (!context.mounted) return;

    if (directLink != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NativePlayerScreen(url: directLink!, episode: episode),
        ),
      );
    } else {
      // Mensaje de error si ningún servidor funcionó de forma nativa
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se pudo obtener el link nativo. Revisa la consola."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}