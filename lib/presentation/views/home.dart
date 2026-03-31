import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polaroid_journal/presentation/viewmodels/journal_entries_viewmodel.dart';
import 'package:polaroid_journal/presentation/viewmodels/journal_viewmodel.dart';
import 'package:polaroid_journal/presentation/views/jounrnal_entry.dart';
import 'package:intl/intl.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(journalEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Journal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(journalEntriesProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: entries.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No entries yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to create your first entry',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _EntryCard(
                  entry: entry,
                  onTap: () async {
                    // Reset state before loading
                    ref.read(journalProvider.notifier).resetState();

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JournalEntryScreen(entryId: entry.id),
                      ),
                    );

                    // Refresh entries list after returning
                    ref.read(journalEntriesProvider.notifier).refresh();
                  },
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Entry'),
                        content: Text('Delete "${entry.title}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await ref
                          .read(journalEntriesProvider.notifier)
                          .deleteEntry(entry.id);
                    }
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).primaryColor,
        onPressed: () async {
          // Reset state before creating new entry
          ref.read(journalProvider.notifier).resetState();

          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const JournalEntryScreen()),
          );

          // Refresh entries list after returning
          ref.read(journalEntriesProvider.notifier).refresh();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final dynamic entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _EntryCard({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: entry.thumbnailPath != null &&
                      File(entry.thumbnailPath).existsSync()
                  ? Image.file(
                      File(entry.thumbnailPath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholder();
                      },
                    )
                  : _buildPlaceholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: onDelete,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy').format(entry.updatedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: Colors.grey,
        ),
      ),
    );
  }
}
