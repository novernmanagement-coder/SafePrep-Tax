// Web (and any other non-dart:io) platform stub for the local CSV
// cache — see csv_cache_io.dart for the real implementation and
// csv_loader.dart for the conditional import that picks between them.
//
// There is no meaningful local filesystem on web, so every operation
// here is a no-op / returns null. Callers already treat "nothing
// cached yet" as a normal, expected outcome and fall back to the
// bundled asset (see readCsvLines() in csv_loader.dart) — this keeps
// the web build compiling and behaving exactly like a fresh install
// with nothing cached, every launch. (Remote CSV updates still get
// fetched over the network via CsvUpdater.syncIfNeeded() same as
// mobile; on web they just aren't persisted between sessions yet —
// fine for now, revisit if the web edition needs that later.)

Future<String?> readCachedContent(String subfolder, String fileName) async =>
    null;

Future<void> writeCachedContent(
  String subfolder,
  String fileName,
  String content,
) async {}
