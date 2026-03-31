import 'package:hive/hive.dart';

part 'journal_entry.g.dart';

@HiveType(typeId: 0)
class JournalEntry {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  final DateTime updatedAt;

  @HiveField(4)
  final String? thumbnailPath;

  @HiveField(5)
  final String serializedState;

  const JournalEntry({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.thumbnailPath,
    required this.serializedState,
  });

  JournalEntry copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? thumbnailPath,
    String? serializedState,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      serializedState: serializedState ?? this.serializedState,
    );
  }
}
