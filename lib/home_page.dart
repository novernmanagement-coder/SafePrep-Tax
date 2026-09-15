import 'dart:async';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'app_state.dart';
import 'csv_loader.dart';
import 'app_state_persistence.dart';
import 'readiness_engine.dart';
import 'assessment_info_page.dart';
import 'cluster_info_page.dart';
import 'dashboard_page.dart';
import 'settings_page.dart';
import 'sixty_second_refresh_page.dart';
import 'about_proctors_page.dart';
import 'final_exam_intro_page.dart';
import 'peace_of_mind_page.dart';
import 'fsme_help_box.dart';
import 'fsme_eye.dart'; // FsmeEyePair, EyeMood
import 'mixpanel_service.dart';
import 'safe_prep_nav_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomeClusterEntry {
  final AppCluster cluster;
  final String label;
  final IconData icon;
  const _HomeClusterEntry(this.cluster, this.label, this.icon);
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final AppState _state = AppState();
  String _currentFact = '';
  List<MilestoneModel> _milestones = [];

  // --- FSME renewal explainer (daysRemaining <= 2, one-time) ---
  final GlobalKey<FsmeEyePairState> _explainerEyeKey =
      GlobalKey<FsmeEyePairState>();
  bool _showFsmeBeat1 = false;
  bool _showFsmeBeat2 = false;
  final List<Timer> _explainerTimers = [];

  // Mirrors the five stops from FsmePostPurchaseLanding / the list in
  // settings_page.dart — same clusters, same labels/icons. Home isn't
  // any one of the five itself, so its FsmeHelpBox opens this list
  // rather than a single ClusterInfoPage the way other pages will.
  static const List<_HomeClusterEntry> _clusters = [
    _HomeClusterEntry(
      AppCluster.assessment,
      'The Assessment',
      Icons.fact_check_outlined,
    ),
    _HomeClusterEntry(
      AppCluster.dashboardStudy,
      'Dashboard and Study',
      Icons.dashboard_customize_outlined,
    ),
    _HomeClusterEntry(AppCluster.trainers, 'The Trainers', Icons.bolt_outlined),
    _HomeClusterEntry(AppCluster.settings, 'Settings', Icons.settings_outlined),
    _HomeClusterEntry(
      AppCluster.finalExam,
      'The Final Exam',
      Icons.workspace_premium_outlined,
    ),
  ];

  static const List<String> _fsmeHelpMessages = [
    "Home base. Everything spins out from here.",
    "Not sure what does what? Story of my life too.",
    "Tap me — I'll 'splain whatever you're stuck on.",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFacts();
    _loadMilestones();

    MixpanelService.instance.track(
      'session_start',
      properties: {
        'is_unlocked': _state.hasUnlockedApp,
        'app_name': 'SP',
        'days_remaining': _state.daysRemaining,
      },
    );
    MixpanelService.instance.track(
      'home_viewed',
      properties: {
        'is_unlocked': _state.hasUnlockedApp,
        'app_name': 'SP',
        'days_remaining': _state.daysRemaining,
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final t in _explainerTimers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      MixpanelService.instance.track(
        'session_end',
        properties: {'app_name': 'SP'},
      );
    }
  }

  void _checkUnlockTrophy() {
    if (_state.hasUnlockedApp &&
        !_state.earnedTrophyIds.contains('AppUnlocked')) {
      _state.addEarnedMilestone('AppUnlocked', 'SafePrep Unlocked');
      AppStatePersistence.save();
    }
  }

  // Reuses the existing 'DiagnosticCompleted' / "Optimized Path Chosen"
  // trophy (normally earned by completing the diagnostic Assessment,
  // see assessment_page_v2.dart) for the mirror-image case: someone who
  // skipped the Assessment entirely but still mastered every study
  // category on their own found an efficient route too. Per Gerry's
  // call — flag if this naming feels backwards, since the trophy ID
  // literally says "DiagnosticCompleted" for a no-diagnostic path.
  void _checkOptimizedPathTrophy() {
    if (!_state.hasTakenAssessment &&
        _state.masteredCategories.length == AppState.allCategories.length &&
        !_state.earnedTrophyIds.contains('DiagnosticCompleted')) {
      _state.addEarnedMilestone('DiagnosticCompleted', 'Optimized Path Chosen');
      AppStatePersistence.save();
    }
  }

  Future<void> _loadFacts() async {
    final facts = await FactLoader.loadAll();
    if (mounted) {
      setState(() {
        _currentFact = facts.map((f) => f.fact).join('  •  ');
      });
    }
  }

  Future<void> _loadMilestones() async {
    final all = await MilestoneLoader.loadAll();
    if (mounted) {
      _checkUnlockTrophy();
      _checkOptimizedPathTrophy();
      _state.readinessScore = ReadinessEngine.calculate(_state);
      _state.readinessCoachMessage = ReadinessEngine.coachMessage(
        _state,
        _state.readinessScore,
      );
      _state.readinessCheerMessage = ReadinessEngine.cheerleaderMessage(
        _state,
        _state.readinessScore,
      );
      setState(() => _milestones = all);
      _maybeStartRenewalExplainer();
    }
  }

  // Fires once, only when the Renew button is actually showing
  // (daysRemaining <= 2 through expiry) and the user hasn't seen this
  // explainer before. Two-beat sequence, not a modal:
  //   Beat 1: under the header, "follow me" line, eyes point down.
  //   Beat 2: above the footer/nav bar, full days-left/readiness/
  //   discount script, holds 10s, then self-clears.
  //
  // TODO: AppState needs a `hasSeenRenewalExplainer` bool (default
  // false) persisted via AppStatePersistence — added here as a
  // field reference; wire the real field/persistence in app_state.dart.
  // TODO: reset hasSeenRenewalExplainer to false on the purchase-
  // success path for buyRenewal(), so this can fire again on a
  // future renewal cycle rather than only ever once, lifetime.
  void _maybeStartRenewalExplainer() {
    final eligible =
        _state.isTimeLimited &&
        !_state.isExpired &&
        (_state.daysRemaining ?? 99) <= 2 &&
        !_state.hasSeenRenewalExplainer; // TODO: add this field to AppState
    if (!eligible) return;

    _explainerTimers.add(
      Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() => _showFsmeBeat1 = true);
        // TODO: fsme_eye.dart doesn't yet have a Point(direction)
        // one-shot — this was scoped as a general widget addition
        // (up/down/left/right), first use case being this screen.
        // Once built: _explainerEyeKey.currentState?.point(EyeDirection.down);
      }),
    );
    _explainerTimers.add(
      Timer(const Duration(milliseconds: 3300), () {
        if (!mounted) return;
        setState(() => _showFsmeBeat1 = false);
      }),
    );
    _explainerTimers.add(
      Timer(const Duration(milliseconds: 3700), () {
        if (!mounted) return;
        setState(() => _showFsmeBeat2 = true);
      }),
    );
    _explainerTimers.add(
      Timer(const Duration(milliseconds: 13700), () {
        if (!mounted) return;
        setState(() => _showFsmeBeat2 = false);
        _state.hasSeenRenewalExplainer = true; // TODO: see field note above
        AppStatePersistence.save();
      }),
    );
  }

  Widget _buildFsmeBeat1() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: !_showFsmeBeat1
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _goldDark),
              ),
              child: Row(
                children: [
                  FsmeEyePair(
                    key: _explainerEyeKey,
                    mood: EyeMood.idle,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hey, follow me — I have something to show ya?',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _goldText,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFsmeBeat2() {
    final daysLeft = _state.daysRemaining ?? 0;
    final readiness = _state.readinessScore;
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: !_showFsmeBeat2
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _goldDark, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const FsmeEyePair(mood: EyeMood.idle, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'F S M E',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 2,
                          color: _goldText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "I see the Boss added the Renew button, so you've got "
                    "$daysLeft day${daysLeft == 1 ? '' : 's'} left. You're "
                    "at $readiness% readiness — want to add another week? "
                    "If so, hit Renew.",
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF4A3728),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "(I talked her into the friends and family discount — "
                    "just \$2.99.)",
                    style: TextStyle(
                      fontSize: 12,
                      color: _goldText,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _openCluster(AppCluster cluster) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClusterInfoPage(
          cluster: cluster,
          launchContext: ClusterLaunchContext.landing,
        ),
      ),
    );
  }

  void _showClusterList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0A0F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What do you want me to \'splain?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 14),
                ..._clusters.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          Navigator.pop(ctx);
                          _openCluster(entry.cluster);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 13,
                            horizontal: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF13130F),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(
                                0xFFD4AF37,
                              ).withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                entry.icon,
                                size: 16,
                                color: const Color(0xFFD4AF37),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  entry.label,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFFF0EDE8),
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: const Color(
                                  0xFFD4AF37,
                                ).withValues(alpha: 0.7),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: AppSizes.primaryButtonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryButton,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonCornerRadius),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: AppFonts.button)),
      ),
    );
  }

  static const Color _goldDark = Color(0xFFC8A84B);
  static const Color _goldLight = Color(0xFFFFF3C4);
  static const Color _goldText = Color(0xFF8B6914);

  bool _isEarned(MilestoneModel m) =>
      _state.earnedTrophyIds.contains(m.trigger);

  void _showInfoModal(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _goldDark, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8B6914),
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF555555),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(
                width: 100,
                height: 40,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _goldDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTrophyModal(BuildContext context, MilestoneModel m, bool earned) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _goldDark, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              Text(
                earned ? '🏆' : '🔒',
                style: const TextStyle(fontSize: 52),
                textAlign: TextAlign.center,
              ),
              Text(
                earned ? m.title : 'Locked',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                earned
                    ? m.message
                    : 'Take the assessment to unlock this trophy and increase your readiness score.',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF555555),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(
                width: 100,
                height: 40,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _goldDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Nice!',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrophyCard(MilestoneModel m, {bool elite = false}) {
    final earned = _isEarned(m);
    return GestureDetector(
      onTap: () => _showTrophyModal(context, m, earned),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
        decoration: BoxDecoration(
          color: earned
              ? (elite ? _goldLight : Colors.white)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: earned ? _goldDark : const Color(0xFFDDDDDD),
            width: earned ? (elite ? 2 : 1.5) : 1,
          ),
        ),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (elite)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: earned ? _goldDark : const Color(0xFFEEEEEE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ELITE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: earned ? Colors.white : const Color(0xFFAAAAAA),
                      ),
                    ),
                  ),
                Text(
                  earned ? '🏆' : '🔒',
                  style: TextStyle(
                    fontSize: earned ? 34 : 26,
                    color: earned ? null : const Color(0xFFBBBBBB),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  m.title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: earned ? FontWeight.w600 : FontWeight.normal,
                    color: earned
                        ? (elite ? _goldText : const Color(0xFF1A1A1A))
                        : const Color(0xFFAAAAAA),
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            if (earned)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: _goldDark,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 11, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTrophyBox({
    required String title,
    required List<String> earnedCategories,
    required String emptyIcon,
    required String infoTitle,
    required String infoMessage,
  }) {
    const categories = AppState.allCategories;
    final earnedSlots = categories
        .where((c) => earnedCategories.contains(c))
        .toList();

    return GestureDetector(
      onTap: () => _showInfoModal(context, infoTitle, infoMessage),
      child: Container(
        height: 95,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8D5A0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _goldText,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            earnedSlots.isEmpty
                ? const Center(
                    child: Text(
                      '🔒',
                      style: TextStyle(fontSize: 22, color: Color(0xFFCCCCCC)),
                    ),
                  )
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          if (i >= earnedSlots.length) {
                            return const SizedBox(width: 26);
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _goldLight,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _goldDark, width: 1),
                              ),
                              child: const Center(
                                child: Text(
                                  '🏆',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      if (earnedSlots.length > 4) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (i) {
                            final idx = i + 4;
                            if (idx >= earnedSlots.length) {
                              return const SizedBox(width: 26);
                            }
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: _goldLight,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: _goldDark,
                                    width: 1,
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    '🏆',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  static const int _seededReadinessDisplay = 62;

  Widget _buildReadinessMeter() {
    final hasRealData =
        _state.latestResult != null || _state.categoryQuizScores.isNotEmpty;
    final showSeeded = !hasRealData && !_state.hasUnlockedApp;
    final score = hasRealData
        ? _state.readinessScore
        : (showSeeded ? _seededReadinessDisplay : _state.readinessScore);
    final isGreenLight = score >= 100;
    String label;
    if (showSeeded) {
      label = 'National avg — adapts as you study';
    } else if (score >= 100) {
      label = '🟢 Green Light';
    } else if (score >= 85) {
      label = 'Nearly Ready';
    } else if (score >= 66) {
      label = 'Almost There';
    } else if (score >= 41) {
      label = 'Building Momentum';
    } else {
      label = 'Keep Going';
    }

    return GestureDetector(
      onTap: () => _showInfoModal(
        context,
        'ServSafe Readiness',
        'Before you\'ve studied, this shows a national average — just something to compare against, not your real score. The moment you study a category or take the assessment, your actual data takes over and your Readiness Score updates to reflect you. 100% means you\'re ready. Take the SafePrep Final Exam to prove it.',
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
        decoration: BoxDecoration(
          color: isGreenLight
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFFFFBF0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isGreenLight
                ? Colors.green.shade300
                : const Color(0xFFE8D5A0),
            width: isGreenLight ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            const Text(
              'ServSafe Readiness',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _goldText,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            _buildPartialStars(score),
            const SizedBox(height: 6),
            Text(
              '$score%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isGreenLight ? Colors.green.shade700 : _goldDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: isGreenLight ? Colors.green.shade600 : _goldText,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartialStars(int score) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final starMin = i * 20.0;
        final starMax = (i + 1) * 20.0;
        double fillFraction = 0.0;
        if (score >= starMax) {
          fillFraction = 1.0;
        } else if (score > starMin) {
          fillFraction = (score - starMin) / 20.0;
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: _buildPartialStar(fillFraction),
        );
      }),
    );
  }

  Widget _buildPartialStar(double fillFraction) {
    return SizedBox(
      width: 24,
      height: 26,
      child: Stack(
        children: [
          const Text(
            '★',
            style: TextStyle(
              fontSize: 22,
              color: Color(0xFFDDDDDD),
              height: 1.1,
            ),
          ),
          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: fillFraction,
              child: const Text(
                '★',
                style: TextStyle(
                  fontSize: 22,
                  color: Color(0xFFC8A84B),
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessMarquee() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8D5A0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: ClipRect(
                    child: ReadinessMarqueeScroller(
                      text: _state.readinessCoachMessage,
                      color: const Color(0xFF1A5276),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Image.asset(
                'Assets/instructor_explaining.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(color: Color(0xFFE8D5A0), height: 1),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: ClipRect(
                    child: ReadinessMarqueeScroller(
                      text: _state.readinessCheerMessage,
                      color: const Color(0xFFC8A84B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Image.asset(
                'Assets/student_correct.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrophySection() {
    if (_milestones.isEmpty) return const SizedBox();
    final topTwo = _milestones.take(2).toList();
    final curriculumDone = _state.curriculumCompletedCategories;
    final mastered = _state.masteredCategories;
    final earnedCount = topTwo.where((m) => _isEarned(m)).length;
    final totalEarned =
        earnedCount +
        (curriculumDone.isNotEmpty ? 1 : 0) +
        (mastered.isNotEmpty ? 1 : 0);
    String subtitle = totalEarned == 0
        ? 'Keep going — trophies are waiting.'
        : '$earnedCount of 2 earned';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8D5A0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              const Text(
                'My Trophies',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const Spacer(),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: topTwo.isNotEmpty
                    ? _buildTrophyCard(topTwo[0])
                    : const SizedBox(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: topTwo.length > 1
                    ? _buildTrophyCard(topTwo[1])
                    : const SizedBox(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMiniTrophyBox(
                  title: 'CURRICULUM',
                  earnedCategories: curriculumDone,
                  emptyIcon: '📖',
                  infoTitle: 'Curriculum Trophies',
                  infoMessage:
                      'Study each category to earn curriculum trophies. Studying increases your readiness score.',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniTrophyBox(
                  title: 'MASTERED',
                  earnedCategories: mastered,
                  emptyIcon: '⭐',
                  infoTitle: 'Mastery Trophies',
                  infoMessage:
                      'Score 85% or higher on a category quiz to earn a mastery trophy.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildReadinessMeter()),
                const SizedBox(width: 10),
                Expanded(child: _buildReadinessMarquee()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterSection() {
    final state = _state;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        spacing: 2,
        children: [
          if (state.isTimeLimited && state.daysRemaining != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${state.daysRemaining} day${state.daysRemaining == 1 ? '' : 's'} of access remaining',
                style: TextStyle(
                  fontSize: 11,
                  color: state.daysRemaining! <= 2
                      ? Colors.redAccent
                      : AppColors.subtleText,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Text(
            AppStrings.footerLine1,
            style: TextStyle(
              fontSize: AppFonts.footer,
              color: AppColors.footerText,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            AppStrings.footerLine2,
            style: TextStyle(
              fontSize: AppFonts.footer,
              color: AppColors.footerText,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            AppStrings.footerLine3,
            style: TextStyle(
              fontSize: AppFonts.footer,
              color: AppColors.starMotifBlue,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Padding(
          padding: AppSizes.pageMargin,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Safe',
                      style: TextStyle(
                        fontSize: AppFonts.header,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bodyText,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Image.asset('Assets/splash.png', width: 36, height: 36),
                    const SizedBox(width: 6),
                    Text(
                      'Prep™',
                      style: TextStyle(
                        fontSize: AppFonts.header,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bodyText,
                      ),
                    ),
                  ],
                ),
              ),
              // FSME renewal-explainer beat 1 (under header)
              _buildFsmeBeat1(),
              Container(
                height: 32,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F0E8),
                  border: Border.all(color: const Color(0xFFC8B89A)),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _currentFact.isEmpty
                      ? const SizedBox()
                      : Marquee(text: _currentFact),
                ),
              ),
              FsmeHelpBox(
                messages: _fsmeHelpMessages,
                onTap: _showClusterList,
                enabled: _state.fsmeEnabled,
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    spacing: AppSizes.cardSpacing,
                    children: [
                      Column(
                        spacing: 2,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: AppSizes.primaryButtonHeight,
                            child: ElevatedButton(
                              onPressed: () {
                                MixpanelService.instance.track(
                                  'curriculum_tapped',
                                  properties: {'app_name': 'SP'},
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AssessmentInfoPage(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryButton,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.buttonCornerRadius,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Create my personalized curriculum',
                                style: TextStyle(
                                  fontSize: AppFonts.button,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            'Study less — take the assessment first',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.subtleText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),

                      Column(
                        spacing: 2,
                        children: [
                          _buildButton(
                            'The SafePrep™ Dashboard',
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DashboardPage(),
                              ),
                            ),
                          ),
                          Text(
                            'Access your study curriculum and view progress',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.subtleText,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),

                      // Final Exam button is always shown to purchased
                      // users — no readiness-score gate. The old
                      // 100%-readiness lock existed only to stop the
                      // now-removed 30-minute trial from letting users
                      // skip straight to the exam without studying;
                      // that population no longer exists, so the gate
                      // (and its "Access enabled when 100%..." footer
                      // line) has been removed entirely rather than
                      // left as unreachable dead code.
                      Column(
                        spacing: 2,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: AppSizes.primaryButtonHeight,
                            child: ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FinalExamIntroPage(),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryButton,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.buttonCornerRadius,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'When ready — take the SafePrep exam',
                                style: TextStyle(fontSize: AppFonts.button),
                              ),
                            ),
                          ),
                          Text(
                            'Take it whenever you\'re ready — no gate.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.success,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),

                      _buildButton(
                        'Settings and information',
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsPage(),
                          ),
                        ),
                      ),

                      Column(
                        spacing: 2,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: AppSizes.primaryButtonHeight,
                            child: ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PeaceOfMindPage(),
                                ),
                              ).then((_) => setState(() {})),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryButton,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.buttonCornerRadius,
                                  ),
                                ),
                              ),
                              child: const Text(
                                '🔓 60 Second Trainers',
                                style: TextStyle(
                                  fontSize: AppFonts.button,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            'Quick tools to sharpen your knowledge',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.subtleText,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),

                      Row(
                        spacing: 8,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: AppSizes.primaryButtonHeight,
                              child: ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const SixtySecondRefreshPage(),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryButton,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.buttonCornerRadius,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  '⏱ 60-Second Refresh',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: SizedBox(
                              height: AppSizes.primaryButtonHeight,
                              child: ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AboutProctorsPage(),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryButton,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.buttonCornerRadius,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  '👤 About Proctors',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      _buildTrophySection(),
                      _buildFooterSection(),
                    ],
                  ),
                ),
              ),
              // FSME renewal-explainer beat 2 (above the nav bar/footer)
              _buildFsmeBeat2(),
              const SafePrepNavBar(),
            ],
          ),
        ),
      ),
    );
  }
}

class ReadinessMarqueeScroller extends StatefulWidget {
  final String text;
  final Color color;
  const ReadinessMarqueeScroller({
    super.key,
    required this.text,
    this.color = const Color(0xFF4A3728),
  });

  @override
  State<ReadinessMarqueeScroller> createState() =>
      _ReadinessMarqueeScrollerState();
}

class _ReadinessMarqueeScrollerState extends State<ReadinessMarqueeScroller> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() async {
    await Future.delayed(const Duration(seconds: 2));
    while (mounted) {
      if (!_scrollController.hasClients) {
        await Future.delayed(const Duration(milliseconds: 200));
        continue;
      }
      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }
      await _scrollController.animateTo(
        max,
        duration: Duration(
          milliseconds: (max * 25).toInt().clamp(3000, 1 << 30),
        ),
        curve: Curves.linear,
      );
      if (!mounted) break;
      _scrollController.jumpTo(0);
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repeated = '${widget.text}          ${widget.text}';
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          repeated,
          style: TextStyle(fontSize: 11, color: widget.color),
        ),
      ),
    );
  }
}

class Marquee extends StatefulWidget {
  final String text;
  const Marquee({super.key, required this.text});

  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() async {
    await Future.delayed(const Duration(seconds: 2));
    while (mounted) {
      if (!_scrollController.hasClients) {
        await Future.delayed(const Duration(milliseconds: 200));
        continue;
      }
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 0) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }
      await _scrollController.animateTo(
        maxExtent,
        duration: Duration(
          milliseconds: (maxExtent * 25).toInt().clamp(3000, 1 << 30),
        ),
        curve: Curves.linear,
      );
      if (!mounted) break;
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          widget.text,
          style: const TextStyle(fontSize: 12, color: Color(0xFF4A3728)),
        ),
      ),
    );
  }
}
