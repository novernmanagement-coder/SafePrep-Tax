import 'app_state.dart';

class ReadinessEngine {
  static const Map<String, double> _examWeights = {
    'Time & Temperature': 0.23,
    'Cross-Contamination': 0.15,
    'Receiving & Storage': 0.15,
    'Personal Hygiene': 0.14,
    'Cleaning & Sanitizing': 0.12,
    'Food Preparation': 0.12,
    'Food Safety Management': 0.05,
    'Facility & Equipment': 0.02,
  };

  static const double _ecFlashCards = 1.0;
  static const double _ecRapidFire = 1.0;
  static const double _ecScenario = 1.0;
  static const double _ec60Second = 1.0;
  static const double _ecMnemonics = 1.0;
  static const double _ecCurriculum = 1.0;
  static const double _ecMaxTotal = 10.0;

  static double _categoryPoints(String category, int score) {
    final weight = _examWeights[category] ?? 0.02;
    final maxPts = weight * 100.0;
    if (score >= 85) return maxPts;
    if (score >= 75) return maxPts * 0.6;
    if (score >= 51) return maxPts * 0.3;
    return 0.0;
  }

  static int calculate(AppState state) {
    double score = 0.0;

    for (final category in AppState.allCategories) {
      if (state.hasScoreForCategory(category)) {
        final catScore = state.getCategoryScore(category);
        score += _categoryPoints(category, catScore);
      }
    }

    final ec = state.extraCreditPoints.clamp(0.0, _ecMaxTotal);

    double finalScore;
    if (state.extraCreditPoints == 0.0) {
      finalScore = (score + ec).clamp(0.0, 88.0);
    } else if (score < 85.0) {
      finalScore = (score + ec).clamp(0.0, 80.0);
    } else {
      finalScore = (score + ec).clamp(0.0, 100.0);
    }

    if (state.finalExamScore != null) {
      final examScore = state.finalExamScore!;
      if (examScore >= 85) {
        finalScore = 100.0;
      } else {
        finalScore = finalScore < examScore.toDouble()
            ? finalScore
            : examScore.toDouble();
      }
    }

    // Trial mode caps
    if (!state.hasUnlockedApp) {
      if (!state.hasTakenAssessment) {
        finalScore = finalScore.clamp(0.0, 49.0);
      } else {
        finalScore = finalScore.clamp(0.0, 68.0);
      }
    }

    // Everyone who has taken the assessment gets at least 5%
    final raw = finalScore.round().clamp(0, 100);
    if (state.hasTakenAssessment && raw < 5) return 5;
    return raw;
  }

  static double improvementDelta(
    String category,
    int previousScore,
    int newScore,
  ) {
    final previousPts = _categoryPoints(category, previousScore);
    final newPts = _categoryPoints(category, newScore);
    return newPts - previousPts;
  }

  static double extraCreditForAction(ExtraCreditAction action) {
    switch (action) {
      case ExtraCreditAction.flashCards:
        return _ecFlashCards;
      case ExtraCreditAction.rapidFire:
        return _ecRapidFire;
      case ExtraCreditAction.scenarioDrills:
        return _ecScenario;
      case ExtraCreditAction.sixtySecond:
        return _ec60Second;
      case ExtraCreditAction.mnemonics:
        return _ecMnemonics;
      case ExtraCreditAction.curriculum:
        return _ecCurriculum;
    }
  }

  static String coachMessage(AppState state, int readinessScore) {
    if (state.finalExamScore != null && state.finalExamScore! < 85) {
      final focus = _focusCategory(state);
      if (focus != null) {
        return '$focus is your biggest opportunity — focus there before retaking.';
      }
      return 'Your exam score is your benchmark — study your priority categories to rebuild.';
    }

    if (!state.hasTakenAssessment) {
      return 'Take the diagnostic assessment to start building your readiness score.';
    }

    final masteredWithoutCurriculum = state.masteredCategories
        .where((c) => !state.hasStudiedCategory(c))
        .toList();
    if (masteredWithoutCurriculum.isNotEmpty) {
      final cat = masteredWithoutCurriculum.first;
      return 'You\'ve mastered $cat — go to the Dashboard and select Study to review the curriculum.';
    }

    final unmastered =
        AppState.allCategories
            .where(
              (c) =>
                  state.hasScoreForCategory(c) &&
                  state.getCategoryScore(c) < AppState.masteryThreshold,
            )
            .toList()
          ..sort(
            (a, b) =>
                state.getCategoryScore(a).compareTo(state.getCategoryScore(b)),
          );

    if (unmastered.isNotEmpty) {
      final cat = unmastered.first;
      final weight = (_examWeights[cat] ?? 0.02) * 100;
      final score = state.getCategoryScore(cat);
      return '$cat needs work — you\'re at $score% and it counts for ${weight.round()}% of the exam.';
    }

    final unstudied = AppState.allCategories
        .where((c) => !state.hasScoreForCategory(c))
        .toList();
    if (unstudied.isNotEmpty) {
      return 'You haven\'t studied ${unstudied.first} yet — start there next.';
    }

    if (readinessScore >= 100) {
      return 'Good luck on your final exam — you\'ve definitely done the work. You\'re ready.';
    }

    if (state.finalExamScore == null && readinessScore >= 85) {
      return 'You\'re ready — take the SafePrep Final Exam to complete your readiness score.';
    }

    if (readinessScore >= 80 && readinessScore < 100) {
      return 'Use Flash Cards and Rapid Fire to push your readiness to 100%.';
    }

    if (readinessScore < 50) {
      return 'Focus on category quizzes — they\'re the fastest way to move the needle.';
    }

    return 'Keep studying — every quiz moves your readiness score.';
  }

  static String cheerleaderMessage(AppState state, int readinessScore) {
    if (readinessScore >= 100) {
      return 'Green light. You\'ve done the work. Go pass that exam.';
    }
    if (readinessScore >= 85) {
      return 'You\'re in the zone — the people who reach this point pass. Keep going.';
    }
    if (readinessScore >= 65) {
      return 'You\'re building something real. Every category mastered is one less thing standing between you and that certification.';
    }
    if (readinessScore >= 40) {
      return 'You\'re past the starting line — momentum is everything now. Don\'t stop.';
    }
    if (state.hasTakenAssessment) {
      return 'You showed up and took the assessment. That\'s how every success story starts.';
    }
    return 'SafePrep was built for one purpose — to get you ready. Let\'s get started.';
  }

  static String? _focusCategory(AppState state) {
    final scored =
        AppState.allCategories
            .where((c) => state.hasScoreForCategory(c))
            .toList()
          ..sort(
            (a, b) =>
                state.getCategoryScore(a).compareTo(state.getCategoryScore(b)),
          );
    return scored.isEmpty ? null : scored.first;
  }
}

enum ExtraCreditAction {
  flashCards,
  rapidFire,
  scenarioDrills,
  sixtySecond,
  mnemonics,
  curriculum,
}
