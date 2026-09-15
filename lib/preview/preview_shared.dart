import 'package:flutter/material.dart';
import '../constants.dart';
import '../safe_prep_nav_bar.dart';

// ─────────────────────────────────────────────────────────────
// SHARED: Middle Marquee — typewriter then scrolls if overflow
// ─────────────────────────────────────────────────────────────
class PreviewMarquee extends StatefulWidget {
  final String text;
  final VoidCallback? onComplete;
  const PreviewMarquee({super.key, required this.text, this.onComplete});

  @override
  State<PreviewMarquee> createState() => _PreviewMarqueeState();
}

class _PreviewMarqueeState extends State<PreviewMarquee> {
  String _displayed = '';
  int _index = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _startTypewriter();
  }

  @override
  void didUpdateWidget(PreviewMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _displayed = '';
      _index = 0;
      _startTypewriter();
    }
  }

  void _startTypewriter() async {
    while (mounted && _index < widget.text.length) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      if (_index >= widget.text.length) break;
      setState(() {
        _displayed = widget.text.substring(
          0,
          (_index + 1).clamp(0, widget.text.length),
        );
        _index++;
      });
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 50),
          curve: Curves.linear,
        );
      }
    }
    if (mounted) {
      widget.onComplete?.call();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Text(
          _displayed,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SHARED: Delayed Next Button + Unlock Button
// Both fade in after 5 seconds
// ─────────────────────────────────────────────────────────────
class PreviewNextButton extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback? onUnlock;
  const PreviewNextButton({super.key, required this.onNext, this.onUnlock});

  @override
  State<PreviewNextButton> createState() => _PreviewNextButtonState();
}

class _PreviewNextButtonState extends State<PreviewNextButton> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 600),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: SizedBox(
              width: double.infinity,
              height: AppSizes.primaryButtonHeight,
              child: ElevatedButton(
                onPressed: _visible ? widget.onNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.black,
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSizes.buttonCornerRadius,
                    ),
                  ),
                  elevation: 4,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Next',
                      style: TextStyle(
                        fontSize: AppFonts.button,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              height: AppSizes.primaryButtonHeight,
              child: ElevatedButton(
                onPressed: _visible ? widget.onUnlock : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF0C575),
                  foregroundColor: const Color(0xFF2A1F00),
                  disabledBackgroundColor: const Color(0xFFF0C575),
                  disabledForegroundColor: const Color(0xFF2A1F00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSizes.buttonCornerRadius,
                    ),
                  ),
                  elevation: 4,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('\ud83d\udd13', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Text(
                      'Unlock the full SafePrep\u2122',
                      style: TextStyle(
                        fontSize: AppFonts.button,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SHARED: Standard SafePrep Header
// ─────────────────────────────────────────────────────────────
Widget buildPreviewHeader() {
  return Padding(
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
          'Prep\u2122',
          style: TextStyle(
            fontSize: AppFonts.header,
            fontWeight: FontWeight.w600,
            color: AppColors.bodyText,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// SHARED: Standard Footer — now a nav bar
// ─────────────────────────────────────────────────────────────
Widget buildPreviewFooter(BuildContext context) {
  return const SafePrepNavBar();
}
