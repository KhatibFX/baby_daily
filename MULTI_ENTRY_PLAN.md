# Multiple Entries Implementation Plan

## Requirements
- Within a session (3+ hours), multiple entries for:
  - Pee events (amount, remarks, time)
  - Poop events (amount, consistency, color, time, photo)
  - Milk intake events (amount, time)
- First entry cannot be deleted
- Subsequent entries can be deleted
- Time validation between wake and sleep times
- Excel export with all entries
- Sleep duration calculation between sessions
- History view with all entries
- Analytics with aggregated data

## Implementation Plan

### 1. Database Schema Update
- [ ] Remove old sessions table and create new schema:
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
- [ ] Update database version to trigger recreation
- [ ] Implement schema creation in DatabaseService

### 2. Model Updates
- [ ] Create new models (PeeEntry, PoopEntry, MilkEntry)
- [ ] Update Session model to include entry lists
- [ ] Update copyWith, toMap, fromMap methods
- [ ] Add entry validation methods

### 3. UI Updates
- [ ] Create base widgets:
  - [ ] EntryListCard
  - [ ] AddEntryButton
  - [ ] DeleteEntryButton
- [ ] Update PeeSectionCard
  - [ ] Show entries list
  - [ ] Add entry functionality
  - [ ] Delete entry functionality (except first)
- [ ] Update PoopSectionCard
  - [ ] Show entries list
  - [ ] Add entry functionality
  - [ ] Delete entry functionality (except first)
  - [ ] Photo handling for each entry
- [ ] Update MilkSectionCard
  - [ ] Show entries list
  - [ ] Add entry functionality
  - [ ] Delete entry functionality (except first)

### 4. Provider Updates
- [ ] Add entry management methods to SessionProvider
  - [ ] addPeeEntry, deletePeeEntry
  - [ ] addPoopEntry, deletePoopEntry
  - [ ] addMilkEntry, deleteMilkEntry
- [ ] Update photo handling for multiple poop entries
- [ ] Modify wake/sleep time validation logic
- [ ] Update database operations for multiple entries
- [ ] Update session loading to include all entries

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
  - [ ] Include entry times in export

### 6. Time Validation Logic
- [ ] Update session_utils.dart
  - [ ] Modify validation for multiple entries
  - [ ] Ensure entries are within session bounds
  - [ ] Allow overlapping times for different types

### 7. Testing
- [ ] Test database schema creation
- [ ] Test photo handling for multiple entries
- [ ] Test UI functionality
  - [ ] Adding entries
  - [ ] Deleting entries
  - [ ] First entry protection
  - [ ] Entry time validation
  - [ ] Photo management per entry
- [ ] Test statistics calculation
- [ ] Test Excel export with multiple entries

## Notes
- Keep track of completed items by marking them with [x]
- Add any issues or observations under each section as they arise
- Document any design decisions made during implementation
