import 'package:flutter/material.dart';
import 'genre_results_screen.dart';

class CategoriesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> categories = [
    {'name': 'Acción', 'icon': Icons.flash_on},
    {'name': 'Aventura', 'icon': Icons.explore},
    {'name': 'Comedia', 'icon': Icons.sentiment_very_satisfied},
    {'name': 'Drama', 'icon': Icons.theater_comedy},
    {'name': 'Fantasía', 'icon': Icons.auto_fix_high},
    {'name': 'Romance', 'icon': Icons.favorite},
    {'name': 'Terror', 'icon': Icons.scuba_diving}, // Un icono que de miedo o similar
    {'name': 'Seinen', 'icon': Icons.person},
    {'name': 'Shonen', 'icon': Icons.bolt},
    {'name': 'Sobrenatural', 'icon': Icons.visibility},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('CATEGORÍAS', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16)),
        shape: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.8)),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          var cat = categories[index];
          return InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (context) => GenreResultsScreen(genreName: cat['name'])
            )),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05), width: 0.8),
                gradient: LinearGradient(
                  colors: [Colors.orange.withOpacity(0.1), Colors.transparent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(cat['icon'], color: Colors.orange, size: 30),
                  const SizedBox(height: 8),
                  Text(cat['name'].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}