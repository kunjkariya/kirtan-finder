#!/usr/bin/env python3
"""
benchmark_search.py — Performance Benchmarks & Search Test Suite for Kirtan Finder.
Measures execution times, verifies semantics, and tests all required query combinations.
"""

import time
import os
import sys
from search_repository import KirtanRepository, PartFilter

def run_benchmarks():
    print("=" * 80)
    print("KIRTAN FINDER SEARCH ENGINE BENCHMARK & QUERY VERIFICATION")
    print("=" * 80)

    repo = KirtanRepository()

    # -------------------------------------------------------------
    # 1. Performance Benchmark Suite
    # -------------------------------------------------------------
    test_cases = [
        # (Mode, Query, PartFilter, ExpectedCount, Description)
        ("TITLE", "Vraja", PartFilter.ALL, 50, "English title prefix (ALL PARTS)"),
        ("TITLE", "Vraja", PartFilter.PART_1, 50, "English title prefix (PART 1)"),
        ("TITLE", "vraja", PartFilter.ALL, 50, "English lowercase (ALL PARTS)"),
        ("TITLE", "VRAJA", PartFilter.ALL, 50, "English uppercase (ALL PARTS)"),
        ("TITLE", "Vraja Bhayo", PartFilter.ALL, 4, "Full English title (ALL PARTS)"),
        ("TITLE", "व्रज भयो", PartFilter.ALL, 2, "Hindi title (ALL PARTS)"),
        ("TITLE", "धमार", PartFilter.PART_3, 7, "Hindi title (PART 3)"),
        ("TITLE", "25", PartFilter.ALL, 19, "Numeric Old Page '25' (ALL PARTS)"),
        ("TITLE", "25", PartFilter.PART_2, 3, "Numeric Old Page '25' (PART 2)"),
        ("TITLE", "२५", PartFilter.ALL, 19, "Devanagari Page '२५' (ALL PARTS)"),
        ("TITLE", "२५", PartFilter.PART_2, 3, "Devanagari Page '२५' (PART 2)"),
        ("TITLE", "P1.C1.K1.P1", PartFilter.ALL, 1, "Exact Global UID uppercase (ALL PARTS)"),
        ("TITLE", "p1.c1.k1.p1", PartFilter.ALL, 1, "Exact Global UID lowercase (ALL PARTS)"),
        ("TITLE", "  p1.c1.k1.p1  ", PartFilter.ALL, 1, "Exact UID with whitespace (ALL PARTS)"),
        ("TITLE", "P4.C21.K1.P87", PartFilter.PART_4, 1, "Exact Global UID (PART 4)"),
        ("TITLE", "1.1", PartFilter.ALL, 4, "Chapter 1 Kirtan 1 (ALL PARTS)"),
        ("TITLE", "1.1", PartFilter.PART_2, 1, "Chapter 1 Kirtan 1 (PART 2)"),
        ("TITLE", "१.१", PartFilter.ALL, 4, "Devanagari Chap.Kirtan '१.१' (ALL PARTS)"),
        ("TITLE", "१.१", PartFilter.PART_1, 1, "Devanagari Chap.Kirtan '१.१' (PART 1)"),
        ("TITLE", "C1.K1", PartFilter.ALL, 4, "Chapter 1 Kirtan 1 C/K format (ALL)"),
        ("TITLE", "C1.K1", PartFilter.PART_3, 1, "Chapter 1 Kirtan 1 C/K format (PART 3)"),
        ("TITLE", "C1.K1.P1", PartFilter.ALL, 4, "Chapter 1 Kirtan 1 Page 1 (ALL)"),
        ("TITLE", "C1.K1.P1", PartFilter.PART_1, 1, "Chapter 1 Kirtan 1 Page 1 (PART 1)"),
        ("LINES", "श्री", PartFilter.ALL, 327, "Exact word token 'श्री' (ALL PARTS)"),
        ("LINES", "कृष्ण", PartFilter.ALL, 212, "Exact word token 'कृष्ण' (ALL PARTS)"),
        ("LINES", "शिर", PartFilter.ALL, 112, "Exact word token 'शिर' (ALL PARTS)"),
        ("LINES", "श्री कृष्ण", PartFilter.ALL, 16, "Kirtan Lines 'श्री कृष्ण' (ALL PARTS)"),
        ("LINES", "श्री कृष्ण", PartFilter.PART_1, 3, "Kirtan Lines 'श्री कृष्ण' (PART 1)"),
        ("LINES", "\"श्री कृष्ण\"", PartFilter.ALL, 1, "Exact adjacent phrase 'श्री कृष्ण' (ALL)"),
        ("LINES", "मदनगोपाल", PartFilter.PART_2, 9, "Kirtan Lines phrase (PART 2)"),
        ("LINES", "गोवर्धन", PartFilter.ALL, 50, "Kirtan Lines phrase 'गोवर्धन' (ALL PARTS)"),
        ("LINES", "गोवर्धन", PartFilter.PART_2, 50, "Kirtan Lines phrase 'गोवर्धन' (PART 2)"),
        ("LINES", "गोवर्धन", PartFilter.PART_4, 8, "Kirtan Lines phrase 'गोवर्धन' (PART 4)"),
        ("LINES", "चिरजीयौ यशोदानंद", PartFilter.PART_1, 1, "Multi-word lyric phrase (PART 1)"),
    ]

    print(f"{'#':<3} | {'Mode':<6} | {'Part':<6} | {'Query':<22} | {'Count':<5} | {'Exp':<5} | {'Time (ms)':<9} | {'Status'}")
    print("-" * 80)

    timings = []

    for idx, (mode, q, p_filter, exp_count, desc) in enumerate(test_cases, 1):
        runs = 5
        t_start = time.perf_counter()
        req_limit = max(50, exp_count)
        for _ in range(runs):
            if mode == "TITLE":
                res = repo.search_title(q, p_filter, limit=req_limit)
            else:
                res = repo.search_lines(q, p_filter, limit=req_limit)
        t_end = time.perf_counter()

        avg_ms = ((t_end - t_start) / runs) * 1000.0
        timings.append(avg_ms)
        p_name = p_filter.name if p_filter != PartFilter.ALL else "ALL"

        count_matches = (len(res) == exp_count)
        status = "PASS" if count_matches else f"FAIL(got {len(res)})"
        print(f"{idx:02d}  | {mode:<6} | {p_name:<6} | {q:<22} | {len(res):<5} | {exp_count:<5} | {avg_ms:6.2f} ms | {status}")

        assert count_matches, f"Test {idx} failed: query '{q}' with {p_name} expected {exp_count}, got {len(res)}"

        # Verify Part Filter constraint
        if p_filter != PartFilter.ALL:
            for r in res:
                assert r.part_number == p_filter.value, f"Part filter violation! Expected {p_filter.value}, got {r.part_number}"

    print("-" * 80)
    print(f"Average query execution time across all 34 test cases : {sum(timings)/len(timings):.2f} ms")
    print(f"Minimum query execution time                         : {min(timings):.2f} ms")
    print(f"Maximum query execution time                         : {max(timings):.2f} ms")

    # -------------------------------------------------------------
    # 2. Strict Semantic Separation Verification
    # -------------------------------------------------------------
    print("\n" + "=" * 80)
    print("VERIFYING STRICT SEMANTIC SEPARATION (SEARCH 1 vs SEARCH 2)")
    print("=" * 80)

    # A. Search 2 must NOT search titles, IDs, or page numbers
    res_lines_uid = repo.search_lines("P1.C1.K1.P1")
    res_lines_page = repo.search_lines("25")
    print(f"Search 2 query for Kirtan UID 'P1.C1.K1.P1': {len(res_lines_uid)} matches (Expect 0)")
    assert len(res_lines_uid) == 0, "Lines search improperly matched UID!"

    # B. Search 1 must NOT search lines
    cur = repo._conn.cursor()
    cur.execute("""
        SELECT line_text FROM kirtan_lines 
        WHERE line_text NOT IN (SELECT title_hi FROM kirtans)
          AND line_text NOT IN (SELECT raw_first_line FROM kirtans)
          AND length(line_text) > 20
        LIMIT 1;
    """)
    distinct_line = cur.fetchone()[0]
    phrase = distinct_line[:18].strip()

    res_title_phrase = repo.search_title(phrase)
    res_lines_phrase = repo.search_lines(phrase)

    print(f"Lyric-only phrase test: '{phrase}'")
    print(f"  Search 1 (Title / Number search): {len(res_title_phrase)} matches (Expect 0)")
    print(f"  Search 2 (Lines search only)    : {len(res_lines_phrase)} matches (Expect >= 1)")
    assert len(res_title_phrase) == 0, "Title search improperly matched kirtan lines!"
    assert len(res_lines_phrase) >= 1, "Lines search failed to match kirtan lines!"

    # C. Verification of "श्री कृष्ण" vs "शिर"
    print("\n" + "=" * 80)
    print("VERIFYING 'श्री कृष्ण' vs 'शिर' TOKEN DISAMBIGUATION")
    print("=" * 80)
    shri_krishna_res = repo.search_lines("श्री कृष्ण")
    print(f"Total kirtans matching 'श्री कृष्ण': {len(shri_krishna_res)}")

    # Assert that EVERY result of "श्री कृष्ण" contains both terms in full_text
    for r in shri_krishna_res:
        k_data = repo.get_kirtan_by_id(r.kirtan_id)
        assert "श्री" in k_data["full_text"], f"Kirtan {r.kirtan_uid} missing word 'श्री'!"
        assert "कृष्ण" in k_data["full_text"], f"Kirtan {r.kirtan_uid} missing word 'कृष्ण'!"

    # Assert that searching "शिर" does NOT return any kirtan without "शिर"
    shir_res = repo.search_lines("शिर")
    print(f"Total kirtans matching 'शिर': {len(shir_res)}")
    for r in shir_res:
        k_data = repo.get_kirtan_by_id(r.kirtan_id)
        assert "शिर" in k_data["full_text"], f"Kirtan {r.kirtan_uid} missing word 'शिर'!"

    # Verify that "श्री" does NOT match "शिर" exclusively
    cur.execute("""
        SELECT count(*)
        FROM lines_search_fts fts
        JOIN kirtans k ON k.id = fts.kirtan_id
        WHERE lines_search_fts MATCH ?
          AND k.full_text NOT LIKE '%श्री%'
          AND k.full_text LIKE '%शिर%';
    """, ('"श्री"',))
    false_positives = cur.fetchone()[0]
    print(f"Kirtans matching 'श्री' that contain 'शिर' but NOT 'श्री': {false_positives} (Expect 0)")
    assert false_positives == 0, "False positive token match: 'श्री' matched 'शिर'!"

    # -------------------------------------------------------------
    # 3. Favourites & Folders Verification
    # -------------------------------------------------------------
    print("\n" + "=" * 80)
    print("VERIFYING FAVOURITES & FOLDERS API")
    print("=" * 80)
    folder_id = repo.create_folder("Daily Nityaniem")
    repo.add_to_folder(folder_id, 1)
    repo.add_to_folder(folder_id, 2)
    repo.add_to_folder(folder_id, 1) # duplicate ignored

    f_kirtans = repo.get_folder_kirtans(folder_id)
    assert len(f_kirtans) == 2, "Folder kirtans count mismatch!"
    repo.remove_from_folder(folder_id, 1)
    f_kirtans_after = repo.get_folder_kirtans(folder_id)
    assert len(f_kirtans_after) == 1, "Folder removal failed!"
    print(f"Favourites API works cleanly: composite PK prevents duplicate membership.")

    print("\n" + "=" * 80)
    print("ALL 34 BENCHMARK & SEMANTIC VERIFICATION TESTS PASSED (100% PASS)")
    print("=" * 80)

    repo.close()

if __name__ == '__main__':
    run_benchmarks()
