import 'package:intl/intl.dart';

void main() {
  String dateStr = "2026-03-01T12:00:00Z";

  try {
    DateTime parsed = DateFormat('dd-MM-yyyy').parseStrict(dateStr);
    print('parseStrict: $parsed');
  } catch (e) {
    print('parseStrict failed: $e');
  }

  try {
    DateTime parsed = DateFormat('dd-MM-yyyy').parse(dateStr);
    print('parse: $parsed');
  } catch (e) {
    print('parse failed: $e');
  }
}
