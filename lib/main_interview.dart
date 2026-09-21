import 'package:flutter/material.dart';
import 'interview_app_home_page.dart';
import 'mixpanel_service.dart';

// Second entry point sharing this same codebase/repo with Tax Starter's
// main.dart, per the "one repo, build flavors" direction: this boots a
// separate, much smaller app (working name "How To Ace The Interview")
// that reuses InterviewPrepPage and the shared engine underneath it,
// without any of Tax Starter's onboarding, dashboard, or paywall.
//
// Deliberately skips AppStatePersistence.load(), CsvUpdater.syncIfNeeded()
// and IAPService.instance.initialize() that main.dart runs — none of
// that (persisted category scores, remote tax-question sync, purchases)
// applies to this MVP. If this app later needs its own purchase/paywall,
// that's a separate, deliberate addition, not something to copy-paste
// back in from main.dart.
//
// This file is only the Dart-side half of the split. To actually build
// this as its own installable app (a separate binary from Tax Starter,
// with its own bundle id, app icon, and display name), it still needs a
// native Flutter flavor/scheme wired up: a second Android product flavor
// and a second iOS scheme/target, each pointing at
// --target=lib/main_interview.dart. This session has no Xcode/Android
// Studio access to add that natively or to compile-check this file —
// run `flutter analyze` / `flutter run -t lib/main_interview.dart`
// locally before relying on it.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 'IA' keeps this app's analytics separate from Tax Starter's 'ST' —
  // see the comment on MixpanelService's _appPrefix for why that
  // matters. Rename freely; it just needs to stay unique across every
  // SafePrep app sharing this Mixpanel project.
  await MixpanelService.instance.init(appPrefix: 'IA');

  runApp(const InterviewAceApp());
}

class InterviewAceApp extends StatelessWidget {
  const InterviewAceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'How To Ace The Interview',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A6FA5)),
        useMaterial3: true,
      ),
      home: const InterviewAppHomePage(),
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
