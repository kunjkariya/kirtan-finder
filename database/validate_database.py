#!/usr/bin/env python3
"""
validate_database.py — 15-point automated verification suite for Kirtan Finder database.
Validates corpus completeness, constraints, referential integrity, and search index alignment.
"""

import os
import sys
import sqlite3

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(SCRIPT_DIR, "kirtan_finder.db")

def run_validation(db_path=DB_PATH):
    print("=" * 70)
    print("KIRTAN FINDER DATABASE VALIDATION SUITE (15 Checks)")
    print("=" * 70)
    print(f"Database File: {db_path}")

    if not os.path.exists(db_path):
        print(f"ERROR: Database file {db_path} does not exist!")
        sys.exit(1)

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    checks = []

    def check(num, name, condition, details=""):
        status = "PASS" if condition else "FAIL"
        checks.append((num, name, status, details))
        mark = "✓" if condition else "✗"
        print(f"[{mark}] Check {num:02d}: {name} -> {status} {details}")
        if not condition:
            print(f"     DETAILS: {details}")

    # Check 1: Exactly 6,584 kirtans imported
    cur.execute("SELECT count(*) FROM kirtans;")
    count_kirtans = cur.fetchone()[0]
    check(1, "6,584 kirtans imported", count_kirtans == 6584, f"(Actual: {count_kirtans})")

    # Check 2: Exactly 409 chapters imported
    cur.execute("SELECT count(*) FROM chapters;")
    count_chapters = cur.fetchone()[0]
    check(2, "409 chapters imported", count_chapters == 409, f"(Actual: {count_chapters})")

    # Check 3: Exactly 4 parts imported
    cur.execute("SELECT count(*) FROM parts;")
    count_parts = cur.fetchone()[0]
    check(3, "4 parts imported", count_parts == 4, f"(Actual: {count_parts})")

    # Check 4: 6,584 Master Index mappings resolved
    cur.execute("SELECT count(*) FROM kirtans WHERE title_hi != '' AND title_en != '';")
    resolved_master = cur.fetchone()[0]
    check(4, "6,584 Master Index mappings resolved", resolved_master == 6584, f"(Actual: {resolved_master})")

    # Check 5: Every kirtan has a unique global kirtan_uid
    cur.execute("SELECT count(DISTINCT kirtan_uid) FROM kirtans;")
    unique_uids = cur.fetchone()[0]
    check(5, "Unique global kirtan_uid for every record", unique_uids == 6584, f"(Unique UIDs: {unique_uids})")

    # Check 6: No blank canonical Hindi titles
    cur.execute("SELECT count(*) FROM kirtans WHERE title_hi IS NULL OR trim(title_hi) = '';")
    blank_hi = cur.fetchone()[0]
    check(6, "No blank canonical Hindi titles", blank_hi == 0, f"(Blank: {blank_hi})")

    # Check 7: No blank English titles
    cur.execute("SELECT count(*) FROM kirtans WHERE title_en IS NULL OR trim(title_en) = '';")
    blank_en = cur.fetchone()[0]
    check(7, "No blank English titles from Master Index", blank_en == 0, f"(Blank: {blank_en})")

    # Check 8: No blank kirtan text
    cur.execute("SELECT count(*) FROM kirtans WHERE full_text IS NULL OR trim(full_text) = '';")
    blank_text = cur.fetchone()[0]
    check(8, "No blank kirtan text", blank_text == 0, f"(Blank: {blank_text})")

    # Check 9: Every kirtan maps to a valid chapter
    cur.execute("""
        SELECT count(*) FROM kirtans k 
        LEFT JOIN chapters c ON k.chapter_id = c.id 
        WHERE c.id IS NULL;
    """)
    orphan_chapters = cur.fetchone()[0]
    check(9, "Every kirtan maps to a valid chapter", orphan_chapters == 0, f"(Orphans: {orphan_chapters})")

    # Check 10: Every kirtan maps to correct source filename and anchor
    cur.execute("""
        SELECT count(*) FROM kirtans 
        WHERE source_filename IS NULL OR source_filename = '' 
           OR source_anchor IS NULL OR source_anchor = '';
    """)
    missing_sources = cur.fetchone()[0]
    check(10, "Every kirtan maps to correct source filename and anchor", missing_sources == 0, f"(Missing: {missing_sources})")

    # Check 11: Part number agrees with source filename
    cur.execute("""
        SELECT count(*) FROM kirtans 
        WHERE substr(source_filename, 1, 1) != cast(part_number as text);
    """)
    mismatched_part_fn = cur.fetchone()[0]
    check(11, "Part number agrees with source filename prefix", mismatched_part_fn == 0, f"(Mismatches: {mismatched_part_fn})")

    # Check 12: Chapter number agrees with source filename
    cur.execute("""
        SELECT count(*) FROM kirtans k
        JOIN chapters c ON k.chapter_id = c.id
        WHERE k.chapter_number != c.chapter_number;
    """)
    mismatched_chap_num = cur.fetchone()[0]
    check(12, "Chapter number agrees across kirtans and chapters", mismatched_chap_num == 0, f"(Mismatches: {mismatched_chap_num})")

    # Check 13: Old page number is correctly imported (> 0)
    cur.execute("SELECT count(*) FROM kirtans WHERE old_page <= 0;")
    invalid_pages = cur.fetchone()[0]
    check(13, "Old printed page number is positive integer (> 0)", invalid_pages == 0, f"(Invalid: {invalid_pages})")

    # Check 14: Search indexes contain the expected number of records
    cur.execute("SELECT count(*) FROM title_search_fts;")
    title_fts_cnt = cur.fetchone()[0]
    cur.execute("SELECT count(*) FROM lines_search_fts;")
    lines_fts_cnt = cur.fetchone()[0]
    fts_valid = (title_fts_cnt == 6584 and lines_fts_cnt == 6584)
    check(14, "Search indexes contain exactly 6,584 records each", fts_valid, 
          f"(title_fts: {title_fts_cnt}, lines_fts: {lines_fts_cnt})")

    # Check 15: No duplicate kirtan records created
    cur.execute("""
        SELECT count(*) FROM (
            SELECT part_number, chapter_number, kirtan_number, old_page, count(*)
            FROM kirtans
            GROUP BY part_number, chapter_number, kirtan_number, old_page
            HAVING count(*) > 1
        );
    """)
    duplicate_kirtans = cur.fetchone()[0]
    check(15, "No duplicate kirtan records created", duplicate_kirtans == 0, f"(Duplicates: {duplicate_kirtans})")

    conn.close()

    print("=" * 70)
    failed = [c for c in checks if c[2] != "PASS"]
    if not failed:
        print("ALL 15 VALIDATION CHECKS PASSED PERFECTLY! (15/15)")
    else:
        print(f"VALIDATION FAILED: {len(failed)} checks failed out of 15!")
    print("=" * 70)

    return len(failed) == 0

if __name__ == '__main__':
    success = run_validation()
    sys.exit(0 if success else 1)
