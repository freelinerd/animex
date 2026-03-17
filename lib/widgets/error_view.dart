import 'package:flutter/material.dart';

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorView({
    Key? key, 
    required this.message, 
    required this.onRetry
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono sutil de advertencia
            Icon(
              Icons.cloud_off_rounded, 
              color: Colors.orange.withOpacity(0.4), 
              size: 70
            ),
            const SizedBox(height: 24),
            const Text(
              'CONEXIÓN INTERRUMPIDA',
              style: TextStyle(
                color: Colors.white, 
                fontSize: 16, 
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 30),
            // Botón de reintento estilo FREELINE
            SizedBox(
              width: 180,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 8),
                    Text('REINTENTAR', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}