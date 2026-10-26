/// Logger interface for libgfx
abstract class LibgfxLogger {
  void debug(String message);

  void info(String message);

  void warning(String message);

  void error(String message, [Object? error, final StackTrace? trace]);
}

/// Default console logger implementation
class ConsoleLogger implements LibgfxLogger {
  /// Whether debug messages and stack traces are printed
  final bool verbose;

  const ConsoleLogger({this.verbose = false});

  @override
  void debug(String message) {
    if (verbose) {
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
  void error(String message, [Object? error, final StackTrace? trace]) {
    print('[ERROR] $message');
    if (error != null) {
      print('  Error: $error');
    }
    if (trace != null && verbose) {
      print('  Stack trace:\n$trace');
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
  void error(String message, [Object? error, final StackTrace? trace]) {}
}

/// Global logger instance
LibgfxLogger _logger = const SilentLogger();

/// The logger libgfx reports to; [SilentLogger] by default. Assign
/// `ConsoleLogger()` to print messages.
LibgfxLogger get logger => _logger;
set logger(final LibgfxLogger value) => _logger = value;
