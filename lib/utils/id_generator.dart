import 'package:uuid/uuid.dart';

final _uuid = Uuid();

/// Generates a unique string ID (UUID v4)
String generateId() => _uuid.v4();
