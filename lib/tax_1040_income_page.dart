import 'dart:async';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'fsme_eye.dart';
import 'home_page.dart';
import 'safe_prep_nav_bar.dart';

// "1040 Basics" — Income section. Drag-and-drop port of the validated
// HTML/JS prototype (1040_income_form_drag.html): real-world income items
// with dollar amounts get dragged onto the actual line of Form 1040 they
// belong on, Line 9 (Total Income) computes live as items land, and the
// console box below the tray explains — in the trainer mascot's voice,
// no name used — why each item belongs where it just landed, citing the
// real source document. Pushed from Tax1040BasicsPage; the system back
// gesture (and the explicit link at the top) both return there.
class Tax1040IncomeDragPage extends StatefulWidget {
  const Tax1040IncomeDragPage({super.key});

  @override
  State<Tax1040IncomeDragPage> createState() => _Tax1040IncomeDragPageState();
}

class _IncomeItem {
  final String line;
  final String desc;
  final int amt;
  final bool taxable;
  final String note;

  const _IncomeItem({
    required this.line,
    required this.desc,
    required this.amt,
    required this.taxable,
    required this.note,
  });
}

// Only 2a (municipal bond interest) is tax-exempt — every other item feeds
// the live Line 9 total. That's the one deliberate "trap" item.
const List<_IncomeItem> _kIncomeItems = [
  _IncomeItem(
    line: '1a',
    desc: 'W-2 reported income',
    amt: 65000,
    taxable: true,
    note:
        "Comes straight off your W-2, box 1. If one line on this form "
        "gets to be easy, glad it's this one.",
  ),
  _IncomeItem(
    line: '2a',
    desc: 'Municipal bond interest (tax-exempt)',
    amt: 200,
    taxable: false,
    note:
        "Traced back to your 1099-INT, box 8. Tax-exempt means exactly "
        "what it sounds like — disclosed here, never taxed. ...and once "
        "your tax-exempt interest tops \$1,500, congrats, you also get to "
        "meet Schedule B.",
  ),
  _IncomeItem(
    line: '2b',
    desc: 'Bank savings account interest (1099-INT)',
    amt: 340,
    taxable: true,
    note:
        "Straight off your 1099-INT, box 1. Ordinary interest, fully "
        "taxable — no trick here, well, except pretending there was one.",
  ),
  _IncomeItem(
    line: '3b',
    desc: 'Ordinary dividends (1099-DIV)',
    amt: 1200,
    taxable: true,
    note:
        "Comes off your 1099-DIV, box 1a. Taxable, goes on 3b — "
        "'qualified' just changes the rate later, don't overthink it now.",
  ),
  _IncomeItem(
    line: '4b',
    desc: 'Traditional IRA distribution, fully taxable',
    amt: 4500,
    taxable: true,
    note:
        "Pulled from your 1099-R, box 2a — that's the taxable amount, "
        "not box 1's full distribution. Learned that distinction the hard "
        "way once. Long story.",
  ),
  _IncomeItem(
    line: '5b',
    desc: 'Pension distribution, fully taxable',
    amt: 18000,
    taxable: true,
    note:
        "Same 1099-R as IRAs, same box 2a. I basically just said the "
        "last line again, but for pensions.",
  ),
  _IncomeItem(
    line: '6b',
    desc: 'Social Security benefits, taxable portion',
    amt: 9500,
    taxable: true,
    note:
        "Starts on your SSA-1099, then runs through the Social Security "
        "Benefits Worksheet to find the taxable slice. Riveting stuff.",
  ),
  _IncomeItem(
    line: '7a',
    desc: 'Capital gain from stock sale',
    amt: 2300,
    taxable: true,
    note:
        "Comes from Schedule D — Form 8949 first if you're itemizing "
        "individual sales.",
  ),
  _IncomeItem(
    line: '8',
    desc: 'Freelance income (Schedule 1, line 8)',
    amt: 3000,
    taxable: true,
    note:
        "Net profit from Schedule C rolls onto Schedule 1, then up here "
        "to line 8. No line of its own on the main form, so it hitches a "
        "ride.",
  ),
];

class _FormLineSpec {
  final String letter;
  final String rowLabel;
  final String desc;
  final bool computed;
  final String? dataLine;

  const _FormLineSpec({
    required this.letter,
    required this.rowLabel,
    required this.desc,
    this.computed = false,
    this.dataLine,
  });
}

const List<_FormLineSpec> _kFormLines = [
  _FormLineSpec(
    letter: '1a',
    rowLabel: '1a',
    desc: 'Total amount from Form(s) W-2, box 1',
    dataLine: '1a',
  ),
  _FormLineSpec(
    letter: 'z',
    rowLabel: '1z',
    desc: 'Add lines 1a through 1h',
    computed: true,
  ),
  _FormLineSpec(
    letter: '2a',
    rowLabel: '2a',
    desc: 'Tax-exempt interest',
    dataLine: '2a',
  ),
  _FormLineSpec(
    letter: 'b',
    rowLabel: '2b',
    desc: 'Taxable interest',
    dataLine: '2b',
  ),
  _FormLineSpec(
    letter: '3b',
    rowLabel: '3b',
    desc: 'Ordinary dividends',
    dataLine: '3b',
  ),
  _FormLineSpec(
    letter: '4b',
    rowLabel: '4b',
    desc: 'IRA distributions — taxable amount',
    dataLine: '4b',
  ),
  _FormLineSpec(
    letter: '5b',
    rowLabel: '5b',
    desc: 'Pensions and annuities — taxable amount',
    dataLine: '5b',
  ),
  _FormLineSpec(
    letter: '6b',
    rowLabel: '6b',
    desc: 'Social security benefits — taxable amount',
    dataLine: '6b',
  ),
  _FormLineSpec(
    letter: '7a',
    rowLabel: '7a',
    desc: 'Capital gain or (loss)',
    dataLine: '7a',
  ),
  _FormLineSpec(
    letter: '8',
    rowLabel: '8',
    desc: 'Additional income from Schedule 1',
    dataLine: '8',
  ),
  _FormLineSpec(
    letter: '9',
    rowLabel: '9',
    desc: 'Add lines 1z, 2b, 3b, 4b, 5b, 6b, 7a, and 8 — total income',
    computed: true,
  ),
];

class _Tax1040IncomeDragPageState extends State<Tax1040IncomeDragPage> {
  static const Color _paper = Color(0xFFDCECE6);
  static const Color _fillBorder = Color(0xFF9AA1D6);
  static const Color _accent = Color(0xFF3A4FB0);
  static const Color _highlight = Color(0xFFFFF3A3);
  static const Color _highlightBorder = Color(0xFFC9A600);
  static const Color _correct = Color(0xFF2F8A4B);
  static const Color _correctBg = Color(0xFFE3F5E8);
  static const Color _wrong = Color(0xFFC0392B);
  static const Color _wrongBg = Color(0xFFFBE3E0);
  static const String _introLine =
      "Drag something up there — I'll tell you why it goes where it goes.";
  static const Duration _typeCharDelay = Duration(milliseconds: 18);

  List<_IncomeItem> _tray = [];
  final Map<String, _IncomeItem> _placed = {};
  int _runningTotal = 0;
  bool _done = false;
  String? _flashWrongLine;

  String _consoleText = _introLine;
  EyeMood _eyeMood = EyeMood.idle;
  int _typeGeneration = 0;
  final GlobalKey<FsmeEyePairState> _eyeKey = GlobalKey<FsmeEyePairState>();

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    final items = List<_IncomeItem>.from(_kIncomeItems)..shuffle();
    _typeGeneration++;
    setState(() {
      _tray = items;
      _placed.clear();
      _runningTotal = 0;
      _done = false;
      _flashWrongLine = null;
      _consoleText = _introLine;
      _eyeMood = EyeMood.idle;
    });
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Future<void> _typeConsole(String text) async {
    final myGen = ++_typeGeneration;
    setState(() {
      _consoleText = '';
      _eyeMood = EyeMood.typing;
    });
    for (var i = 1; i <= text.length; i++) {
      if (!mounted || myGen != _typeGeneration) return;
      await Future.delayed(_typeCharDelay);
      if (!mounted || myGen != _typeGeneration) return;
      setState(() => _consoleText = text.substring(0, i));
    }
    if (!mounted || myGen != _typeGeneration) return;
    setState(() => _eyeMood = EyeMood.idle);
  }

  // DragTarget's onAccept fires WHILE Flutter's mouse tracker is still
  // mid-way through processing the pointer-up event that ended the drag.
  // Mutating the tree synchronously in there (in particular removing the
  // dropped Draggable from _tray, which un-mounts its MouseRegion) trips
  // the framework's own "!_debugDuringDeviceUpdate" assertion in
  // mouse_tracker.dart — a known Flutter DragTarget footgun, not a bug in
  // this exercise's logic. Fix: push every state mutation triggered by a
  // drop to the frame AFTER the current one via addPostFrameCallback, so
  // it runs once the mouse tracker's device update pass has finished.
  void _handleDrop(String targetLine, _IncomeItem item) {
    if (item.line != targetLine) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _flashWrongLine = targetLine);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          setState(() => _flashWrongLine = null);
        });
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _completeDrop(targetLine, item);
    });
  }

  void _completeDrop(String targetLine, _IncomeItem item) {
    setState(() {
      _placed[targetLine] = item;
      _tray.remove(item);
      if (item.taxable) _runningTotal += item.amt;
    });

    _typeConsole(item.note);

    if (_placed.length == _kIncomeItems.length) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() => _done = true);
      });
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
            ),
            child: Row(
              children: [
                Text(
                  'Tax',
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
                  'Starter:',
                  style: TextStyle(
                    fontSize: AppFonts.header,
                    fontWeight: FontWeight.w600,
                    color: AppColors.bodyText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackLink() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () => Navigator.pop(context),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          '‹ Back to 1040 Basics',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryButton,
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final total = _kIncomeItems.length;
    final matched = _placed.length;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : matched / total,
              minHeight: 8,
              backgroundColor: const Color(0xFFD6D6D6),
              valueColor: const AlwaysStoppedAnimation<Color>(_accent),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$matched / $total',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _accent,
          ),
        ),
      ],
    );
  }

  Widget _buildDottedLine() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, 1),
              painter: _DottedLinePainter(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSlot(_FormLineSpec spec) {
    if (spec.computed) {
      final value = spec.rowLabel == '1z'
          ? (_placed['1a']?.amt ?? 0)
          : _runningTotal;
      return Container(
        width: 92,
        height: 26,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9D6),
          border: Border.all(color: _highlightBorder, width: 1.5),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          '\$${_fmt(value)}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: _correct,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    final line = spec.dataLine!;
    final placedItem = _placed[line];
    final isWrong = _flashWrongLine == line;

    return DragTarget<_IncomeItem>(
      onWillAcceptWithDetails: (details) => placedItem == null,
      onAcceptWithDetails: (details) => _handleDrop(line, details.data),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty && placedItem == null;
        Color bg = const Color(0xFFF3F3F3);
        Color border = const Color(0xFFB7BCC7);
        if (placedItem != null) {
          bg = _correctBg;
          border = _correct;
        } else if (isWrong) {
          bg = _wrongBg;
          border = _wrong;
        } else if (hovering) {
          border = _accent;
        }
        return Container(
          width: 92,
          height: 26,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: hovering ? 2 : 1.5),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            placedItem != null ? '\$${_fmt(placedItem.amt)}' : '?',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: placedItem != null ? _correct : const Color(0xFF999999),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }

  Widget _buildFormLineRow(_FormLineSpec spec) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      decoration: BoxDecoration(
        color: spec.computed ? _highlight : null,
        border: const Border(
          bottom: BorderSide(color: Color(0xFF7A8A83), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              spec.letter,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              spec.desc,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: spec.computed ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          _buildDottedLine(),
          Container(
            width: 26,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 1),
            decoration: BoxDecoration(
              color: _paper,
              border: Border.all(
                color: spec.computed ? _highlightBorder : Colors.black87,
              ),
            ),
            child: Text(
              spec.rowLabel,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10.5,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _buildSlot(spec),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      decoration: BoxDecoration(
        color: _paper,
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.black, width: 1.5),
              ),
            ),
            child: const Text(
              'Income',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          // NOTE: deliberately NOT wrapped in IntrinsicHeight (it was
          // originally, to make the sidebar stretch to match the table's
          // height) — IntrinsicHeight forces every descendant to support
          // intrinsic-dimension sizing, and _buildDottedLine() below uses
          // a LayoutBuilder, which explicitly does not support that and
          // throws on every layout pass. That was producing a blank
          // screen with the layout exception (plus a cascading
          // mouse_tracker assertion once the render tree never
          // successfully completed a frame). CrossAxisAlignment.stretch
          // on the Row alone still stretches the sidebar to the table's
          // real height via normal two-pass flex layout — no intrinsic
          // query involved, so LayoutBuilder underneath is safe again.
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 82,
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.black, width: 1.5),
                  ),
                ),
                child: const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Attach Form(s) W-2 here.\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            'Also attach Forms W-2G and 1099-R if tax '
                            'was withheld.',
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: 9.5, height: 1.3),
                ),
              ),
              Expanded(
                child: Column(
                  children: _kFormLines.map(_buildFormLineRow).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrayCard(_IncomeItem item) {
    final card = Container(
      constraints: const BoxConstraints(minWidth: 148, maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _fillBorder, width: 1.5),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.desc,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '\$${_fmt(item.amt)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _accent,
            ),
          ),
        ],
      ),
    );

    return Draggable<_IncomeItem>(
      data: item,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 180, child: card),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: card,
    );
  }

  Widget _buildTray() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE4E4E4),
        borderRadius: BorderRadius.circular(12),
      ),
      constraints: const BoxConstraints(minHeight: 56),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _tray.map(_buildTrayCard).toList(),
      ),
    );
  }

  Widget _buildConsole() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1D22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: FsmeEyePair(
              key: _eyeKey,
              mood: _eyeMood,
              size: 18,
              spacing: 6,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _consoleText,
              style: const TextStyle(
                color: Color(0xFFF0C14B),
                fontStyle: FontStyle.italic,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonePanel() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: _correctBg,
        border: Border.all(color: _correct, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Income section complete',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D5C31),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Total income (Line 9) comes to \$${_fmt(_runningTotal)} — the '
            '\$200 in tax-exempt municipal bond interest on Line 2a '
            'correctly never made it into that total.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF2B2F38)),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: _init,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryButton,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSizes.buttonCornerRadius,
                    ),
                  ),
                ),
                child: const Text('Play again'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryButton,
                  side: BorderSide(color: AppColors.primaryButton),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSizes.buttonCornerRadius,
                    ),
                  ),
                ),
                child: const Text('Back to 1040 Basics'),
              ),
            ],
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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: AppSizes.pageMargin,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    _buildHeader(),
                    _buildBackLink(),
                    Text(
                      'Section 2 of 6 · Income',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.strongText,
                      ),
                    ),
                    Text(
                      'Drag each item onto the line it belongs on',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppFonts.header,
                        fontWeight: FontWeight.bold,
                        color: AppColors.strongText,
                      ),
                    ),
                    Text(
                      'Read what it is, then drop it in the right spot on '
                      'the actual form.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.bodyText),
                    ),
                    _buildProgress(),
                    _buildForm(),
                    Text(
                      'DRAG FROM HERE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: AppColors.subtleText,
                      ),
                    ),
                    _buildTray(),
                    _buildConsole(),
                    if (_done) _buildDonePanel(),
                  ],
                ),
              ),
            ),
            const SafePrepNavBar(),
          ],
        ),
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x88555555)
      ..strokeWidth = 1;
    const dashWidth = 2.0;
    const dashSpace = 2.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + dashWidth, size.height),
        paint,
      );
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLinePainter oldDelegate) => false;
}
