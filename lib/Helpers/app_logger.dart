import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

enum LogMode { printOnly, loggerOnly, crashlyticsOnly, loggerAndCrashlytics }

enum LogType { log, warn, error }

class AppLogger {
  static LogMode mode = LogMode.loggerAndCrashlytics;

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 3, // Increased method count to show more of the call stack
      errorMethodCount: 5, // Increased error method count for error logging
      lineLength: 80,
      colors: true,
      printEmojis: true,
      printTime: false,
    ),
  );

  static void log(
    String message, {
    LogType type = LogType.log,
    dynamic error, // Optional error object (e.g., Exception)
    StackTrace? stackTrace, // Optional explicit stack trace
  }) {
    // If no stack trace is provided, create a dummy one for non-error types
    // This allows logger to format the stack trace unless it's an ERROR,
    // where we rely on the specific error log below.
    final trace =
        stackTrace ?? (type == LogType.error ? StackTrace.current : null);

    // Crashlytics does not take a stackTrace for general logs, but it does for reports.
    // For general logs, we just pass the message.
    if (kReleaseMode &&
        (mode == LogMode.crashlyticsOnly ||
            mode == LogMode.loggerAndCrashlytics)) {
      if (type == LogType.error && error != null) {
        // For errors, use the full report for crashlytics
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: message,
          fatal:
              false, // Use fatal:true if this represents an unrecoverable app crash
        );
      } else {
        // For general logs and warnings
        FirebaseCrashlytics.instance.log(message);
      }
    }

    switch (mode) {
      case LogMode.printOnly:
        if (!kReleaseMode) _printLog(message, type, trace);
        break;

      case LogMode.loggerOnly:
      case LogMode.loggerAndCrashlytics: // Logger is always used here
        _logWithLogger(message, type, error, trace);
        break;

      case LogMode.crashlyticsOnly:
        // Logging handled above for Crashlytics. Use print for debug mode fallbacks.
        if (!kReleaseMode) _printLog(message, type, trace);
        break;
    }
  }

  static void _printLog(String message, LogType type, StackTrace? stackTrace) {
    // Simple print doesn't automatically format the stack trace nicely,
    // but we can include it.
    final prefix = switch (type) {
      LogType.log => 'LOG',
      LogType.warn => 'WARN',
      LogType.error => 'ERROR',
    };
    print('$prefix: $message');
    if (stackTrace != null) {
      print('STACK TRACE: \n$stackTrace');
    }
  }

  static void _logWithLogger(
    String message,
    LogType type,
    dynamic error,
    StackTrace? stackTrace,
  ) {
    // The logger package takes the optional error object and stack trace
    switch (type) {
      case LogType.log:
        _logger.i(message, error: error, stackTrace: stackTrace);
        break;
      case LogType.warn:
        _logger.w(message, error: error, stackTrace: stackTrace);
        break;
      case LogType.error:
        // For errors, we generally pass both error and stackTrace if available
        _logger.e(message, error: error, stackTrace: stackTrace);
        break;
    }
  }
}
