import 'package:intl/intl.dart';

class DateUtil {
  static String transformUtc2LocalTimeString(String utcTimeString) {
    if (utcTimeString.isEmpty) return '';
    final DateTime utcTime = DateFormat('yyyy-MM-dd HH:mm', 'en_US').parseUtc(utcTimeString).toLocal();
    final String localTime = DateFormat('yyyy-MM-dd HH:mm').format(utcTime);
    return localTime;
  }
}
