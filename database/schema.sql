-- =====================================================================
-- Kirtan Finder SQLite Database Schema (Step 2)
-- Designed for Flutter (iOS, iPadOS, Android) using sqflite / drift
-- =====================================================================

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------
-- 1. PARTS TABLE
-- Represents the 4 main canonical parts of the Kirtan collection.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS parts (
    id INTEGER PRIMARY KEY,           -- 1, 2, 3, 4
    part_number INTEGER UNIQUE NOT NULL,
    name_hi TEXT NOT NULL,            -- e.g. "भाग १"
    name_en TEXT NOT NULL,            -- e.g. "Part 1"
    order_num INTEGER NOT NULL
);

-- ---------------------------------------------------------------------
-- 2. CHAPTERS TABLE
-- 409 chapters across the 4 parts.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chapters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chapter_uid TEXT UNIQUE NOT NULL, -- e.g. "P1.C001"
    part_id INTEGER NOT NULL REFERENCES parts(id) ON DELETE RESTRICT,
    part_number INTEGER NOT NULL,     -- 1..4 (denormalized for filtering)
    chapter_number INTEGER NOT NULL,  -- 1..173
    title_hi TEXT NOT NULL,           -- e.g. "जन्माष्टमी बधाई"
    title_en TEXT,                    -- e.g. "Janmashtami Badhai" (from master_titles.xhtml)
    subtitle_hi TEXT,                 -- e.g. "आसोवद - १३" from meta, or NULL
    source_filename TEXT NOT NULL,    -- e.g. "1_001_जन्माष्टमी बधाई.xhtml"
    order_num INTEGER NOT NULL,       -- 1..409 global sequence
    CONSTRAINT uq_part_chapter UNIQUE (part_number, chapter_number)
);

-- ---------------------------------------------------------------------
-- 3. KIRTANS TABLE (Core Entity)
-- 6,584 kirtans with authoritative titles, metadata, and link mappings.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS kirtans (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    kirtan_uid TEXT UNIQUE NOT NULL,  -- Stable global UID: "P1.C1.K1.P1"
    part_id INTEGER NOT NULL REFERENCES parts(id) ON DELETE RESTRICT,
    chapter_id INTEGER NOT NULL REFERENCES chapters(id) ON DELETE RESTRICT,
    part_number INTEGER NOT NULL,     -- 1..4 (for fast Part Filter)
    chapter_number INTEGER NOT NULL,  -- Chapter number in part
    kirtan_number INTEGER NOT NULL,   -- Kirtan sequence in chapter
    old_page INTEGER NOT NULL,        -- Printed book page (data-old-page)
    raag TEXT NOT NULL,               -- Raag / Prakar string as in source
    raag_normalized TEXT NOT NULL,    -- Cleaned raag string for UI filter
    title_hi TEXT NOT NULL,           -- Canonical Hindi title from master_index
    title_en TEXT NOT NULL,           -- Pre-existing English title from master_index
    raw_first_line TEXT NOT NULL,     -- Sung first line from XHTML .title-line
    full_text TEXT NOT NULL,          -- Complete lyrics (all lines concatenated)
    youtube_url TEXT,                 -- YouTube search query link from source
    source_filename TEXT NOT NULL,    -- Source XHTML filename
    source_anchor TEXT NOT NULL,      -- Source anchor ID (e.g. "1-1-1")
    search_id_raw TEXT NOT NULL,      -- e.g. "कीर्तन क्रमांक : १.१"
    line_count INTEGER NOT NULL,      -- Number of lyric lines
    verse_count INTEGER NOT NULL,     -- Number of stanzas/verses
    order_num INTEGER NOT NULL,       -- Global sequential ordering (1..6584)
    unique_kirtan_id TEXT UNIQUE NOT NULL -- Canonical public unique ID (e.g. "n1", "n1541", "n6584")
);

-- ---------------------------------------------------------------------
-- 4. KIRTAN LINES TABLE (Structured Lyrics Viewer)
-- 55,787 individual lines for verse/line rendering in UI.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS kirtan_lines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    kirtan_id INTEGER NOT NULL REFERENCES kirtans(id) ON DELETE CASCADE,
    line_number INTEGER NOT NULL,     -- Line sequence in kirtan (1..N)
    verse_number INTEGER NOT NULL,    -- Stanza number (1..M)
    is_title_line BOOLEAN NOT NULL DEFAULT 0,
    is_verse_end BOOLEAN NOT NULL DEFAULT 0,
    line_text TEXT NOT NULL,          -- Lyric line text
    verse_marker TEXT                 -- e.g. "॥१॥" or NULL
);

-- ---------------------------------------------------------------------
-- 5. B-TREE INDEXES
-- Designed specifically for the query patterns and Part filters.
-- ---------------------------------------------------------------------

-- A. Page number lookup: Crucial for numeric queries (e.g. '25')
CREATE INDEX IF NOT EXISTS idx_kirtans_part_old_page 
ON kirtans(part_number, old_page);

CREATE INDEX IF NOT EXISTS idx_kirtans_old_page 
ON kirtans(old_page);

-- B. Part filter and chapter browsing
CREATE INDEX IF NOT EXISTS idx_kirtans_part_number 
ON kirtans(part_number);

CREATE INDEX IF NOT EXISTS idx_kirtans_chapter_id 
ON kirtans(chapter_id);

CREATE INDEX IF NOT EXISTS idx_kirtans_part_chap_kirtan 
ON kirtans(part_number, chapter_number, kirtan_number);

-- C. Stable identifier lookup
CREATE INDEX IF NOT EXISTS idx_kirtans_kirtan_uid 
ON kirtans(kirtan_uid);

CREATE UNIQUE INDEX IF NOT EXISTS idx_kirtans_unique_kirtan_id 
ON kirtans(unique_kirtan_id);

-- D. Chapter indexing
CREATE INDEX IF NOT EXISTS idx_chapters_part_number 
ON chapters(part_number, chapter_number);

-- E. Kirtan lines indexing for fast display when viewing a Kirtan
CREATE INDEX IF NOT EXISTS idx_kirtan_lines_kirtan_line 
ON kirtan_lines(kirtan_id, line_number);

-- ---------------------------------------------------------------------
-- 6. FULL-TEXT SEARCH (FTS5) INDEXES
-- Separate virtual tables for separate search modes.
-- ---------------------------------------------------------------------

-- SEARCH 1 FTS: Title & Identifier Search
-- Searches Hindi title, English title, Kirtan UID, and search_id.
-- (Numeric page search is handled via indexed B-tree old_page query).
-- categories 'L* M* N*' ensures Devanagari vowel marks (matras) and viramas (M*)
-- are treated as part of the word tokens rather than word delimiters.
CREATE VIRTUAL TABLE IF NOT EXISTS title_search_fts USING fts5(
    kirtan_id UNINDEXED,
    kirtan_uid,
    title_hi,
    title_en,
    search_id_raw,
    tokenize = "unicode61 categories 'L* M* N*'"
);

-- SEARCH 2 FTS: Kirtan Lines Search Only
-- Contains ONLY the actual kirtan lyrics/lines.
-- Does NOT contain titles, raag, chapter, page, or IDs.
CREATE VIRTUAL TABLE IF NOT EXISTS lines_search_fts USING fts5(
    kirtan_id UNINDEXED,
    kirtan_lines_text,
    tokenize = "unicode61 categories 'L* M* N*'"
);

-- ---------------------------------------------------------------------
-- 7. USER FAVOURITES & FOLDERS (No text duplication)
-- Relational references: a kirtan can belong to multiple folders.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS folders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL,      -- Epoch timestamp (milliseconds)
    updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS folder_kirtans (
    folder_id INTEGER NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
    kirtan_id INTEGER NOT NULL REFERENCES kirtans(id) ON DELETE CASCADE,
    added_at INTEGER NOT NULL,         -- Epoch timestamp (milliseconds)
    PRIMARY KEY (folder_id, kirtan_id)
);

CREATE INDEX IF NOT EXISTS idx_folder_kirtans_kirtan_id 
ON folder_kirtans(kirtan_id);
