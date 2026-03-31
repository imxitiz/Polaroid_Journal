import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:polaroid_journal/data/models/journal_entry.dart';
import 'package:polaroid_journal/data/models/journal_state.dart';
import 'package:polaroid_journal/data/models/layer_model.dart';
import 'package:whiteboard/whiteboard.dart';

class JournalRepository {
  static const String _boxName = 'journal_entries';
  static const String _thumbnailsDir = 'thumbnails';

  Box<JournalEntry>? _box;

  Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(JournalEntryAdapter());
    }
    _box = await Hive.openBox<JournalEntry>(_boxName);
  }

  Future<String> _getThumbnailsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final thumbDir = Directory('${appDir.path}/$_thumbnailsDir');
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }
    return thumbDir.path;
  }

  Future<String> saveThumbnail(String entryId, ui.Image image) async {
    final thumbDir = await _getThumbnailsDirectory();
    final filePath = '$thumbDir/$entryId.png';

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final file = File(filePath);
    await file.writeAsBytes(pngBytes);

    return filePath;
  }

  String _serializeState(JournalState state) {
    final Map<String, dynamic> stateMap = {
      'layers': state.layers.map((l) => _serializeLayer(l)).toList(),
      'background': _serializeBackground(state.background),
    };
    return jsonEncode(stateMap);
  }

  Map<String, dynamic> _serializeLayer(LayerModel layer) {
    String? imagePath;
    String? imageType;

    // Handle image serialization
    if (layer.image != null) {
      if (layer.image is FileImage) {
        imagePath = (layer.image as FileImage).file.path;
        imageType = 'file';
      } else if (layer.image is AssetImage) {
        imagePath = (layer.image as AssetImage).assetName;
        imageType = 'asset';
      }
    }

    return {
      'id': layer.id,
      'type': layer.type.name,
      'position': {'dx': layer.position.dx, 'dy': layer.position.dy},
      'scale': layer.scale,
      'rotation': layer.rotation,
      'text': layer.text,
      'isBold': layer.isBold,
      'isItalic': layer.isItalic,
      'isUnderline': layer.isUnderline,
      'textColor': layer.textColor?.value,
      'textAlign': layer.textAlign.index,
      'fontFamily': layer.fontFamily,
      'imagePath': imagePath,
      'imageType': imageType,
    };
  }

  Map<String, dynamic> _serializeBackground(BackgroundConfig bg) {
    String? imagePath;
    String? imageType;

    // Handle background image serialization
    if (bg.image != null) {
      if (bg.image is FileImage) {
        imagePath = (bg.image as FileImage).file.path;
        imageType = 'file';
      } else if (bg.image is AssetImage) {
        imagePath = (bg.image as AssetImage).assetName;
        imageType = 'asset';
      }
    }

    return {
      'primaryColor': bg.primaryColor?.value,
      'secondaryColor': bg.secondaryColor?.value,
      'opacity': bg.opacity,
      'blur': bg.blur,
      'imagePath': imagePath,
      'imageType': imageType,
    };
  }

  JournalState _deserializeState(String serialized) {
    final Map<String, dynamic> stateMap = jsonDecode(serialized);
    return JournalState(
      layers: (stateMap['layers'] as List)
          .map((l) => _deserializeLayer(l))
          .toList(),
      background: _deserializeBackground(stateMap['background']),
    );
  }

  LayerModel _deserializeLayer(Map<String, dynamic> data) {
    // Restore image based on type
    ImageProvider? image;
    if (data['imagePath'] != null && data['imageType'] != null) {
      if (data['imageType'] == 'file') {
        image = FileImage(File(data['imagePath']));
      } else if (data['imageType'] == 'asset') {
        image = AssetImage(data['imagePath']);
      }
    }

    // Create new whiteboard controller for drawing layers
    WhiteBoardController? whiteBoardController;
    if (data['type'] == LayerType.drawing.name) {
      whiteBoardController = WhiteBoardController();
    }

    return LayerModel(
      id: data['id'],
      type: LayerType.values.firstWhere((e) => e.name == data['type']),
      position: Offset(data['position']['dx'], data['position']['dy']),
      scale: data['scale'],
      rotation: data['rotation'],
      text: data['text'],
      isBold: data['isBold'],
      isItalic: data['isItalic'],
      isUnderline: data['isUnderline'],
      textColor: data['textColor'] != null ? Color(data['textColor']) : null,
      textAlign: TextAlign.values[data['textAlign']],
      fontFamily: data['fontFamily'],
      image: image,
      whiteBoardController: whiteBoardController,
    );
  }

  BackgroundConfig _deserializeBackground(Map<String, dynamic> data) {
    // Restore background image based on type
    ImageProvider? image;
    if (data['imagePath'] != null && data['imageType'] != null) {
      if (data['imageType'] == 'file') {
        image = FileImage(File(data['imagePath']));
      } else if (data['imageType'] == 'asset') {
        image = AssetImage(data['imagePath']);
      }
    }

    return BackgroundConfig(
      primaryColor: data['primaryColor'] != null ? Color(data['primaryColor']) : null,
      secondaryColor: data['secondaryColor'] != null ? Color(data['secondaryColor']) : null,
      opacity: data['opacity'],
      blur: data['blur'],
      image: image,
    );
  }

  Future<void> saveEntry(JournalEntry entry) async {
    await _box?.put(entry.id, entry);
  }

  Future<void> updateEntry(JournalEntry entry) async {
    await _box?.put(entry.id, entry);
  }

  Future<void> deleteEntry(String id) async {
    final entry = _box?.get(id);
    if (entry?.thumbnailPath != null) {
      final file = File(entry!.thumbnailPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _box?.delete(id);
  }

  JournalEntry? getEntry(String id) {
    return _box?.get(id);
  }

  List<JournalEntry> getAllEntries() {
    return _box?.values.toList() ?? [];
  }

  Future<JournalEntry> createEntry({
    required String title,
    required JournalState state,
    ui.Image? thumbnail,
  }) async {
    final now = DateTime.now();
    final id = now.millisecondsSinceEpoch.toString();

    String? thumbnailPath;
    if (thumbnail != null) {
      thumbnailPath = await saveThumbnail(id, thumbnail);
    }

    final entry = JournalEntry(
      id: id,
      title: title,
      createdAt: now,
      updatedAt: now,
      thumbnailPath: thumbnailPath,
      serializedState: _serializeState(state),
    );

    await saveEntry(entry);
    return entry;
  }

  Future<JournalEntry> updateEntryWithState({
    required String id,
    String? title,
    required JournalState state,
    ui.Image? thumbnail,
  }) async {
    final existing = getEntry(id);
    if (existing == null) {
      throw Exception('Entry not found');
    }

    String? thumbnailPath = existing.thumbnailPath;
    if (thumbnail != null) {
      thumbnailPath = await saveThumbnail(id, thumbnail);
    }

    final updated = existing.copyWith(
      title: title ?? existing.title,
      updatedAt: DateTime.now(),
      thumbnailPath: thumbnailPath,
      serializedState: _serializeState(state),
    );

    await updateEntry(updated);
    return updated;
  }

  JournalState loadState(JournalEntry entry) {
    return _deserializeState(entry.serializedState);
  }
}
