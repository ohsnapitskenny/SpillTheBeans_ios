-- Spill the Beans — D1 schema
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS coffees;
DROP TABLE IF EXISTS coffee_shops;
DROP TABLE IF EXISTS place_details;

CREATE TABLE coffees (
  id             TEXT PRIMARY KEY,
  name           TEXT NOT NULL,
  origin_country TEXT NOT NULL,
  origin_region  TEXT,
  origin_flag    TEXT NOT NULL,
  process        TEXT NOT NULL,
  roast_level    TEXT NOT NULL,
  flavor_tags    TEXT NOT NULL,   -- JSON array of strings
  tasting_note   TEXT NOT NULL,
  producer       TEXT,
  altitude       TEXT,
  harvest_season TEXT,
  roaster        TEXT,            -- Dutch roaster whose lineup this bean is from
  created_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE coffee_shops (
  id              TEXT PRIMARY KEY,
  name            TEXT NOT NULL,
  address         TEXT NOT NULL,
  latitude        REAL NOT NULL,
  longitude       REAL NOT NULL,
  category        TEXT NOT NULL,
  rating          REAL NOT NULL,
  opening_hours   TEXT NOT NULL,    -- JSON array of {day, hours}
  roaster_info    TEXT,
  description     TEXT NOT NULL,
  tags            TEXT NOT NULL,    -- JSON array of strings
  google_place_id TEXT,             -- Places API resource id (backfill-place-ids.js)
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE reviews (
  id          TEXT PRIMARY KEY,
  coffee_id   TEXT NOT NULL REFERENCES coffees(id),
  user_id     TEXT NOT NULL,
  username    TEXT NOT NULL,
  brew_method TEXT NOT NULL,
  rating      INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  note        TEXT NOT NULL,
  created_at  TEXT NOT NULL
);

CREATE INDEX idx_reviews_coffee ON reviews(coffee_id);
CREATE INDEX idx_reviews_user   ON reviews(user_id);

-- Google Places details, cached from the API and refreshed daily by the worker
-- cron. Keyed by the Google place id (coffee_shops.google_place_id links to it).
CREATE TABLE place_details (
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
