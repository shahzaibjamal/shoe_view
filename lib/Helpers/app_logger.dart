import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

enum LogMode {
  printOnly,
  loggerOnly,
  crashlyticsOnly,
  loggerAndCrashlytics,
}

enum LogType {
  log,
  warn,
  error,
}

class AppLogger {
  static LogMode mode = LogMode.loggerAndCrashlytics;

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 3,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      printTime: false,
    ),
  );

  static void log(String message, {LogType type = LogType.log}) {
    switch (mode) {
      case LogMode.printOnly:
        if (!kReleaseMode) _printLog(message, type);
        break;

      case LogMode.loggerOnly:
        _logWithLogger(message, type);
        break;

      case LogMode.crashlyticsOnly:
        if (kReleaseMode) {
          FirebaseCrashlytics.instance.log(message);
        } else {
          _printLog(message, type);
        }
        break;

      case LogMode.loggerAndCrashlytics:
        _logWithLogger(message, type);
        if (kReleaseMode) {
          FirebaseCrashlytics.instance.log(message);
        }
        break;
    }
  }

  static void _printLog(String message, LogType type) {
    switch (type) {
      case LogType.log:
        print('LOG: $message');
        break;
      case LogType.warn:
        print('WARN: $message');
        break;
      case LogType.error:
        print('ERROR: $message');
        break;
    }
  }

  static void _logWithLogger(String message, LogType type) {
    switch (type) {
      case LogType.log:
        _logger.i(message);
        break;
      case LogType.warn:
        _logger.w(message);
        break;
      case LogType.error:
        _logger.e(message);
        break;
    }
  }
}
