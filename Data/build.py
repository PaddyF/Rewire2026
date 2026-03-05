#!/usr/bin/env python3
"""
build.py — converts lineup.yaml → lineup.json

The YAML has two top-level collections:
  - artists: dict of slug → artist data
  - slots:   list of scheduled performances

The JSON output mirrors this structure so the frontend (and Swift app)
can join slots → artists by artist_ids.

Usage:
    python build.py                  # produces lineup.json in same directory
    python build.py --watch          # rebuild on every save (requires watchdog)
"""

import json
import sys
import pathlib
import yaml

ROOT = pathlib.Path(__file__).parent
SRC  = ROOT / "lineup.yaml"
OUT  = ROOT / "lineup.json"


def load_and_validate(path: pathlib.Path) -> dict:
    with open(path, encoding="utf-8") as f:
        data = yaml.safe_load(f)

    if not isinstance(data, dict):
        raise ValueError("lineup.yaml must be a top-level YAML mapping with 'artists' and 'slots' keys")

    if "artists" not in data or "slots" not in data:
        raise ValueError("lineup.yaml must contain both 'artists' and 'slots' keys")

    artists = data["artists"]
    slots = data["slots"]

    if not isinstance(artists, dict):
        raise ValueError("'artists' must be a mapping (slug → artist data)")
    if not isinstance(slots, list):
        raise ValueError("'slots' must be a list")

    valid_waves = {"W1", "W2", "W3"}
    valid_days = {"Thu", "Fri", "Sat", "Sun", None}
    errors = []

    # Validate artists
    for slug, artist in artists.items():
        if "name" not in artist:
            errors.append(f"artists.{slug}: missing required field 'name'")

    # Validate slots
    for i, slot in enumerate(slots):
        label = slot.get("display_name", f"[slot {i}]")

        if "display_name" not in slot:
            errors.append(f"slot {i}: missing required field 'display_name'")
        if "wave" not in slot:
            errors.append(f"{label}: missing required field 'wave'")
        elif slot["wave"] not in valid_waves:
            errors.append(f"{label}: wave must be W1, W2, or W3 (got {slot['wave']!r})")
        if "artist_ids" not in slot or not slot["artist_ids"]:
            errors.append(f"{label}: missing or empty 'artist_ids'")
        else:
            for aid in slot["artist_ids"]:
                if aid not in artists:
                    errors.append(f"{label}: artist_id '{aid}' not found in artists")

        day = slot.get("day")
        if day is not None:
            days = day if isinstance(day, list) else [day]
            for d in days:
                if d not in valid_days:
                    errors.append(f"{label}: day must be Thu/Fri/Sat/Sun or null (got {d!r})")

    if errors:
        print("⚠️  Validation errors:")
        for e in errors:
            print(f"   {e}")
        sys.exit(1)

    return data


def build():
    data = load_and_validate(SRC)

    # Clean up null values for smaller JSON
    artists = data["artists"]
    slots = data["slots"]

    # Strip None values from slots
    clean_slots = []
    for slot in slots:
        clean = {k: v for k, v in slot.items() if v is not None}
        clean_slots.append(clean)

    output = {
        "artists": artists,
        "slots": clean_slots,
    }

    json_str = json.dumps(output, ensure_ascii=False, indent=2)
    OUT.write_text(json_str, encoding="utf-8")
    print(f"✓  {len(artists)} artists, {len(slots)} slots → {OUT}")


def watch():
    try:
        from watchdog.observers import Observer
        from watchdog.events import FileSystemEventHandler
        import time
    except ImportError:
        print("Install watchdog first:  pip install watchdog")
        sys.exit(1)

    class Handler(FileSystemEventHandler):
        def on_modified(self, event):
            if event.src_path.endswith("lineup.yaml"):
                print(f"\n↺  {SRC.name} changed — rebuilding…")
                try:
                    build()
                except Exception as exc:
                    print(f"✗  {exc}")

    build()  # initial build
    observer = Observer()
    observer.schedule(Handler(), str(ROOT), recursive=False)
    observer.start()
    print(f"  Watching {SRC} — press Ctrl+C to stop")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()


if __name__ == "__main__":
    if "--watch" in sys.argv:
        watch()
    else:
        build()
