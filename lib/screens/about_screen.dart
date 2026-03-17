import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  static const _version = '1.4.1';
  static const _githubUrl = '';
  static const _instagramUrl = 'https://www.instagram.com/freelinex?igsh=ZXNuMWg3eHN6OHk4';
  static const _twitterUrl = 'https://x.com/freelinex_';

  // Solo muestra links que tengan URL configurado
  List<Map<String, dynamic>> get _links => [
    if (_githubUrl.isNotEmpty)
      {'icon': Icons.code_rounded, 'label': 'GitHub', 'url': _githubUrl},
    if (_instagramUrl.isNotEmpty)
      {'icon': Icons.camera_alt_outlined, 'label': 'Instagram', 'url': _instagramUrl},
    if (_twitterUrl.isNotEmpty)
      {'icon': Icons.alternate_email_rounded, 'label': 'Twitter / X', 'url': _twitterUrl},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Acerca de',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        shape: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.8),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Logo / nombre ───────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/animex_logo.png',
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'by FREELINE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.2),
                        width: 0.8,
                      ),
                    ),
                    child: const Text(
                      'v$_version',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // ── Descripción ─────────────────────────────────────────────────
            _Section(
              title: 'SOBRE LA APP',
              child: const Text(
                'AnimeX es una aplicación de streaming de anime diseñada por '
                'FREELINE para brindarte la mejor experiencia visual posible. '
                'Disfruta tus series favoritas sin interrupciones y una interfaz moderna e intuitiva.'
                'Anime Online - Ningún vídeo se encuentra alojado en nuestros servidores.',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.7,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Creador ─────────────────────────────────────────────────────
            _Section(
              title: 'CREADOR',
              child: _InfoRow(
                icon: Icons.person_rounded,
                label: 'Desarrollado bajo la firma',
                value: 'FREELINE',
              ),
            ),

            const SizedBox(height: 24),

            // ── Créditos ────────────────────────────────────────────────────
            _Section(
              title: 'CRÉDITOS',
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.public_rounded,
                    label: 'Contenido provisto por',
                    value: 'AnimeFLV.NET',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.06),
                        width: 0.8,
                      ),
                    ),
                    child: const Text(
                      'Esta aplicación no almacena ni distribuye contenido. '
                      'Todo el contenido es propiedad de sus respectivos autores '
                      'y se accede a través de fuentes públicas.',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Redes / Links (solo si hay al menos uno configurado) ─────────
            if (_links.isNotEmpty) ...[
              const SizedBox(height: 24),
              _Section(
                title: 'SÍGUENOS',
                child: Column(
                  children: [
                    for (int i = 0; i < _links.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _LinkRow(
                        icon: _links[i]['icon'] as IconData,
                        label: _links[i]['label'] as String,
                        url: _links[i]['url'] as String,
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 40),

            // ── Footer ──────────────────────────────────────────────────────
            Center(
              child: Text(
                '© ${DateTime.now().year} FREELINE. Todos los derechos reservados.',
                style: const TextStyle(color: Colors.white24, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Sección con título ────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

// ── Fila de información ───────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange, size: 18),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Fila de link ──────────────────────────────────────────────────────────────
class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;

  const _LinkRow({
    required this.icon,
    required this.label,
    required this.url,
  });

  String get _handle {
    try {
      final uri = Uri.parse(url);
      final path = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      // Ignora segmentos que parecen parámetros o hashes
      final clean = path.firstWhere(
        (s) => !s.contains('?') && !s.contains('='),
        orElse: () => uri.host,
      );
      return '@$clean';
    } catch (_) {
      return url;
    }
  }

  Future<void> _launch() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _launch,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.orange.withOpacity(0.15),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.orange, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _handle,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white24,
              size: 12,
            ),
          ],
        ),
      ),
    );
  }
}