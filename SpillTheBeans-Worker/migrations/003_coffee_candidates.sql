-- Migration: bean images and the review queue for imported beans (dashboard
-- Beans page → "Import queue"). Adds one nullable column to coffees and a new
-- table; touches no existing rows.
ALTER TABLE coffees ADD COLUMN image_key TEXT;   -- COFFEE_IMAGES KV key, NULL = no image

CREATE TABLE IF NOT EXISTS coffee_candidates (
  id               TEXT PRIMARY KEY,   -- source:handle, e.g. koffiekenner:syoum-family
  source           TEXT NOT NULL,      -- e.g. "Koffie Kenner"
  source_url       TEXT,
  name             TEXT NOT NULL,
  roaster          TEXT,
  origin_country   TEXT,               -- NULL until known; required to add
  origin_region    TEXT,
  process          TEXT,               -- Washed | Natural | Honey | Anaerobic; required to add
  roast_level      TEXT,               -- Light … Dark; required to add
  flavor_tags      TEXT NOT NULL DEFAULT '[]',
  tasting_note     TEXT,
  producer         TEXT,
  altitude         TEXT,
  image_source_url TEXT,               -- copied into COFFEE_IMAGES when added
  research_notes   TEXT,               -- where the data came from, open questions
  status           TEXT NOT NULL DEFAULT 'pending',   -- pending | added | declined
  coffee_id        TEXT,               -- coffees.id once added
  found_at         TEXT NOT NULL DEFAULT (datetime('now')),
  decided_at       TEXT
);
