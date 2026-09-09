import 'package:flutter/material.dart';

import '../../widgets/brand_mark.dart';

/// Shown whenever the app has nothing else to show yet: while start-up is
/// still wiring the services together, and again while the router waits for
/// the saved session to be restored. The same screen for both, so the two run
/// into each other without a visible seam.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(size: 96),
            SizedBox(height: 28),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}
