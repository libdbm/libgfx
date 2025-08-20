/// Logger interface for libgfx
abstract class LibgfxLogger {
  void debug(String message);

  void info(String message);

  void warning(String message);

  void error(String message, [Object? error, StackTrace? stackTrace]);
}

/// Default console logger implementation
class ConsoleLogger implements LibgfxLogger {
  final bool enableDebug;

  const ConsoleLogger({this.enableDebug = false});

  @override
  void debug(String message) {
    if (enableDebug) {
      print('[DEBUG] $message');
    }
  }

  @override
  void info(String message) {
    print('[INFO] $message');
  }

  @override
  void warning(String message) {
    print('[WARNING] $message');
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    print('[ERROR] $message');
    if (error != null) {
      print('  Error: $error');
    }
    if (stackTrace != null && enableDebug) {
      print('  Stack trace:\n$stackTrace');
    }
  }
}

/// Silent logger that suppresses all output
class SilentLogger implements LibgfxLogger {
  const SilentLogger();

  @override
  void debug(String message) {}

  @override
  void info(String message) {}

  @override
  void warning(String message) {}

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {}
}

/// Global logger instance
LibgfxLogger _logger = const SilentLogger();

/// Get the current logger
LibgfxLogger get logger => _logger;

/// Set a custom logger
void setLogger(LibgfxLogger newLogger) {
  _logger = newLogger;
}

/// Enable console logging
void enableConsoleLogging({bool debug = false}) {
  _logger = ConsoleLogger(enableDebug: debug);
}
