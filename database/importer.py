#!/usr/bin/env python3
"""
importer.py — Deterministic SQLite database importer for the Kirtan Finder project.
Ingests 409 chapter XHTML files, master_index.xhtml, and master_titles.xhtml.
Populates relational tables, B-tree indexes, and separate FTS5 search virtual tables.
"""

import os
import re
import sys
import sqlite3
import unicodedata
from collections import defaultdict
from bs4 import BeautifulSoup, XMLParsedAsHTMLWarning
import warnings

# Suppress XML parsed as HTML warnings from BeautifulSoup
warnings.filterwarnings("ignore", category=XMLParsedAsHTMLWarning)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_candidate = os.path.join(os.path.dirname(SCRIPT_DIR), "corpus")
CORPUS_DIR = _candidate if os.path.exists(_candidate) else os.path.dirname(SCRIPT_DIR)
DB_PATH = os.path.join(SCRIPT_DIR, "kirtan_finder.db")
SCHEMA_PATH = os.path.join(SCRIPT_DIR, "schema.sql")

def normalize_space(s):
    """Normalize whitespace (consecutive spaces, newlines, tabs into single space)."""
    if not s:
        return ""
    return re.sub(r"\s+", " ", s).strip()

def clean_raag(raag):
    """Clean raw raag for UI filters (removes trailing dandas, asterisks, punctuation)."""
    if not raag:
        return ""
    r = raag.strip()
    r = re.sub(r"[॥।*_]+$", "", r).strip()
    return r

def parse_master_titles(corpus_dir):
    """
    Parse master_titles.xhtml to extract canonical chapter titles (Hindi & English).
    Returns dict: (part_num, chap_num) -> {'hi': ..., 'en': ...}
    """
    path = os.path.join(corpus_dir, "master_titles.xhtml")
    if not os.path.exists(path):
        print(f"Warning: master_titles.xhtml not found at {path}")
        return {}

    with open(path, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f.read(), "lxml")

    table = soup.find("table")
    rows = table.find_all("tr") if table else []
    
    chapter_titles = {}
    current_part = None
    chap_counters = defaultdict(int)

    for i in range(1, len(rows), 2):
        r1 = rows[i]
        part_td = r1.find("td", class_="part-cell")
        hi_td = r1.find("td", class_="hi-title")
        r2 = rows[i+1] if i + 1 < len(rows) else None
        en_td = r2.find("td", class_="en-title") if r2 else None

        if part_td:
            p_text = part_td.get_text(strip=True)
            m = re.search(r"Part\s*(\d+)", p_text)
            if m:
                current_part = int(m.group(1))

        if not current_part:
            continue

        chap_counters[current_part] += 1
        chap_num = chap_counters[current_part]

        hi_text = normalize_space(hi_td.get_text(strip=True) if hi_td else "")
        en_text = normalize_space(en_td.get_text(strip=True) if en_td else "")

        # Clean leading numbers like '१. ' or '1. ' from Hindi title
        hi_clean = re.sub(r"^[०-९0-9]+[\.\-\s]+", "", hi_text).strip()
        en_clean = re.sub(r"^[0-9]+[\.\-\s]+", "", en_text).strip()

        chapter_titles[(current_part, chap_num)] = {
            "title_hi": hi_clean if hi_clean else hi_text,
            "title_en": en_clean if en_clean else en_text,
            "raw_hi": hi_text,
            "raw_en": en_text
        }

    return chapter_titles

def parse_master_index(corpus_dir):
    """
    Parse master_index.xhtml to extract canonical titles (Hindi & English) and link mappings.
    Returns dict: (normalized_fn, anchor) -> {
        'id_cell': ...,
        'title_hi': ...,
        'title_en': ...,
        'original_fn': ...
    }
    """
    path = os.path.join(corpus_dir, "master_index.xhtml")
    with open(path, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f.read(), "lxml")

    table = soup.find("table")
    rows = table.find_all("tr") if table else []

    master_map = {}
    current_part = 1

    for i in range(1, len(rows), 2):
        r1 = rows[i]
        part_td = r1.find("td", class_="part-cell")
        id_td = r1.find("td", class_="id-cell")
        hi_td = r1.find("td", class_="hi-title")
        r2 = rows[i+1] if i + 1 < len(rows) else None
        en_td = r2.find("td", class_="en-title") if r2 else None

        if part_td:
            p_text = part_td.get_text(strip=True)
            m = re.search(r"Part\s*(\d+)", p_text)
            if m:
                current_part = int(m.group(1))

        if not id_td or not hi_td or not en_td:
            continue

        id_a = id_td.find("a")
        href = id_a.get("href", "") if id_a else ""
        if "#" not in href:
            continue

        fn, anchor = href.split("#", 1)
        id_cell = normalize_space(id_td.get_text(strip=True))
        hi_title = normalize_space(hi_td.get_text(strip=True))
        en_title = normalize_space(en_td.get_text(strip=True))

        # Handle whitespace/newline differences between master_index href and filesystem
        norm_fn = normalize_space(fn)

        master_map[(norm_fn, anchor)] = {
            "part_number": current_part,
            "id_cell": id_cell,
            "title_hi": hi_title,
            "title_en": en_title,
            "raw_filename": fn
        }

    return master_map

def import_corpus(corpus_dir=CORPUS_DIR, db_path=DB_PATH):
    print("=" * 70)
    print("KIRTAN FINDER DATABASE IMPORTER (Step 2)")
    print("=" * 70)
    print(f"Corpus Directory : {corpus_dir}")
    print(f"Output Database  : {db_path}")

    # 1. Remove existing db file if present for deterministic re-import
    if os.path.exists(db_path):
        os.remove(db_path)
        print("Removed existing database file for a clean deterministic import.")

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    # 2. Execute schema DDL
    print("Applying schema DDL...")
    with open(SCHEMA_PATH, "r", encoding="utf-8") as f:
        schema_sql = f.read()
    cur.executescript(schema_sql)

    # 3. Populate Parts Table
    parts_data = [
        (1, 1, "भाग १", "Part 1", 1),
        (2, 2, "भाग २", "Part 2", 2),
        (3, 3, "भाग ३", "Part 3", 3),
        (4, 4, "भाग ४", "Part 4", 4)
    ]
    cur.executemany(
        "INSERT INTO parts (id, part_number, name_hi, name_en, order_num) VALUES (?, ?, ?, ?, ?);",
        parts_data
    )

    # 4. Parse master indexes
    print("Parsing master_titles.xhtml...")
    chapter_titles_meta = parse_master_titles(corpus_dir)
    print(f"  Parsed {len(chapter_titles_meta)} chapter titles from master_titles.xhtml.")

    print("Parsing master_index.xhtml...")
    master_index_map = parse_master_index(corpus_dir)
    print(f"  Parsed {len(master_index_map)} kirtan entries from master_index.xhtml.")

    # 5. List and sort all chapter files
    files = sorted(os.listdir(corpus_dir))
    fn_regex = re.compile(r"^([1-4])_(\d{3})_(.+)\.xhtml$", re.DOTALL)
    chapter_files = [f for f in files if fn_regex.match(f)]
    print(f"Found {len(chapter_files)} chapter XHTML files to import.")

    # Counters and tracking
    total_kirtans_count = 0
    total_lines_count = 0
    kirtans_order_seq = 0
    chapters_order_seq = 0

    # Batch insert lists for maximum performance
    kirtans_to_insert = []
    lines_to_insert = []
    title_fts_to_insert = []
    lines_fts_to_insert = []

    print("Processing chapters and extracting kirtans...")

    for fname in chapter_files:
        m = fn_regex.match(fname)
        part_num = int(m.group(1))
        chap_num = int(m.group(2))
        fn_title = m.group(3).strip()

        chapters_order_seq += 1
        chap_uid = f"P{part_num}.C{chap_num:03d}"
        filepath = os.path.join(corpus_dir, fname)

        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()

        soup = BeautifulSoup(content, "lxml")

        # Chapter level metadata
        h1 = soup.find("h1")
        h1_text = normalize_space(h1.get_text() if h1 else "")
        meta_sub = soup.find("meta", attrs={"name": "chapter-subtitle"})
        subtitle = normalize_space(meta_sub["content"]) if (meta_sub and meta_sub.get("content")) else None

        # Look up canonical title from master_titles if available, else fallback to filename / h1
        title_meta = chapter_titles_meta.get((part_num, chap_num), {})
        chap_title_hi = title_meta.get("title_hi") or h1_text or fn_title
        chap_title_en = title_meta.get("title_en") or None

        # Insert chapter
        cur.execute("""
            INSERT INTO chapters (
                chapter_uid, part_id, part_number, chapter_number,
                title_hi, title_en, subtitle_hi, source_filename, order_num
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """, (
            chap_uid, part_num, part_num, chap_num,
            chap_title_hi, chap_title_en, subtitle, fname, chapters_order_seq
        ))
        chapter_db_id = cur.lastrowid

        # Process each kirtan block in this chapter
        k_blocks = soup.find_all("div", class_="kirtan-block")

        for kb in k_blocks:
            total_kirtans_count += 1
            kirtans_order_seq += 1
            kirtan_db_id = kirtans_order_seq

            block_id = kb.get("id", "").strip()
            data_chap = int(kb.get("data-chapter", chap_num))
            data_old_page = int(kb.get("data-old-page", 0))
            data_raag = normalize_space(kb.get("data-raag", ""))
            cleaned_raag = clean_raag(data_raag)

            # Block ID components: {chapter}-{kirtan}-{page}
            parts = block_id.split("-")
            kirtan_num_in_chap = int(parts[1]) if len(parts) >= 2 else kirtans_order_seq

            # Stable canonical UID
            kirtan_uid = f"P{part_num}.C{data_chap}.K{kirtan_num_in_chap}.P{data_old_page}"

            # Header info
            header = kb.find("div", class_="kirtan-header")
            search_id_p = header.find("p", class_="search-id") if header else None
            search_id_raw = normalize_space(search_id_p.get_text() if search_id_p else "")

            # Look up Master Index authoritative titles
            norm_fname = normalize_space(fname)
            master_entry = master_index_map.get((norm_fname, block_id))
            if not master_entry:
                # Try fallback matching by prefix if filename had whitespace variations
                for (m_fn, m_anc), val in master_index_map.items():
                    if m_anc == block_id and m_fn.startswith(f"{part_num}_{chap_num:03d}"):
                        master_entry = val
                        break

            title_hi = master_entry["title_hi"] if master_entry else ""
            title_en = master_entry["title_en"] if master_entry else ""

            # Body parsing
            body = kb.find("div", class_="kirtan-body")
            # Recursive search handles any rare double-nested body divs
            p_lines = body.find_all("p") if body else []

            lines_data = []
            youtube_url = None
            raw_first_line = None
            verse_idx = 1
            current_verse_lines = []

            for p in p_lines:
                classes = p.get("class", [])
                if "kirtan-line" not in classes:
                    continue

                total_lines_count += 1
                is_title = "title-line" in classes
                is_verse_end = "verse-end" in classes

                # Extract YouTube URL
                a_tag = p.find("a")
                if a_tag and "href" in a_tag.attrs:
                    if not youtube_url:
                        youtube_url = a_tag["href"]

                # Extract verse marker if present
                vm_span = p.find("span", class_="verse-marker")
                vm_text = normalize_space(vm_span.get_text()) if vm_span else None

                # Extract clean line text
                if vm_span:
                    line_full = p.get_text()
                    if vm_text and line_full.endswith(vm_text):
                        line_clean = line_full[:-len(vm_text)].strip()
                    else:
                        line_clean = line_full.replace(vm_text, "").strip()
                else:
                    line_clean = p.get_text().strip()

                if is_title and raw_first_line is None:
                    raw_first_line = line_clean

                line_num = len(lines_data) + 1
                lines_data.append({
                    "kirtan_id": kirtan_db_id,
                    "line_number": line_num,
                    "verse_number": verse_idx,
                    "is_title_line": 1 if is_title else 0,
                    "is_verse_end": 1 if (is_verse_end or vm_span) else 0,
                    "line_text": line_clean,
                    "verse_marker": vm_text
                })

                if is_verse_end or vm_span:
                    verse_idx += 1

            # If fallback needed for titles
            if not title_hi:
                title_hi = raw_first_line or ""
            if raw_first_line is None:
                raw_first_line = title_hi

            # Complete kirtan text (for storage & line FTS search)
            full_text_lines = [l["line_text"] for l in lines_data]
            complete_kirtan_text = "\n".join(full_text_lines)

            # Stage Kirtan record
            kirtans_to_insert.append((
                kirtan_db_id, kirtan_uid, part_num, chapter_db_id,
                part_num, chap_num, kirtan_num_in_chap, data_old_page,
                data_raag, cleaned_raag, title_hi, title_en,
                raw_first_line, complete_kirtan_text, youtube_url,
                fname, block_id, search_id_raw,
                len(lines_data), max(1, verse_idx - 1 if (verse_idx > 1 and not current_verse_lines) else verse_idx),
                kirtans_order_seq
            ))

            # Stage Lines records
            for ld in lines_data:
                lines_to_insert.append((
                    ld["kirtan_id"], ld["line_number"], ld["verse_number"],
                    ld["is_title_line"], ld["is_verse_end"],
                    ld["line_text"], ld["verse_marker"]
                ))

            # Stage FTS records:
            # 1. Title Search FTS (kirtan_id, kirtan_uid, title_hi, title_en, search_id_raw)
            title_fts_to_insert.append((
                kirtan_db_id, kirtan_uid, title_hi, title_en, search_id_raw
            ))

            # 2. Lines Search FTS (kirtan_id, kirtan_lines_text) — ONLY lyric lines!
            lines_fts_to_insert.append((
                kirtan_db_id, complete_kirtan_text
            ))

    print(f"Inserting {len(kirtans_to_insert)} kirtans...")
    cur.executemany("""
        INSERT INTO kirtans (
            id, kirtan_uid, part_id, chapter_id,
            part_number, chapter_number, kirtan_number, old_page,
            raag, raag_normalized, title_hi, title_en,
            raw_first_line, full_text, youtube_url,
            source_filename, source_anchor, search_id_raw,
            line_count, verse_count, order_num
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """, kirtans_to_insert)

    print(f"Inserting {len(lines_to_insert)} kirtan lines...")
    cur.executemany("""
        INSERT INTO kirtan_lines (
            kirtan_id, line_number, verse_number,
            is_title_line, is_verse_end, line_text, verse_marker
        ) VALUES (?, ?, ?, ?, ?, ?, ?);
    """, lines_to_insert)

    print("Populating title_search_fts FTS5 table...")
    cur.executemany("""
        INSERT INTO title_search_fts (
            kirtan_id, kirtan_uid, title_hi, title_en, search_id_raw
        ) VALUES (?, ?, ?, ?, ?);
    """, title_fts_to_insert)

    print("Populating lines_search_fts FTS5 table...")
    cur.executemany("""
        INSERT INTO lines_search_fts (
            kirtan_id, kirtan_lines_text
        ) VALUES (?, ?);
    """, lines_fts_to_insert)

    # Commit all data
    conn.commit()

    # Optimize FTS indexes
    print("Optimizing FTS5 indexes...")
    cur.execute("INSERT INTO title_search_fts(title_search_fts) VALUES('optimize');")
    cur.execute("INSERT INTO lines_search_fts(lines_search_fts) VALUES('optimize');")
    conn.commit()

    # Database file size
    db_size_bytes = os.path.getsize(db_path)
    db_size_mb = db_size_bytes / (1024 * 1024)

    conn.close()

    print("=" * 70)
    print("IMPORT COMPLETE SUCCESSFULLY")
    print(f"  Parts Imported        : {len(parts_data)}")
    print(f"  Chapters Imported     : {len(chapter_files)}")
    print(f"  Kirtans Imported      : {len(kirtans_to_insert)}")
    print(f"  Kirtan Lines Imported : {len(lines_to_insert)}")
    print(f"  Database File Size    : {db_size_mb:.2f} MB ({db_size_bytes:,} bytes)")
    print("=" * 70)

if __name__ == '__main__':
    import_corpus()
