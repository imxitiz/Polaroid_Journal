import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polaroid_journal/data/models/layer_model.dart';
import 'package:polaroid_journal/data/repositories/journal_repository.dart';
import '../../data/models/journal_state.dart';
import '../../data/models/journal_entry.dart';

class JournalNotifier extends Notifier<JournalState> {
  final JournalRepository _repository = JournalRepository();

  @override
  JournalState build() {
    return const JournalState(layers: []);
  }

  Future<void> initRepository() async {
    await _repository.init();
  }

  // ─── Entry operations ─────────────────────────────────────────────────────

  void loadEntry(String entryId) {
    final entry = _repository.getEntry(entryId);
    if (entry != null) {
      final loadedState = _repository.loadState(entry);
      state = loadedState.copyWith(
        entryId: entry.id,
        title: entry.title,
      );
    }
  }

  void setTitle(String title) {
    state = state.copyWith(title: title);
  }

  void toggleAutoSave() {
    state = state.copyWith(isAutoSaveEnabled: !state.isAutoSaveEnabled);
  }

  Future<JournalEntry> saveEntry({ui.Image? thumbnail}) async {
    if (state.entryId != null) {
      // Update existing entry
      return await _repository.updateEntryWithState(
        id: state.entryId!,
        title: state.title,
        state: state,
        thumbnail: thumbnail,
      );
    } else {
      // Create new entry
      final entry = await _repository.createEntry(
        title: state.title,
        state: state,
        thumbnail: thumbnail,
      );
      state = state.copyWith(entryId: entry.id);
      return entry;
    }
  }

  Future<void> autoSave({ui.Image? thumbnail}) async {
    if (state.isAutoSaveEnabled) {
      await saveEntry(thumbnail: thumbnail);
    }
  }

  void resetState() {
    state = const JournalState(layers: []);
  }

  // ─── Layer operations ─────────────────────────────────────────────────────

  void addLayer(LayerModel newLayer) {
    state = state.copyWith(layers: [...state.layers, newLayer]);
  }

  void updateLayer(LayerModel updatedLayer) {
    state = state.copyWith(
      layers: state.layers
          .map((l) => l.id == updatedLayer.id ? updatedLayer : l)
          .toList(),
    );
  }

  void removeLayer(String id) {
    state = state.copyWith(
      layers: state.layers.where((l) => l.id != id).toList(),
    );
  }

  void reorderToTop(String id) {
    final layer = state.layers.firstWhere((l) => l.id == id);
    final rest = state.layers.where((l) => l.id != id).toList();
    state = state.copyWith(layers: [...rest, layer]);
  }

  // ─── Background operations ────────────────────────────────────────────────

  void updateBackground(BackgroundConfig config) {
    state = state.copyWith(background: config);
  }

  void setPrimaryColor(Color? color) {
    state = state.copyWith(
      background: state.background.copyWith(primaryColor: color),
    );
  }

  void setSecondaryColor(Color? color) {
    state = state.copyWith(
      background: color == null
          ? state.background.copyWith(clearSecondaryColor: true)
          : state.background.copyWith(secondaryColor: color),
    );
  }

  void setBackgroundImage(ImageProvider? image) {
    state = state.copyWith(
      background: image == null
          ? state.background.copyWith(clearImage: true)
          : state.background.copyWith(image: image),
    );
  }

  void setOpacity(double opacity) {
    state = state.copyWith(
      background: state.background.copyWith(opacity: opacity),
    );
  }

  void setBlur(double blur) {
    state = state.copyWith(
      background: state.background.copyWith(blur: blur),
    );
  }
}

final journalProvider = NotifierProvider<JournalNotifier, JournalState>(
  JournalNotifier.new,
);