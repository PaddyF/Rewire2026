# rewire-2026

Lineup data and viewer for Rewire 2026 (9–12 Apr, The Hague).

## Structure

```
lineup.yaml       ← source of truth — edit this
lineup.json       ← compiled output (generated, don't edit)
build.py          ← yaml → json compiler
fill_gaps.py      ← Claude Code script: fills missing RYM data
index.html        ← web viewer (loads lineup.json via fetch)
```

## Data Model

The YAML has two top-level collections:

### `artists` — individual artists keyed by slug

```yaml
artists:
  actress:
    name: Actress
    genres: "IDM, Microhouse, Ambient, R&B Concrète"
    latest:
      title: Darren J. Cunningham / Statik
      year: 2024
      label: Smalltown Supersound
    top_rated:
      title: Splazsh
      year: 2010
      rating: 3.47
      votes: 3494
    notes: Free text paragraph.
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
    type: World Premiere
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
  Amsterdam feat. Shishani & Moor Mother, Immaculate Deception Of History)
  but her genres and releases are stored once.
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

Or use VS Code Live Server, etc. The page won't load from `file://` due to CORS.

### 4. Fill data gaps (Claude Code)

```bash
# See what's missing (no API calls)
python fill_gaps.py --dry-run

# Fill all gaps
python fill_gaps.py

# Fill gaps for one artist
python fill_gaps.py --artist "Colleen"

# Only fill missing top_rated ratings
python fill_gaps.py --field top_rated

# After filling, recompile
python build.py
```

`fill_gaps.py` requires the `ANTHROPIC_API_KEY` environment variable,
which Claude Code provides automatically.

```bash
pip install anthropic pyyaml
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
    let topRated: Release?
    let notes: String?
}

struct Slot: Codable {
    let displayName: String
    let day: String?
    let time: String?
    let stage: String?
    let wave: String
    let type: String?
    let isCollab: Bool
    let artistIds: [String]
    let project: String?
    let collabNotes: String?
    let collabLatest: Release?
    let collabTopRated: Release?
}

struct Lineup: Codable {
    let artists: [String: Artist]
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
