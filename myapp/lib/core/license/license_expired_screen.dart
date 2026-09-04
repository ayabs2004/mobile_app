import 'package:flutter/material.dart';

class LicenseExpiredScreen extends StatelessWidget {
  final VoidCallback? onRetry;

  const LicenseExpiredScreen({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D18),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.redAccent),
              const SizedBox(height: 24),
              const Text(
                'Licence inactive',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "La licence de l'application est actuellement "
                'inactive ou expiree. Merci de contacter le support.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.shade400,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    // Feedback visuel au clic (ripple + assombrissement au press)
                    elevation: 2,
                    shadowColor: Colors.black45,
                    overlayColor: Colors.black.withOpacity(0.15),
                  ).copyWith(
                    // Ripple bien visible meme sur fond fonce
                    splashFactory: InkRipple.splashFactory,
                  ),
                  child: const Text('Reessayer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}