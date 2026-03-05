#!/usr/bin/env python3
"""Parse the Rewire 2026 HTML table and output artists.json"""

import re
import json
import html
import unicodedata
import sys

def strip_html(text):
    if not text or text == '—':
        return ''
    text = re.sub(r'<br\s*/?>', ' — ', text, flags=re.IGNORECASE)
    # Add space before opening tags to avoid words running together
    text = re.sub(r'<', ' <', text)
    text = re.sub(r'<[^>]+>', '', text)
    text = html.unescape(text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text

def slugify(name):
    normalized = unicodedata.normalize('NFD', name)
    ascii_str = ''.join(c for c in normalized if unicodedata.category(c) != 'Mn')
    slug = re.sub(r'[^a-z0-9]+', '-', ascii_str.lower())
    return slug.strip('-')

def extract_field(obj_str, key):
    m = re.search(rf'{key}:"([^"]*)"', obj_str)
    if m:
        return m.group(1)
    return ''

def extract_objects(js_array):
    """Extract individual JS object strings from the D array."""
    objects = []
    depth = 0
    start = -1
    for i, c in enumerate(js_array):
        if c == '{':
            if depth == 0:
                start = i
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0 and start >= 0:
                objects.append(js_array[start:i+1])
                start = -1
    return objects

def make_id(name, existing_ids):
    base = slugify(name)
    if not base:
        base = 'artist'
    candidate = base
    counter = 2
    while candidate in existing_ids:
        candidate = f'{base}-{counter}'
        counter += 1
    existing_ids.add(candidate)
    return candidate

def parse_html(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    m = re.search(r'const D=\[(.*?)\];', content, re.DOTALL)
    if not m:
        print('ERROR: Could not find data array in HTML', file=sys.stderr)
        sys.exit(1)

    data_str = m.group(1)
    objects = extract_objects(data_str)
    print(f'Found {len(objects)} objects', file=sys.stderr)

    artists = []
    existing_ids = set()

    for obj in objects:
        n = extract_field(obj, 'n')
        if not n:
            continue

        p = extract_field(obj, 'p')
        w = extract_field(obj, 'w')
        t = extract_field(obj, 't')
        g = extract_field(obj, 'g')
        l = extract_field(obj, 'l')
        r = extract_field(obj, 'r')
        o = extract_field(obj, 'o')

        wave = int(w[1]) if w and len(w) >= 2 and w[1].isdigit() else 1
        requires_plus = 'Plus Ticket' in t
        genres = [gn.strip() for gn in g.split(',') if gn.strip()] if g else []

        artist = {
            'id': make_id(n, existing_ids),
            'name': html.unescape(n),
            'subtitle': html.unescape(p),
            'wave': wave,
            'performanceType': html.unescape(t),
            'genres': genres,
            'latestRelease': strip_html(l),
            'recommendedRelease': strip_html(r),
            'description': html.unescape(o),
            'day': None,
            'stage': None,
            'startTime': None,
            'endTime': None,
            'requiresPlusTicket': requires_plus,
        }
        artists.append(artist)

    return artists

if __name__ == '__main__':
    src = '/Users/paddyf/Downloads/rewire_2026_table.html'
    artists = parse_html(src)
    print(f'Parsed {len(artists)} artists', file=sys.stderr)
    print(json.dumps(artists, indent=2, ensure_ascii=False))
