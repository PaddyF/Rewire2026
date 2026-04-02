#!/usr/bin/env python3
"""
scrape_timetable.py — fetch timetable data from Prismic CMS and update lineup.yaml

Fetches all artist documents from Prismic, extracts 2026 festival event scheduling
(day, time, stage), fuzzy-matches to our existing slots, and updates lineup.yaml.
"""

import json
import re
import sys
import pathlib
from datetime import datetime, timezone, timedelta
from difflib import SequenceMatcher
from urllib.request import urlopen, Request
from urllib.parse import quote
import yaml

ROOT = pathlib.Path(__file__).parent
SRC = ROOT / "lineup.yaml"

PRISMIC_API = "https://rewirefestival.cdn.prismic.io/api/v2/documents/search"
PRISMIC_REF = "ab02zhEAACQAxd_J"

# Venue ID → display name mapping (from Prismic venue documents)
VENUE_MAP = {
    "ZfHC0RMAAJ5aOS1S": "Amare – Concertzaal",
    "Y-VpthEAACYAh6cU": "Amare – Danstheater",
    "Z9A_txEAACIA9zKF": "Amare – Studio",
    "Z90--BEAACIA84GJ": "Amare – Swing",
    "Z9PucxEAACEAdTdX": "Amare – Jazz I",
    "Z9gRthEAAB8Af9wu": "Amare – Salsa",
    "Z9GX4REAACIA-SbC": "Amare – 6th Floor",
    "abvKCBEAACIAw680": "Amare – Foyer",
    "YASQqBEAAJTq63jc": "Theater aan het Spui – Zaal 1",
    "Y_eE5hAAACAA41BM": "Theater aan het Spui – Zaal 2",
    "ZAniFhAAACQALZfi": "Theater aan het Spui – Foyer",
    "YASQqBEAAJTq63i8": "Korzo – Zaal",
    "Y_d_DRAAACIA4zVt": "Korzo – Studio",
    "ZgP1ZxAAAAoDVDki": "Korzo – Club",
    "ZAjKuhAAACQAK90J": "Korzo",
    "Z-VhVxEAAB4Aj5zT": "PAARD – Foyer",
    "Z9PegREAACAAdR6v": "The Grey Space – Foyer",
    "YASQqBEAAJTq63k6": "The Grey Space – Basement",
    "ZfAoGBMAAPwnMgaq": "The Grey Space – RNDR",
    "ZfAlaBMAALgnMfnU": "The Grey Space – Booth",
    "Z9gX_BEAAB4Af-YE": "West Den Haag – Auditorium",
    "ZfMBqRAAAFcHYLql": "West Den Haag – Alphabetum",
    "ZfMBORAAAL4GYLiY": "West Den Haag – Basement",
    "abu6KhEAACMAw5CQ": "West Den Haag – Hearing Room",
    "abu6VREAACIAw5Dc": "West Den Haag – Engine Room",
    "abu6jREAACMAw5FC": "West Den Haag – Inner Room",
    "Z9PpYhEAAB8AdS-R": "West Den Haag – Booth",
    "abu6qxEAACIAw5F7": "West Den Haag – Entrance",
    "abvFjBEAACIAw6ZC": "West Den Haag – Multiple Rooms",
    "Z8b7UBIAACQAiWsu": "Duitse Kerk",
    "abv5OhEAACIAxAaK": "Pulchri Studio",
    "YhYYAhEAACQAO8zn": "Das Leben am Haverkamp",
    "Yhiu7REAACUARfW_": "Filmhuis Den Haag",
    "ZfxM3BEAAHNNpF3t": "Filmhuis Den Haag – Foyer",
    "aaAdmhIAACAACeaO": "Laak",
    "abu8fxEAACUAw5Tm": "Subterra",
    "Y-PAshAAACEAtXK9": "Concordia",
    "YSZrYRIAACQAZbi6": "Barthkapel",
    "YSZtXBIAACIAZb_M": "Hofvijver",
    "ZfBmvxMAAFcwMyhV": "GR8",
    "Z8xINxEAACMA8XS8": "1646",
    "Z7iFOBAAAB8AQ0Gf": "Heden",
    "ZfL-JxAAAFcHYKo1": "Kloostertuin",
    "ZfMI-BAAAD4HYNzw": "Billytown",
    "abvIehEAACQAw6vC": "Page Not Found – Outside",
    "Z9BdoBEAACQA92IP": "The Hague Central Station",
    "Z9F0ThEAACIA-PBS": "Ministry of Infrastructure",
    "abu6KhEAACMAw5CQ": "West Den Haag – Hearing Room",
    # Additional venues found during scrape
    "YSdSwhIAACMAaarz": "Koorenhuis",
    "YASQqBEAAJTq63kU": "Lutherse Kerk",
    "YjNPthAAACAAQj6r": "Nieuwe Kerk",
    "Y-OnLBAAACEAtP8p": "PAARD I",
    "YASQqBEAAJTq63j4": "PAARD II",
    "YhirPxEAACMAReWH": "Grote Kerk",
    "ZfL9dxAAAL4GYKcQ": "Paleiskerk",
    "ZcORaRAAACQAgCsg": "Pulchri Studio",
    "YASQqBEAAJTq63jS": "Quartair",
}

# CET is UTC+2 during April (CEST)
CEST = timezone(timedelta(hours=2))

DAY_MAP = {
    9: "Thu",
    10: "Fri",
    11: "Sat",
    12: "Sun",
}


def fetch_all_artists():
    """Fetch all artist documents from Prismic, filtering for 2026 events."""
    all_artists = []
    page = 1
    total_pages = 1

    while page <= total_pages:
        q = quote('[[at(document.type,"artist")]]')
        url = f"{PRISMIC_API}?ref={PRISMIC_REF}&q={q}&pageSize=100&page={page}"
        req = Request(url, headers={"User-Agent": "Rewire2026-Scraper/1.0"})
        with urlopen(req) as resp:
            data = json.loads(resp.read())

        total_pages = data["total_pages"]
        print(f"  Fetching page {page}/{total_pages} ({len(data['results'])} results)")

        for doc in data["results"]:
            title = None
            events = []

            # Extract title
            doc_data = doc.get("data", {})
            if "title" in doc_data:
                title_field = doc_data["title"]
                if isinstance(title_field, list):
                    title = title_field[0].get("text", "") if title_field else ""
                elif isinstance(title_field, str):
                    title = title_field

            # Extract festival events with 2026 dates
            for evt in doc_data.get("festivalevents", []):
                start = evt.get("start")
                if not start or "2026" not in str(start):
                    continue

                venue_id = None
                venue_data = evt.get("venue", {})
                if isinstance(venue_data, dict):
                    venue_id = venue_data.get("id")

                events.append({
                    "start": start,
                    "end": evt.get("end"),
                    "venue_id": venue_id,
                })

            if title and events:
                all_artists.append({
                    "title": title,
                    "uid": doc.get("uid", ""),
                    "events": events,
                })

        page += 1

    return all_artists


def parse_time(iso_str):
    """Parse ISO datetime string to (day_abbrev, time_str HH:MM)."""
    dt = datetime.fromisoformat(iso_str.replace("+0000", "+00:00"))
    dt_local = dt.astimezone(CEST)
    day = dt_local.day
    # Handle late-night shows (after midnight = previous day)
    hour = dt_local.hour
    if hour < 6:
        day -= 1
        # Format as 24+ hour for late night
        time_str = f"{hour + 24}:{dt_local.minute:02d}"
    else:
        time_str = f"{dt_local.hour:02d}:{dt_local.minute:02d}"
    return DAY_MAP.get(day, f"Day{day}"), time_str


def get_venue_name(venue_id):
    """Map venue ID to display name."""
    return VENUE_MAP.get(venue_id, venue_id or "Unknown")


def fuzzy_match_score(a, b):
    """Compute similarity between two strings."""
    # Normalize
    a = a.lower().strip()
    b = b.lower().strip()
    if a == b:
        return 1.0
    return SequenceMatcher(None, a, b).ratio()


def normalize_name(name):
    """Normalize display name for matching."""
    # Remove common prefixes/suffixes that differ
    name = re.sub(r'\s*\(.*?\)\s*', '', name)  # Remove parenthetical
    name = name.replace("'", "'").replace("'", "'").replace(""", '"').replace(""", '"')
    name = name.replace("–", "-").replace("—", "-")
    return name.strip()


def match_scraped_to_slots(scraped, slots):
    """Match scraped artist names to slot display_names."""
    matches = []
    unmatched_scraped = []

    slot_names = [s["display_name"] for s in slots]
    slot_names_normalized = [normalize_name(n) for n in slot_names]

    for artist in scraped:
        title = artist["title"]
        title_norm = normalize_name(title)

        # Try exact match first
        best_score = 0
        best_idx = -1

        for i, sn in enumerate(slot_names_normalized):
            score = fuzzy_match_score(title_norm, sn)
            if score > best_score:
                best_score = score
                best_idx = i

        if best_score >= 0.75:
            matches.append({
                "scraped_title": title,
                "slot_name": slot_names[best_idx],
                "slot_idx": best_idx,
                "score": best_score,
                "events": artist["events"],
            })
        else:
            unmatched_scraped.append((title, best_score, slot_names[best_idx] if best_idx >= 0 else "?"))

    return matches, unmatched_scraped


def main():
    dry_run = "--dry-run" in sys.argv

    print("Fetching artist data from Prismic...")
    scraped = fetch_all_artists()
    print(f"Found {len(scraped)} artists with 2026 events")

    print("\nLoading lineup.yaml...")
    with open(SRC, encoding="utf-8") as f:
        data = yaml.safe_load(f)

    slots = data["slots"]
    print(f"Found {len(slots)} slots")

    print("\nMatching scraped data to slots...")
    matches, unmatched = match_scraped_to_slots(scraped, slots)
    print(f"Matched: {len(matches)}, Unmatched scraped: {len(unmatched)}")

    if unmatched:
        print("\n--- Unmatched scraped artists ---")
        for title, score, closest in unmatched:
            print(f"  {title} (best: {score:.2f} → {closest})")

    # Apply updates
    updated = 0
    for m in matches:
        slot = slots[m["slot_idx"]]
        evt = m["events"][0]  # Use first event for single performances

        day, time_str = parse_time(evt["start"])
        venue = get_venue_name(evt["venue_id"])

        old_day = slot.get("day")
        old_time = slot.get("time")
        old_stage = slot.get("stage")

        # Check if this is a multi-day event (installation etc)
        if len(m["events"]) > 1:
            days = []
            for e in m["events"]:
                d, _ = parse_time(e["start"])
                if d not in days:
                    days.append(d)
            if len(days) > 1:
                # Multi-day: keep existing day array or set new one
                day = days
                _, time_str = parse_time(m["events"][0]["start"])

        new_time = time_str
        new_stage = venue

        # Only update if we have new data
        changes = []
        if old_time is None and new_time:
            slot["time"] = new_time
            changes.append(f"time={new_time}")
        if old_stage is None and new_stage and new_stage != "Unknown":
            slot["stage"] = new_stage
            changes.append(f"stage={new_stage}")
        # Update day if it was null or if scraped data differs
        if isinstance(day, list):
            if old_day != day:
                slot["day"] = day
                changes.append(f"day={day}")
        elif old_day is None and day:
            slot["day"] = day
            changes.append(f"day={day}")

        if changes:
            updated += 1
            if dry_run:
                print(f"  Would update '{slot['display_name']}': {', '.join(changes)}")
            else:
                print(f"  Updated '{slot['display_name']}': {', '.join(changes)}")

    print(f"\n{'Would update' if dry_run else 'Updated'} {updated} slots")

    # Count remaining gaps
    no_time = sum(1 for s in slots if not s.get("time"))
    no_stage = sum(1 for s in slots if not s.get("stage"))
    print(f"Remaining gaps: {no_time} without time, {no_stage} without stage")

    if not dry_run and updated > 0:
        print("\nWriting updated lineup.yaml...")
        with open(SRC, "w", encoding="utf-8") as f:
            yaml.dump(data, f, allow_unicode=True, default_flow_style=False, sort_keys=False, width=120)
        print("Done!")
    elif dry_run:
        print("\nDry run — no files modified.")


if __name__ == "__main__":
    main()
