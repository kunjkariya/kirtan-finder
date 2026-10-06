#!/usr/bin/env python3
"""
search_repository.py — Clean, high-performance Search Repository & Data Access Layer.
Implements the two distinct search modes (Title/Number search and Kirtan lines search)
with strict Part filtering, B-tree indexed page lookups, and FTS5 snippet generation.
"""

import os
import re
import sqlite3
import unicodedata
from enum import Enum
from typing import List, Dict, Any, Optional

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_DB_PATH = os.path.join(SCRIPT_DIR, "kirtan_finder.db")

class PartFilter(Enum):
    ALL = None
    PART_1 = 1
    PART_2 = 2
    PART_3 = 3
    PART_4 = 4

    @classmethod
    def from_value(cls, val):
        if isinstance(val, cls):
            return val
        if val is None or val == 0 or val == "ALL" or val == "ALL_PARTS":
            return cls.ALL
        if isinstance(val, int) and 1 <= val <= 4:
            return cls(val)
        if isinstance(val, str):
            clean = val.strip().upper()
            if clean in ("1", "PART_1", "PART 1", "P1"):
                return cls.PART_1
            if clean in ("2", "PART_2", "PART 2", "P2"):
                return cls.PART_2
            if clean in ("3", "PART_3", "PART 3", "P3"):
                return cls.PART_3
            if clean in ("4", "PART_4", "PART 4", "P4"):
                return cls.PART_4
        return cls.ALL

class SearchResult:
    def __init__(self, data: Dict[str, Any]):
        self.kirtan_id: int = data.get("id")
        self.kirtan_uid: str = data.get("kirtan_uid", "")
        self.part_number: int = data.get("part_number", 0)
        self.chapter_number: int = data.get("chapter_number", 0)
        self.chapter_title: str = data.get("chapter_title", "")
        self.kirtan_number: int = data.get("kirtan_number", 0)
        self.old_page: int = data.get("old_page", 0)
        self.raag: str = data.get("raag", "")
        self.raag_normalized: str = data.get("raag_normalized", "")
        self.title_hi: str = data.get("title_hi", "")
        self.title_en: str = data.get("title_en", "")
        self.raw_first_line: str = data.get("raw_first_line", "")
        self.source_filename: str = data.get("source_filename", "")
        self.source_anchor: str = data.get("source_anchor", "")
        self.matching_snippet: Optional[str] = data.get("matching_snippet", None)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "kirtan_id": self.kirtan_id,
            "kirtan_uid": self.kirtan_uid,
            "part_number": self.part_number,
            "chapter_number": self.chapter_number,
            "chapter_title": self.chapter_title,
            "kirtan_number": self.kirtan_number,
            "old_page": self.old_page,
            "raag": self.raag,
            "raag_normalized": self.raag_normalized,
            "title_hi": self.title_hi,
            "title_en": self.title_en,
            "raw_first_line": self.raw_first_line,
            "source_filename": self.source_filename,
            "source_anchor": self.source_anchor,
            "matching_snippet": self.matching_snippet
        }

    def __repr__(self):
        return (f"<SearchResult [{self.kirtan_uid}] Part {self.part_number}, "
                f"Page {self.old_page} | {self.title_hi} | {self.title_en}>")


class KirtanRepository:
    """
    Search Repository implementing:
    - Search 1: Title / Number / Page search
    - Search 2: Kirtan lines search only
    - Part filtering
    - Kirtan details & line viewing
    - Favourites / Folders management
    """

    DEV_TO_LAT = str.maketrans("०१२३४५६७८९", "0123456789")
    LAT_TO_DEV = str.maketrans("0123456789", "०१२३४५६७८९")

    def __init__(self, db_path: str = DEFAULT_DB_PATH):
        self.db_path = db_path
        if not os.path.exists(db_path):
            raise FileNotFoundError(f"Database not found at: {db_path}. Run importer.py first.")
        self._conn = sqlite3.connect(self.db_path)
        self._conn.row_factory = sqlite3.Row

    def close(self):
        if self._conn:
            self._conn.close()

    def _prepare_title_fts_query(self, query: str) -> str:
        """
        Prepare query for Search 1 (Title Search FTS).
        - If query is wrapped in quotes, treats as exact phrase.
        - Latin/English tokens get prefix wildcard '*' for natural autocomplete (e.g. 'Vraja' -> '"Vraja"*').
        - Devanagari tokens match exact words or user-provided wildcards.
        """
        q = query.strip()
        if (q.startswith('"') and q.endswith('"')) or (q.startswith("'") and q.endswith("'")):
            inner = q[1:-1].strip()
            cleaned = re.sub(r'["*:\^\-\(\)\[\]\{\}\?\+\,\;।॥]', " ", inner)
            tokens = [t.strip() for t in cleaned.split() if t.strip()]
            if not tokens:
                return ""
            return '"' + " ".join(tokens) + '"'

        cleaned = re.sub(r'["*:\^\-\(\)\[\]\{\}\?\+\.\,\;।॥]', " ", q)
        tokens = [t.strip() for t in cleaned.split() if t.strip()]
        if not tokens:
            return ""

        formatted = []
        for t in tokens:
            # If Latin/ASCII characters, add prefix wildcard for typing convenience
            if all(ord(ch) < 128 for ch in t):
                formatted.append(f'"{t}"*')
            else:
                formatted.append(f'"{t}"')
        return " ".join(formatted)

    def _prepare_lines_fts_query(self, query: str) -> str:
        """
        Prepare query for Search 2 (Kirtan Lines Search Only).
        - If query is wrapped in quotes, treats as exact adjacent phrase (e.g. '"श्री कृष्ण"').
        - Unquoted words are matched as exact tokens combined with boolean AND (e.g. '"श्री" "कृष्ण"').
        - Does NOT add automatic prefix '*' wildcards, preventing false-positive prefix matches like 'शिर' matching 'श्री'.
        """
        q = query.strip()
        if (q.startswith('"') and q.endswith('"')) or (q.startswith("'") and q.endswith("'")):
            inner = q[1:-1].strip()
            cleaned = re.sub(r'["*:\^\-\(\)\[\]\{\}\?\+\,\;।॥]', " ", inner)
            tokens = [t.strip() for t in cleaned.split() if t.strip()]
            if not tokens:
                return ""
            return '"' + " ".join(tokens) + '"'

        cleaned = re.sub(r'["*:\^\-\(\)\[\]\{\}\?\+\.\,\;।॥]', " ", q)
        tokens = [t.strip() for t in cleaned.split() if t.strip()]
        if not tokens:
            return ""
        # Exact tokens only — space in FTS5 acts as boolean AND
        return " ".join(f'"{t}"' for t in tokens)

    # -----------------------------------------------------------------
    # SEARCH 1: Title / Number / Page Search
    # -----------------------------------------------------------------
    def search_title(
        self,
        query: str,
        part_filter: Any = PartFilter.ALL,
        limit: int = 50,
        offset: int = 0
    ) -> List[SearchResult]:
        """
        SEARCH 1: Title / Number Search
        Searches:
        1. Kirtan number / ID (e.g. 'P1.C1.K1.P1', '1.1')
        2. Old printed page number (e.g. '25' or '२५')
        3. Hindi title (e.g. 'व्रज भयो')
        4. English title (e.g. 'Vraja Bhayo')

        Does NOT search kirtan lines.
        """
        q = query.strip()
        if not q:
            return []

        p_enum = PartFilter.from_value(part_filter)
        part_val = p_enum.value # None for ALL, or 1, 2, 3, 4

        q_norm = q.translate(self.DEV_TO_LAT)
        cur = self._conn.cursor()

        # -------------------------------------------------------------
        # Path A: Pure Numeric Query -> Page Number Search (e.g. "25", "२५")
        # Uses B-tree index: idx_kirtans_part_old_page or idx_kirtans_old_page
        # -------------------------------------------------------------
        if q_norm.isdigit():
            page_num = int(q_norm)
            sql = """
                SELECT k.id, k.kirtan_uid, k.part_number, k.chapter_number, c.title_hi AS chapter_title,
                       k.kirtan_number, k.old_page, k.raag, k.raag_normalized,
                       k.title_hi, k.title_en, k.raw_first_line,
                       k.source_filename, k.source_anchor, NULL AS matching_snippet
                FROM kirtans k
                JOIN chapters c ON k.chapter_id = c.id
                WHERE k.old_page = ?
                  AND (? IS NULL OR k.part_number = ?)
                ORDER BY k.part_number, k.chapter_number, k.kirtan_number
                LIMIT ? OFFSET ?;
            """
            cur.execute(sql, (page_num, part_val, part_val, limit, offset))
            rows = cur.fetchall()
            return [SearchResult(dict(r)) for r in rows]

        # -------------------------------------------------------------
        # Path B: Full Canonical UID (e.g. "P1.C1.K1.P1")
        # Uses unique index on kirtan_uid
        # -------------------------------------------------------------
        if re.match(r"^p[1-4]\.c\d+\.k\d+\.p\d+$", q_norm, re.IGNORECASE):
            uid_upper = q_norm.upper()
            sql = """
                SELECT k.id, k.kirtan_uid, k.part_number, k.chapter_number, c.title_hi AS chapter_title,
                       k.kirtan_number, k.old_page, k.raag, k.raag_normalized,
                       k.title_hi, k.title_en, k.raw_first_line,
                       k.source_filename, k.source_anchor, NULL AS matching_snippet
                FROM kirtans k
                JOIN chapters c ON k.chapter_id = c.id
                WHERE upper(k.kirtan_uid) = ?
                  AND (? IS NULL OR k.part_number = ?)
                LIMIT ? OFFSET ?;
            """
            cur.execute(sql, (uid_upper, part_val, part_val, limit, offset))
            rows = cur.fetchall()
            if rows:
                return [SearchResult(dict(r)) for r in rows]

        # -------------------------------------------------------------
        # Path C: Chapter.Kirtan Numbering (e.g. "1.1", "१.१", "C1.K1", "C1.K1.P1")
        # Strictly matches Chapter Number and Kirtan Number
        # -------------------------------------------------------------
        m_num = re.match(r"^c?(\d+)\.k?(\d+)(\.p?(\d+))?$", q_norm, re.IGNORECASE)
        if m_num:
            chap_n = int(m_num.group(1))
            kirt_n = int(m_num.group(2))
            page_n = int(m_num.group(4)) if m_num.group(4) else None

            sql = """
                SELECT k.id, k.kirtan_uid, k.part_number, k.chapter_number, c.title_hi AS chapter_title,
                       k.kirtan_number, k.old_page, k.raag, k.raag_normalized,
                       k.title_hi, k.title_en, k.raw_first_line,
                       k.source_filename, k.source_anchor, NULL AS matching_snippet
                FROM kirtans k
                JOIN chapters c ON k.chapter_id = c.id
                WHERE k.chapter_number = ?
                  AND k.kirtan_number = ?
                  AND (? IS NULL OR k.old_page = ?)
                  AND (? IS NULL OR k.part_number = ?)
                ORDER BY k.part_number, k.chapter_number, k.kirtan_number
                LIMIT ? OFFSET ?;
            """
            cur.execute(sql, (chap_n, kirt_n, page_n, page_n, part_val, part_val, limit, offset))
            rows = cur.fetchall()
            if rows:
                return [SearchResult(dict(r)) for r in rows]

        # -------------------------------------------------------------
        # Path D: Text Title Search (Hindi or English titles via FTS5)
        # -------------------------------------------------------------
        fts_q = self._prepare_title_fts_query(q)
        if not fts_q:
            return []

        sql = """
            SELECT k.id, k.kirtan_uid, k.part_number, k.chapter_number, c.title_hi AS chapter_title,
                   k.kirtan_number, k.old_page, k.raag, k.raag_normalized,
                   k.title_hi, k.title_en, k.raw_first_line,
                   k.source_filename, k.source_anchor, NULL AS matching_snippet
            FROM title_search_fts fts
            JOIN kirtans k ON k.id = fts.kirtan_id
            JOIN chapters c ON k.chapter_id = c.id
            WHERE title_search_fts MATCH ?
              AND (? IS NULL OR k.part_number = ?)
            ORDER BY fts.rank
            LIMIT ? OFFSET ?;
        """
        cur.execute(sql, (fts_q, part_val, part_val, limit, offset))
        rows = cur.fetchall()

        # Fallback to substring LIKE if FTS had 0 results for single short token
        if not rows and len(q) >= 2:
            like_pat = f"%{q}%"
            like_sql = """
                SELECT k.id, k.kirtan_uid, k.part_number, k.chapter_number, c.title_hi AS chapter_title,
                       k.kirtan_number, k.old_page, k.raag, k.raag_normalized,
                       k.title_hi, k.title_en, k.raw_first_line,
                       k.source_filename, k.source_anchor, NULL AS matching_snippet
                FROM kirtans k
                JOIN chapters c ON k.chapter_id = c.id
                WHERE (k.title_hi LIKE ? OR k.title_en LIKE ? OR k.kirtan_uid LIKE ?)
                  AND (? IS NULL OR k.part_number = ?)
                ORDER BY k.part_number, k.chapter_number, k.kirtan_number
                LIMIT ? OFFSET ?;
            """
            cur.execute(like_sql, (like_pat, like_pat, like_pat, part_val, part_val, limit, offset))
            rows = cur.fetchall()

        return [SearchResult(dict(r)) for r in rows]

    # -----------------------------------------------------------------
    # SEARCH 2: Kirtan Lines Search Only
    # -----------------------------------------------------------------
    def search_lines(
        self,
        query: str,
        part_filter: Any = PartFilter.ALL,
        limit: int = 50,
        offset: int = 0
    ) -> List[SearchResult]:
        """
        SEARCH 2: Kirtan Lines Search
        Searches ONLY the actual kirtan lines (complete kirtan text).
        Must NOT search Hindi title, English title, chapter, raag, page, or ID.
        Returns matching records with highlighted snippets of the matched line.
        """
        q = query.strip()
        if not q:
            return []

        p_enum = PartFilter.from_value(part_filter)
        part_val = p_enum.value

        fts_q = self._prepare_lines_fts_query(q)
        if not fts_q:
            return []

        cur = self._conn.cursor()

        sql = """
            SELECT k.id, k.kirtan_uid, k.part_number, k.chapter_number, c.title_hi AS chapter_title,
                   k.kirtan_number, k.old_page, k.raag, k.raag_normalized,
                   k.title_hi, k.title_en, k.raw_first_line,
                   k.source_filename, k.source_anchor,
                   snippet(lines_search_fts, 1, '<mark>', '</mark>', '...', 10) AS matching_snippet
            FROM lines_search_fts fts
            JOIN kirtans k ON k.id = fts.kirtan_id
            JOIN chapters c ON k.chapter_id = c.id
            WHERE lines_search_fts MATCH ?
              AND (? IS NULL OR k.part_number = ?)
            ORDER BY fts.rank
            LIMIT ? OFFSET ?;
        """
        cur.execute(sql, (fts_q, part_val, part_val, limit, offset))
        rows = cur.fetchall()

        # Fallback to substring LIKE if FTS had 0 results
        if not rows and len(q) >= 2:
            like_pat = f"%{q}%"
            like_sql = """
                SELECT k.id, k.kirtan_uid, k.part_number, k.chapter_number, c.title_hi AS chapter_title,
                       k.kirtan_number, k.old_page, k.raag, k.raag_normalized,
                       k.title_hi, k.title_en, k.raw_first_line,
                       k.source_filename, k.source_anchor, NULL AS matching_snippet
                FROM kirtans k
                JOIN chapters c ON k.chapter_id = c.id
                WHERE k.full_text LIKE ?
                  AND (? IS NULL OR k.part_number = ?)
                ORDER BY k.part_number, k.chapter_number, k.kirtan_number
                LIMIT ? OFFSET ?;
            """
            cur.execute(like_sql, (like_pat, part_val, part_val, limit, offset))
            rows = cur.fetchall()

        return [SearchResult(dict(r)) for r in rows]

    # -----------------------------------------------------------------
    # Content Retrieval Methods
    # -----------------------------------------------------------------
    def get_kirtan_by_id(self, kirtan_id: int) -> Optional[Dict[str, Any]]:
        cur = self._conn.cursor()
        cur.execute("""
            SELECT k.*, c.title_hi as chapter_title, c.chapter_uid
            FROM kirtans k
            JOIN chapters c ON k.chapter_id = c.id
            WHERE k.id = ?;
        """, (kirtan_id,))
        row = cur.fetchone()
        return dict(row) if row else None

    def get_kirtan_by_uid(self, kirtan_uid: str) -> Optional[Dict[str, Any]]:
        cur = self._conn.cursor()
        cur.execute("""
            SELECT k.*, c.title_hi as chapter_title, c.chapter_uid
            FROM kirtans k
            JOIN chapters c ON k.chapter_id = c.id
            WHERE upper(k.kirtan_uid) = upper(?);
        """, (kirtan_uid,))
        row = cur.fetchone()
        return dict(row) if row else None

    def get_kirtan_lines(self, kirtan_id: int) -> List[Dict[str, Any]]:
        cur = self._conn.cursor()
        cur.execute("""
            SELECT line_number, verse_number, is_title_line, is_verse_end, line_text, verse_marker
            FROM kirtan_lines
            WHERE kirtan_id = ?
            ORDER BY line_number ASC;
        """, (kirtan_id,))
        return [dict(r) for r in cur.fetchall()]

    def get_parts(self) -> List[Dict[str, Any]]:
        cur = self._conn.cursor()
        cur.execute("SELECT * FROM parts ORDER BY order_num;")
        return [dict(r) for r in cur.fetchall()]

    def get_chapters(self, part_number: Optional[int] = None) -> List[Dict[str, Any]]:
        cur = self._conn.cursor()
        if part_number is not None:
            cur.execute("SELECT * FROM chapters WHERE part_number = ? ORDER BY chapter_number;", (part_number,))
        else:
            cur.execute("SELECT * FROM chapters ORDER BY order_num;")
        return [dict(r) for r in cur.fetchall()]

    # -----------------------------------------------------------------
    # Favourites & Folders API
    # -----------------------------------------------------------------
    def create_folder(self, name: str) -> int:
        cur = self._conn.cursor()
        import time
        now = int(time.time() * 1000)
        cur.execute("INSERT INTO folders (name, created_at, updated_at) VALUES (?, ?, ?);", (name, now, now))
        self._conn.commit()
        return cur.lastrowid

    def get_folders(self) -> List[Dict[str, Any]]:
        cur = self._conn.cursor()
        cur.execute("""
            SELECT f.id, f.name, f.created_at, count(fk.kirtan_id) as kirtan_count
            FROM folders f
            LEFT JOIN folder_kirtans fk ON f.id = fk.folder_id
            GROUP BY f.id
            ORDER BY f.name;
        """)
        return [dict(r) for r in cur.fetchall()]

    def add_to_folder(self, folder_id: int, kirtan_id: int) -> bool:
        cur = self._conn.cursor()
        import time
        now = int(time.time() * 1000)
        try:
            cur.execute("""
                INSERT OR IGNORE INTO folder_kirtans (folder_id, kirtan_id, added_at)
                VALUES (?, ?, ?);
            """, (folder_id, kirtan_id, now))
            self._conn.commit()
            return True
        except Exception:
            return False

    def remove_from_folder(self, folder_id: int, kirtan_id: int) -> bool:
        cur = self._conn.cursor()
        cur.execute("DELETE FROM folder_kirtans WHERE folder_id = ? AND kirtan_id = ?;", (folder_id, kirtan_id))
        self._conn.commit()
        return cur.rowcount > 0

    def get_folder_kirtans(self, folder_id: int) -> List[Dict[str, Any]]:
        cur = self._conn.cursor()
        cur.execute("""
            SELECT k.id, k.kirtan_uid, k.part_number, k.chapter_number, k.kirtan_number,
                   k.old_page, k.raag, k.title_hi, k.title_en, fk.added_at
            FROM folder_kirtans fk
            JOIN kirtans k ON fk.kirtan_id = k.id
            WHERE fk.folder_id = ?
            ORDER BY fk.added_at DESC;
        """, (folder_id,))
        return [dict(r) for r in cur.fetchall()]
