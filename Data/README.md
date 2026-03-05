# rewire-2026 data

Lineup data pipeline for Rewire 2026 (9–12 Apr, The Hague).

## Structure

```
lineup.yaml       ← source of truth — edit this
lineup.json       ← compiled output (generated, don't edit)
build.py          ← yaml → json compiler
fill_gaps.py      ← gap detection and data-fill workflow
index.html        ← web viewer (loads lineup.json via fetch)
```

## Data Model

The YAML has two top-level collections:

### `artists` — individual artists keyed by slug

```yaml
artists:
  actress:
    name: Actress
    genres: "IDM, Dub Techno, Glitch, Ambient, Abstract Hip-Hop"
    latest:
      title: Darren J. Cunningham / Statik
      year: 2024
      label: Smalltown Supersound
    top_rated:
      title: Splazsh
      year: 2010
      rating: 3.47
      votes: 3494
    notes: Free text bio paragraph.
```

Each artist holds their own genres, discography, and notes — independently
of which slot(s) they appear in.

### `slots` — scheduled performances

```yaml
slots:
  - display_name: "Actress & Suzanne Ciani"
    day: Fri                     # Thu | Fri | Sat | Sun  (or null)
    time: "22:00"                # 24h format (or null)
    stage: Rewire Main           # venue/stage (or null)
    wave: W1
    world_premiere: true         # bool — separate from type
    type: Live A/V               # Live | DJ Set | Installation | Live A/V… (or null)
    is_collab: true
    artist_ids: [actress, suzanne-ciani]
    project: "'Concrète Waves'"
    collab_notes: "World premiere. Actress's R&B concrète meets Ciani's Buchla synthesis."
    collab_latest:               # optional: release by the collab itself
      title: Concrète Waves
      year: 2026
```

A slot references one or more artists via `artist_ids`. For solo/band acts,
there's a single ID. For collabs (`is_collab: true`), each participant is
a separate artist entry with their own genres and releases.

This means:
- **Moor Mother** appears in 3 slots (Sumac & Moor Mother, Cello Octet
  Amsterdam feat. Shishani & Moor Mother, solo) but her genres and releases
  are stored once.
- **Caterina Barbieri** appears in 2 slots (with MFO, with ONCEIM) with
  the same artist data.

## Workflow

### 1. Edit data
Open `lineup.yaml` and edit freely. YAML supports comments (`#`).

### 2. Compile

```bash
python build.py           # one-shot compile
python build.py --watch   # auto-rebuild on save (pip install watchdog)
```

### 3. View in browser

```bash
python -m http.server 8000
# open http://localhost:8000
```

Or use VS Code Live Server. The page won't load from `file://` due to CORS.

### 4. Sync to iOS app

```bash
cp lineup.json ../Rewire2026/Resources/lineup.json
# then rebuild in Xcode (⌘R)
```

### 5. Fill data gaps

`fill_gaps.py` detects missing fields and supports a Claude Code export/apply
workflow — no Anthropic API credits required.

```bash
# See what's missing across all fields (no changes made)
python fill_gaps.py --dry-run

# Export gaps for a field as JSON (for Claude Code to research)
python fill_gaps.py --field notes --export /tmp/notes_gaps.json
python fill_gaps.py --field genres --export /tmp/genre_gaps.json
python fill_gaps.py --field perf_type --export /tmp/perf_type_gaps.json
python fill_gaps.py --field top_rated --export /tmp/rym_gaps.json

# Apply a filled JSON back to lineup.yaml
python fill_gaps.py --field notes --apply /tmp/notes_results.json
python fill_gaps.py --field perf_type --apply /tmp/perf_type_results.json

# After filling, recompile
python build.py
```

#### Supported fields

| `--field` | Detects | Fills |
|---|---|---|
| `notes` | artists with no bio or < 20 chars | `notes` string |
| `genres` | artists with < 3 genres | `genres` string |
| `top_rated` | missing RYM top-rated release | `top_rated` block |
| `latest` | missing latest release | `latest` block |
| `perf_type` | World Premiere slots with no `type` | `type` string |

#### Apply JSON format

For `notes` / `genres`:
```json
[
  { "slug": "actress", "notes": "Bio text…", "genres": "IDM, Dub Techno, Glitch" }
]
```

For `perf_type`:
```json
[
  { "display_name": "Actress & Suzanne Ciani", "type": "Live A/V" }
]
```

## Swift App

The compiled `lineup.json` maps to Swift `Codable` structs:

```swift
struct Release: Codable {
    let title: String?
    let year: Int?
    let label: String?
    let artist: String?
    let note: String?
    let rating: Double?
    let votes: Int?
}

struct Artist: Codable {
    let name: String
    let genres: String?
    let latest: Release?
    let topRated: Release?   // JSON key: top_rated
    let notes: String?
}

struct Slot: Codable {
    let displayName: String  // JSON: display_name
    let day: String?
    let time: String?
    let stage: String?
    let wave: String         // "W1" | "W2" | "W3"
    let worldPremiere: Bool  // JSON: world_premiere
    let type: String?
    let isCollab: Bool       // JSON: is_collab
    let artistIds: [String]  // JSON: artist_ids
    let project: String?
    let collabNotes: String? // JSON: collab_notes
    let collabLatest: Release?
    let collabTopRated: Release?
}

struct Lineup: Codable {
    let artists: [String: Artist]  // slug → Artist
    let slots: [Slot]
}
```

Load with:
```swift
let data = try Data(contentsOf: Bundle.main.url(forResource: "lineup", withExtension: "json")!)
let lineup = try JSONDecoder().decode(Lineup.self, from: data)

// Resolve a collab's participants:
for slot in lineup.slots where slot.isCollab {
    let participants = slot.artistIds.compactMap { lineup.artists[$0] }
    // Each participant has their own .genres, .latest, .topRated
}
```
