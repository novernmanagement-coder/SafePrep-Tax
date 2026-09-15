import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'constants.dart';
import 'csv_loader.dart';
import 'mixpanel_service.dart';
import 'iap_service.dart';
import 'fsme_eye.dart';
import 'onboard/onboard_final_trust_page.dart';
import 'fsme_post_purchase_landing.dart';

/// Limited Rapid Fire — the $4.99 decline path's free taste.
///
/// This is a SELLING PAGE that happens to be a working tool. It runs a
/// capped version of Rapid Fire (3 weakest categories × 5 questions each
/// = 15 total) with a persistent "limited version" banner and a re-ask
/// at every category's 5-question ceiling. Each re-ask names the
/// category, states how many more questions are available, and offers
/// the unlock — turning one paywall into several conversion moments
/// that fire while the user is engaged.
///
/// VISUAL FIDELITY: mirrors the real RapidFirePage — the speech-bubble
/// question card ([_BubblePainter]), category color map, slide in/out,
/// and the ✓/✗/— score boxes — so the taste looks like the actual tool.
/// The interaction stays instant-answer (both choices shown at once, tap
/// reveals green/red) rather than the full tool's timed reveal, because
/// this is a funnel stage and snappier converts better.
///
/// Separate file from rapid_fire_page.dart intentionally. The full
/// trainer is a tool; this is a funnel stage that uses the tool's
/// mechanics. Mixing the two would compromise both.
///
/// Per the standing typing rule: user-audience FSME lines type out
/// character by character; boss/self/processing lines reveal instantly,
/// one line at a time. Eyes match the funnel-wide 26x26 spec.
class RapidFireLimitedPage extends StatefulWidget {
  const RapidFireLimitedPage({super.key});

  @override
  State<RapidFireLimitedPage> createState() => _RapidFireLimitedPageState();
}

/// Who an FSME completion-screen line is directed at / how it renders.
/// - user: FSME's default voice (gold) — types out.
/// - boss: directed at the boss (blue) — instant.
/// - self: muttering/thinking to himself (gray) — instant.
/// - processing: the "assessment script" readout bits — teal, instant.
enum _FsmeAudience { user, boss, self, processing }

/// Script-definition line (immutable).
class _FsmeLine {
  final String text;
  final _FsmeAudience audience;
  const _FsmeLine(this.text, {this.audience = _FsmeAudience.user});
}

/// Mutable render-time counterpart — [text] grows as a user-audience
/// line types out; other lines just get their full text set once.
class _TermLine {
  String text;
  final _FsmeAudience audience;
  _TermLine(this.text, this.audience);
}

class _RapidFireLimitedPageState extends State<RapidFireLimitedPage>
    with TickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _red = Color(0xFFC62828);
  // Matches the boss-line / self-line / processing colors used across
  // the rest of the funnel.
  static const Color _bossBlue = Color(0xFF4A9BE2);
  static const Color _selfGray = Color(0xFF9E9E9E);
  static const Color _processingTeal = Color(0xFF6FA8A6);

  static const int _questionsPerCategory = 3;

  /// Short labels for the category-clear pill row — the real category
  /// names are too long to fit three across.
  static const Map<String, String> _shortLabels = {
    'Time & Temperature': 'Time & Temp',
    'Receiving & Storage': 'Receiving',
    'Cross-Contamination': 'Cross-Contam',
  };
  static const int _slideInMs = 320;
  static const int _slideOutMs = 260;

  /// Category color map — matched to the real RapidFirePage so the
  /// speech bubble reads the same per category.
  static const Map<String, Color> _categoryColors = {
    'Time & Temperature': Color(0xFFC0392B),
    'Cross-Contamination': Color(0xFFE67E22),
    'Food Preparation': Color(0xFF27AE60),
    'Receiving & Storage': Color(0xFF2980B9),
    'Personal Hygiene': Color(0xFF8E44AD),
    'Cleaning & Sanitizing': Color(0xFF16A085),
    'Facility & Equipment': Color(0xFF34495E),
    'Food Safety Management': Color(0xFFB7950B),
  };

  /// FSME's free Find a Proctor service — offered on the completion
  /// screen as a neutral next step for someone who finished the free
  /// taste and didn't buy. Framed as "when you're ready," not a claim
  /// that they ARE ready.
  static const String _fsmeProctorUrl =
      'https://foodsafetymadeeasy.com/find-a-proctor/';

  /// Full question bank counts per category — used in the re-ask copy
  /// to show how many more are available. Approximate is fine; these
  /// come from the bank distribution noted in the diagnostic spec.
  static const Map<String, int> _bankCounts = {
    'Time & Temperature': 70,
    'Cross-Contamination': 42,
    'Cleaning & Sanitizing': 38,
    'Personal Hygiene': 36,
    'Food Preparation': 34,
    'Receiving & Storage': 44,
    'Facility & Equipment': 22,
    'Food Safety Management': 20,
    'Food Safety Foundations': 12,
    'Pathogens': 12,
    'Pest Management': 6,
  };

  List<String> _categories = [];
  Map<String, List<QuestionModel>> _categoryDecks = {};
  Map<String, int> _categoryProgress = {};

  // ── Engagement upgrade: per-category correct tally, streak, trophy ──
  // _categoryCorrect tracks correct (not just answered) per category —
  // that's what "cleared perfectly" means, distinct from _categoryProgress
  // which just tracks how many of that category have been answered.
  Map<String, int> _categoryCorrect = {};
  int _currentStreak = 0;
  int _bestStreak = 0;

  // Set once _loadQuestion() decides a category has hit its limit — read
  // by _categoryLimitView()/the trophy burst to know if THIS category run
  // was a perfect _questionsPerCategory-for-_questionsPerCategory.
  bool _currentCategoryPerfect = false;
  // Guards the trophy-burst animation to fire once per category, even
  // though _categoryLimitView() can rebuild multiple times while showing.
  final Set<String> _trophyShownFor = {};
  AnimationController? _trophyController;
  // True for the duration of the trophy-burst animation only — gates
  // the full-screen overlay in build() so it's only in the widget tree
  // while trophies are actually flying (see _trophyOverlay()).
  bool _showTrophyOverlay = false;

  // Live reaction eyes, shown under the question/answer panels during
  // play (separate from the popup-box _davEye() used in the limit/
  // completion screens) — reuses the shared FsmeEyePair widget so the
  // reactions (bulge on correct, eyes-rolled-up on wrong) match the
  // real RapidFirePage's behavior exactly.
  final GlobalKey<FsmeEyePairState> _liveEyeKey = GlobalKey<FsmeEyePairState>();
  EyeMood _liveEyeMood = EyeMood.idle;
  Timer? _liveEyeRevertTimer;

  int _currentCatIndex = 0;
  bool _loaded = false;

  // Question state
  String _questionText = '';
  String _answerAText = '';
  String _answerBText = '';
  int _correctSlot = 0;
  bool _answered = false;

  // Answer button colors (real tool uses slate-blue idle, green/red/grey
  // on reveal).
  Color _colorA = const Color(0xFF4A6FA5);
  Color _colorB = const Color(0xFF4A6FA5);

  int _totalCorrect = 0;
  int _totalIncorrect = 0;
  int _totalAnswered = 0;

  // Category limit reached
  bool _showingLimit = false;

  // All done
  bool _allDone = false;

  // Slide animation for the question bubble.
  AnimationController? _slideController;
  Animation<Offset> _slideOffset = const AlwaysStoppedAnimation(Offset.zero);

  // ── FSME (completion screen only) ───────────────────────────────────
  /// Terminal lines revealed so far in the completion FSME box.
  final List<_TermLine> _fsmeLines = [];
  bool _fsmeStarted = false;

  // ── FSME (category-limit screen, first hit only) ─────────────────────
  /// True once the popup has ever fired — checked before scheduling, so
  /// picking "Continue to next category" never re-triggers it on the
  /// 2nd or 3rd category's limit screen.
  bool _limitFsmeShown = false;
  bool _limitFsmeVisible = false;
  final List<_TermLine> _limitFsmeLines = [];
  Timer? _limitFsmeInTimer;

  /// FSME's one-time pop-up on the first category-limit re-ask: he
  /// takes credit for the design, explains the real tool's speed
  /// pressure, then privately gloats about the Byte-Me trophy.
  static const List<_FsmeLine> _limitFsmeScript = [
    _FsmeLine(
      'See, I told you it was cool — I designed this for maximum '
      'retention.',
    ),
    _FsmeLine(
      'The real version makes you answer quickly, or it just moves on '
      'to the next question — no time to think, react and choose.',
    ),
    _FsmeLine(
      'Yup, I am genius. This bad boy won first place — suck on it, '
      'Goggles.',
      audience: _FsmeAudience.self,
    ),
  ];

  // ── FSME (final category-limit screen, once all 3 are done) ──────────
  /// True once the closing tease has ever fired — mirrors _limitFsmeShown
  /// so it only plays on the very first time the LAST category's limit
  /// screen is reached (there's only one "last category" screen per
  /// session anyway, but this also guards rebuilds of that screen).
  bool _finalTeaseShown = false;
  bool _finalTeaseVisible = false;
  final List<_TermLine> _finalTeaseLines = [];
  Timer? _finalTeaseInTimer;

  /// FSME's closing pitch, once the user has cleared all 3 free
  /// categories (9 of 9): the trophy tease from the shelf above, then
  /// — after a beat, like he just remembered — the actual sales
  /// pitch. Last line undercuts the 98% stat for a laugh, so it reads as
  /// him being honest rather than a hard close.
  static const List<_FsmeLine> _finalTeaseScript = [
    _FsmeLine(
      'Bet you’re wondering why I won first place for “Best Use '
      'Of The Word ‘Mnemonic’”… get the app and I’ll show ya.',
    ),
    _FsmeLine('Oh yeah — this app comes with a money-back guarantee.'),
    _FsmeLine('They built this thing just for you.'),
    _FsmeLine('98% pass rate.'),
    _FsmeLine(
      'Heck, I’m only right 97.896526652% of the time.',
      audience: _FsmeAudience.self,
    ),
  ];

  int _gazeTarget = 0;
  double _gazeCurrent = 0.0;
  Timer? _gazeTimer;
  AnimationController? _gazeAnim;
  AnimationController? _blinkController;
  Timer? _blinkTimer;
  final Random _rng = Random();

  static const Color _eyeRed = Color(0xFFE24B4A);

  /// FSME's snarky completion readout, typed one line at a time.
  ///
  /// - "Running assessment script" through "Conclusion: ..." are the
  ///   script's own readout — tagged `processing`.
  /// - "Subject is a robot..." is him puzzling it out to himself —
  ///   `self`.
  /// - "wait. Boss? Is that you?" through "I'll play along." are
  ///   addressed at her — `boss`.
  /// - The opening line and the closing hand-off are addressed to the
  ///   user — default `user`, type out.
  static const List<_FsmeLine> _fsmeScript = [
    _FsmeLine('Okay. You got a taste of the SafePrep experience.'),
    _FsmeLine(
      'Running assessment script ..........',
      audience: _FsmeAudience.processing,
    ),
    _FsmeLine(
      'Subject is intelligent... subject is capable...',
      audience: _FsmeAudience.processing,
    ),
    _FsmeLine(
      'Subject retained an ALARMING amount of food safety '
      'knowledge in a very short window ............',
      audience: _FsmeAudience.processing,
    ),
    _FsmeLine(
      'Conclusion: ...divine intervention? Mind-meld program '
      'actually worked? ...No. Nobody learns THAT fast.',
      audience: _FsmeAudience.processing,
    ),
    _FsmeLine(
      '...Subject is a robot. Subject has to be a robot.',
      audience: _FsmeAudience.self,
    ),
    _FsmeLine(
      '...wait. Boss? Is that you? Are you messing with me again?',
      audience: _FsmeAudience.boss,
    ),
    _FsmeLine("...Okay. Okay, I'll play along.", audience: _FsmeAudience.boss),
    _FsmeLine(
      'Since you already know everything, all that’s left is to '
      'find a local proctor and make it official.',
    ),
    _FsmeLine('Here — use this. It’s free. Congratulations.'),
  ];

  /// Top 3 categories by real exam weight (matches the Trust page's
  /// weighted breakdown) — fixed for everyone now that there's no
  /// diagnostic to personalize against.
  static const List<String> _topCategories = [
    'Time & Temperature',
    'Receiving & Storage',
    'Cross-Contamination',
  ];

  Color get _currentColor {
    final cat = _currentCatIndex < _categories.length
        ? _categories[_currentCatIndex]
        : '';
    return _categoryColors[cat] ?? _gold;
  }

  @override
  void initState() {
    super.initState();
    MixpanelService.instance.track(
      'SpOn_RefLtd_Viewed',
      properties: {'app_name': 'SP'},
    );
    _loadDecks();
  }

  @override
  void dispose() {
    _slideController?.dispose();
    _gazeAnim?.dispose();
    _blinkController?.dispose();
    _trophyController?.dispose();
    _gazeTimer?.cancel();
    _blinkTimer?.cancel();
    _limitFsmeInTimer?.cancel();
    _finalTeaseInTimer?.cancel();
    _liveEyeRevertTimer?.cancel();
    super.dispose();
  }

  // ── FSME (shared eye animation) ──────────────────────────────────────

  bool _eyesStarted = false;

  /// Lazily creates and starts the gaze/blink controllers exactly once,
  /// no matter which popup (category-limit or completion) triggers it
  /// first.
  void _ensureEyeAnimation() {
    if (_eyesStarted) return;
    _eyesStarted = true;

    _gazeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(_advanceGaze);
    _gazeAnim!.repeat();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _scheduleGaze();
    _scheduleBlink();
  }

  // ── FSME (completion) ───────────────────────────────────────────────

  /// Kicks off the completion FSME readout. Called once, the first
  /// time the completion view builds.
  void _startFsme() {
    if (_fsmeStarted) return;
    _fsmeStarted = true;
    _ensureEyeAnimation();
    _revealFsme();
  }

  /// Reveals the completion script one line at a time. User-audience
  /// lines type out character by character; boss/self/processing lines
  /// appear instantly. Pause between every line either way.
  Future<void> _revealFsme() async {
    await Future.delayed(const Duration(milliseconds: 400));
    for (final line in _fsmeScript) {
      if (!mounted) return;

      if (line.audience == _FsmeAudience.user) {
        final entry = _TermLine('', line.audience);
        setState(() => _fsmeLines.add(entry));
        for (var i = 1; i <= line.text.length; i++) {
          if (!mounted) return;
          setState(() => entry.text = line.text.substring(0, i));
          await Future.delayed(const Duration(milliseconds: 18));
        }
      } else {
        setState(() => _fsmeLines.add(_TermLine(line.text, line.audience)));
      }

      await Future.delayed(const Duration(milliseconds: 900));
    }
  }

  /// Schedules the category-limit popup, but only the very first time
  /// it's called — subsequent calls (from later categories' limit
  /// screens) are no-ops.
  void _maybeStartLimitFsme() {
    if (_limitFsmeShown) return;
    _limitFsmeShown = true;
    _limitFsmeInTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _ensureEyeAnimation();
      setState(() => _limitFsmeVisible = true);
      _revealLimitFsme();
    });
  }

  /// Reveals the category-limit script one line at a time — same
  /// typing rule as the completion readout.
  Future<void> _revealLimitFsme() async {
    for (final line in _limitFsmeScript) {
      if (!mounted) return;

      if (line.audience == _FsmeAudience.user) {
        final entry = _TermLine('', line.audience);
        setState(() => _limitFsmeLines.add(entry));
        for (var i = 1; i <= line.text.length; i++) {
          if (!mounted) return;
          setState(() => entry.text = line.text.substring(0, i));
          await Future.delayed(const Duration(milliseconds: 18));
        }
      } else {
        setState(
          () => _limitFsmeLines.add(_TermLine(line.text, line.audience)),
        );
      }

      await Future.delayed(const Duration(milliseconds: 900));
    }
  }

  /// Schedules the closing tease, but only the very first time it's
  /// called — mirrors _maybeStartLimitFsme().
  void _maybeStartFinalTease() {
    if (_finalTeaseShown) return;
    _finalTeaseShown = true;
    _finalTeaseInTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _ensureEyeAnimation();
      setState(() => _finalTeaseVisible = true);
      _revealFinalTease();
    });
  }

  /// Reveals the closing-tease script one line at a time — same typing
  /// rule as the other scripts, but with an extra-long pause after the
  /// trophy tease (line 0) before the sales pitch lands, so it reads as
  /// him catching himself remembering something rather than one flat
  /// list.
  Future<void> _revealFinalTease() async {
    for (var idx = 0; idx < _finalTeaseScript.length; idx++) {
      final line = _finalTeaseScript[idx];
      if (!mounted) return;

      if (line.audience == _FsmeAudience.user) {
        final entry = _TermLine('', line.audience);
        setState(() => _finalTeaseLines.add(entry));
        for (var i = 1; i <= line.text.length; i++) {
          if (!mounted) return;
          setState(() => entry.text = line.text.substring(0, i));
          await Future.delayed(const Duration(milliseconds: 18));
        }
      } else {
        setState(
          () => _finalTeaseLines.add(_TermLine(line.text, line.audience)),
        );
      }

      final pause = idx == 0
          ? const Duration(milliseconds: 2200)
          : const Duration(milliseconds: 900);
      await Future.delayed(pause);
    }
  }

  // ── FSME (trophy burst) ─────────────────────────────────────────────
  /// Fires once, the first time a category is cleared PERFECTLY
  /// ($_questionsPerCategory-for-$_questionsPerCategory) — 5 trophies
  /// rise up the FULL SCREEN (see _trophyOverlay/_floatingTrophy), then
  /// the bragging line lands in the celebration box. Guarded by
  /// _trophyShownFor so re-rendering the limit screen (setState, e.g.
  /// from the score row updating) never re-triggers it for a category
  /// already celebrated.
  ///
  /// 2800ms (was 1400ms) and a near-full-screen rise (was a 46px fan
  /// confined to a 60px box) — the original was over almost before it
  /// registered. See _floatingTrophy for the travel math.
  static const int _trophyCount = 5;
  static const List<double> _trophyAngles = [-56, -28, 0, 28, 56];

  void _maybeStartTrophyBurst(String cat) {
    if (!_currentCategoryPerfect || _trophyShownFor.contains(cat)) return;
    _trophyShownFor.add(cat);
    _ensureEyeAnimation();
    if (_trophyController == null) {
      _trophyController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2800),
      );
      // Take the full-screen overlay back out of the tree once the
      // animation finishes — it's IgnorePointer'd, but no reason to
      // keep it (and its AnimatedBuilder rebuilds) mounted forever.
      _trophyController!.addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _showTrophyOverlay = false);
        }
      });
    }
    setState(() => _showTrophyOverlay = true);
    _trophyController!.forward(from: 0.0);
  }

  /// Full-screen trophy overlay — laid over the whole Scaffold body by
  /// build() (see the Stack there), not confined to the small
  /// _celebrationBox card. IgnorePointer so it never blocks taps on the
  /// real UI underneath while it plays.
  Widget _trophyOverlay(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return IgnorePointer(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            for (int i = 0; i < _trophyCount; i++)
              _floatingTrophy(_trophyAngles[i], i * 0.12, size),
          ],
        ),
      ),
    );
  }

  /// One trophy rising from roughly where the celebration card sits
  /// toward the top of the screen — scales in with an overshoot, rises
  /// most of the screen height with a gentle horizontal fan along
  /// [angleDeg] so the $_trophyCount trophies don't overlap, then fades
  /// in the last 40% of the animation. Driven entirely by
  /// _trophyController's single value so all trophies stay in sync,
  /// just staggered by [startFraction].
  Widget _floatingTrophy(
    double angleDeg,
    double startFraction,
    Size screenSize,
  ) {
    return AnimatedBuilder(
      animation: _trophyController ?? const AlwaysStoppedAnimation(0.0),
      builder: (context, _) {
        final raw = _trophyController?.value ?? 0.0;
        final progress = ((raw - startFraction) / (1 - startFraction)).clamp(
          0.0,
          1.0,
        );
        final scale = Curves.easeOutBack.transform(progress);
        final rise = Curves.easeOutCubic.transform(progress);
        final fadeStart = (progress - 0.6) / 0.4;
        final opacity = 1.0 - fadeStart.clamp(0.0, 1.0);
        final rad = angleDeg * (pi / 180);
        // Mostly straight up the screen, with a light horizontal fan so
        // the 5 trophies read as a burst rather than a single column.
        final dx = sin(rad) * 80 * rise;
        final dy = -screenSize.height * 0.6 * rise;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(
              scale: scale,
              child: const Text('🏆', style: TextStyle(fontSize: 30)),
            ),
          ),
        );
      },
    );
  }

  /// FSME's trophy case — three of his (entirely self-proclaimed)
  /// Byte-Me Conference awards, shown above his eyes in _celebrationBox
  /// on a perfect category. Static and purely cosmetic — no animation,
  /// no game logic, just his ego on full display.
  Widget _trophyShelf() {
    const awards = [
      'Best Tool Created By A Tool',
      'Best Use Of The Word “Mnemonic”',
      'Best Learning Tool Ever Created Since The Dawn Of Time — Or '
          'Last Thursday',
    ];
    return Column(
      children: [
        Text(
          'BYTE-ME CONFERENCE  •  1ST PLACE (x3)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
            color: _gold.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        for (final award in awards)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    award,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _softWhite.withValues(alpha: 0.8),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Shared eye header — one eye pair + "F S M E" wordmark, centered.
  /// Used by _celebrationBox() so there is ever only ONE eye pair on
  /// screen at a time, whether the box is showing the trophy burst,
  /// the scripted first-category popup, or both merged together.
  Widget _eyeHeaderRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _davEye(),
        const SizedBox(width: 10),
        Text(
          'F S M E',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 3,
            color: _eyeRed.withValues(alpha: 0.3),
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(width: 10),
        _davEye(),
      ],
    );
  }

  /// The ONE celebration box shown on _categoryLimitView() — merges
  /// what used to be two separate boxes (trophy burst + the scripted
  /// first-category popup), which could both fire on the same screen
  /// (category 0 cleared perfectly) and stack two redundant eye pairs.
  /// Now there's a single eye header; the trophies themselves fly
  /// full-screen via _trophyOverlay (see build()), not inside this box.
  /// The scripted lines (category 0's first limit screen only) type in
  /// below a divider if that's also happening. Either half can appear
  /// alone.
  Widget _celebrationBox(String cat) {
    final bool perfect = _currentCategoryPerfect;
    final bool showScript = _currentCatIndex == 0 && _limitFsmeVisible;
    // Last category's limit screen only — the closing tease (trophy
    // callback + sales pitch) plays here regardless of whether this
    // category itself was perfect or first. See _maybeStartFinalTease().
    final bool showFinalTease =
        _currentCatIndex == _categories.length - 1 && _finalTeaseVisible;

    return AnimatedOpacity(
      // Perfect shows immediately (no delay); the scripted halves fade
      // in on their own 2s-delayed schedules via _limitFsmeVisible /
      // _finalTeaseVisible — see _maybeStartLimitFsme() /
      // _maybeStartFinalTease(). showScript/showFinalTease already
      // encode those flags, so the divider/lines below only ever
      // appear once true.
      opacity: (perfect || _limitFsmeVisible || _finalTeaseVisible) ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 2300),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(14, perfect ? 20 : 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E14),
          borderRadius: BorderRadius.circular(perfect ? 10 : 8),
          border: Border.all(
            color: _gold.withValues(alpha: perfect ? 0.4 : 0.25),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // FSME's trophy case — his three (self-proclaimed) awards,
            // sitting above his eyes. Static/cosmetic only, separate
            // from the flying _trophyOverlay burst.
            if (perfect) ...[_trophyShelf(), const SizedBox(height: 14)],

            // Trophies themselves also fly across the full screen (see
            // _trophyOverlay, laid over the Scaffold body in build()) —
            // this box just keeps the single eye header + bragging line
            // (and, on a perfect category, the trophy shelf above it).
            _eyeHeaderRow(),

            const SizedBox(height: 10),

            if (perfect) ...[
              Text(
                'PERFECT  •  ${_shortLabels[cat] ?? cat}  '
                '$_questionsPerCategory/$_questionsPerCategory',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: _gold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '"This is why I won first place. Every single one of '
                'these."',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                  color: _selfGray,
                ),
              ),
            ],

            if (showScript) ...[
              if (perfect) ...[
                const SizedBox(height: 14),
                Divider(color: _gold.withValues(alpha: 0.15), height: 1),
                const SizedBox(height: 12),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final line in _limitFsmeLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '> ${line.text}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.5,
                          color: switch (line.audience) {
                            _FsmeAudience.boss => _bossBlue,
                            _FsmeAudience.self => _selfGray,
                            _FsmeAudience.processing => _processingTeal,
                            _FsmeAudience.user => _gold.withValues(alpha: 0.85),
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ],

            if (showFinalTease) ...[
              if (perfect || showScript) ...[
                const SizedBox(height: 14),
                Divider(color: _gold.withValues(alpha: 0.15), height: 1),
                const SizedBox(height: 12),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final line in _finalTeaseLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '> ${line.text}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.5,
                          color: switch (line.audience) {
                            _FsmeAudience.boss => _bossBlue,
                            _FsmeAudience.self => _selfGray,
                            _FsmeAudience.processing => _processingTeal,
                            _FsmeAudience.user => _gold.withValues(alpha: 0.85),
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _advanceGaze() {
    final target = _gazeTarget.toDouble();
    final next = _gazeCurrent + (target - _gazeCurrent) * 0.18;
    if ((next - _gazeCurrent).abs() > 0.001) {
      setState(() => _gazeCurrent = next);
    }
  }

  void _scheduleGaze() {
    final delay = Duration(milliseconds: 1800 + _rng.nextInt(2200));
    _gazeTimer = Timer(delay, () {
      if (!mounted) return;
      if (_rng.nextDouble() < 0.30) {
        setState(() => _gazeTarget = _rng.nextBool() ? -1 : 1);
        Timer(Duration(milliseconds: 700 + _rng.nextInt(400)), () {
          if (mounted) setState(() => _gazeTarget = 0);
        });
      } else {
        setState(() => _gazeTarget = 0);
      }
      _scheduleGaze();
    });
  }

  void _scheduleBlink() {
    final delay = Duration(milliseconds: 3000 + _rng.nextInt(5000));
    _blinkTimer = Timer(delay, () async {
      if (!mounted) return;
      await _blinkController?.forward(from: 0.0);
      if (mounted) await _blinkController?.reverse();
      _scheduleBlink();
    });
  }

  Future<void> _launchProctor() async {
    MixpanelService.instance.track(
      'SpOn_RefLtd_ProctorFinder',
      properties: {'app_name': 'SP'},
    );
    final uri = Uri.parse(_fsmeProctorUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// "Still want to see more?" — the clinical trust page, offered as
  /// one more chance before the free "Find a proctor" exit. Only
  /// reachable from here, i.e. only after Rapid Fire is genuinely
  /// COMPLETE (this method lives in _fsmeBox(), gated on `done`).
  void _seeMore() {
    MixpanelService.instance.track(
      'SpOn_RefLtd_SeeMore',
      properties: {'app_name': 'SP'},
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OnboardFinalTrustPage()),
    );
  }

  Future<void> _loadDecks() async {
    // No diagnostic exists anymore to personalize this — top 3 by real
    // exam weight (matches the Trust page's breakdown), fixed for
    // everyone. This screen is a one-time taste, not somewhere users
    // return to repeatedly, so a fixed set is fine.
    final weakest = List<String>.from(_topCategories);

    final all = await QuestionLoader.loadAll(shuffle: false);
    final decks = <String, List<QuestionModel>>{};
    final progress = <String, int>{};
    final correct = <String, int>{};

    for (final cat in weakest) {
      final questions =
          all
              .where((q) => q.category.toLowerCase() == cat.toLowerCase())
              .toList()
            ..shuffle();
      decks[cat] = questions.take(_questionsPerCategory).toList();
      progress[cat] = 0;
      correct[cat] = 0;
    }

    if (!mounted) return;
    setState(() {
      _categories = weakest;
      _categoryDecks = decks;
      _categoryProgress = progress;
      _categoryCorrect = correct;
      _loaded = true;
    });

    _loadQuestion();
  }

  Future<void> _loadQuestion() async {
    if (_currentCatIndex >= _categories.length) {
      setState(() => _allDone = true);
      return;
    }

    final cat = _categories[_currentCatIndex];
    final deck = _categoryDecks[cat] ?? [];
    final progress = _categoryProgress[cat] ?? 0;

    if (progress >= deck.length || progress >= _questionsPerCategory) {
      setState(() {
        _showingLimit = true;
        _currentCategoryPerfect =
            (_categoryCorrect[cat] ?? 0) >= _questionsPerCategory;
      });
      return;
    }

    final q = deck[progress];
    final answers = [q.answer1, q.answer2, q.answer3, q.answer4];
    final correctText = answers[q.correctAnswer];
    final wrongs = <String>[];
    for (int i = 0; i < answers.length; i++) {
      if (i != q.correctAnswer) wrongs.add(answers[i]);
    }
    wrongs.shuffle();

    final slot = Random().nextInt(2);

    setState(() {
      _questionText = q.questionText;
      _correctSlot = slot;
      _answerAText = slot == 0 ? correctText : wrongs[0];
      _answerBText = slot == 1 ? correctText : wrongs[0];
      _answered = false;
      _showingLimit = false;
      _colorA = const Color(0xFF4A6FA5);
      _colorB = const Color(0xFF4A6FA5);
    });

    await _slideIn();
  }

  Future<void> _slideIn() async {
    _slideController?.dispose();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _slideInMs),
    );
    _slideOffset = Tween<Offset>(begin: const Offset(1.5, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _slideController!,
            curve: Curves.easeOutCubic,
          ),
        );
    if (mounted) setState(() {});
    await _slideController!.forward();
  }

  Future<void> _slideOut() async {
    _slideController?.dispose();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _slideOutMs),
    );
    _slideOffset = Tween<Offset>(begin: Offset.zero, end: const Offset(-1.5, 0))
        .animate(
          CurvedAnimation(parent: _slideController!, curve: Curves.easeInCubic),
        );
    if (mounted) setState(() {});
    await _slideController!.forward();
  }

  void _onAnswer(bool tappedA) {
    if (_answered) return;

    final isCorrect =
        (tappedA && _correctSlot == 0) || (!tappedA && _correctSlot == 1);

    final cat = _categories[_currentCatIndex];

    setState(() {
      _answered = true;
      _totalAnswered++;
      if (isCorrect) {
        _totalCorrect++;
        _categoryCorrect[cat] = (_categoryCorrect[cat] ?? 0) + 1;
        _currentStreak++;
        if (_currentStreak > _bestStreak) _bestStreak = _currentStreak;
      } else {
        _totalIncorrect++;
        _currentStreak = 0;
      }
      _categoryProgress[cat] = (_categoryProgress[cat] ?? 0) + 1;

      // Reveal colors, matching the real tool: correct slot green, the
      // tapped-wrong slot red, the other loser greyed.
      if (isCorrect) {
        if (tappedA) {
          _colorA = _green;
          _colorB = const Color(0xFF888888);
        } else {
          _colorB = _green;
          _colorA = const Color(0xFF888888);
        }
      } else {
        if (tappedA) {
          _colorA = _red;
          _colorB = _green;
        } else {
          _colorB = _red;
          _colorA = _green;
        }
      }
    });

    _reactLiveEyes(isCorrect);

    MixpanelService.instance.track(
      'SpOn_RefLtd_Answered',
      properties: {
        'app_name': 'SP',
        'category': cat,
        'correct': isCorrect,
        'question_in_category': _categoryProgress[cat],
      },
    );

    // Auto-advance after a beat: slide the current card out, then load
    // the next.
    Future.delayed(const Duration(milliseconds: 900), () async {
      if (!mounted) return;
      await _slideOut();
      if (!mounted) return;
      _loadQuestion();
    });
  }

  /// Reacts to each answer, live, under the panels — bulge (surprise)
  /// on correct, eyes rolled up (befuddled mood, gaze locked straight
  /// up) on wrong. Wrong reverts to idle after a beat instead of
  /// staying stuck looking confused; correct's bulge is a one-shot
  /// that hands control back to whatever mood was active on its own.
  /// Matches the reaction pattern already used in the real
  /// RapidFirePage — same widget, same moods.
  void _reactLiveEyes(bool isCorrect) {
    if (isCorrect) {
      _liveEyeRevertTimer?.cancel();
      if (_liveEyeMood != EyeMood.idle)
        setState(() => _liveEyeMood = EyeMood.idle);
      _liveEyeKey.currentState?.surprise();
    } else {
      _liveEyeRevertTimer?.cancel();
      setState(() => _liveEyeMood = EyeMood.befuddled);
      _liveEyeRevertTimer = Timer(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() => _liveEyeMood = EyeMood.idle);
      });
    }
  }

  void _continueToNextCategory() {
    MixpanelService.instance.track(
      'SpOn_RefLtd_CatLimit',
      properties: {'app_name': 'SP', 'category': _categories[_currentCatIndex]},
    );

    setState(() {
      _currentCatIndex++;
      _showingLimit = false;
    });
    _loadQuestion();
  }

  /// Shared $4.99 unlock. Triggers the real IAP; only a VERIFIED success
  /// opens the app — routed to FsmePostPurchaseLanding, same destination
  /// as every other purchase entry point (paywall, trust page). Cancel or
  /// failure returns to the paywall.
  bool _purchasing = false;

  Future<void> _unlock(String source) async {
    if (_purchasing) return;
    setState(() => _purchasing = true);

    MixpanelService.instance.track(
      'SpOn_Purchase',
      properties: {
        'app_name': 'SP',
        'tier': 'sp',
        'source': source,
        'price': '\$4.99',
      },
    );

    var result = await IAPService.instance.buySevenDay();
    if (!mounted) return;

    // See IAPService.waitForLateUnlock — a timeout doesn't necessarily
    // mean the purchase failed, just that confirmation arrived late.
    if (result == IAPResult.timeout) {
      final unlockedLate = await IAPService.instance.waitForLateUnlock();
      if (!mounted) return;
      if (unlockedLate) result = IAPResult.success;
    }

    setState(() => _purchasing = false);

    if (result == IAPResult.success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const FsmePostPurchaseLanding()),
        (_) => false,
      );
    } else {
      // Cancel or fail → back to the paywall to decide again.
      if (Navigator.canPop(context)) Navigator.pop(context);
      final message = result.userMessage;
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  // ── Build methods ───────────────────────────────────────────────

  Widget _limitedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: _gold.withValues(alpha: 0.12),
      child: Column(
        children: [
          Text(
            'LIMITED VERSION  •  $_totalAnswered of '
            '${_categories.length * _questionsPerCategory} free questions',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: _gold,
            ),
          ),
          if (_categories.isNotEmpty) ...[
            const SizedBox(height: 8),
            _categoryPillsRow(),
          ],
          // Streak only shows once it's actually worth bragging about —
          // a "0" or "1" streak chip is just noise.
          if (_currentStreak >= 2) ...[
            const SizedBox(height: 6),
            _streakChip(),
          ],
        ],
      ),
    );
  }

  /// One pill per category: outline while not yet reached, filled gold
  /// with a checkmark once cleared, filled with a trophy if cleared
  /// perfectly ($_questionsPerCategory-for-$_questionsPerCategory). The
  /// visible "finish line" for the whole round — glance at this row to
  /// see exactly how close to done you are.
  Widget _categoryPillsRow() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: _categories.asMap().entries.map((entry) {
        final index = entry.key;
        final cat = entry.value;
        final progress = _categoryProgress[cat] ?? 0;
        final correct = _categoryCorrect[cat] ?? 0;
        final cleared = progress >= _questionsPerCategory;
        final perfect = cleared && correct >= _questionsPerCategory;
        final isCurrent = index == _currentCatIndex && !cleared;
        final color = _categoryColors[cat] ?? _gold;

        final String label = _shortLabels[cat] ?? cat;
        final Widget? icon = perfect
            ? const Text('🏆', style: TextStyle(fontSize: 12))
            : cleared
            ? Icon(Icons.check_rounded, size: 13, color: _darkBg)
            : null;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: cleared
                ? (perfect ? _gold : color.withValues(alpha: 0.85))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cleared
                  ? Colors.transparent
                  : color.withValues(alpha: isCurrent ? 0.9 : 0.35),
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon, const SizedBox(width: 4)],
              Text(
                cleared ? '$label $progress/$_questionsPerCategory' : label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                  color: cleared ? _darkBg : color.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _streakChip() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🔥', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(
          '$_currentStreak in a row',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _gold.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _questionView() {
    final cat = _currentCatIndex < _categories.length
        ? _categories[_currentCatIndex]
        : '';
    final progress = _categoryProgress[cat] ?? 0;
    final color = _currentColor;

    return Column(
      children: [
        // Category accent strip, matching the real tool.
        Container(height: 3, color: color.withValues(alpha: 0.4)),

        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                '$progress of $_questionsPerCategory',
                style: TextStyle(
                  fontSize: 12,
                  color: _softWhite.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Speech-bubble question card + answer buttons, sliding as a unit.
        SlideTransition(
          position: _slideOffset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _questionBubble(color),
              const SizedBox(height: 16),
              _answerButtons(),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // FSME, under the panels — reacts live to each answer (bulge
        // on correct, eyes rolled up on wrong). See _reactLiveEyes().
        FsmeEyePair(key: _liveEyeKey, mood: _liveEyeMood, size: 24, spacing: 8),

        const SizedBox(height: 14),

        _scoreCounters(),
      ],
    );
  }

  Widget _questionBubble(Color color) {
    return CustomPaint(
      painter: _BubblePainter(color: color),
      child: SizedBox(
        width: 320,
        height: 150,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Center(
            child: Text(
              _questionText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _answerButtons() {
    return SizedBox(
      width: 320,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _answerButton(
                'A',
                _answerAText,
                _colorA,
                () => _onAnswer(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _answerButton(
                'B',
                _answerBText,
                _colorB,
                () => _onAnswer(false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _answerButton(
    String label,
    String text,
    Color bg,
    VoidCallback onTap,
  ) {
    return ElevatedButton(
      onPressed: _answered ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        disabledBackgroundColor: bg,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 72),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0x99FFFFFF),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _scoreCounters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Expanded(
            child: _scoreBox(
              '✓ Correct',
              '$_totalCorrect',
              const Color(0xFFE8F5E9),
              const Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _scoreBox(
              '✗ Incorrect',
              '$_totalIncorrect',
              const Color(0xFFFFEBEE),
              const Color(0xFFC62828),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _scoreBox(
              '— Total',
              '$_totalAnswered',
              const Color(0xFFF5F5F5),
              const Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBox(String label, String value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  /// The re-ask screen — fires when a category hits its 5-question limit.
  /// Names the category, states how many more are in the full version,
  /// and offers the unlock. This is the conversion moment.
  Widget _categoryLimitView() {
    final cat = _categories[_currentCatIndex];
    final bankTotal = _bankCounts[cat] ?? 30;
    final remaining = bankTotal - _questionsPerCategory;
    final hasMoreCategories = _currentCatIndex < _categories.length - 1;

    // Deferred so we never call setState during build; the flag inside
    // guarantees this only ever fires once, on the very first category-
    // limit screen the user sees.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartLimitFsme());
    // Separate guard, separate trigger — this one can fire on ANY
    // category (not just the first), whenever that category happened
    // to be cleared perfectly.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeStartTrophyBurst(cat),
    );
    // Closing tease — the LAST category's limit screen only, whether
    // or not that category itself was perfect.
    if (!hasMoreCategories) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeStartFinalTease(),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 40, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 30),

          Icon(Icons.lock_outline, size: 32, color: _gold),

          const SizedBox(height: 14),

          Text(
            'That’s your $_questionsPerCategory free questions\nin $cat.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _softWhite,
              height: 1.35,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'There are $remaining more — and ServSafe will hammer '
            'home this category on the test.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _softWhite.withValues(alpha: 0.5),
              height: 1.5,
            ),
          ),

          if (_currentCategoryPerfect ||
              (_currentCatIndex == 0 && _limitFsmeVisible) ||
              (!hasMoreCategories && _finalTeaseVisible)) ...[
            const SizedBox(height: 18),
            _celebrationBox(cat),
          ],

          const SizedBox(height: 24),

          // Unlock button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _purchasing ? null : () => _unlock('cat_limit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _darkBg,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSizes.buttonCornerRadius,
                  ),
                ),
              ),
              child: const Text(
                'Unlock SafePrep  —  \$4.99',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          const SizedBox(height: 14),

          if (hasMoreCategories)
            GestureDetector(
              onTap: _continueToNextCategory,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Continue to next category  →',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _gold,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// One glowing red eye that darts and blinks — resized to match the
  /// funnel-wide 26x26 spec (was 40x40).
  Widget _davEye() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _gazeAnim ?? const AlwaysStoppedAnimation(0.0),
        _blinkController ?? const AlwaysStoppedAnimation(0.0),
      ]),
      builder: (context, _) {
        final blink = 1.0 - (_blinkController?.value ?? 0.0) * 0.92;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(1.0, blink),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFFFF2200),
                  Color(0xFFCC1100),
                  Color(0xFF660000),
                  Color(0xFF1A0000),
                ],
                stops: [0.0, 0.35, 0.7, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: _eyeRed.withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Transform.translate(
                offset: Offset(_gazeCurrent * 5, 0.5),
                child: Container(
                  width: 8,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0000),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// FSME completion box — animated eyes + snarky typed readout, then the
  /// free proctor-finder offer as a tappable exit. Color follows each
  /// line's audience.
  Widget _fsmeBox() {
    final bool done = _fsmeLines.length >= _fsmeScript.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _davEye(),
            const SizedBox(width: 16),
            Text(
              'F S M E',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 3,
                color: _eyeRed.withValues(alpha: 0.3),
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(width: 16),
            _davEye(),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _gold.withValues(alpha: 0.4), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final line in _fsmeLines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    '> ${line.text}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      height: 1.5,
                      color: switch (line.audience) {
                        _FsmeAudience.boss => _bossBlue,
                        _FsmeAudience.self => _selfGray,
                        _FsmeAudience.processing => _processingTeal,
                        _FsmeAudience.user => _gold.withValues(alpha: 0.85),
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),

        // "Still want to see more?" — offered first, before the free
        // proctor exit, since it's one more real chance to convert.
        // Both appear once the readout finishes.
        if (done) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _seeMore,
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _darkBg,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSizes.buttonCornerRadius,
                  ),
                ),
              ),
              child: const Text(
                'Still want to see more?  →',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],

        // Proctor finder — appears once the readout finishes. Framed as
        // "when you're ready," a tappable exit, not an auto-launch.
        if (done) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: _launchProctor,
              style: OutlinedButton.styleFrom(
                foregroundColor: _gold,
                side: BorderSide(color: _gold.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSizes.buttonCornerRadius,
                  ),
                ),
              ),
              child: const Text(
                'Find a proctor near me  →',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Final screen after all 15 questions — one more conversion moment.
  Widget _completionView() {
    // Kick off FSME the first time this view renders — deferred to after
    // the frame so we never call setState during build.
    if (!_fsmeStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startFsme());
    }

    final pct = _totalAnswered > 0
        ? ((_totalCorrect / _totalAnswered) * 100).round()
        : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 40, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 30),

          Text(
            'LIMITED VERSION COMPLETE',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
              color: _gold,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            '$_totalCorrect of $_totalAnswered correct',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _softWhite,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            '$pct% across your 3 weakest categories',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _softWhite.withValues(alpha: 0.5),
            ),
          ),

          if (_bestStreak >= 2) ...[
            const SizedBox(height: 8),
            Text(
              '🔥 Best streak: $_bestStreak in a row',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _gold.withValues(alpha: 0.8),
              ),
            ),
          ],

          const SizedBox(height: 8),

          Text(
            'That was ${_categories.length * _questionsPerCategory} '
            'questions out of 500+.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _softWhite.withValues(alpha: 0.4),
              fontStyle: FontStyle.italic,
            ),
          ),

          const SizedBox(height: 28),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _purchasing ? null : () => _unlock('completion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _darkBg,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSizes.buttonCornerRadius,
                  ),
                ),
              ),
              child: const Text(
                'Unlock SafePrep  —  \$4.99',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // FSME's snarky sign-off + free proctor-finder exit.
          _fsmeBox(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        backgroundColor: _darkBg,
        body: Center(child: CircularProgressIndicator(color: _gold)),
      );
    }

    return Scaffold(
      backgroundColor: _darkBg,
      // Stack, not just SafeArea/Column directly — the trophy-burst
      // overlay (_trophyOverlay) needs to sit ABOVE the whole screen,
      // not confined inside _celebrationBox, so it's layered on top
      // here rather than nested in the normal content tree.
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _limitedBanner(),
                Expanded(
                  child: SingleChildScrollView(
                    child: _allDone
                        ? _completionView()
                        : _showingLimit
                        ? _categoryLimitView()
                        : _questionView(),
                  ),
                ),
              ],
            ),
          ),
          if (_showTrophyOverlay) _trophyOverlay(context),
        ],
      ),
    );
  }
}

/// Speech-bubble painter — copied from the real RapidFirePage so the
/// limited version's question card reads identically.
class _BubblePainter extends CustomPainter {
  final Color color;
  const _BubblePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(20, 0)
      ..quadraticBezierTo(0, 0, 0, 20)
      ..lineTo(0, 100)
      ..quadraticBezierTo(0, 120, 20, 120)
      ..lineTo(30, 120)
      ..lineTo(20, 145)
      ..lineTo(60, 120)
      ..lineTo(300, 120)
      ..quadraticBezierTo(320, 120, 320, 100)
      ..lineTo(320, 20)
      ..quadraticBezierTo(320, 0, 300, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.color != color;
}
