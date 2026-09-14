-- Migration: cache Google Places details in D1, refreshed daily by the worker cron.
-- Safe to run against the live database — creates the table only if absent and
-- touches nothing else.
CREATE TABLE IF NOT EXISTS place_details (
  google_place_id   TEXT PRIMARY KEY,
  rating            REAL,
  user_rating_count INTEGER,
  weekday_hours     TEXT,   -- JSON [{day, hours}]
  periods           TEXT,   -- JSON Google opening-hours periods (for live open-now)
  photo_names       TEXT,   -- JSON [places/.../photos/...] (proxied to URLs on read)
  tags              TEXT,   -- JSON array of attribute labels
  reviews           TEXT,   -- JSON [{author, authorPhotoURI, rating, relativeTime, text}]
  google_maps_uri   TEXT,
  website_uri       TEXT,
  address           TEXT,   -- Google formatted address
  updated_at        TEXT NOT NULL DEFAULT (datetime('now'))
);
