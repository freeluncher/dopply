// =============================================================================
// Loading Screen - Simplified Loading Widget
// =============================================================================

import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  final String message;
  final bool showSpinner;

  const LoadingScreen({
    super.key,
    this.message = 'Memuat...',
    this.showSpinner = true,
  });

  @override
  Widget build(BuildContext context) {
    print(
      '[LOADING SCREEN] build() called, message: $message, showSpinner: $showSpinner',
    );
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Image.asset(
                'assets/images/icon-dopply-transparent.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 32),

            // Loading Spinner
            if (showSpinner)
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),

            const SizedBox(height: 16),

            // Loading Message
            Text(
              message,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
