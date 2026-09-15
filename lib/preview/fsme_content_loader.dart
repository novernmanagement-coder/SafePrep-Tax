import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../fsme_popup.dart';

/// ─────────────────────────────────────────────────────────────────────
/// FSME content loader — fetches the three remote CSVs (events registry,
/// opener pool, and line content) and assembles a ready-to-use
/// `List<FsmeLine>` for [FsmePopup].
///
/// Mirrors the existing `csv_loader.dart` pattern (remote-hosted CSVs,
/// same base-URL convention) so this content can be edited through the
/// WordPress CMS and updated without an app release — the same way
/// ServSafeCurriculum.csv already works.
///
/// ── Files ────────────────────────────────────────────────────────────
/// - fsme_events.csv   — registry: event_id, set, subset, location,
///   description, date_added. Metadata only; not needed at runtime to
///   render a popup, but keeps a single source of truth for what
///   exists and where. Useful for an admin/CMS listing view.
/// - fsme_openers.csv  — opener_id, msg_type, text. msg_type is one of
///   Hedge / EGO / Help. A blank text row is intentional (some pulls
///   should skip the opener entirely so the hedge itself never becomes
///   a tell).
/// - fsme_lines.csv     — event_id, line_order, audience, flash, text.
///   The actual per-event script content, ordered.
///
/// ── Tokens ───────────────────────────────────────────────────────────
/// Some lines contain runtime-computed values that can't live in a
/// CMS-edited CSV as fixed text (a confidence percentage, the study
/// mode they picked, etc.). Those lines carry a `{TOKEN}` placeholder;
/// pass the resolved values in [tokens] and they're substituted before
/// the line is returned. Known tokens in the current content:
/// MODE_LABEL, CONFIDENCE_REACTION, CONFIDENCE_INDEX, KNOWLEDGE_PCT,
/// ASSESSMENT, RECOMMENDATION.
class FsmeContentLoader {
  FsmeContentLoader._();
  static final FsmeContentLoader instance = FsmeContentLoader._();

  /// Base URL for the hosted CSVs. Point this at wherever the CMS ends
  /// up serving them (same host/pattern as the question-bank CSVs).
  /// TODO(Gerry): replace with the real CMS path once it's live.
  static const String _baseUrl =
      'https://foodsafetymadeeasy.com/wp-content/uploads/fsme-content/';

  List<_EventRow>? _events;
  List<_OpenerRow>? _openers;
  Map<String, List<FsmeLine>>? _linesByEvent;

  bool get _loaded =>
      _events != null && _openers != null && _linesByEvent != null;

  /// Fetches and parses all three CSVs. Call once (e.g. app startup or
  /// first popup use); subsequent calls are no-ops unless [force] is
  /// true. Safe to call redundantly — cheap check, not a re-fetch.
  Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;

    final results = await Future.wait([
      _fetchCsv('fsme_events.csv'),
      _fetchCsv('fsme_openers.csv'),
      _fetchCsv('fsme_lines.csv'),
    ]);

    _events = results[0].skip(1).map(_EventRow.fromRow).toList();
    _openers = results[1].skip(1).map(_OpenerRow.fromRow).toList();

    final lines = <String, List<FsmeLine>>{};
    for (final row in results[2].skip(1)) {
      if (row.length < 5) continue;
      final eventId = row[0].trim();
      final audience = _audienceFrom(row[2].trim());
      final flash = row[3].trim().toLowerCase() == 'true';
      final text = row[4];
      lines
          .putIfAbsent(eventId, () => [])
          .add(FsmeLine(text, audience: audience, flash: flash));
    }
    _linesByEvent = lines;
  }

  /// Builds the popup script for [eventId]: an optional randomized
  /// opener of [openerType] (pass null to skip the opener entirely),
  /// followed by that event's lines with any `{TOKEN}` placeholders
  /// resolved from [tokens].
  ///
  /// Throws a [StateError] if [load] hasn't been called yet, and
  /// returns an empty list (rather than throwing) if [eventId] isn't
  /// found — a missing/mistyped event shouldn't crash a screen, just
  /// silently show nothing.
  List<FsmeLine> buildScript(
    String eventId, {
    String? openerType = 'Hedge',
    Map<String, String> tokens = const {},
  }) {
    if (!_loaded) {
      throw StateError(
        'FsmeContentLoader.load() must complete before buildScript() '
        'is called.',
      );
    }

    final script = <FsmeLine>[];

    if (openerType != null) {
      final opener = _randomOpener(openerType);
      if (opener != null && opener.text.isNotEmpty) {
        script.add(FsmeLine(opener.text));
      }
    }

    final eventLines = _linesByEvent![eventId] ?? const [];
    for (final line in eventLines) {
      script.add(
        FsmeLine(
          _resolveTokens(line.text, tokens),
          audience: line.audience,
          flash: line.flash,
        ),
      );
    }

    return script;
  }

  /// All registered events for a given set/subset — e.g. every MAIN APP
  /// trainer popup — for building an admin listing or picking a random
  /// one to rotate through.
  List<String> eventIdsFor({required String set, String? subset}) {
    if (!_loaded) return const [];
    return _events!
        .where(
          (e) =>
              e.set.toUpperCase() == set.toUpperCase() &&
              (subset == null ||
                  e.subset.toUpperCase() == subset.toUpperCase()),
        )
        .map((e) => e.eventId)
        .toList();
  }

  _OpenerRow? _randomOpener(String msgType) {
    final pool = _openers!
        .where((o) => o.msgType.toLowerCase() == msgType.toLowerCase())
        .toList();
    if (pool.isEmpty) return null;
    return pool[math.Random().nextInt(pool.length)];
  }

  String _resolveTokens(String text, Map<String, String> tokens) {
    var result = text;
    for (final entry in tokens.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }

  FsmeAudience _audienceFrom(String raw) {
    switch (raw.toLowerCase()) {
      case 'boss':
        return FsmeAudience.boss;
      case 'self':
        return FsmeAudience.self;
      case 'processing':
        return FsmeAudience.processing;
      // 'normal' / 'verdict' / 'call' map to user for now — those are
      // this-specific-screen render rules (band color, red call line)
      // that the shared FsmePopup widget doesn't special-case. Screens
      // needing that distinction (readiness, diagnostic Q1) should
      // keep their own custom rendering rather than FsmePopup, or this
      // loader can be extended with a wider enum if that changes.
      case 'user':
      case 'normal':
      case 'verdict':
      case 'call':
      default:
        return FsmeAudience.user;
    }
  }

  Future<List<List<String>>> _fetchCsv(String filename) async {
    final response = await http.get(Uri.parse('$_baseUrl$filename'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load $filename: ${response.statusCode}');
    }
    return _parseCsv(response.body);
  }

  /// Minimal CSV parser handling quoted fields (with escaped "" for a
  /// literal quote) and commas inside quotes. No external dependency —
  /// the content here doesn't need anything fancier.
  List<List<String>> _parseCsv(String raw) {
    final rows = <List<String>>[];
    final lines = raw.split(RegExp(r'\r\n|\r|\n'));

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final row = <String>[];
      final buffer = StringBuffer();
      bool inQuotes = false;

      for (var i = 0; i < line.length; i++) {
        final char = line[i];
        if (inQuotes) {
          if (char == '"') {
            if (i + 1 < line.length && line[i + 1] == '"') {
              buffer.write('"');
              i++;
            } else {
              inQuotes = false;
            }
          } else {
            buffer.write(char);
          }
        } else {
          if (char == '"') {
            inQuotes = true;
          } else if (char == ',') {
            row.add(buffer.toString());
            buffer.clear();
          } else {
            buffer.write(char);
          }
        }
      }
      row.add(buffer.toString());
      rows.add(row);
    }
    return rows;
  }
}

class _EventRow {
  final String eventId;
  final String set;
  final String subset;
  final String location;
  final String description;
  final String dateAdded;

  _EventRow({
    required this.eventId,
    required this.set,
    required this.subset,
    required this.location,
    required this.description,
    required this.dateAdded,
  });

  factory _EventRow.fromRow(List<String> row) {
    return _EventRow(
      eventId: row.isNotEmpty ? row[0].trim() : '',
      set: row.length > 1 ? row[1].trim() : '',
      subset: row.length > 2 ? row[2].trim() : '',
      location: row.length > 3 ? row[3].trim() : '',
      description: row.length > 4 ? row[4].trim() : '',
      dateAdded: row.length > 5 ? row[5].trim() : '',
    );
  }
}

class _OpenerRow {
  final String openerId;
  final String msgType;
  final String text;

  _OpenerRow({
    required this.openerId,
    required this.msgType,
    required this.text,
  });

  factory _OpenerRow.fromRow(List<String> row) {
    return _OpenerRow(
      openerId: row.isNotEmpty ? row[0].trim() : '',
      msgType: row.length > 1 ? row[1].trim() : '',
      text: row.length > 2 ? row[2] : '',
    );
  }
}
