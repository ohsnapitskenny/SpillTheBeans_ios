-- Spill the Beans — D1 schema
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS coffees;
DROP TABLE IF EXISTS coffee_shops;

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
  created_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE coffee_shops (
  id            TEXT PRIMARY KEY,
  name          TEXT NOT NULL,
  address       TEXT NOT NULL,
  latitude      REAL NOT NULL,
  longitude     REAL NOT NULL,
  category      TEXT NOT NULL,
  rating        REAL NOT NULL,
  opening_hours TEXT NOT NULL,    -- JSON array of {day, hours}
  roaster_info  TEXT,
  description   TEXT NOT NULL,
  tags          TEXT NOT NULL,    -- JSON array of strings
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
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
