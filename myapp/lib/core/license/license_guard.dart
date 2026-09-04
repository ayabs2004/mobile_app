import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'license_expired_screen.dart';
import 'license_provider.dart';

class LicenseGuard extends ConsumerWidget {
  final Widget child;

  const LicenseGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licenseAsync = ref.watch(licenseValidProvider);

    return licenseAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF080D18),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => LicenseExpiredScreen(
        onRetry: () => ref.invalidate(licenseValidProvider),
      ),
      data: (isValid) {
        if (!isValid) {
          return LicenseExpiredScreen(
            onRetry: () => ref.invalidate(licenseValidProvider),
          );
        }
        return child;
      },
    );
  }
}
