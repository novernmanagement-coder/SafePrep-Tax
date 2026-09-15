/// Answers collected during the onboarding funnel.
///
/// Deliberately NOT persisted and NOT written into AppState — the
/// onboarding is a conversion flow, not a data source for the adaptive
/// engine. It populates nothing in the app; the real readiness meter and
/// study plan are built from in-app activity after purchase.
library;

/// ServSafe test history, captured on the knowledge-level screen.
/// Replaces an earlier self-assessed-confidence version of this
/// question (Confident / Prepared / Almost ready / New to ServSafe) —
/// that framing risked social-desirability bias (people overstating
/// readiness to avoid admitting low knowledge, even with no one
/// watching), which meant the plan built from it could feel wrong to
/// them right at the paywall. Asking about test HISTORY instead of
/// self-assessed competence is a plain fact, not a judgment call, so
/// there's nothing to feel awkward about answering honestly. Flat,
/// equal-weight options — no tier/scope language — since there's only
/// one product to buy, so there's nothing to price-game toward. Drives
/// paywall subline copy and FSME's one-line reaction only; does NOT
/// change the underlying curriculum, pacing, or which category starts
/// first.
enum KnowledgeLevel {
  firstTime,
  takenBefore,
  takenMultiple;

  String get tag {
    switch (this) {
      case KnowledgeLevel.firstTime:
        return 'first_time';
      case KnowledgeLevel.takenBefore:
        return 'taken_before';
      case KnowledgeLevel.takenMultiple:
        return 'taken_multiple';
    }
  }
}

/// How far out the user's exam is. Captured on screen 4, used to pace the
/// plan and modulate the results copy.
///
/// [notScheduled] is also a proctoring lead — those users should be
/// pointed at the FSME Find a Proctor directory rather than urgency copy.
enum ExamWindow {
  oneToThree,
  fourToTen,
  tenPlus,
  notScheduled;

  /// Value sent to Mixpanel and carried through the funnel.
  String get tag {
    switch (this) {
      case ExamWindow.oneToThree:
        return '1-3_days';
      case ExamWindow.fourToTen:
        return '4-10_days';
      case ExamWindow.tenPlus:
        return '10+_days';
      case ExamWindow.notScheduled:
        return 'not_scheduled';
    }
  }

  /// Rough day count for the "X minutes a day" math on the results
  /// screen. Null when nothing is booked — no deadline, no pacing.
  int? get daysToExam {
    switch (this) {
      case ExamWindow.oneToThree:
        return 2;
      case ExamWindow.fourToTen:
        return 7;
      case ExamWindow.tenPlus:
        return 14;
      case ExamWindow.notScheduled:
        return null;
    }
  }

  /// Display text matching exactly what the user tapped on the exam-date
  /// screen (see OnboardExamDate) — used to recap their own answer back
  /// to them on the paywall, so it must read the same both places.
  String get label {
    switch (this) {
      case ExamWindow.oneToThree:
        return '1–2 days';
      case ExamWindow.fourToTen:
        return '3–4 days';
      case ExamWindow.tenPlus:
        return '5+ days';
      case ExamWindow.notScheduled:
        return 'Not scheduled yet';
    }
  }
}

/// How the user wants questions presented. Chosen on screen 5.
///
/// Three genuinely distinct render modes:
///   [explanations] — correct answer green, wrong pick red, plus a
///                    per-question explanation.
///   [answersOnly]  — correct answer green, wrong pick red, no explanation.
///   [quizFormat]   — no feedback at all during the quiz; everything is
///                    revealed on the results screen.
enum StudyStyle {
  explanations,
  answersOnly,
  quizFormat;

  String get tag {
    switch (this) {
      case StudyStyle.explanations:
        return 'answers_and_explanations';
      case StudyStyle.answersOnly:
        return 'answers_only';
      case StudyStyle.quizFormat:
        return 'quiz_format';
    }
  }

  /// True when the diagnostic should mark answers as they're given.
  /// False for [quizFormat], where the results screen carries the whole
  /// emotional load on its own.
  bool get showsImmediateFeedback => this != StudyStyle.quizFormat;

  /// True only when a per-question explanation should appear.
  bool get showsExplanations => this == StudyStyle.explanations;

  /// Display text matching exactly what the user tapped on the study-
  /// style screen (see OnboardStudyStyle) — used to recap their own
  /// answer back to them on the paywall.
  String get label {
    switch (this) {
      case StudyStyle.explanations:
        return 'Answers and explanations';
      case StudyStyle.answersOnly:
        return 'Answers only';
      case StudyStyle.quizFormat:
        return 'Quiz format';
    }
  }
}

/// Where the user wants to start. Chosen on screen 6, the last
/// question before the paywall.
///
/// This is a ROUTING choice, not a content-tiering one — no new
/// content gets authored for any of the three options. Each just
/// points at something that already exists in the app: [fullCurriculum]
/// lands on Dashboard & Study with no assessment required, [hotTopics]
/// suggests taking the Assessment first (it already surfaces weak
/// areas and builds a focused plan), and [refresher] suggests Trainers
/// (already the fast, 60-second reinforcement tool). Nothing is
/// gated by this choice, consistent with the app's existing "you do
/// you" philosophy — it only sets a default starting point and the
/// paywall recap copy, never what someone is allowed to access.
///
/// This answer is captured, shown back on the paywall recap, and
/// drives a second FSME reaction line on the paywall itself (see
/// OnboardPaywall._contentLineFor). It is NOT YET wired into the
/// post-purchase FSME landing page's routing/callback line — that's a
/// separate follow-up.
enum ContentPreference {
  fullCurriculum,
  hotTopics,
  refresher;

  String get tag {
    switch (this) {
      case ContentPreference.fullCurriculum:
        return 'full_curriculum';
      case ContentPreference.hotTopics:
        return 'hot_topics';
      case ContentPreference.refresher:
        return 'refresher';
    }
  }

  /// Display text matching exactly what the user tapped on the
  /// content-preference screen (see OnboardContentPreference) — used
  /// to recap their own answer back to them on the paywall.
  String get label {
    switch (this) {
      case ContentPreference.fullCurriculum:
        return 'Full Curriculum';
      case ContentPreference.hotTopics:
        return 'Hot Topics';
      case ContentPreference.refresher:
        return 'Refresher';
    }
  }
}

/// SharedPreferences key holding how many times the user has completed
/// onboarding (reached the paywall). Formerly incremented inside
/// OnboardReadiness on the diagnostic verdict screen; that screen is
/// gone in the self-report redesign, so OnboardPaywall increments this
/// now instead — reaching the paywall is the new equivalent of "ran the
/// funnel." Read by SplashPage to gate the free-attempts count. Same
/// string value preserved so existing installs' saved counts aren't
/// orphaned.
const String kOnboardingRunsKey = 'onboarding_runs_completed';

/// Free onboarding run-throughs before the splash requires the access
/// code.
const int kMaxFreeRuns = 2;

/// Funnel-scoped answer store. Lives for the duration of onboarding only.
class OnboardingAnswers {
  OnboardingAnswers._();
  static final OnboardingAnswers instance = OnboardingAnswers._();

  KnowledgeLevel? knowledgeLevel;
  ExamWindow? examWindow;
  StudyStyle? studyStyle;
  ContentPreference? contentPreference;

  void reset() {
    knowledgeLevel = null;
    examWindow = null;
    studyStyle = null;
    contentPreference = null;
  }
}
