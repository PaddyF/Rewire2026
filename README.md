# Rewire 2026

Native SwiftUI iOS app for tracking the [Rewire festival](https://rewire.nl) lineup — The Hague, 9–12 April 2026.

## Features

- **Lineup** — searchable, filterable list of 166 artists with wave badges, genre tags, and performance types
- **My List** — bookmarked and rated artists, sorted by Must See rating
- **Planner** — shows your picks now; switches to a day-by-day schedule grid once the timetable drops

Each artist detail view has:
- 5-star "Must See" rating (persists across app restarts)
- Personal notes text field (persists across app restarts)
- Bookmark toggle
- Release info (latest + top-rated), bio, Plus Ticket warning, World Premiere badge

## Requirements

- Xcode 15+
- iOS 17+ target (simulator or physical device)
- No third-party dependencies

## Build & Run

```bash
cd ~/Developer/Rewire2026
open Rewire2026.xcodeproj
```

Select your device or simulator, hit **Run** (⌘R). A free Apple ID works for personal device deployment (no paid developer account needed).

## Project Structure

```
Rewire2026/
├── RewireApp.swift              # Entry point, SwiftData model container
├── ContentView.swift            # TabView (Lineup / My List / Planner)
├── Models/
│   ├── Artist.swift             # Codable structs — Slot, Artist, Release, Lineup
│   ├── UserArtistData.swift     # SwiftData model — ratings, notes, bookmarks
│   └── ArtistStore.swift        # Loads lineup.json, EnvironmentObject
├── Views/
│   ├── Lineup/
│   │   ├── LineupView.swift     # Searchable list with wave filter chips
│   │   └── ArtistRowView.swift  # Row: name, genres, type badge, rating
│   ├── Detail/
│   │   ├── ArtistDetailView.swift   # Full detail + rating/notes/bookmark
│   │   └── MustSeeRatingView.swift  # 5-star tap component
│   ├── MyList/
│   │   └── MyListView.swift     # Bookmarked/rated artists
│   ├── Planner/
│   │   └── PlannerView.swift    # Pre/post timetable views
│   ├── Schedule/
│   │   └── ScheduleView.swift   # Day-by-day grid (shown once timetable drops)
│   └── Shared/
│       └── Components.swift     # WorldPremiereBadge, TypeBadge, DayBadge, WaveBadge…
├── Theme/
│   └── AppTheme.swift           # Color palette, Color(hex:) extension
└── Resources/
    └── lineup.json              # Compiled artist + slot data (generated from Data/)
```

## Updating Artist Data

All source data lives in `Data/lineup.yaml`. The pipeline is:

```
Data/lineup.yaml  →  Data/fill_gaps.py  →  Data/lineup.json  →  Rewire2026/Resources/lineup.json
```

See `Data/README.md` for full workflow details.

### Quick update

```bash
cd ~/Developer/Rewire2026/Data
# edit lineup.yaml as needed, then:
python build.py
cp lineup.json ../Rewire2026/Resources/lineup.json
# rebuild in Xcode (⌘R)
```

### When the timetable drops

Populate `day`, `time`, and `stage` on each slot in `lineup.yaml`, then rebuild. The Planner tab automatically switches from the "coming soon" placeholder to a schedule grid once any slot has a `day` value.

## Data Model

### Slot (from JSON — one per performance)

| Field | Type | Notes |
|---|---|---|
| `displayName` | String | Billing name for the performance |
| `wave` | String | "W1" / "W2" / "W3" |
| `type` | String? | Live / DJ Set / Installation / Live A/V… |
| `worldPremiere` | Bool | True if a world premiere |
| `day` | String? | "Thu" / "Fri" / "Sat" / "Sun" — nil until timetable |
| `stage` | String? | Venue/stage name — nil until timetable |
| `time` | String? | "22:30" format — nil until timetable |
| `isCollab` | Bool | Two or more artists sharing a slot |
| `artistIds` | [String] | Slugs referencing entries in `artists` dict |
| `project` | String? | Collab project name if named |
| `collabNotes` | String? | Short description of the collaboration |

### Artist (from JSON — one per individual, reused across slots)

| Field | Type | Notes |
|---|---|---|
| `name` | String | Display name |
| `genres` | String? | Comma-separated genre tags |
| `notes` | String? | Bio paragraph |
| `latest` | Release? | Most recent record |
| `topRated` | Release? | Highest-rated record (RYM data) |

### UserArtistData (SwiftData — persisted on device)

| Field | Type | Notes |
|---|---|---|
| `artistId` | String | Foreign key → `Slot.displayName` |
| `mustSeeRating` | Int | 0 = unrated, 1–5 |
| `personalNotes` | String | Free text, saves on type |
| `isBookmarked` | Bool | Appears in My List and Planner |

## Design

| Token | Value |
|---|---|
| Background | `#0a0a0a` |
| Surface | `#111111` |
| Accent (Wave 1) | `#c8ff00` neon lime |
| Secondary (Wave 2) | `#00d4ff` cyan |
| Tertiary (Wave 3) | `#ff6b35` orange |
| Text | `#e8e8e0` |
| Muted | `#666666` |
| Font | SF Mono (headers/labels), SF Pro (body) |
