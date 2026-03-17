import 'package:animex/screens/main_screen.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 0; // Controla la transparencia

  @override
  void initState() {
    super.initState();
    
    // 1. Iniciamos la animación de aparición después de un momento
    Future.delayed(Duration(milliseconds: 300), () {
      if (mounted) setState(() => _opacity = 1.0);
    });

    // 2. Esperamos un total de 4 segundos antes de ir a la Home
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: Duration(milliseconds: 800),
            pageBuilder: (_, __, ___) => MainScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedOpacity(
          duration: Duration(milliseconds: 1500), // La aparición dura 1.5 segundos
          curve: Curves.easeIn,
          opacity: _opacity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              
              // El logo de la "Empresa" Madre
              Image.asset('assets/images/animex_logo.png',height: 50,),
              Image.asset('assets/images/freeline_logo_outlined.png', height: 33,),
                            
              // El área de especialización
              Text(
                'ENTERTAINMENT & SOFTWARE',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 4,
                ),
              ),
              SizedBox(height: 60),
              // Un indicador de carga más fino y elegante
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.orange.withOpacity(0.5),
                  strokeWidth: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}