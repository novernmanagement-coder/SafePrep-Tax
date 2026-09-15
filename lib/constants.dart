import 'dart:io' show Platform;
import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const Color servSafeBlue = Color(0xFFE3F0F9);
  static const Color headerBlue = Color(0xFFD9E8F4);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Text Colors
  static const Color bodyText = Color(0xFF555555);
  static const Color subtleText = Color(0xFF666666);
  static const Color footerText = Color(0xFF888888);
  static const Color strongText = Color(0xFF333333);
  static const Color starMotifBlue = Color(0xFFC0D2E4);

  // Button Colors
  static const Color primaryButton = Color(0xFF4A6FA5);
  static const Color primaryButtonForeground = Colors.white;
  static const Color secondaryButton = Colors.white;
  static const Color secondaryButtonForeground = Color(0xFF4A6FA5);
  static const Color neutralButton = Color(0xFFEFEFEF);
  static const Color neutralButtonForeground = Color(0xFF333333);
  static const Color upgradeButton = Color(0xFFF0C575);
  static const Color disabledButton = Color(0xFFDDDDDD);
  static const Color disabledButtonForeground = Color(0xFF999999);
  static const Color selectedAnswer = Color(0xFFD0D0D0);
  static const Color selectedAnswerForeground = Color(0xFF000000);
  static const Color selectedAnswerBorder = Color(0xFFA0A0A0);

  // Status Colors
  static const Color error = Color(0xFFD64545);
  static const Color warning = Color(0xFFE6A23C);
  static const Color success = Color(0xFF3BA776);
  static const Color divider = Color(0xFFDDDDDD);
  static const Color cardBorder = Color(0xFFE0E0E0);

  // Score Band Colors
  static const Color scoreBand1 = Color(0xFFE05C5C); // 0-50%
  static const Color scoreBand2 = Color(0xFFE8924A); // 51-65%
  static const Color scoreBand3 = Color(0xFFE6C94A); // 66-84%
  static const Color scoreBand4 = Color(0xFF3BA776); // 85-100%

  // Progress Colors
  static const Color progressBar = Color(0xFF4A6FA5);
  static const Color progressBarBackground = Color(0xFFD9E8F4);
  static const Color progressGreen = Color(0xFF3BA776);
  static const Color progressBlue = Color(0xFF4A6FA5);
  static const Color progressTeal = Color(0xFF26A69A);
  static const Color progressYellow = Color(0xFFE6A23C);

  // Footer Button Colors
  static const Color footerButton = Colors.white;
  static const Color footerButtonForeground = Color(0xFF4A6FA5);
  static const Color footerButtonBorder = Color(0xFF4A6FA5);
  static const Color footerButtonSelected = Color(0xFF4A6FA5);
  static const Color footerButtonSelectedForeground = Colors.white;
}

class AppSizes {
  // Layout
  static const double pageWidth = 393;
  static const double pageMaxWidth = 393;
  static const double maxTextWidth = 360;
  static const EdgeInsets pageMargin = EdgeInsets.all(4);

  // Spacing
  static const double headerSpacing = 6;
  static const double bodySpacing = 16;
  static const double sectionSpacing = 12;
  static const double dividerSpacing = 8;
  static const double buttonSpacingVertical = 8;
  static const double buttonSpacingHorizontal = 8;
  static const double cardSpacing = 10;
  static const double footerPadding = 10;
  static const double footerSpacing = 2;
  static const EdgeInsets cardPadding = EdgeInsets.all(12);

  // Icons
  static const double iconLarge = 48;
  static const double iconMedium = 36;
  static const double iconSmall = 24;

  // Buttons
  static const double primaryButtonWidth = 240;
  static const double primaryButtonHeight = 44;
  static const double buttonCornerRadius = 8;
  static const double buttonBorderThickness = 1;

  // Input Fields
  static const double inputFieldHeight = 38;
  static const double inputCornerRadius = 6;

  // Cards
  static const double cardCornerRadius = 10;
  static const double progressBarHeight = 6;
  static const double modalWidth = 340;
  static const double modalPadding = 16;

  // Footer Bar
  static const double footerButtonWidth = 110;
  static const double footerButtonHeight = 44;
  static const double footerButtonCornerRadius = 8;
  static const double footerButtonSpacing = 6;
  static const double footerBarWidth = 393;
}

class AppFonts {
  static const String questionFont = 'Palatino Linotype';

  static const double header = 20;
  static const double subheader = 13;
  static const double body = 13;
  static const double caption = 11;
  static const double button = 13;
  static const double label = 12;
  static const double title = 22;
  static const double question = 15;
  static const double footer = 11;
  static const double ticker = 12;
}

class AppStrings {
  static const String footerLine1 = 'Designed for you ~ in every detail.';
  static const String footerLine2 = 'SafePrep™: ServSafe® & NRA® trademarks.';
  static const String footerLine3 = '⋆⋆⋆⋆⋆';

  static const String navHome = 'Home';
  static const String navDashboard = 'Dashboard';
  static const String navRapidFire = 'Rapid Fire';

  static const List<String> skipButtonLines = [
    "I don't know — and that's okay",
    "If you don't know, it's OK — just click this button",
    "Not sure? You can tap me",
    "If you're stuck, just click here",
    "It's okay to keep going — just click here",
  ];
}

class AppConstants {
  // ── Trial / Access ─────────────────────────────────────────
  // The real, live number for paying customers is 7 days (matches
  // the $4.99 initial-purchase / $2.99-per-week-renewal model). For
  // an Android closed-testing build, testers need to stay opted in
  // well past 7 days without hitting the paywall, so this resolves
  // automatically by platform instead of being a value someone has
  // to remember to flip back before shipping a real iOS build.
  //
  // To change what testers get during closed testing, edit the
  // Android-side number below — nothing else needs to change.
  static final int trialDurationDays = Platform.isAndroid ? 60 : 7;

  // Exam Engine
  static const int totalQuestions = 91;
  static const int diagnosticQuestions = 20; // trial
  static const int diagnosticQuestionsFull = 31; // paid
  static const int passingScorePercent = 85;
  static const int expertThreshold = 95;
  static const int upgradePromptThreshold = 60;
  static const int maxAttempts = 3;
  static const int questionBatchSize = 5;
  // Quiz Difficulty Weights
  static const double quizHardRatioRecovery = 0.20;
  static const double quizMediumRatioRecovery = 0.40;
  static const double quizHardRatioAssessment = 0.40;
  static const double quizMediumRatioAssessment = 0.40;
  static const double quizHardRatioStandard = 0.50;
  static const double quizMediumRatioStandard = 0.30;

  // Animations
  static const int skipButtonDelayMs = 10000;
  static const int pageTransitionDurationMs = 1200;
  static const int cardFadeDurationMs = 200;

  // Difficulty Weights
  static const double diagnosticHardWeight = 0.50;
  static const double diagnosticMediumWeight = 0.30;
  static const double diagnosticEasyWeight = 0.20;

  static const double finalExamHardWeight = 0.60;
  static const double finalExamMediumWeight = 0.30;
  static const double finalExamEasyWeight = 0.10;

  // Card Shadow
  static List<BoxShadow> cardShadow = [
    const BoxShadow(
      color: Color(0x33000000),
      blurRadius: 12,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
  ];
}
