import 'package:flutter/material.dart';

enum ExpertClubResult { takeExam, skip }

class ExpertClubDialog extends StatelessWidget {
  final String userName;

  const ExpertClubDialog({super.key, required this.userName});

  static Future<ExpertClubResult> show(
      BuildContext context, String userName) async {
    final result = await showDialog<ExpertClubResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExpertClubDialog(userName: userName),
    );
    return result ?? ExpertClubResult.skip;
  }

  @override
  Widget build(BuildContext context) {
    final displayName = userName.isNotEmpty ? userName : 'SafePrep';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFFF0C575),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 0,
          children: [
            // Trophy illustration
            SizedBox(
              width: 160,
              height: 180,
              child: CustomPaint(
                painter: _TrophyPainter(name: displayName),
              ),
            ),

            const SizedBox(height: 16),

            // Headline
            const Text(
              'Top 5%.',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3A2A00),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Subtext
            const Text(
              'You scored in the top 5%. Now put your mind at ease — take the Final Exam.',
              style: TextStyle(fontSize: 14, color: Color(0xFF5A4000)),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Take Exam button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.pop(context, ExpertClubResult.takeExam),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A2A00),
                  foregroundColor: const Color(0xFFF0C575),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Take the Final Exam',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: 10),

            // Skip
            GestureDetector(
              onTap: () => Navigator.pop(context, ExpertClubResult.skip),
              child: const Text(
                'Home Page',
                style: TextStyle(fontSize: 12, color: Color(0xFF7A5A00)),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrophyPainter extends CustomPainter {
  final String name;
  _TrophyPainter({required this.name});

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / 180;
    final double sy = size.height / 210;

    final shadowPaint = Paint()..color = const Color(0xFFB8860B);
    final mainPaint = Paint()..color = const Color(0xFFDAA520);
    final shinePaint = Paint()
      ..color = const Color(0xFFFFE87C).withValues(alpha: 0.6);
    final darkPaint = Paint()..color = const Color(0xFF8B6914);

    // Cup body shadow
    final bodyPath = Path()
      ..moveTo(30 * sx, 15 * sy)
      ..lineTo(150 * sx, 15 * sy)
      ..lineTo(135 * sx, 112 * sy)
      ..quadraticBezierTo(90 * sx, 142 * sy, 45 * sx, 112 * sy)
      ..close();
    canvas.drawPath(bodyPath, shadowPaint);

    // Cup body main
    final mainPath = Path()
      ..moveTo(37 * sx, 15 * sy)
      ..lineTo(143 * sx, 15 * sy)
      ..lineTo(129 * sx, 108 * sy)
      ..quadraticBezierTo(90 * sx, 135 * sy, 51 * sx, 108 * sy)
      ..close();
    canvas.drawPath(mainPath, mainPaint);

    // Cup shine
    final shinePath = Path()
      ..moveTo(52 * sx, 21 * sy)
      ..lineTo(82 * sx, 21 * sy)
      ..lineTo(75 * sx, 67 * sy)
      ..quadraticBezierTo(63 * sx, 75 * sy, 54 * sx, 67 * sy)
      ..close();
    canvas.drawPath(shinePath, shinePaint);

    // Left handle
    final handlePaint = Paint()
      ..color = const Color(0xFFB8860B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9 * sx;
    final leftHandle = Path()
      ..moveTo(33 * sx, 37 * sy)
      ..cubicTo(6 * sx, 37 * sy, 6 * sx, 97 * sy, 33 * sx, 97 * sy);
    canvas.drawPath(leftHandle, handlePaint);

    // Right handle
    final rightHandle = Path()
      ..moveTo(147 * sx, 37 * sy)
      ..cubicTo(174 * sx, 37 * sy, 174 * sx, 97 * sy, 147 * sx, 97 * sy);
    canvas.drawPath(rightHandle, handlePaint);

    // Stem
    final stemRect = Rect.fromLTWH(81 * sx, 132 * sy, 18 * sx, 33 * sy);
    canvas.drawRect(stemRect, shadowPaint);

    // Base
    final baseRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(45 * sx, 162 * sy, 90 * sx, 15 * sy),
        Radius.circular(6 * sx));
    canvas.drawRRect(baseRect, shadowPaint);

    // Placard background
    final placardRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(30 * sx, 174 * sy, 120 * sx, 34 * sy),
        Radius.circular(4 * sx));
    canvas.drawRRect(placardRect, darkPaint);

    // Placard text
    final tp1 = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFE87C)),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp1.layout(maxWidth: 116 * sx);
    tp1.paint(canvas, Offset(32 * sx, 178 * sy));

    final tp2 = TextPainter(
      text: const TextSpan(
        text: '95%+ Club',
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFE87C)),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp2.layout(maxWidth: 116 * sx);
    tp2.paint(canvas, Offset(32 * sx, 192 * sy));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}