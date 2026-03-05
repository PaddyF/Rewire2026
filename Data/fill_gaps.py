#!/usr/bin/env python3
"""
fill_gaps.py — uses Claude + web_search to fill missing RYM data in lineup.yaml

What it does:
  - Reads lineup.yaml (artists + slots structure)
  - Finds artists where top_rated.rating (or top_rated.votes) is missing
  - Fires a focused Anthropic API call with web_search for each
  - Writes structured results back into the YAML (preserves comments & ordering)
  - Prints a diff summary of what changed

Usage:
    python fill_gaps.py                   # fill all gaps (latest + top_rated)
    python fill_gaps.py --dry-run         # print what would change, don't write
    python fill_gaps.py --artist "Colleen"  # target a single artist by name
    python fill_gaps.py --field latest    # only fill missing 'latest' entries
    python fill_gaps.py --field top_rated # only fill missing 'top_rated' entries
    python fill_gaps.py --field genres    # fill missing artist genres
    python fill_gaps.py --field timetable # fill missing slot day/time/stage

Requirements:
    pip install anthropic pyyaml

The script expects ANTHROPIC_API_KEY to be set in your environment,
which Claude Code provides automatically.
"""

import json
import os
import re
import sys
import time
import pathlib
import argparse
import urllib.request
import anthropic
import yaml

ROOT  = pathlib.Path(__file__).parent
SRC   = ROOT / "lineup.yaml"
MODEL = "claude-sonnet-4-20250514"

client = anthropic.Anthropic()  # reads ANTHROPIC_API_KEY from env


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
        response = client.messages.create(
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
        response = client.messages.create(
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
        response = client.messages.create(
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

    to_process = [(slug, a) for slug, a in targets.items() if not a.get("genres")]

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

    if args.field == "genres":
        run_genres(data, args)
        return
    if args.field == "timetable":
        run_timetable(data, args)
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


# ─── CLI ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Fill RYM data gaps in lineup.yaml")
    parser.add_argument("--dry-run",  action="store_true", help="Print gaps without calling API")
    parser.add_argument("--artist",   type=str, default=None, help="Target a single artist by name (substring match)")
    parser.add_argument("--field",    type=str, default=None,
                        choices=["latest", "top_rated", "genres", "timetable"],
                        help="Only fill the specified field (genres and timetable use separate data sources)")
    args = parser.parse_args()
    run(args)
