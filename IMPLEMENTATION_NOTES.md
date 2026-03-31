# Entry Saving, Auto-Save, and Preview Thumbnails Implementation

## Overview
This implementation adds persistent storage, auto-save functionality, and thumbnail previews to the Polaroid Journal app, addressing issue #2.

## Features Implemented

### 1. Entry Saving
- **Save Button**: Added a save icon button in the AppBar of the journal entry screen
- **Manual Save**: Users can manually save entries at any time
- **Title Field**: Editable title field in the AppBar (defaults to "Untitled")
- **Persistent Storage**: Entries are saved to local database using Hive
- **Thumbnail Generation**: Automatically generates a preview thumbnail when saving

### 2. Auto-Save
- **Toggle Button**: Cloud icon button in AppBar to enable/disable auto-save
  - Cloud with checkmark (cloud_done): Auto-save enabled
  - Cloud with slash (cloud_off): Auto-save disabled
- **Automatic Triggers**: Auto-save is triggered on:
  - Layer updates (move, resize, rotate)
  - Layer deletion
  - Layer copying
  - Any other layer modifications
- **Silent Operation**: Auto-save failures are silent to avoid interrupting user workflow

### 3. Preview Thumbnails
- **Grid View**: Home screen displays entries in a 2-column grid
- **Thumbnail Display**: Each entry card shows:
  - Preview thumbnail of the journal canvas
  - Entry title
  - Last updated date
  - Delete button
- **Fallback UI**: Shows placeholder icon if thumbnail is not available
- **Efficient Storage**: Thumbnails are generated at lower resolution (0.3x) for optimal storage

## Technical Details

### Database Structure
- **Database**: Hive (NoSQL, Flutter-optimized)
- **Storage Location**: Application documents directory
- **Thumbnails Directory**: Separate `thumbnails/` folder for preview images

### Models

#### JournalEntry Model
```dart
- id: String (timestamp-based)
- title: String
- createdAt: DateTime
- updatedAt: DateTime
- thumbnailPath: String? (file path to thumbnail PNG)
- serializedState: String (JSON-encoded journal state)
```

#### JournalState Extensions
```dart
- entryId: String? (null for new entries)
- title: String (default: "Untitled")
- isAutoSaveEnabled: bool (default: false)
```

### Serialization Strategy
- **Layers**: JSON serialization with support for:
  - Text layers (all formatting preserved)
  - Photo layers (FileImage and AssetImage paths stored)
  - Drawing layers (new WhiteBoardController created on load)
- **Background**: Colors, opacity, blur, and background image paths
- **Limitation**: Drawing layer content is not persisted (new blank canvas on load)

### File Structure
```
lib/
├── data/
│   ├── models/
│   │   ├── journal_entry.dart        # Entry model with Hive annotations
│   │   └── journal_entry.g.dart      # Generated Hive adapter
│   └── repositories/
│       └── journal_repository.dart   # Persistence layer
├── presentation/
│   ├── viewmodels/
│   │   ├── journal_viewmodel.dart           # Updated with save/load
│   │   └── journal_entries_viewmodel.dart   # New: entries list management
│   └── views/
│       ├── home.dart                 # Updated: grid view with thumbnails
│       └── jounrnal_entry.dart       # Updated: save, title, auto-save UI
```

## Usage Instructions

### For Users

1. **Creating a New Entry**
   - Tap the "+" button on the home screen
   - Add photos, drawings, text, and customize background
   - Enter a title in the AppBar text field

2. **Saving an Entry**
   - Tap the save icon (💾) in the AppBar
   - Entry is saved with a thumbnail preview

3. **Using Auto-Save**
   - Tap the cloud icon to enable auto-save
   - Icon changes to cloud with checkmark when enabled
   - Entry saves automatically after each change

4. **Viewing Saved Entries**
   - Home screen shows all entries in a grid
   - Each card displays thumbnail, title, and date
   - Tap any card to edit that entry

5. **Deleting an Entry**
   - Tap the delete icon on an entry card
   - Confirm deletion in the dialog

### For Developers

1. **Install Dependencies**
   ```bash
   flutter pub get
   ```

2. **Required Packages Added**
   - `hive: ^2.2.3` - NoSQL database
   - `hive_flutter: ^1.1.0` - Flutter integration
   - `path_provider: ^2.1.5` - File system access
   - `intl: ^0.19.0` - Date formatting

3. **Database Initialization**
   - Hive is initialized on first access to JournalNotifier
   - Adapter is registered automatically
   - No migration needed for updates

4. **Testing**
   ```bash
   flutter test
   ```

## Known Limitations

1. **Drawing Layer Persistence**: Drawing layer strokes are not persisted due to WhiteBoardController limitations. A new blank drawing layer is created when loading entries with drawings.

2. **Image References**: Images must remain at their original file paths. Moving or deleting source images will break entry display.

3. **Background Images**: Similar to layer images, background images rely on file path references.

## Future Enhancements

1. **Drawing Persistence**: Implement custom drawing serialization to save/restore strokes
2. **Image Copying**: Copy images to app's internal storage for reliability
3. **Export Options**: Add export to PDF, PNG, or share functionality
4. **Search/Filter**: Add search and filtering capabilities for entries
5. **Tags/Categories**: Organize entries with tags or categories
6. **Cloud Sync**: Optional cloud backup and multi-device sync

## Migration Notes

- **Existing Users**: No data migration needed (fresh installation)
- **State Reset**: Journal state is reset when navigating to home screen to avoid conflicts
- **Backward Compatibility**: Not applicable (new feature)

## Testing Checklist

- [x] Create new entry with title
- [x] Save entry manually
- [x] Enable auto-save
- [x] Verify auto-save on layer changes
- [x] Load saved entry
- [x] Edit existing entry
- [x] Delete entry
- [x] View entry list with thumbnails
- [x] Verify thumbnail generation
- [x] Test with photos, text, and drawings
- [x] Test with background colors and images
- [ ] Performance testing with many entries
- [ ] Error handling validation
