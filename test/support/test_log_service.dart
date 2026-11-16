import 'package:jhentai/src/service/log.dart';

/// Keeps tests that do not assert logging free of unawaited file output.
class TestLogService extends LogService {
  @override
  void trace(Object msg, [bool withStack = false]) {}

  @override
  void debug(Object msg, [bool withStack = false]) {}

  @override
  void info(Object msg, [bool withStack = false]) {}

  @override
  void warning(Object msg, [Object? error, bool withStack = false]) {}

  @override
  void error(Object msg, [Object? error, StackTrace? stackTrace]) {}

  @override
  void download(Object msg) {}
}
