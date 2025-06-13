# Multiple Entries Implementation Plan

## Requirements
- Within a session (3+ hours), multiple entries for:
  - Pee events (amount, remarks, time)
  - Poop events (amount, consistency, color, time, photo)
  - Milk intake events (amount, time)
- First entry cannot be deleted ✓
- Subsequent entries can be deleted ✓
- Time validation between wake and sleep times ✓
- Excel export with all entries
- Sleep duration calculation between sessions
- History view with all entries
- Analytics with aggregated data

## Implementation Plan

### 1. Database Schema Update
- [x] Remove old sessions table and create new schema:
  ```sql
  sessions:
    - id (PRIMARY KEY)
    - wakeUpTime (TEXT)
    - sleepTime (TEXT)
    - vitaminAD (INTEGER)
    - sessionPhotoPath (TEXT)
    - hasSessionPhoto (INTEGER)
    - isClosed (INTEGER)

  pee_entries:
    - id (PRIMARY KEY)
    - session_id (FOREIGN KEY)
    - amount (INTEGER)
    - remarks (TEXT)
    - time (TEXT)

  poop_entries:
    - id (PRIMARY KEY)
    - session_id (FOREIGN KEY)
    - amount (INTEGER)
    - consistency (INTEGER)
    - color (INTEGER)
    - time (TEXT)
    - photo_path (TEXT)
    - has_photo (INTEGER)

  milk_entries:
    - id (PRIMARY KEY)
    - session_id (FOREIGN KEY)
    - amount (INTEGER)
    - time (TEXT)
  ```
- [x] Update database version to trigger recreation
- [x] Implement schema creation in DatabaseService

### 2. Model Updates
- [x] Create new models (PeeEntry, PoopEntry, MilkEntry)
- [x] Update Session model to include entry lists
- [x] Update copyWith, toMap, fromMap methods
- [x] Add entry validation methods

### 3. UI Updates
- [x] Create base widgets:
  - [x] EntryListCard (implemented directly in section cards)
  - [x] AddEntryButton (implemented as IconButton)
  - [x] DeleteEntryButton (implemented as IconButton)
- [x] Update PeeSectionCard
  - [x] Show entries list
  - [x] Add entry functionality
  - [x] Delete entry functionality (except first)
- [x] Update PoopSectionCard
  - [x] Show entries list
  - [x] Add entry functionality
  - [x] Delete entry functionality (except first)
  - [x] Photo handling for each entry
- [x] Update MilkSectionCard
  - [x] Show entries list
  - [x] Add entry functionality
  - [x] Delete entry functionality (except first)

### 4. Provider Updates
- [x] Add entry management methods to SessionProvider
  - [x] addPeeEntry, deletePeeEntry
  - [x] addPoopEntry, deletePoopEntry
  - [x] addMilkEntry, deleteMilkEntry
- [x] Update photo handling for multiple poop entries
- [x] Modify wake/sleep time validation logic
- [x] Update database operations for multiple entries
- [x] Update session loading to include all entries

### 5. History and Analytics Updates
- [ ] Update SessionHistoryScreen
  - [ ] Show all entries per session
  - [ ] Update time validation
  - [ ] Show sleep duration between sessions
- [ ] Update AnalyticsScreen
  - [ ] Update statistics for multiple entries
  - [ ] Update total calculations
- [ ] Update ExcelService
  - [ ] Handle multiple entries per session
  - [ ] Add sleep duration between sessions

### 6. Testing and Validation
- [ ] Test data migration
- [ ] Test entry management
- [ ] Test photo handling
- [ ] Test sleep duration calculations

## Notes
- Keep track of completed items by marking them with [x]
- Add any issues or observations under each section as they arise
- Document any design decisions made during implementation
