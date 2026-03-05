#!/usr/bin/env python3
"""
fill_gaps.py — gap detection and data filling for lineup.yaml

Two workflows are supported:

  A) Claude Code workflow (no API credits needed — uses Claude Max subscription):
       python fill_gaps.py --dry-run              # show all gaps across all fields
       python fill_gaps.py --field notes --export gaps.json
       # → Claude Code reads gaps.json, researches each entry, writes results.json
       python fill_gaps.py --field notes --apply results.json

  B) Anthropic API workflow (requires API credits):
       python fill_gaps.py --field notes          # fill via API calls

  --export <file>   Write gap data as JSON for Claude Code to research
  --apply  <file>   Read filled JSON from Claude Code and write to lineup.yaml
  --dry-run         Show gap summary without writing anything
  --field           One of: latest, top_rated, genres, timetable, notes, perf_type
  --artist          Target a single artist by name (substring match)
"""

import json
import os
import re
import sys
import time
import pathlib
import argparse
import urllib.request
import yaml

# Load .env from repo root if present
_env_path = pathlib.Path(__file__).parent.parent / ".env"
if _env_path.exists():
    for _line in _env_path.read_text().splitlines():
        _line = _line.strip()
        if _line and not _line.startswith("#") and "=" in _line:
            _k, _, _v = _line.partition("=")
            os.environ.setdefault(_k.strip(), _v.strip())

ROOT  = pathlib.Path(__file__).parent
SRC   = ROOT / "lineup.yaml"
MODEL = "claude-sonnet-4-20250514"


def _get_client():
    """Lazy-load Anthropic client — only needed for API workflow."""
    try:
        import anthropic
        return anthropic.Anthropic()
    except ImportError:
        print("anthropic package not installed. API workflow unavailable.")
        sys.exit(1)


# ─── Helpers ──────────────────────────────────────────────────────────────────

def load_yaml() -> dict:
    with open(SRC, encoding="utf-8") as f:
        return yaml.safe_load(f)


def save_yaml(data: dict):
    """Write back to lineup.yaml, preserving header comments."""
    with open(SRC, encoding="utf-8") as f:
        raw = f.read()

    # Preserve the comment block at the top
    header_lines = []
    for line in raw.splitlines():
        if line.startswith("#") or line == "":
            header_lines.append(line)
        else:
            break
    header = "\n".join(header_lines) + "\n\n" if header_lines else ""

    dumped = yaml.dump(
        data,
        allow_unicode=True,
        default_flow_style=False,
        sort_keys=False,
        indent=2,
        width=120,
    )
    with open(SRC, "w", encoding="utf-8") as f:
        f.write(header + dumped)


def rewire_slug(name: str) -> str:
    """Convert a name to a Rewire website URL slug."""
    slug = name.lower()
    slug = re.sub(r"[',\.]", "", slug)
    slug = slug.replace(" & ", "--")
    slug = re.sub(r"\s+", "-", slug)
    return slug


def is_visual_artist(artist: dict) -> bool:
    """Return True if the artist is primarily a visual/installation artist."""
    genres = (artist.get("genres") or "").lower()
    return any(x in genres for x in ["visual art", "light art", "film", "a/v"])


def has_gap(artist: dict, field: str) -> bool:
    """Return True if the given field (latest or top_rated) is missing key info."""
    # Skip visual artists — they won't have RYM pages
    if is_visual_artist(artist):
        return False

    entry = artist.get(field)
    if not entry:
        return True
    if field == "top_rated":
        return not entry.get("rating") or not entry.get("votes")
    if field == "latest":
        return not entry.get("year") and not entry.get("title")
    return False


def gaps_for(artist: dict, target_field: str | None) -> list[str]:
    """Return list of field names that have gaps for this artist."""
    fields = ["latest", "top_rated"] if target_field is None else [target_field]
    return [f for f in fields if has_gap(artist, f)]


# ─── API call ─────────────────────────────────────────────────────────────────

SYSTEM_PROMPT = """You are a music data researcher specialising in RateYourMusic (RYM).
Given an artist name and what data is missing, search RYM and return ONLY a JSON object
(no markdown, no preamble) with this exact structure:

{
  "latest": {
    "title": "Album Title",
    "year": 2025,
    "label": "Label Name",          // optional
    "artist": "If different",       // optional — omit if same as input artist
    "note": "e.g. #42 of 2025",    // optional
    "rating": 3.47,                 // optional — RYM score if available
    "votes": 1234                   // optional — number of RYM ratings
  },
  "top_rated": {
    "title": "Best Album Title",
    "year": 2019,
    "label": "Label Name",          // optional
    "artist": "If different",       // optional
    "note": "e.g. #113 of year",   // optional
    "rating": 3.82,                 // RYM score — always include if found
    "votes": 4500                   // always include if found
  }
}

Rules:
- Only include keys for the fields you were asked to fill.
- If you genuinely cannot find data (e.g. no RYM page, no discography), return
  {"not_found": true, "reason": "brief explanation"}.
- For "latest": the most recently released album, EP, or mix — not a reissue.
- For "top_rated": the single highest-rated entry on their RYM artist page.
- Ratings should be the RYM weighted score (e.g. 3.47), not Metacritic or Pitchfork.
- votes should be the integer count of RYM ratings.
- Year should be an integer, not a string.
"""


def search_rym(artist: dict, missing_fields: list[str]) -> dict | None:
    """
    Call Claude with web_search to look up RYM data for the given artist.
    Returns a dict with 'latest' and/or 'top_rated' keys, or None on failure.
    """
    name = artist["name"]
    field_desc = " and ".join(f"**{f}**" for f in missing_fields)
    genres = artist.get("genres", "")
    hint = f" (genres: {genres})" if genres else ""

    prompt = (
        f"Look up the RateYourMusic page for artist: {name}{hint}\n\n"
        f"I need to fill in the following missing data: {field_desc}\n\n"
        "Search RYM, find the relevant page, and return the JSON as instructed."
    )

    try:
        response = _get_client().messages.create(
            model=MODEL,
            max_tokens=1000,
            system=SYSTEM_PROMPT,
            tools=[{"type": "web_search_20250305", "name": "web_search"}],
            messages=[{"role": "user", "content": prompt}],
        )

        text = ""
        for block in response.content:
            if hasattr(block, "text"):
                text += block.text

        text = text.strip()
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)

        result = json.loads(text)
        if result.get("not_found"):
            print(f"  ↳ not found: {result.get('reason', 'no reason given')}")
            return None
        return result

    except json.JSONDecodeError as e:
        print(f"  ✗ JSON parse error: {e}")
        print(f"    Raw response: {text[:300]}")
        return None
    except Exception as e:
        print(f"  ✗ API error: {e}")
        return None


GENRES_SYSTEM_PROMPT = """You are a music genre researcher specialising in RateYourMusic (RYM) genre taxonomy.
Given an artist name, identify their primary musical genres.
Return ONLY a JSON object (no markdown, no preamble):

{"genres": "Genre1, Genre2, Genre3"}

Rules:
- Use RateYourMusic genre terminology where possible (e.g. "IDM", "Deconstructed Club", "Electroacoustic").
- List 2–5 genres, comma-separated, most prominent first.
- If you genuinely cannot identify the artist, return:
  {"not_found": true, "reason": "brief explanation"}
"""


def search_genres(artist: dict) -> dict | None:
    """Call Claude with web_search to find genre tags for the given artist."""
    name = artist["name"]
    prompt = (
        f"Find the primary musical genres for artist: {name}\n\n"
        "Search RateYourMusic and any relevant sources, then return the JSON as instructed."
    )
    try:
        response = _get_client().messages.create(
            model=MODEL,
            max_tokens=300,
            system=GENRES_SYSTEM_PROMPT,
            tools=[{"type": "web_search_20250305", "name": "web_search"}],
            messages=[{"role": "user", "content": prompt}],
        )
        text = ""
        for block in response.content:
            if hasattr(block, "text"):
                text += block.text
        text = text.strip()
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
        result = json.loads(text)
        if result.get("not_found"):
            print(f"  ↳ not found: {result.get('reason', 'no reason given')}")
            return None
        return result
    except json.JSONDecodeError as e:
        print(f"  ✗ JSON parse error: {e}")
        print(f"    Raw response: {text[:300]}")
        return None
    except Exception as e:
        print(f"  ✗ API error: {e}")
        return None


NOTES_SYSTEM_PROMPT = """You are compiling artist data for a music festival app.
Given an artist name, search for their Rewire 2026 festival page first
(https://www.rewirefestival.nl/artist/...) then any other reliable sources.

Return ONLY a JSON object (no markdown, no preamble):

{
  "notes": "1-2 sentence bio here.",
  "genres": "Genre1, Genre2, Genre3"
}

Rules for notes:
- Be specific and vivid — mention sonic character, key influences, cultural context, or what makes them distinctive.
- Do NOT use marketing superlatives ("groundbreaking", "visionary", "pioneering").
- Prefer information from the Rewire festival page where available.
- Write in present tense, third person. Aim for under 200 characters.

Rules for genres:
- Use RateYourMusic genre terminology (e.g. "IDM", "Deconstructed Club", "Electroacoustic", "Noise").
- List 2–5 genres, comma-separated, most prominent first.
- Only include "genres" if you find reliable genre information — omit the key if uncertain.
- If the existing genres supplied look correct, you may omit the key.

If you genuinely cannot find anything about this artist, return:
  {"not_found": true, "reason": "brief explanation"}
"""


def search_notes(artist: dict, slug: str) -> dict | None:
    name = artist["name"]
    genres = artist.get("genres", "")
    rewire_url = f"https://www.rewirefestival.nl/artist/{slug}"
    prompt = (
        f"Artist: {name}\n"
        f"Current genres in our database: {genres or '(none)'}\n"
        f"Rewire 2026 page: {rewire_url}\n\n"
        "Search their Rewire page and other sources. Return the JSON as instructed, "
        "correcting genres if the page shows something different from what we have."
    )
    try:
        response = _get_client().messages.create(
            model=MODEL,
            max_tokens=400,
            system=NOTES_SYSTEM_PROMPT,
            tools=[{"type": "web_search_20250305", "name": "web_search"}],
            messages=[{"role": "user", "content": prompt}],
        )
        text = ""
        for block in response.content:
            if hasattr(block, "text"):
                text += block.text
        text = text.strip()
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
        result = json.loads(text)
        if result.get("not_found"):
            print(f"  ↳ not found: {result.get('reason', 'no reason given')}")
            return None
        return result
    except json.JSONDecodeError as e:
        print(f"  ✗ JSON parse error: {e}")
        return None
    except Exception as e:
        print(f"  ✗ API error: {e}")
        return None


NOTES_MIN_LENGTH = 60  # notes shorter than this are treated as gaps
NOTES_SKIP_PHRASES = ["minimal public discography", "laak club programme", "proximity music"]
THIN_THRESHOLD = 3


def needs_notes_fill(artist: dict) -> bool:
    notes = (artist.get("notes") or "").strip()
    if not notes:
        return True
    if len(notes) < NOTES_MIN_LENGTH:
        return True
    return False


def needs_genre_fill(artist: dict) -> bool:
    g = artist.get("genres") or ""
    if not g:
        return True
    if is_visual_artist(artist):
        return False
    return len([x for x in g.split(",") if x.strip()]) < THIN_THRESHOLD


def needs_perf_type_fill(slot: dict) -> bool:
    return bool(slot.get("world_premiere")) and not slot.get("type")


def run_notes(data: dict, args):
    """Fill missing or stub artist notes/descriptions using web_search."""
    artists = data["artists"]

    if args.artist:
        targets = {s: a for s, a in artists.items() if args.artist.lower() in a["name"].lower()}
        if not targets:
            print(f"No artist matching '{args.artist}' found.")
            sys.exit(1)
    else:
        targets = artists

    to_process = [
        (slug, a) for slug, a in targets.items()
        if needs_notes_fill(a)
        and not any(p in (a.get("notes") or "").lower() for p in NOTES_SKIP_PHRASES)
    ]

    if not to_process:
        print("✓ No notes gaps found!")
        return

    print(f"Found {len(to_process)} artist(s) with missing or short notes:\n")
    total_changes = 0

    for i, (slug, artist) in enumerate(to_process, 1):
        name = artist["name"]
        existing = (artist.get("notes") or "").strip()
        status = "(missing)" if not existing else f"(short: {existing!r})"
        print(f"[{i}/{len(to_process)}] {name} ({slug}) {status}")

        if args.dry_run:
            print("  (dry-run — skipping API call)")
            continue

        result = search_notes(artist, rewire_slug(name))
        if result and "notes" in result:
            artist["notes"] = result["notes"]
            print(f"  ✓ notes = {result['notes']!r}")
            total_changes += 1
            if "genres" in result and result["genres"] != artist.get("genres"):
                old_genres = artist.get("genres") or "(none)"
                artist["genres"] = result["genres"]
                print(f"  ✓ genres updated: {old_genres!r} → {result['genres']!r}")
        else:
            print("  ↳ skipping")

        if i < len(to_process):
            time.sleep(1)

    if not args.dry_run and total_changes > 0:
        save_yaml(data)
        print(f"\n✓ Wrote notes for {total_changes} artist(s) → {SRC}")
        print("  Run  python build.py  to regenerate lineup.json")
    elif not args.dry_run:
        print("\n↳ No changes to write.")


REWIRE_DAY_URLS = {
    "Thu": "https://www.rewirefestival.nl/line/up/2026?date=Thu%209%20April",
    "Fri": "https://www.rewirefestival.nl/line/up/2026?date=Fri%2010%20April",
    "Sat": "https://www.rewirefestival.nl/line/up/2026?date=Sat%2011%20April",
    "Sun": "https://www.rewirefestival.nl/line/up/2026?date=Sun%2012%20April",
}

PARSE_DAY_PROMPT = """Extract all performer and artist names listed on this Rewire festival day page.
Return ONLY a JSON array of display name strings, exactly as they appear on the page:

["Artist Name 1", "Artist Name 2", ...]

If no performers are found, return [].
Do not include venue names, stage names, or descriptive text — only performer names."""


def fetch_artists_for_day(day: str, url: str) -> list[str]:
    """Fetch a Rewire day page and return list of performer display names."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            html = resp.read().decode("utf-8", errors="replace")
    except Exception as e:
        print(f"  ✗ Failed to fetch {day} page: {e}")
        return []

    # Truncate to avoid token limits; the lineup section is near the top
    if len(html) > 60000:
        html = html[:60000]

    try:
        response = _get_client().messages.create(
            model=MODEL,
            max_tokens=1000,
            messages=[{"role": "user", "content": f"{PARSE_DAY_PROMPT}\n\nHTML:\n{html}"}],
        )
        text = response.content[0].text.strip()
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
        names = json.loads(text)
        return names if isinstance(names, list) else []
    except Exception as e:
        print(f"  ✗ Failed to parse {day} page: {e}")
        return []


# ─── Genre and timetable runners ──────────────────────────────────────────────

def run_genres(data: dict, args):
    """Fill missing genres for artists using web_search."""
    artists = data["artists"]

    if args.artist:
        targets = {s: a for s, a in artists.items() if args.artist.lower() in a["name"].lower()}
        if not targets:
            print(f"No artist matching '{args.artist}' found.")
            sys.exit(1)
    else:
        targets = artists

    to_process = [(slug, a) for slug, a in targets.items() if needs_genre_fill(a)]

    if not to_process:
        print("✓ No genre gaps — all artists have genres!")
        return

    print(f"Found {len(to_process)} artist(s) missing genres:\n")
    total_changes = 0

    for i, (slug, artist) in enumerate(to_process, 1):
        name = artist["name"]
        print(f"[{i}/{len(to_process)}] {name} ({slug})")

        if args.dry_run:
            print("  (dry-run — skipping API call)")
            continue

        result = search_genres(artist)
        if result and "genres" in result:
            artist["genres"] = result["genres"]
            print(f"  ✓ genres = {result['genres']!r}")
            total_changes += 1
        else:
            print("  ↳ skipping")

        if i < len(to_process):
            time.sleep(1)

    if not args.dry_run and total_changes > 0:
        save_yaml(data)
        print(f"\n✓ Wrote genres for {total_changes} artist(s) → {SRC}")
        print("  Run  python build.py  to regenerate lineup.json")
    elif not args.dry_run:
        print("\n↳ No changes to write.")


def run_timetable(data: dict, args):
    """Fill missing slot days by scraping the Rewire day pages.
    Note: time and stage are not available from the website — only day is filled.
    """
    slots = data["slots"]

    day_gaps   = [s for s in slots if s.get("day")   is None]
    time_gaps  = [s for s in slots if s.get("time")  is None]
    stage_gaps = [s for s in slots if s.get("stage") is None]

    if not day_gaps and not time_gaps and not stage_gaps:
        print("✓ No timetable gaps — all slots are complete!")
        return

    print(f"Timetable gap summary:")
    print(f"  day  : {len(day_gaps)} slot(s) missing")
    print(f"  time : {len(time_gaps)} slot(s) missing  (not auto-fillable — check official timetable)")
    print(f"  stage: {len(stage_gaps)} slot(s) missing  (not auto-fillable — check official timetable)")

    if not day_gaps:
        print("\n✓ All slot days are already filled.")
        return

    print(f"\nWill attempt to fill {len(day_gaps)} missing day(s).")

    if args.dry_run:
        print("\nSlots missing day:")
        for slot in day_gaps:
            print(f"  {slot['display_name']}")
        return

    # Fetch all 4 day pages and build lowercased name → day mapping
    print("\nFetching Rewire day pages…")
    name_to_day: dict[str, str] = {}
    for day, url in REWIRE_DAY_URLS.items():
        print(f"  Fetching {day}…", end=" ", flush=True)
        names = fetch_artists_for_day(day, url)
        print(f"{len(names)} performers found")
        for name in names:
            name_to_day[name.lower()] = day

    # Match slots and apply
    print()
    total_changes = 0
    unmatched = []
    for slot in day_gaps:
        display = slot["display_name"]
        day = name_to_day.get(display.lower())
        if day:
            slot["day"] = day
            print(f"  ✓ {display}: day = {day!r}")
            total_changes += 1
        else:
            unmatched.append(display)

    if unmatched:
        print(f"\n  ? Not matched ({len(unmatched)}) — check names against website manually:")
        for name in unmatched:
            print(f"      {name}")

    if total_changes > 0:
        save_yaml(data)
        print(f"\n✓ Wrote {total_changes} day update(s) → {SRC}")
        print("  Run  python build.py  to regenerate lineup.json")
    else:
        print("\n↳ No changes to write.")


PERF_TYPE_SYSTEM_PROMPT = """You are a music festival researcher.
Given a performer or ensemble appearing at Rewire 2026 in The Hague (April 2026),
determine the format of their performance.

Return ONLY a JSON object (no markdown, no preamble):
{"type": "Live A/V"}

Valid type values include: Live, Live A/V, DJ Set, Installation, Performance,
Lecture, Film Screening, Live Set, Audiovisual Performance, etc.
Use the most specific accurate term you can find.

If you genuinely cannot determine the performance format, return:
{"not_found": true, "reason": "brief explanation"}
"""


def search_perf_type(slot: dict) -> dict | None:
    """Call Claude with web_search to find the real performance type for a WP slot."""
    name = slot["display_name"]
    notes = slot.get("collab_notes") or slot.get("project") or ""
    prompt = (
        f"Performer: {name}\n"
        f"Context: World Premiere performance at Rewire 2026 (The Hague, April 2026)\n"
        + (f"Notes: {notes}\n" if notes else "")
        + "\nWhat is the performance format (Live, Live A/V, DJ Set, Installation, etc.)? "
        "Search the Rewire 2026 website and any press coverage, then return the JSON."
    )
    try:
        response = _get_client().messages.create(
            model=MODEL,
            max_tokens=200,
            system=PERF_TYPE_SYSTEM_PROMPT,
            tools=[{"type": "web_search_20250305", "name": "web_search"}],
            messages=[{"role": "user", "content": prompt}],
        )
        text = ""
        for block in response.content:
            if hasattr(block, "text"):
                text += block.text
        text = text.strip()
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
        result = json.loads(text)
        if result.get("not_found"):
            print(f"  ↳ not found: {result.get('reason', 'no reason given')}")
            return None
        return result
    except json.JSONDecodeError as e:
        print(f"  ✗ JSON parse error: {e}")
        return None
    except Exception as e:
        print(f"  ✗ API error: {e}")
        return None


def run_perf_type(data: dict, args):
    """Find World Premiere slots with no performance type and fill them in."""
    slots = data["slots"]

    to_fill = [s for s in slots if s.get("world_premiere") and not s.get("type")]

    if not to_fill:
        print("✓ All World Premiere slots already have a performance type!")
        return

    print(f"Found {len(to_fill)} World Premiere slot(s) with no performance type:\n")
    for s in to_fill:
        print(f"  {s['display_name']}")

    if args.dry_run:
        return

    print()
    total_changes = 0
    for i, slot in enumerate(to_fill, 1):
        name = slot["display_name"]
        print(f"[{i}/{len(to_fill)}] {name}")

        result = search_perf_type(slot)
        if result and "type" in result:
            slot["type"] = result["type"]
            print(f"  ✓ type = {result['type']!r}")
            total_changes += 1
        else:
            print("  ↳ skipping")

        if i < len(to_fill):
            time.sleep(1)

    if total_changes > 0:
        save_yaml(data)
        print(f"\n✓ Wrote {total_changes} performance type(s) → {SRC}")
        print("  Run  python build.py  to regenerate lineup.json")
    else:
        print("\n↳ No changes to write.")


# ─── Full gap summary ─────────────────────────────────────────────────────────

def run_summary(data: dict):
    """Print a gap summary across all fields."""
    artists = data["artists"]
    slots   = data["slots"]

    # RYM gaps
    rym_gaps = [
        (a["name"], gaps_for(a, None))
        for a in artists.values()
        if gaps_for(a, None)
    ]
    # Genre gaps
    genre_gaps = [a["name"] for a in artists.values() if needs_genre_fill(a)]
    # Notes gaps
    notes_gaps = [
        a["name"] for a in artists.values()
        if needs_notes_fill(a)
        and not any(p in (a.get("notes") or "").lower() for p in NOTES_SKIP_PHRASES)
    ]
    # Perf type gaps
    perf_gaps = [s["display_name"] for s in slots if needs_perf_type_fill(s)]
    # Timetable gaps
    day_gaps   = [s["display_name"] for s in slots if s.get("day")   is None]
    time_gaps  = [s["display_name"] for s in slots if s.get("time")  is None]
    stage_gaps = [s["display_name"] for s in slots if s.get("stage") is None]

    print("═" * 60)
    print("  GAP SUMMARY")
    print("═" * 60)

    print(f"\n▸ RYM (latest / top_rated)  — {len(rym_gaps)} artist(s)")
    for name, missing in rym_gaps:
        print(f"    {name}  [{', '.join(missing)}]")

    print(f"\n▸ Genres (< {THIN_THRESHOLD})  — {len(genre_gaps)} artist(s)")
    for name in genre_gaps:
        print(f"    {name}")

    print(f"\n▸ Notes (missing / short)  — {len(notes_gaps)} artist(s)")
    for name in notes_gaps:
        print(f"    {name}")

    print(f"\n▸ Perf type (World Premiere, no type)  — {len(perf_gaps)} slot(s)")
    for name in perf_gaps:
        print(f"    {name}")

    print(f"\n▸ Timetable")
    print(f"    day  : {len(day_gaps)} slot(s) missing")
    print(f"    time : {len(time_gaps)} slot(s) missing")
    print(f"    stage: {len(stage_gaps)} slot(s) missing")

    total = len(rym_gaps) + len(genre_gaps) + len(notes_gaps) + len(perf_gaps)
    print(f"\n{'═' * 60}")
    print(f"  {total} artist/slot gaps across RYM, genres, notes, perf_type")
    print(f"  (timetable gaps excluded — awaiting official release)")
    print("═" * 60)


# ─── Main loop ────────────────────────────────────────────────────────────────

def apply_result(artist: dict, result: dict) -> dict:
    """Merge API result into the artist dict. Returns a dict of changes made."""
    changes = {}
    for field in ("latest", "top_rated"):
        if field not in result:
            continue
        new = result[field]
        old = artist.get(field) or {}
        updated = dict(old)
        for key, val in new.items():
            if key not in old or old[key] is None:
                updated[key] = val
                changes[f"{field}.{key}"] = val
        artist[field] = updated
    return changes


def run(args):
    data = load_yaml()

    if args.export:
        run_export(data, args)
        return
    if args.apply:
        run_apply(data, args)
        return

    if args.dry_run and args.field is None:
        run_summary(data)
        return

    if args.field == "genres":
        run_genres(data, args)
        return
    if args.field == "timetable":
        run_timetable(data, args)
        return
    if args.field == "notes":
        run_notes(data, args)
        return
    if args.field == "perf_type":
        run_perf_type(data, args)
        return

    artists = data["artists"]

    # Filter by artist name if requested
    if args.artist:
        targets = {
            slug: a for slug, a in artists.items()
            if args.artist.lower() in a["name"].lower()
        }
        if not targets:
            print(f"No artist matching '{args.artist}' found.")
            sys.exit(1)
    else:
        targets = artists

    # Find which artists actually have gaps
    to_process = [
        (slug, a, gaps_for(a, args.field))
        for slug, a in targets.items()
    ]
    to_process = [(slug, a, gaps) for slug, a, gaps in to_process if gaps]

    if not to_process:
        print("✓ No gaps found — all artists are complete!")
        return

    print(f"Found {len(to_process)} artist(s) with gaps:\n")
    total_changes = 0

    for i, (slug, artist, missing) in enumerate(to_process, 1):
        name = artist["name"]
        print(f"[{i}/{len(to_process)}] {name} ({slug})  (missing: {', '.join(missing)})")

        if args.dry_run:
            print("  (dry-run — skipping API call)")
            continue

        result = search_rym(artist, missing)
        if result:
            changes = apply_result(artist, result)
            if changes:
                for k, v in changes.items():
                    print(f"  ✓ {k} = {v!r}")
                total_changes += len(changes)
            else:
                print("  ↳ no new fields added (already complete or data not found)")
        else:
            print("  ↳ skipping")

        if i < len(to_process):
            time.sleep(1)

    if not args.dry_run and total_changes > 0:
        save_yaml(data)
        print(f"\n✓ Wrote {total_changes} updates → {SRC}")
        print("  Run  python build.py  to regenerate lineup.json")
    elif not args.dry_run:
        print("\n↳ No changes to write.")


# ─── Export / Apply (Claude Code workflow) ────────────────────────────────────

def run_export(data: dict, args):
    """Write gap data to a JSON file for Claude Code to research and fill."""
    field = args.field
    if not field:
        print("--export requires --field to be specified.")
        sys.exit(1)

    artists = data["artists"]
    slots   = data["slots"]
    out_path = pathlib.Path(args.export)

    if field == "notes":
        targets = {s: a for s, a in artists.items() if args.artist is None or args.artist.lower() in a["name"].lower()}
        rows = [
            {
                "slug": slug,
                "name": a["name"],
                "existing_notes": (a.get("notes") or "").strip(),
                "existing_genres": (a.get("genres") or "").strip(),
                "rewire_url": f"https://www.rewirefestival.nl/artist/{rewire_slug(a['name'])}",
            }
            for slug, a in targets.items()
            if needs_notes_fill(a)
            and not any(p in (a.get("notes") or "").lower() for p in NOTES_SKIP_PHRASES)
        ]
        desc = f"{len(rows)} artist(s) needing notes"

    elif field == "genres":
        targets = {s: a for s, a in artists.items() if args.artist is None or args.artist.lower() in a["name"].lower()}
        rows = [
            {
                "slug": slug,
                "name": a["name"],
                "existing_genres": (a.get("genres") or "").strip(),
                "rewire_url": f"https://www.rewirefestival.nl/artist/{rewire_slug(a['name'])}",
            }
            for slug, a in targets.items()
            if needs_genre_fill(a)
        ]
        desc = f"{len(rows)} artist(s) needing genres"

    elif field == "perf_type":
        rows = [
            {
                "display_name": s["display_name"],
                "rewire_url": f"https://www.rewirefestival.nl/artist/{rewire_slug(s['display_name'])}",
                "collab_notes": s.get("collab_notes") or "",
                "project": s.get("project") or "",
            }
            for s in slots
            if needs_perf_type_fill(s)
        ]
        desc = f"{len(rows)} slot(s) needing performance type"

    elif field in ("latest", "top_rated"):
        targets = {s: a for s, a in artists.items() if args.artist is None or args.artist.lower() in a["name"].lower()}
        rows = [
            {
                "slug": slug,
                "name": a["name"],
                "existing_genres": (a.get("genres") or "").strip(),
                "missing": gaps_for(a, field),
                "existing_latest": a.get("latest"),
                "existing_top_rated": a.get("top_rated"),
            }
            for slug, a in targets.items()
            if gaps_for(a, field)
        ]
        desc = f"{len(rows)} artist(s) with RYM gaps"

    else:
        print(f"--export not supported for --field {field}")
        sys.exit(1)

    out_path.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"✓ Exported {desc} → {out_path}")
    print(f"\nNext step: have Claude Code research each entry and produce a results JSON,")
    print(f"then run:  python fill_gaps.py --field {field} --apply <results.json>")


def run_apply(data: dict, args):
    """Read a Claude-Code-filled JSON file and write results to lineup.yaml."""
    field = args.field
    if not field:
        print("--apply requires --field to be specified.")
        sys.exit(1)

    in_path = pathlib.Path(args.apply)
    if not in_path.exists():
        print(f"File not found: {in_path}")
        sys.exit(1)

    results = json.loads(in_path.read_text(encoding="utf-8"))
    artists = data["artists"]
    slots   = data["slots"]
    total_changes = 0

    if field in ("notes", "genres"):
        for entry in results:
            slug = entry.get("slug")
            if slug not in artists:
                print(f"  ? Unknown slug: {slug!r} — skipping")
                continue
            artist = artists[slug]
            if "notes" in entry and entry["notes"]:
                old = artist.get("notes") or ""
                artist["notes"] = entry["notes"]
                print(f"  ✓ {artist['name']}: notes updated")
                if old:
                    print(f"      was: {old!r}")
                total_changes += 1
            if "genres" in entry and entry["genres"] and entry["genres"] != artist.get("genres"):
                print(f"  ✓ {artist['name']}: genres {artist.get('genres')!r} → {entry['genres']!r}")
                artist["genres"] = entry["genres"]
                total_changes += 1

    elif field == "perf_type":
        slot_map = {s["display_name"]: s for s in slots}
        for entry in results:
            name = entry.get("display_name")
            if name not in slot_map:
                print(f"  ? Unknown slot: {name!r} — skipping")
                continue
            if "type" in entry and entry["type"]:
                slot_map[name]["type"] = entry["type"]
                print(f"  ✓ {name}: type = {entry['type']!r}")
                total_changes += 1

    elif field in ("latest", "top_rated"):
        for entry in results:
            slug = entry.get("slug")
            if slug not in artists:
                print(f"  ? Unknown slug: {slug!r} — skipping")
                continue
            changes = apply_result(artists[slug], entry)
            for k, v in changes.items():
                print(f"  ✓ {artists[slug]['name']}: {k} = {v!r}")
            total_changes += len(changes)

    if total_changes > 0:
        save_yaml(data)
        print(f"\n✓ Applied {total_changes} update(s) → {SRC}")
        print("  Run  python build.py  to regenerate lineup.json")
    else:
        print("\n↳ No changes to write.")


# ─── CLI ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Fill RYM data gaps in lineup.yaml")
    parser.add_argument("--dry-run",  action="store_true", help="Print gap summary without writing anything")
    parser.add_argument("--artist",   type=str, default=None, help="Target a single artist by name (substring match)")
    parser.add_argument("--field",    type=str, default=None,
                        choices=["latest", "top_rated", "genres", "timetable", "notes", "perf_type"],
                        help="Field to fill")
    parser.add_argument("--export",   type=str, default=None, metavar="FILE",
                        help="Export gap data as JSON for Claude Code to research (use with --field)")
    parser.add_argument("--apply",    type=str, default=None, metavar="FILE",
                        help="Apply Claude Code research results from JSON file (use with --field)")
    args = parser.parse_args()
    run(args)
