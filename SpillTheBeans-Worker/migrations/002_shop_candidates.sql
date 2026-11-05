-- Migration: review queue for cafés found on Google by the dashboard's "Find new cafés".
-- Safe to run against the live database — creates the table only if absent and
-- touches nothing else.
CREATE TABLE IF NOT EXISTS shop_candidates (
  google_place_id   TEXT PRIMARY KEY,
  name              TEXT NOT NULL,
  address           TEXT NOT NULL,
  latitude          REAL NOT NULL,
  longitude         REAL NOT NULL,
  rating            REAL,
  user_rating_count INTEGER,
  summary           TEXT,            -- Google editorial summary, used as the description
  google_maps_uri   TEXT,
  website_uri       TEXT,
  search_query      TEXT,            -- the search that found it, e.g. "specialty coffee in Utrecht"
  status            TEXT NOT NULL DEFAULT 'pending',   -- pending | added | declined
  shop_id           TEXT,            -- coffee_shops.id once added
  found_at          TEXT NOT NULL DEFAULT (datetime('now')),
  decided_at        TEXT
);
