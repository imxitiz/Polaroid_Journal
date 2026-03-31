import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
// import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:polaroid_journal/core/utils/tools_enum.dart';
import 'package:polaroid_journal/data/models/layer_model.dart';
import 'package:polaroid_journal/presentation/viewmodels/journal_viewmodel.dart';
import 'package:polaroid_journal/presentation/widgets/layer/moveable_layer.dart';
import 'package:polaroid_journal/presentation/widgets/stickers_bottom_sheet.dart';
import 'package:polaroid_journal/presentation/views/journal_canvas.dart';
import 'package:polaroid_journal/presentation/views/journal_toolbar.dart';
import 'package:whiteboard/whiteboard.dart';

class JournalEntryScreen extends ConsumerStatefulWidget {
  final String? entryId;

  const JournalEntryScreen({super.key, this.entryId});

  @override
  ConsumerState<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends ConsumerState<JournalEntryScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final TextEditingController _titleController = TextEditingController();
  LayerModel? focusedLayer;

  Color currentTextColor = Colors.black;
  Color currentBrushColor = Colors.black;
  Color? currentColor = Colors.black;
  bool isIgnoring = true;

  bool isErasing = false;
  double strokeWidth = 3;

  bool isOpen = false;
  Tool? selectedTool;
  SubTool? selectedSubTool;

  bool _isPickingImage = false;

  bool _isExporting = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(journalProvider.notifier).initRepository();
      if (widget.entryId != null) {
        ref.read(journalProvider.notifier).loadEntry(widget.entryId!);
        _titleController.text = ref.read(journalProvider).title;
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // ─── Layer actions ────────────────────────────────────────────────────────

  void _onPhotoFocused(LayerModel layer) {
    setState(() {
      _bringToTop(layer);
      if (selectedTool != Tool.draw) focusedLayer = layer;
      if (selectedTool != Tool.image) selectedTool = Tool.image;
    });
  }

  void _onTextFocused(LayerModel layer) {
    setState(() {
      _bringToTop(layer);
      if (selectedTool != Tool.draw) focusedLayer = layer;
      if (selectedTool != Tool.text) selectedTool = Tool.text;
    });
  }

  void _onLayerRemoved(LayerModel layer) {
    ref.read(journalProvider.notifier).removeLayer(layer.id);
    setState(() => focusedLayer = null);
    _triggerAutoSave();
  }

  void _copyLayer(LayerModel layer) {
    final copy = layer.copyWith(
      id: UniqueKey().toString(),
      position: Offset(layer.position.dx + 20, layer.position.dy + 20),
    );
    ref.read(journalProvider.notifier).addLayer(copy);
    _triggerAutoSave();
  }

  void _onLayerUpdated(LayerModel updatedLayer) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(journalProvider.notifier).updateLayer(updatedLayer);
      setState(() => focusedLayer = updatedLayer);
      _triggerAutoSave();
    });
  }

  void _bringToTop(LayerModel layer) {
    final layers = ref.read(journalProvider).layers;
    if (layers.last != layer) {
      ref.read(journalProvider.notifier).reorderToTop(layer.id);
    }
  }

  // ─── Image picking ────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    _isPickingImage = true;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) {
      _isPickingImage = false;
      return;
    }

    if (selectedSubTool == SubTool.photo) {
      final layer = LayerModel(
        id: UniqueKey().toString(),
        type: LayerType.photo,
        image: FileImage(File(picked.path)),
      );
      setState(() {
        focusedLayer = layer;
        ref.read(journalProvider.notifier).addLayer(layer);
      });
    }

    if (selectedSubTool == SubTool.wallpaper) {
      ref
          .read(journalProvider.notifier)
          .setBackgroundImage(FileImage(File(picked.path)));
    }

    _isPickingImage = false;
  }

  // ─── Text ─────────────────────────────────────────────────────────────────

  void _addTextField() {
    final layer = LayerModel(
      id: UniqueKey().toString(),
      type: LayerType.text,
      text: '',
    );
    setState(() {
      focusedLayer = layer;
      ref.read(journalProvider.notifier).addLayer(layer);
    });
  }

  // ─── Color ────────────────────────────────────────────────────────────────

  void _changeColor(Color? color) {
    if (color != null) {
      if (selectedTool == Tool.draw) currentBrushColor = color;
      if (selectedTool == Tool.text) {
        currentTextColor = color;
        ref
            .read(journalProvider.notifier)
            .updateLayer(focusedLayer!.copyWith(textColor: color));
        setState(() {
          focusedLayer = ref
              .read(journalProvider)
              .layers
              .firstWhere((l) => l.id == focusedLayer!.id);
        });
      }
    }
    if (selectedTool == Tool.background) {
      if (selectedSubTool == SubTool.secondaryBackgroundColor) {
        ref.read(journalProvider.notifier).setSecondaryColor(color);
      } else {
        ref.read(journalProvider.notifier).setPrimaryColor(color);
      }
    }
    setState(() => currentColor = color);
  }

  // ─── Font ─────────────────────────────────────────────────────────────────

  void _changeFont(String font) {
    ref
        .read(journalProvider.notifier)
        .updateLayer(focusedLayer!.copyWith(fontFamily: font));
    setState(() {
      focusedLayer = ref
          .read(journalProvider)
          .layers
          .firstWhere((l) => l.id == focusedLayer!.id);
    });
  }

  // ─── Stickers ─────────────────────────────────────────────────────────────

  void _openStickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      builder: (context) {
        return StickersBottomSheet(
          onSelect: (sticker) {
            Navigator.pop(context);
            final layer = LayerModel(
              id: UniqueKey().toString(),
              type: LayerType.photo,
              image: AssetImage(sticker),
            );
            FocusScope.of(context).unfocus();
            setState(() {
              focusedLayer = layer;
              ref.read(journalProvider.notifier).addLayer(layer);
            });
          },
        );
      },
    );
  }

  // ─── Tool selection ───────────────────────────────────────────────────────

  void _onCanvasTapped() {
    FocusScope.of(context).unfocus();
    if (selectedTool != Tool.draw) {
      setState(() {
        selectedTool = null;
        selectedSubTool = null;
        focusedLayer = null;
      });
    }
  }

  void _onSubToolSelected(SubTool selected) async {
    setState(() {
      selectedSubTool = selected;
      if (selected == SubTool.erase) isErasing = !isErasing;
      if (selected == SubTool.secondaryBackgroundColor) {
        currentColor = ref.read(journalProvider).background.secondaryColor;
      }
      if (selected == SubTool.primaryBackgroundColor) {
        currentColor = ref.read(journalProvider).background.primaryColor;
      }
      if (selected == SubTool.add) {
        final l = LayerModel(
          id: UniqueKey().toString(),
          type: LayerType.drawing,
          whiteBoardController: WhiteBoardController(),
        );
        ref.read(journalProvider.notifier).addLayer(l);
        focusedLayer = l;
      }
    });
    if (selected == SubTool.photo) await _pickImage();
    if (selected == SubTool.sticker) _openStickerSheet();
  }

  void _onToolSelected(Tool tool) async {
    setState(() {
      isOpen = false;
      selectedTool = tool;
      if (tool == Tool.draw) {
        isIgnoring = false;
        final layers = ref.read(journalProvider).layers;
        final drawingLayer = layers.lastWhere(
          (l) => l.type == LayerType.drawing,
          orElse: () {
            final l = LayerModel(
              id: UniqueKey().toString(),
              type: LayerType.drawing,
              whiteBoardController: WhiteBoardController(),
            );
            ref.read(journalProvider.notifier).addLayer(l);
            return l;
          },
        );
        focusedLayer = drawingLayer;
      } else {
        isIgnoring = true;
      }
      if (tool == Tool.text) currentColor = currentTextColor;
      if (tool == Tool.background) {
        currentColor = ref.read(journalProvider).background.primaryColor;
      }
    });
    if (tool == Tool.text) _addTextField();
  }

  void _changeStrokeWidth(double width) {
    setState(() => strokeWidth = width);
  }

  //  ─── Save ──────────────────────────────────────────────────────────────────

  Future<void> _saveEntry() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saving...")),
      );
    }

    try {
      // Update title
      ref.read(journalProvider.notifier).setTitle(_titleController.text);

      // Generate thumbnail
      final boundary = _canvasKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 0.3); // Lower quality for thumbnail

      // Save entry
      await ref.read(journalProvider.notifier).saveEntry(thumbnail: image);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Entry saved successfully")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Save failed: $e")),
      );
    }

    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _triggerAutoSave() async {
    if (ref.read(journalProvider).isAutoSaveEnabled) {
      try {
        ref.read(journalProvider.notifier).setTitle(_titleController.text);
        final boundary = _canvasKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 0.3);
          await ref.read(journalProvider.notifier).autoSave(thumbnail: image);
        }
      } catch (e) {
        // Silent fail for auto-save
      }
    }
  }

  //  ─── Export ────────────────────────────────────────────────────────────────

  Future<void> _exportCanvas() async {
    if (_isExporting) return;

    setState(() => _isExporting = true);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Exporting...")));
    }

    try {
      final boundary =
          _canvasKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      await Gal.putImageBytes(pngBytes);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Saved to gallery")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Export failed")));
    }

    if (mounted) setState(() => _isExporting = false);
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionBtn(
          Icons.copy_rounded,
          Colors.white,
          () => _copyLayer(focusedLayer!),
        ),
        const SizedBox(width: 8),
        _actionBtn(
          Icons.delete_rounded,
          Colors.red,
          () => _onLayerRemoved(focusedLayer!),
        ),
      ],
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDragging = ref.watch(isDraggingProvider);
    final journalState = ref.watch(journalProvider);

    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          width: 200,
          child: TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: 'Entry Title',
              border: InputBorder.none,
            ),
            style: const TextStyle(fontSize: 18),
            onChanged: (value) {
              ref.read(journalProvider.notifier).setTitle(value);
            },
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              journalState.isAutoSaveEnabled
                  ? Icons.cloud_done
                  : Icons.cloud_off,
            ),
            onPressed: () {
              ref.read(journalProvider.notifier).toggleAutoSave();
            },
            tooltip: journalState.isAutoSaveEnabled
                ? 'Auto-save enabled'
                : 'Auto-save disabled',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveEntry,
            tooltip: 'Save entry',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportCanvas,
            tooltip: 'Export to gallery',
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: RepaintBoundary(
              key: _canvasKey,
              child: JournalCanvas(
                focusedLayer: focusedLayer,
                selectedTool: selectedTool,
                isOpen: isOpen,
                isIgnoring: isIgnoring,
                currentBrushColor: currentBrushColor,
                strokeWidth: strokeWidth,
                isErasing: isErasing,
                onCanvasTapped: _onCanvasTapped,
                onPhotoFocused: _onPhotoFocused,
                onTextFocused: _onTextFocused,
                onLayerRemoved: _onLayerRemoved,
                onDismissOverlay: () => setState(() => isOpen = false),
              ),
            ),
          ),
          if (focusedLayer != null && selectedTool != Tool.draw && !isDragging)
            Positioned(
              left: MediaQuery.of(context).size.width / 2.5,
              top: () {
                final latest = ref
                    .read(journalProvider)
                    .layers
                    .firstWhere(
                      (l) => l.id == focusedLayer!.id,
                      orElse: () => focusedLayer!,
                    );
                return latest.position.dy < 30
                    ? latest.position.dy + (200 * latest.scale)
                    : latest.position.dy - (20 * latest.scale);
              }(),
              child: _buildActionButtons(),
            ),
        ],
      ),
      floatingActionButton: JournalToolbar(
        focusedLayer: focusedLayer,
        selectedTool: selectedTool,
        selectedSubTool: selectedSubTool,
        isOpen: isOpen,
        strokeWidth: strokeWidth,
        currentColor: currentColor,
        currentBrushColor: currentBrushColor,
        onToolSelected: _onToolSelected,
        onSubToolSelected: _onSubToolSelected,
        onLayerUpdated: _onLayerUpdated,
        onColorChanged: _changeColor,
        onFontChanged: _changeFont,
        onStrokeWidthChanged: _changeStrokeWidth,
        onToggle: () => setState(() {
          selectedSubTool = null;
          isOpen = !isOpen;
        }),
        pickImage: _pickImage,
      ),
    );
  }
}
