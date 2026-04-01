import 'package:flutter/foundation.dart';

/// A thin, level-aware logger.
///
/// In debug mode all levels are emitted via [debugPrint].
/// In release/profile mode only [warning] and [error] are emitted,
/// keeping the production log clean while still surfacing real problems.
abstract final class AppLogger {
  // ─── Public API ────────────────────────────────────────────────

  /// Fine-grained diagnostic information. Silent in production.
  static void debug(String tag, String message) {
    if (kDebugMode) _emit('DEBUG', tag, message);
  }

  /// Normal operational events. Silent in production.
  static void info(String tag, String message) {
    if (kDebugMode) _emit('INFO', tag, message);
  }

  /// Unexpected situations that are recoverable. Always emitted.
  static void warning(String tag, String message) {
    _emit('WARN', tag, message);
  }

  /// Unrecoverable errors that the user may notice. Always emitted.
  static void error(String tag, String message, [Object? exception]) {
    _emit('ERROR', tag, message);
    if (exception != null) {
      debugPrint('[ERROR][$tag] ↳ $exception');
    }
  }

  // ─── Internal ──────────────────────────────────────────────────

  static void _emit(String level, String tag, String message) {
    debugPrint('[$level][$tag] $message');
  }
}
