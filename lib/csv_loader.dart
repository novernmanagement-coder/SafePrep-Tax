import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'app_state.dart';

// ─────────────────────────────────────────────────────────────────
// REMOTE CSV CONFIG
// ─────────────────────────────────────────────────────────────────
const String _baseUrl =
    'https://raw.githubusercontent.com/novernmanagement-coder/SafePrep_Content/main';

const String _versionUrl = '$_baseUrl/version.json';

const List<String> _remoteFiles = [
  'FinalTestQuestions5.csv',
  'MarqueeFacts.csv',
  'ServSafeCurriculum.csv',
  'ServSafeMilestones.csv',
  'ServSafeProTips.csv',
  'ScenarioDrills.csv',
];

// Every SafePrep sibling app (Manager, Alcohol, Español, Refresher) is
// built from this same shared codebase and downloads the exact same
// filenames via the exact same getApplicationDocumentsDirectory() call
// below. On Android/iOS that's harmless — each app's documents
// directory is sandboxed per package/bundle ID by the OS. On Windows
// desktop it is NOT sandboxed at all: getApplicationDocumentsDirectory()
// there just resolves to the real Windows "Documents" folder, shared
// by every app running under that Windows user account. Running two
// sibling apps' Windows builds on the same dev machine — even at
// different times — makes them silently overwrite each other's cached
// CSVs and csv_version.json, with no error and no signal that it
// happened (this is exactly how English SafePrep Manager ended up
// showing Spanish ServSafeCurriculum.csv content after Español had
// been run on the same PC — confirmed Aug 2026). Namespacing under a
// per-app subfolder isolates each sibling app's cache even on Windows.
//
// Each SafePrep app's copy of this file should set its own value here
// — same pattern as MixpanelService._appPrefix:
//   SafePrep Manager   → 'SafePrepManager'
//   SafePrep Alcohol    → 'SafePrepAlcohol'
//   SafePrep Español    → 'SafePrepEspanol'
//   SafePrep Refresher  → 'SafePrepRefresher'
//   SafePrep Tax        → 'SafePrepTax'
const String _contentSubfolder = 'SafePrepTax';

Future<Directory> _contentDir() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/$_contentSubfolder');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

// ─────────────────────────────────────────────────────────────────
// CSV UPDATER
// ─────────────────────────────────────────────────────────────────
class CsvUpdater {
  static Future<void> syncIfNeeded() async {
    try {
      final response = await http
          .get(Uri.parse(_versionUrl))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) return;

      final remoteVersion = jsonDecode(response.body) as Map<String, dynamic>;
      final localVersion = await _loadLocalVersion();

      for (final file in _remoteFiles) {
        final remoteVer = remoteVersion[file]?.toString() ?? '0';
        final localVer = localVersion[file]?.toString() ?? '0';

        if (remoteVer != localVer) {
          final success = await _downloadFile(file);
          if (success) localVersion[file] = remoteVer;
        }
      }

      await _saveLocalVersion(localVersion);
    } catch (e) {
      debugPrint('CSV sync skipped: $e');
    }
  }

  static Future<bool> _downloadFile(String fileName) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/$fileName'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return false;

      final dir = await _contentDir();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(response.body, encoding: utf8);
      debugPrint('CSV updated: $fileName');
      return true;
    } catch (e) {
      debugPrint('CSV download failed ($fileName): $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> _loadLocalVersion() async {
    try {
      final dir = await _contentDir();
      final file = File('${dir.path}/csv_version.json');
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveLocalVersion(Map<String, dynamic> version) async {
    try {
      final dir = await _contentDir();
      final file = File('${dir.path}/csv_version.json');
      await file.writeAsString(jsonEncode(version));
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────
// CSV READER
// ─────────────────────────────────────────────────────────────────
Future<List<String>> readCsvLines(String fileName) async {
  try {
    final dir = await _contentDir();
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) {
      final content = await file.readAsString(encoding: utf8);
      return content
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    }
  } catch (_) {}

  return _readAssetLines(fileName);
}

Future<List<String>> _readAssetLines(String fileName) async {
  final raw = await rootBundle.loadString('Assets/$fileName');
  return raw
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
}

// ─────────────────────────────────────────────────────────────────
// CSV HELPER
// ─────────────────────────────────────────────────────────────────
List<String> splitCsvLine(String line) {
  final result = <String>[];
  final sb = StringBuffer();
  bool inQuotes = false;

  for (int i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      inQuotes = !inQuotes;
    } else if (c == ',' && !inQuotes) {
      result.add(sb.toString().trim());
      sb.clear();
    } else {
      sb.write(c);
    }
  }
  result.add(sb.toString().trim());
  return result;
}

Future<List<String>> readAssetLines(String fileName) => readCsvLines(fileName);

// ─────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────
class QuestionModel {
  final String id;
  final String dot;
  final String questionText;
  final String answer1;
  final String answer2;
  final String answer3;
  final String answer4;
  final int correctAnswer;
  final String category;
  final String subcategory;
  final String explanation;
  final int mustInclude;
  final int difficulty;

  QuestionModel({
    required this.id,
    required this.dot,
    required this.questionText,
    required this.answer1,
    required this.answer2,
    required this.answer3,
    required this.answer4,
    required this.correctAnswer,
    required this.category,
    required this.subcategory,
    required this.explanation,
    required this.mustInclude,
    required this.difficulty,
  });
}

class FactModel {
  final String id;
  final String category;
  final String fact;
  FactModel({required this.id, required this.category, required this.fact});
}

class CurriculumModel {
  final int id;
  final String category;
  final String subcategory;
  final String difficulty;
  final String mode;
  final int orderIndex;
  final String conceptTitle;
  final String content;
  final String keyPoints;

  CurriculumModel({
    required this.id,
    required this.category,
    required this.subcategory,
    required this.difficulty,
    required this.mode,
    required this.orderIndex,
    required this.conceptTitle,
    required this.content,
    required this.keyPoints,
  });
}

class MilestoneModel {
  final int id;
  final String type;
  final String trigger;
  final int threshold;
  final String category;
  final String title;
  final String emoTone;
  final String icon;
  final String message;
  final bool elite;

  MilestoneModel({
    required this.id,
    required this.type,
    required this.trigger,
    required this.threshold,
    required this.category,
    required this.title,
    required this.emoTone,
    required this.icon,
    required this.message,
    required this.elite,
  });
}

class ProTipModel {
  final String id;
  final String type;
  final String category;
  final String content;
  final bool mustHave;

  ProTipModel({
    required this.id,
    required this.type,
    required this.category,
    required this.content,
    required this.mustHave,
  });
}

class ScenarioDrillModel {
  final String id;
  final String category;
  final int difficulty;
  final String servSafeVersion;
  final String scenario;
  final String choice1;
  final String choice2;
  final String choice3;
  final int correctChoice;
  final String explanation;

  ScenarioDrillModel({
    required this.id,
    required this.category,
    required this.difficulty,
    required this.servSafeVersion,
    required this.scenario,
    required this.choice1,
    required this.choice2,
    required this.choice3,
    required this.correctChoice,
    required this.explanation,
  });
}

// ─────────────────────────────────────────────────────────────────
// QUESTION LOADER
// ─────────────────────────────────────────────────────────────────
class QuestionLoader {
  static Future<List<QuestionModel>> loadAll({bool shuffle = true}) async {
    final lines = await readCsvLines('FinalTestQuestions5.csv');
    final questions = <QuestionModel>[];

    for (int i = 1; i < lines.length; i++) {
      final parts = splitCsvLine(lines[i]);
      if (parts.length < 13) continue;

      int correctAnswer = 0;
      final parsed = int.tryParse(parts[7]);
      if (parsed != null && parsed >= 1 && parsed <= 4) {
        correctAnswer = parsed - 1;
      }

      final mustInclude = int.tryParse(parts[11]) ?? 0;
      final difficulty = (int.tryParse(parts[12]) ?? 2).clamp(1, 3);

      questions.add(
        QuestionModel(
          id: parts[0],
          dot: parts[1],
          questionText: parts[2],
          answer1: parts[3],
          answer2: parts[4],
          answer3: parts[5],
          answer4: parts[6],
          correctAnswer: correctAnswer,
          category: _normalizeCategory(parts[8]),
          subcategory: parts[9],
          explanation: parts[10],
          mustInclude: mustInclude,
          difficulty: difficulty,
        ),
      );
    }

    if (shuffle) questions.shuffle();
    return questions;
  }

  static Future<List<QuestionModel>> loadByCategory(
    String category, {
    bool shuffle = true,
  }) async {
    final all = await loadAll(shuffle: false);
    final filtered = all
        .where((q) => q.category.toLowerCase() == category.toLowerCase())
        .toList();
    if (shuffle) filtered.shuffle();
    return filtered;
  }

  static String _normalizeCategory(String category) {
    if (category.toLowerCase() == 'pest management') {
      return 'Food Safety Management';
    }
    return category;
  }
}

// ─────────────────────────────────────────────────────────────────
// FACT LOADER
// ─────────────────────────────────────────────────────────────────
class FactLoader {
  static Future<List<FactModel>> loadAll({bool shuffle = true}) async {
    final lines = await readCsvLines('MarqueeFacts.csv');
    final facts = <FactModel>[];

    for (int i = 1; i < lines.length; i++) {
      final parts = splitCsvLine(lines[i]);
      if (parts.length != 3) continue;
      facts.add(FactModel(id: parts[0], category: parts[1], fact: parts[2]));
    }

    if (shuffle) facts.shuffle();
    return facts;
  }

  static Future<List<FactModel>> loadByCategory(
    String category, {
    bool shuffle = true,
  }) async {
    final all = await loadAll(shuffle: false);
    final filtered = all
        .where((f) => f.category.toLowerCase() == category.toLowerCase())
        .toList();
    if (shuffle) filtered.shuffle();
    return filtered;
  }
}

// ─────────────────────────────────────────────────────────────────
// MILESTONE LOADER
// ─────────────────────────────────────────────────────────────────
class MilestoneLoader {
  static Future<List<MilestoneModel>> loadAll() async {
    final lines = await readCsvLines('ServSafeMilestones.csv');
    final milestones = <MilestoneModel>[];

    for (int i = 1; i < lines.length; i++) {
      final parts = splitCsvLine(lines[i]);
      if (parts.length < 9) continue;

      final id = int.tryParse(parts[0]);
      if (id == null) continue;

      final threshold = int.tryParse(parts[3]) ?? 0;
      final elite = parts.length >= 10 && parts[9].trim() == '1';

      milestones.add(
        MilestoneModel(
          id: id,
          type: parts[1],
          trigger: parts[2],
          threshold: threshold,
          category: parts[4],
          title: parts[5],
          emoTone: parts[6],
          icon: parts[7],
          message: parts[8],
          elite: elite,
        ),
      );
    }

    return milestones;
  }
}

// ─────────────────────────────────────────────────────────────────
// CURRICULUM LOADER
// ─────────────────────────────────────────────────────────────────
class CurriculumLoader {
  static Future<List<CurriculumModel>> loadAll() async {
    final lines = await readCsvLines('ServSafeCurriculum.csv');
    final concepts = <CurriculumModel>[];

    for (int i = 1; i < lines.length; i++) {
      final parts = splitCsvLine(lines[i]);
      if (parts.length < 8) continue;

      final id = int.tryParse(parts[0]);
      if (id == null) continue;

      concepts.add(
        CurriculumModel(
          id: id,
          category: parts[1],
          subcategory: parts[2],
          difficulty: parts[3],
          mode: parts[4],
          orderIndex: int.tryParse(parts[5]) ?? 0,
          conceptTitle: parts[6],
          content: parts[7],
          keyPoints: parts.length > 8 ? parts[8] : '',
        ),
      );
    }

    return concepts;
  }

  static Future<List<CurriculumModel>> loadByCategory(
    String category,
    String mode,
  ) async {
    final all = await loadAll();
    return all
        .where(
          (c) =>
              c.category.toLowerCase() == category.toLowerCase() &&
              c.mode.toLowerCase() == mode.toLowerCase(),
        )
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }
}

// ─────────────────────────────────────────────────────────────────
// PRO TIP LOADER
// ─────────────────────────────────────────────────────────────────
class ProTipLoader {
  static Future<List<ProTipModel>> loadAll({bool shuffle = false}) async {
    final lines = await readCsvLines('ServSafeProTips.csv');
    final tips = <ProTipModel>[];

    for (int i = 1; i < lines.length; i++) {
      final parts = splitCsvLine(lines[i]);
      if (parts.length < 5) continue;

      tips.add(
        ProTipModel(
          id: parts[0],
          type: parts[1],
          category: parts[2],
          content: parts[3],
          mustHave: parts[4] == '1',
        ),
      );
    }

    if (shuffle) tips.shuffle();
    return tips;
  }

  static Future<List<ProTipModel>> loadPersonalized() async {
    final all = await loadAll(shuffle: false);
    final state = AppState();

    final weakCategories = AppState.allCategories
        .where(
          (c) =>
              state.hasScoreForCategory(c) &&
              state.getCategoryScore(c) < AppState.masteryThreshold,
        )
        .map((c) => c.toLowerCase())
        .toSet();

    if (weakCategories.isEmpty) return all..shuffle();

    final mustHave = all.where((t) => t.mustHave).toList()..shuffle();
    final weakTips =
        all
            .where(
              (t) =>
                  !t.mustHave &&
                  weakCategories.contains(t.category.toLowerCase()),
            )
            .toList()
          ..shuffle();
    final rest =
        all
            .where(
              (t) =>
                  !t.mustHave &&
                  !weakCategories.contains(t.category.toLowerCase()),
            )
            .toList()
          ..shuffle();

    return [...mustHave, ...weakTips, ...rest];
  }
}

// ─────────────────────────────────────────────────────────────────
// SCENARIO DRILL LOADER
// ─────────────────────────────────────────────────────────────────
class ScenarioDrillLoader {
  static const String currentVersion = '8';

  static Future<List<ScenarioDrillModel>> loadAll() async {
    final lines = await readCsvLines('ScenarioDrills.csv');
    final drills = <ScenarioDrillModel>[];

    for (int i = 1; i < lines.length; i++) {
      final parts = splitCsvLine(lines[i]);
      if (parts.length < 10) continue;

      final correct = int.tryParse(parts[8]) ?? 1;

      drills.add(
        ScenarioDrillModel(
          id: parts[0],
          category: parts[1],
          difficulty: int.tryParse(parts[2]) ?? 2,
          servSafeVersion: parts[3],
          scenario: parts[4],
          choice1: parts[5],
          choice2: parts[6],
          choice3: parts[7],
          correctChoice: correct.clamp(1, 3),
          explanation: parts[9],
        ),
      );
    }

    return drills;
  }
}

// ─────────────────────────────────────────────────────────────────
// QUESTION SHUFFLE
// ─────────────────────────────────────────────────────────────────
extension QuestionShuffleX on QuestionModel {
  QuestionModel shuffled() {
    final answers = [answer1, answer2, answer3, answer4];
    final indices = [0, 1, 2, 3]..shuffle();
    final newCorrect = indices.indexOf(correctAnswer);

    return QuestionModel(
      id: id,
      dot: dot,
      questionText: questionText,
      answer1: answers[indices[0]],
      answer2: answers[indices[1]],
      answer3: answers[indices[2]],
      answer4: answers[indices[3]],
      correctAnswer: newCorrect,
      category: category,
      subcategory: subcategory,
      explanation: explanation,
      mustInclude: mustInclude,
      difficulty: difficulty,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SCORING ENGINE
// ─────────────────────────────────────────────────────────────────
class ScoringEngine {
  static TestResult processResults(
    List<QuestionModel> questions,
    List<int> selectedAnswers,
    TestType type,
  ) {
    int totalCorrect = 0;
    final categoryTotal = <String, int>{};
    final categoryCorrect = <String, int>{};
    final missedIds = <String>[];

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final category = q.category;

      categoryTotal[category] = (categoryTotal[category] ?? 0) + 1;
      categoryCorrect.putIfAbsent(category, () => 0);

      final isCorrect =
          i < selectedAnswers.length && selectedAnswers[i] == q.correctAnswer;

      if (isCorrect) {
        totalCorrect++;
        categoryCorrect[category] = categoryCorrect[category]! + 1;
      } else {
        missedIds.add(q.id);
      }
    }

    final overallScore = questions.isEmpty
        ? 0
        : (totalCorrect * 100) ~/ questions.length;

    final categoryScores = <String, int>{};
    for (final cat in categoryTotal.keys) {
      final total = categoryTotal[cat]!;
      final correct = categoryCorrect[cat] ?? 0;
      categoryScores[cat] = total == 0 ? 0 : (correct * 100) ~/ total;
    }

    return TestResult(
      timestamp: DateTime.now(),
      type: type,
      overallScore: overallScore,
      categoryScores: categoryScores,
      missedQuestionIds: missedIds,
    );
  }
}
