# Rewire 2026

Native SwiftUI iOS app for tracking the [Rewire festival](https://rewire.nl) lineup — The Hague, April 2026.

## Features

- **Lineup** — searchable, filterable list of 128+ artists with wave badges, genre tags, and performance types
- **My List** — bookmarked and rated artists, sorted by Must See rating
- **Planner** — shows your picks now; switches to a day-by-day schedule grid once the timetable drops

Each artist detail view has:
- 5-star "Must See" rating (persists across app restarts)
- Personal notes text field (persists across app restarts)
- Bookmark toggle
- Release info, description, Plus Ticket warning

## Requirements

- Xcode 15+
- iOS 17+ target (simulator or physical device)
- No third-party dependencies

## Build & Run

```bash
cd ~/Developer/Rewire2026
xcodegen generate        # regenerate .xcodeproj after any project.yml changes
open Rewire2026.xcodeproj
```

Select your device or simulator, hit **Run** (⌘R). A free Apple ID works for personal device deployment (no paid developer account needed).

## Project Structure

```
Rewire2026/
├── RewireApp.swift              # Entry point, SwiftData model container
├── ContentView.swift            # TabView (Lineup / My List / Planner)
├── Models/
│   ├── Artist.swift             # Codable struct — loaded from JSON
│   ├── UserArtistData.swift     # SwiftData model — ratings, notes, bookmarks
│   └── ArtistStore.swift        # Loads artists.json, EnvironmentObject
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
│   └── Shared/
│       └── Components.swift     # WaveBadge, TypeBadge, FilterChip, GenreTag…
├── Theme/
│   └── AppTheme.swift           # Color palette, Color(hex:) extension
└── Resources/
    └── artists.json             # Artist data — single source of truth
```

## Updating Artist Data

All artist data lives in `Rewire2026/Resources/artists.json`. The source HTML is at `~/Downloads/rewire_2026_table.html`.

### Adding new announcement waves

1. Update `~/Downloads/rewire_2026_table.html` with the new artist rows
2. Run the parser:
   ```bash
   cd ~/Developer/Rewire2026
   python3 scripts/parse_lineup.py 2>/dev/null > Rewire2026/Resources/artists.json
   ```
3. Rebuild in Xcode (⌘R)

### When the timetable drops

1. Update `artists.json` manually (or extend the Python parser) to populate these fields on each artist:
   ```json
   "day": "Friday",
   "stage": "Korzo",
   "startTime": "22:30",
   "endTime": "23:30"
   ```
2. Rebuild — the Planner tab automatically switches from the "coming soon" placeholder to a schedule grid once any artist has a `day` value.

## Data Model

### Artist (from JSON — static, updatable by rebuilding)

| Field | Type | Notes |
|---|---|---|
| `id` | String | Slugified name, stable unique key |
| `name` | String | Display name |
| `subtitle` | String | Project name or alias |
| `wave` | Int | 1, 2, or 3 |
| `performanceType` | String | Live / DJ Set / Installation / World Premiere… |
| `genres` | [String] | Comma-split from source |
| `latestRelease` | String | Most recent record |
| `recommendedRelease` | String | Best entry point |
| `description` | String | Notes/context |
| `day` | String? | nil until timetable drops |
| `stage` | String? | nil until timetable drops |
| `startTime` | String? | "22:30" format |
| `endTime` | String? | "23:30" format |
| `requiresPlusTicket` | Bool | Einstürzende Neubauten, OPN |

### UserArtistData (SwiftData — persisted on device)

| Field | Type | Notes |
|---|---|---|
| `artistId` | String | Foreign key → `Artist.id` |
| `mustSeeRating` | Int | 0 = unrated, 1–5 |
| `personalNotes` | String | Free text, saves on type |
| `isBookmarked` | Bool | Appears in My List and Planner |

## Design

Matches the HTML table's aesthetic:

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

## Future: Remote JSON

If rebuilding for data updates becomes annoying, the architecture already supports remote JSON. Change `ArtistStore.load()` to fetch from a URL (e.g. a GitHub Gist) instead of `Bundle.main` — the `Artist` model is identical, so nothing else needs to change.
