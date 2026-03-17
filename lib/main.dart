import 'package:flutter/material.dart';
import 'screens/splash_screen.dart'; // Importa la nueva pantalla

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Freeline AnimeX',
      debugShowCheckedModeBanner: false, // Quita la banda roja de debug
      theme: ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    primary: Colors.orange,
    secondary: Colors.orangeAccent,
    surface: Colors.black,
    background: Colors.black,
  ),
  // Tipografía personalizada para que se vea más moderno
  textTheme: const TextTheme(
    displayLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    bodyLarge: TextStyle(color: Colors.white70),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.black,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(color: Colors.orange, fontSize: 20, fontWeight: FontWeight.bold),
  ),
),
      home: SplashScreen(), // Cambiamos HomeScreen por SplashScreen
    );
  }
}