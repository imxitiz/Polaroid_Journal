import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polaroid_journal/data/models/journal_entry.dart';
import 'package:polaroid_journal/data/repositories/journal_repository.dart';

class JournalEntriesNotifier extends Notifier<List<JournalEntry>> {
  final JournalRepository _repository = JournalRepository();

  @override
  List<JournalEntry> build() {
    _loadEntries();
    return [];
  }

  Future<void> _loadEntries() async {
    await _repository.init();
    final entries = _repository.getAllEntries();
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = entries;
  }

  Future<void> refresh() async {
    await _loadEntries();
  }

  Future<void> deleteEntry(String id) async {
    await _repository.deleteEntry(id);
    await refresh();
  }
}

final journalEntriesProvider =
    NotifierProvider<JournalEntriesNotifier, List<JournalEntry>>(
  JournalEntriesNotifier.new,
);
