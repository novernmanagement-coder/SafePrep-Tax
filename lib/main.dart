import 'dart:io';
import 'package:flutter/material.dart';
import 'app_state_persistence.dart';
import 'csv_loader.dart';
import 'iap_service.dart';
import 'splash_page.dart';
import 'mixpanel_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Mixpanel
  await MixpanelService.instance.init();

  // Load persisted user state first
  await AppStatePersistence.load();

  // Sync CSVs from GitHub in the background.
  // Won't block launch — if offline, bundled/cached files are used.
  CsvUpdater.syncIfNeeded();

  // Initialize IAP service — iOS and Android only.
  //
  // FIXED (Aug 2026): this used to be awaited here, which meant the
  // whole app — including SplashPage — could not paint its first
  // Flutter frame until Play Billing/StoreKit finished connecting.
  // The native Android launch icon shows automatically while waiting
  // for that first frame, so a slow or hung billing connection (seen
  // right after a fresh Play Store install) left the app stuck on
  // that icon forever: no error, no Flutter UI, nothing. Fire this
  // off in the background instead, same as CsvUpdater.syncIfNeeded()
  // just above — the paywall already handles products not being
  // loaded yet (IAPResult.productNotFound) and retries _loadProducts()
  // itself if a product is missing when a purchase is attempted.
  if (Platform.isIOS || Platform.isAndroid) {
    IAPService.instance.initialize();
  }

  runApp(const SafePrepApp());
}

class SafePrepApp extends StatelessWidget {
  const SafePrepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tax Starter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0077C8)),
        useMaterial3: true,
      ),
      home: const SplashPage(),
      builder: (context, child) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390, maxHeight: 844),
            child: child!,
          ),
        );
      },
    );
  }
}
