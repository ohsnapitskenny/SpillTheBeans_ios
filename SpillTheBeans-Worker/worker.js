// Spill the Beans — API Worker
// Auth endpoints:
//   POST /auth/register  { username, password, displayName?, email? }
//   POST /auth/login     { username, password }
//   GET  /auth/verify    Authorization: Bearer <token>
//   POST /auth/logout    Authorization: Bearer <token>
//   GET  /admin/me       Authorization: Bearer <token> — 200 for admins, 403 otherwise
//
// Admin endpoints (Authorization: Bearer <admin session token>):
//   POST /admin/shops/discover                 { query? } — search Google, queue new cafés
//   GET  /admin/shop-candidates                the queue (pending, added, declined)
//   POST /admin/shop-candidates/:placeId/add   { category? } — add to coffee_shops
//   POST /admin/shop-candidates/:placeId/decline | /restore
//   GET  /admin/coffee-candidates              bean import queue
//   POST /admin/coffee-candidates/:id          { ...fields } — edit a pending bean
//   POST /admin/coffee-candidates/:id/add      add to coffees (copies the image into KV)
//   POST /admin/coffee-candidates/:id/decline | /restore
//   POST /admin/refresh-places                 refresh the stalest cached places (also ADMIN_TOKEN)
//
// Data endpoints (backed by D1):
//   GET  /coffees                 — all coffee beans
//   GET  /shops                   — all coffee shops
//   GET  /coffees/:id/reviews     — reviews for one coffee
//   GET  /my/reviews              — reviews by the authenticated user
//   POST /reviews                 — create a review (authenticated)
//
// Google Places endpoints (key stays server-side):
//   GET  /shops/:id/place         — place details, served from the D1 cache
//   GET  /place-photo?name=&w=    — streams a Places photo through the worker
//   GET  /coffee-images/:key      — a bean photo stored in COFFEE_IMAGES (KV)
//   POST /admin/refresh-places    — force a full refresh (Authorization: Bearer ADMIN_TOKEN)
//
// The place cache (D1 table `place_details`) is refreshed by the worker only:
// a daily cron job. App requests are always answered from the cache.
//
// Bindings (set in wrangler.toml):
//   USERS    (KV) — user records keyed by username
//   SESSIONS (KV) — session tokens with 90-day TTL
//   DB       (D1) — coffees, coffee_shops, reviews, place_details tables
//
// Secrets:
//   GOOGLE_MAPS_API_KEY — Places API key (wrangler secret put GOOGLE_MAPS_API_KEY)
//   ADMIN_TOKEN         — guards POST /admin/refresh-places (wrangler secret put ADMIN_TOKEN)

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  });
}

// PBKDF2 with SHA-256, 100k iterations — runs natively in the V8 runtime.
async function hashPassword(password, salt) {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw', enc.encode(password), { name: 'PBKDF2' }, false, ['deriveBits']
  );
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt: enc.encode(salt), iterations: 100_000, hash: 'SHA-256' },
    key, 256
  );
  return Array.from(new Uint8Array(bits)).map(b => b.toString(16).padStart(2, '0')).join('');
}

function randomHex(bytes = 32) {
  const arr = new Uint8Array(bytes);
  crypto.getRandomValues(arr);
  return Array.from(arr).map(b => b.toString(16).padStart(2, '0')).join('');
}

// ── Route handlers ────────────────────────────────────────────────────────────

async function handleRegister(request, env) {
  let body;
  try { body = await request.json(); } catch { return json({ error: 'Invalid JSON' }, 400); }

  const { username, password, displayName, email } = body;
  if (!username || !password) return json({ error: 'username and password are required' }, 400);

  const normalized = username.toLowerCase().trim();
  if (normalized.length < 3)  return json({ error: 'Username must be at least 3 characters' }, 400);
  if (password.length < 8)    return json({ error: 'Password must be at least 8 characters' }, 400);

  const existing = await env.USERS.get(`user:${normalized}`);
  if (existing) return json({ error: 'Username already taken' }, 409);

  const id   = crypto.randomUUID();
  const salt = randomHex(16);
  const hash = await hashPassword(password, salt);

  const user = {
    id,
    username: normalized,
    displayName: (displayName || '').trim() || normalized,
    email: email || null,
    passwordHash: hash,
    salt,
    createdAt: new Date().toISOString(),
  };

  await env.USERS.put(`user:${normalized}`, JSON.stringify(user));

  const token = randomHex(32);
  await env.SESSIONS.put(
    `session:${token}`,
    JSON.stringify({ userId: id, username: normalized, displayName: user.displayName, email: user.email }),
    { expirationTtl: 60 * 60 * 24 * 90 }   // 90 days
  );

  return json({
    token,
    user: { id, username: normalized, displayName: user.displayName, email: user.email },
  });
}

async function handleLogin(request, env) {
  let body;
  try { body = await request.json(); } catch { return json({ error: 'Invalid JSON' }, 400); }

  const { username, password } = body;
  if (!username || !password) return json({ error: 'username and password are required' }, 400);

  const normalized = username.toLowerCase().trim();
  const raw = await env.USERS.get(`user:${normalized}`);
  if (!raw) return json({ error: 'Invalid username or password' }, 401);

  const user = JSON.parse(raw);
  const hash = await hashPassword(password, user.salt);
  if (hash !== user.passwordHash) return json({ error: 'Invalid username or password' }, 401);

  const token = randomHex(32);
  await env.SESSIONS.put(
    `session:${token}`,
    JSON.stringify({ userId: user.id, username: user.username, displayName: user.displayName, email: user.email }),
    { expirationTtl: 60 * 60 * 24 * 90 }
  );

  return json({
    token,
    user: { id: user.id, username: user.username, displayName: user.displayName, email: user.email },
  });
}

async function handleVerify(request, env) {
  const token = (request.headers.get('Authorization') || '').replace('Bearer ', '').trim();
  if (!token) return json({ error: 'Missing token' }, 401);

  const raw = await env.SESSIONS.get(`session:${token}`);
  if (!raw) return json({ error: 'Invalid or expired token' }, 401);

  const s = JSON.parse(raw);
  return json({ user: { id: s.userId, username: s.username, displayName: s.displayName, email: s.email } });
}

async function handleLogout(request, env) {
  const token = (request.headers.get('Authorization') || '').replace('Bearer ', '').trim();
  if (token) await env.SESSIONS.delete(`session:${token}`);
  return json({ success: true });
}

// Admins are the usernames listed in ADMIN_USERNAMES (comma-separated, see wrangler.toml).
function isAdmin(env, username) {
  const admins = (env.ADMIN_USERNAMES || '').split(',').map(u => u.trim().toLowerCase()).filter(Boolean);
  return admins.includes(username);
}

// Used by the admin dashboard to check that a signed-in user is an admin.
async function handleAdminMe(request, env) {
  const s = await sessionFromRequest(request, env);
  if (!s) return json({ error: 'Invalid or expired token' }, 401);
  if (!isAdmin(env, s.username)) return json({ error: 'This account is not an admin' }, 403);
  return json({ user: { id: s.userId, username: s.username, displayName: s.displayName, email: s.email } });
}

// ── Data handlers (D1) ────────────────────────────────────────────────────────

// Row mappers reshape flat D1 rows into the exact JSON the iOS models decode.

// imageURL points at this worker's /coffee-images route (origin from the request).
function coffeeFromRow(r, origin = '') {
  return {
    id: r.id,
    name: r.name,
    origin: { country: r.origin_country, region: r.origin_region, flag: r.origin_flag },
    process: r.process,
    roastLevel: r.roast_level,
    flavorTags: JSON.parse(r.flavor_tags),
    tastingNote: r.tasting_note,
    producer: r.producer,
    altitude: r.altitude,
    harvestSeason: r.harvest_season,
    roaster: r.roaster,
    imageURL: r.image_key ? `${origin}/coffee-images/${r.image_key}` : null,
  };
}

function shopFromRow(r) {
  return {
    id: r.id,
    name: r.name,
    address: r.address,
    latitude: r.latitude,
    longitude: r.longitude,
    category: r.category,
    rating: r.rating,
    openingHours: JSON.parse(r.opening_hours),
    roasterInfo: r.roaster_info,
    description: r.description,
    tags: JSON.parse(r.tags),
  };
}

function reviewFromRow(r) {
  return {
    id: r.id,
    coffeeId: r.coffee_id,
    userId: r.user_id,
    username: r.username,
    brewMethod: r.brew_method,
    rating: r.rating,
    note: r.note,
    date: r.created_at,
  };
}

async function handleGetCoffees(request, env) {
  const origin = new URL(request.url).origin;
  const { results } = await env.DB.prepare(
    'SELECT * FROM coffees ORDER BY created_at DESC, name'
  ).all();
  return json(results.map((r) => coffeeFromRow(r, origin)));
}

async function handleGetShops(env) {
  const { results } = await env.DB.prepare(
    'SELECT * FROM coffee_shops ORDER BY name'
  ).all();
  return json(results.map(shopFromRow));
}

async function handleGetCoffeeReviews(env, coffeeId) {
  const { results } = await env.DB.prepare(
    'SELECT * FROM reviews WHERE coffee_id = ?1 COLLATE NOCASE ORDER BY created_at DESC'
  ).bind(coffeeId).all();
  return json(results.map(reviewFromRow));
}

// Resolves the session for a Bearer token, or null.
async function sessionFromRequest(request, env) {
  const token = (request.headers.get('Authorization') || '').replace('Bearer ', '').trim();
  if (!token) return null;
  const raw = await env.SESSIONS.get(`session:${token}`);
  return raw ? JSON.parse(raw) : null;
}

async function handleGetMyReviews(request, env) {
  const session = await sessionFromRequest(request, env);
  if (!session) return json({ error: 'Unauthorized' }, 401);

  const { results } = await env.DB.prepare(
    'SELECT * FROM reviews WHERE user_id = ?1 ORDER BY created_at DESC'
  ).bind(session.userId).all();
  return json(results.map(reviewFromRow));
}

async function handleCreateReview(request, env) {
  const session = await sessionFromRequest(request, env);
  if (!session) return json({ error: 'Unauthorized' }, 401);

  let body;
  try { body = await request.json(); } catch { return json({ error: 'Invalid JSON' }, 400); }

  const { coffeeId, brewMethod, rating, note } = body;
  if (!coffeeId || !brewMethod || !rating) {
    return json({ error: 'coffeeId, brewMethod and rating are required' }, 400);
  }
  if (rating < 1 || rating > 5) return json({ error: 'rating must be 1–5' }, 400);

  const coffee = await env.DB.prepare('SELECT id FROM coffees WHERE id = ?1 COLLATE NOCASE')
    .bind(coffeeId).first();
  if (!coffee) return json({ error: 'Unknown coffee' }, 404);

  const review = {
    id: crypto.randomUUID().toUpperCase(),
    coffee_id: coffee.id,
    user_id: session.userId,
    username: session.username,
    brew_method: brewMethod,
    rating,
    note: note || '',
    created_at: new Date().toISOString(),
  };

  await env.DB.prepare(
    `INSERT INTO reviews (id, coffee_id, user_id, username, brew_method, rating, note, created_at)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)`
  ).bind(review.id, review.coffee_id, review.user_id, review.username,
         review.brew_method, review.rating, review.note, review.created_at).run();

  return json(reviewFromRow(review));
}

// ── Google Places (server-side proxy) ─────────────────────────────────────────
// The app never talks to Google directly: this keeps the API key out of the
// bundle. Place details are stored in D1 (table `place_details`); the app only
// ever reads that cache. Google is called by the worker via refreshPlace() for the
// daily cron, a one-off self-heal for a place that was never cached, and an
// admin's manual refresh.

const PLACE_FIELD_MASK = [
  'rating',
  'userRatingCount',
  'currentOpeningHours.openNow',
  'currentOpeningHours.weekdayDescriptions',
  'regularOpeningHours.weekdayDescriptions',
  'photos.name',
  'googleMapsUri',
  'websiteUri',
  'reviews',
  'outdoorSeating',
  'allowsDogs',
  'dineIn',
  'takeout',
  'delivery',
  'servesVegetarianFood',
  'servesDessert',
  'servesBrunch',
  'goodForGroups',
  'liveMusic',
  'regularOpeningHours.periods',
  'formattedAddress',
].join(',');

// Boolean place attributes → the tag pills the app shows.
const TAG_ATTRIBUTES = [
  ['outdoorSeating', 'Outdoor Seating'],
  ['allowsDogs', 'Pet Friendly'],
  ['dineIn', 'Dine-in'],
  ['takeout', 'Takeaway'],
  ['delivery', 'Delivery'],
  ['servesVegetarianFood', 'Vegetarian Options'],
  ['servesDessert', 'Desserts'],
  ['servesBrunch', 'Brunch'],
  ['goodForGroups', 'Good for Groups'],
  ['liveMusic', 'Live Music'],
];

// "Monday: 8:00 AM – 5:00 PM" → { day, hours } (the shape the iOS app renders).
// Google uses narrow no-break spaces around AM/PM; normalise to plain spaces.
function weekdayDescriptionsToHours(descriptions) {
  return (descriptions || []).map((line) => {
    const clean = line.replace(/[   ]/g, ' ');
    const idx = clean.indexOf(': ');
    if (idx === -1) return { day: clean, hours: '' };
    return { day: clean.slice(0, idx), hours: clean.slice(idx + 2) };
  });
}

// Places API base URL. PLACES_API_BASE only exists to point local tests at a
// stand-in server; it is never set in wrangler.toml.
function placesApi(env) {
  return env.PLACES_API_BASE || 'https://places.googleapis.com/v1';
}

// Fetch the raw place from the Google Places API. Throws on a non-200.
async function fetchGooglePlace(env, placeId) {
  const resp = await fetch(
    `${placesApi(env)}/places/${encodeURIComponent(placeId)}`,
    { headers: { 'X-Goog-Api-Key': env.GOOGLE_MAPS_API_KEY, 'X-Goog-FieldMask': PLACE_FIELD_MASK } }
  );
  if (!resp.ok) throw new Error(`Places ${resp.status}: ${(await resp.text()).slice(0, 200)}`);
  return resp.json();
}

// Map a raw Google place into the columns stored in `place_details`.
function placeToRow(placeId, place) {
  return {
    google_place_id:   placeId,
    rating:            place.rating ?? null,
    user_rating_count: place.userRatingCount ?? null,
    weekday_hours: JSON.stringify(weekdayDescriptionsToHours(
      place.currentOpeningHours?.weekdayDescriptions ??
      place.regularOpeningHours?.weekdayDescriptions
    )),
    periods: JSON.stringify(
      place.regularOpeningHours?.periods ?? place.currentOpeningHours?.periods ?? []
    ),
    photo_names: JSON.stringify((place.photos || []).slice(0, 8).map((p) => p.name)),
    tags: JSON.stringify(
      TAG_ATTRIBUTES.filter(([key]) => place[key] === true).map(([, label]) => label)
    ),
    reviews: JSON.stringify(
      (place.reviews || [])
        .map((r) => ({
          author: r.authorAttribution?.displayName || 'Google user',
          authorPhotoURI: r.authorAttribution?.photoUri ?? null,
          rating: r.rating ?? null,
          relativeTime: r.relativePublishTimeDescription || '',
          text: r.text?.text || '',
        }))
        .filter((r) => r.text)
        .slice(0, 5)
    ),
    google_maps_uri: place.googleMapsUri ?? null,
    website_uri:     place.websiteUri ?? null,
    address:         place.formattedAddress ?? null,
  };
}

// Upsert one stored place row into D1.
function upsertPlaceStmt(env, row) {
  return env.DB.prepare(
    `INSERT INTO place_details
       (google_place_id, rating, user_rating_count, weekday_hours, periods,
        photo_names, tags, reviews, google_maps_uri, website_uri, address, updated_at)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, datetime('now'))
     ON CONFLICT(google_place_id) DO UPDATE SET
       rating=excluded.rating, user_rating_count=excluded.user_rating_count,
       weekday_hours=excluded.weekday_hours, periods=excluded.periods,
       photo_names=excluded.photo_names, tags=excluded.tags, reviews=excluded.reviews,
       google_maps_uri=excluded.google_maps_uri, website_uri=excluded.website_uri,
       address=excluded.address, updated_at=datetime('now')`
  ).bind(row.google_place_id, row.rating, row.user_rating_count, row.weekday_hours,
         row.periods, row.photo_names, row.tags, row.reviews, row.google_maps_uri,
         row.website_uri, row.address);
}

// Fetch one place from Google and store it in D1, also syncing the shop's rating.
// The only code path that calls the Places details API; used by the daily cron,
// the first-view self-heal and the refresh-on-view of stale places.
async function refreshPlace(env, placeId) {
  const place = await fetchGooglePlace(env, placeId);
  const row = placeToRow(placeId, place);
  await upsertPlaceStmt(env, row).run();
  if (typeof row.rating === 'number') {
    await env.DB.prepare('UPDATE coffee_shops SET rating = ?1 WHERE google_place_id = ?2')
      .bind(row.rating, placeId).run();
  }
  return row;
}

// Current wall-clock in the shops' timezone (all are in the Netherlands).
// Returns { day: 0=Sun…6=Sat, minutes: since local midnight } to match the
// day numbering Google uses in opening-hours periods.
function nowInAmsterdam() {
  const local = new Date(new Date().toLocaleString('en-US', { timeZone: 'Europe/Amsterdam' }));
  return { day: local.getDay(), minutes: local.getHours() * 60 + local.getMinutes() };
}

// Compute open/closed from Google opening-hours periods, live at request time,
// so a once-a-day refresh still yields an accurate badge. null = unknown.
function computeOpenNow(periods) {
  if (!Array.isArray(periods) || periods.length === 0) return null;
  const { day, minutes } = nowInAmsterdam();
  for (const p of periods) {
    if (!p.open) continue;
    if (!p.close) return true; // open 24/7
    const openMin  = (p.open.hour  || 0) * 60 + (p.open.minute  || 0);
    const closeMin = (p.close.hour || 0) * 60 + (p.close.minute || 0);
    if (p.open.day === p.close.day) {
      if (day === p.open.day && minutes >= openMin && minutes < closeMin) return true;
    } else {
      // Spans midnight / multiple days: open from openMin on open.day until
      // closeMin on close.day.
      if (day === p.open.day  && minutes >= openMin)  return true;
      if (day === p.close.day && minutes <  closeMin) return true;
    }
  }
  return false;
}

// Build the app-facing response from a stored row + request origin. Photo URLs
// are rebuilt from the stored names so they always point at this worker, and
// open-now is computed live.
function rowToDetails(row, origin) {
  const names = JSON.parse(row.photo_names || '[]');
  return {
    rating:          row.rating ?? null,
    userRatingCount: row.user_rating_count ?? null,
    openNow:         computeOpenNow(JSON.parse(row.periods || '[]')),
    weekdayHours:    JSON.parse(row.weekday_hours || '[]'),
    photos: names.map((n) => `${origin}/place-photo?name=${encodeURIComponent(n)}&w=1000`),
    tags:            JSON.parse(row.tags || '[]'),
    reviews:         JSON.parse(row.reviews || '[]'),
    googleMapsURI:   row.google_maps_uri ?? null,
    websiteURI:      row.website_uri ?? null,
    address:         row.address ?? null,
  };
}

// Refresh every linked shop's place details from Google. Used by the daily cron
// and the admin endpoint. Returns a summary.
// A single Worker invocation may make at most 50 fetch subrequests, so we
// refresh at most this many places per run — the stalest (and never-cached)
// first. The daily cron therefore fires three times in a row (135 places at
// most); anything not yet cached also self-heals on first view.
const PLACES_REFRESH_BATCH = 45;

// The cron's later runs skip places an earlier run already refreshed today.
const PLACE_DAILY_MIN_AGE = '-20 hours';

async function refreshAllPlaces(env, limit = PLACES_REFRESH_BATCH, minAge = '-0 seconds') {
  if (!env.GOOGLE_MAPS_API_KEY) {
    console.error('places refresh: GOOGLE_MAPS_API_KEY not set');
    return { ok: 0, failed: 0, total: 0 };
  }
  const batch = Math.max(1, Math.min(limit, PLACES_REFRESH_BATCH));

  // Never-cached places (NULL updated_at) sort first in ASC order, then the
  // oldest — so each run tackles the most out-of-date entries.
  const { results } = await env.DB.prepare(
    `SELECT cs.google_place_id AS placeId
       FROM coffee_shops cs
       LEFT JOIN place_details pd ON pd.google_place_id = cs.google_place_id
      WHERE cs.google_place_id IS NOT NULL AND cs.google_place_id <> ''
      GROUP BY cs.google_place_id
     HAVING MAX(pd.updated_at) IS NULL OR MAX(pd.updated_at) < datetime('now', ?2)
      ORDER BY MAX(pd.updated_at) ASC
      LIMIT ?1`
  ).bind(batch, minAge).all();

  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  let ok = 0, failed = 0;
  for (const { placeId } of results) {
    try {
      await refreshPlace(env, placeId);
      ok++;
    } catch (e) {
      failed++;
      console.error('places refresh failed for', placeId, e.message);
    }
    await sleep(80);
  }
  console.log(`places refresh: ${ok} ok, ${failed} failed of ${results.length}`);
  return { ok, failed, total: results.length };
}

async function handleGetShopPlace(request, env, shopId) {
  const shop = await env.DB.prepare(
    'SELECT id, google_place_id FROM coffee_shops WHERE id = ?1 COLLATE NOCASE'
  ).bind(shopId).first();
  if (!shop) return json({ error: 'Unknown shop' }, 404);
  if (!shop.google_place_id) return json({ error: 'Shop has no linked Google place' }, 404);

  const origin = new URL(request.url).origin;

  // Primary path: serve from our own D1 cache (no Google call on this request).
  let row = await env.DB.prepare(
    'SELECT * FROM place_details WHERE google_place_id = ?1'
  ).bind(shop.google_place_id).first();

  if (!row) {
    // Self-heal: a place the daily cron hasn't populated yet is fetched once and
    // stored, so it's cached for everyone from then on.
    if (!env.GOOGLE_MAPS_API_KEY) return json({ error: 'Places API not configured' }, 503);
    try {
      row = await refreshPlace(env, shop.google_place_id);
    } catch (e) {
      console.error('place self-heal failed', e.message);
      return json({ error: 'Places lookup failed' }, 502);
    }
  }

  return json(rowToDetails(row, origin));
}

async function handleGetPlacePhoto(request, env, ctx) {
  if (!env.GOOGLE_MAPS_API_KEY) return json({ error: 'Places API not configured' }, 503);

  const url = new URL(request.url);
  const name = url.searchParams.get('name') || '';
  const width = Math.min(parseInt(url.searchParams.get('w') || '1000', 10) || 1000, 1600);
  // Only proxy genuine Places photo resources — never arbitrary URLs.
  if (!/^places\/[A-Za-z0-9_-]+\/photos\/[A-Za-z0-9_-]+$/.test(name)) {
    return json({ error: 'Invalid photo name' }, 400);
  }

  // Serve from the edge cache when possible (the key never appears in our URL).
  const cache = caches.default;
  const cacheKey = new Request(url.toString(), { method: 'GET' });
  const hit = await cache.match(cacheKey);
  if (hit) return hit;

  const resp = await fetch(
    `https://places.googleapis.com/v1/${name}/media?maxWidthPx=${width}&key=${env.GOOGLE_MAPS_API_KEY}`,
    { redirect: 'follow' }
  );
  if (!resp.ok) return json({ error: 'Photo fetch failed' }, 502);

  const out = new Response(resp.body, {
    status: 200,
    headers: {
      'Content-Type': resp.headers.get('Content-Type') || 'image/jpeg',
      'Cache-Control': 'public, max-age=86400',
      ...CORS,
    },
  });
  ctx.waitUntil(cache.put(cacheKey, out.clone()));
  return out;
}

// ── Bean import queue (admin) ─────────────────────────────────────────────────
// Beans imported from shops (one-off imports such as Koffie Kenner) wait in
// coffee_candidates. An admin completes missing fields in the dashboard, then
// adds or declines each one. Adding copies the photo into COFFEE_IMAGES (KV)
// so the app never depends on the shop's servers.

// The values the iOS app can decode (Coffee.swift ProcessingMethod / RoastLevel).
const PROCESSES = ['Washed', 'Natural', 'Honey', 'Anaerobic', 'Wet Hulled', 'Carbonic Maceration'];
const ROAST_LEVELS = ['Light', 'Medium Light', 'Medium', 'Medium Dark', 'Dark'];

// Coffee-growing countries → flag. Blends ("Brazil & Peru") use the first country.
const COUNTRY_FLAGS = {
  Bolivia: '🇧🇴', Brazil: '🇧🇷', Burundi: '🇧🇮', China: '🇨🇳', Colombia: '🇨🇴', 'Costa Rica': '🇨🇷',
  Congo: '🇨🇩', 'DR Congo': '🇨🇩', Ecuador: '🇪🇨', 'El Salvador': '🇸🇻', Ethiopia: '🇪🇹', Guatemala: '🇬🇹',
  Honduras: '🇭🇳', India: '🇮🇳', Indonesia: '🇮🇩', Jamaica: '🇯🇲', Kenya: '🇰🇪', Malawi: '🇲🇼',
  Mexico: '🇲🇽', Myanmar: '🇲🇲', Nepal: '🇳🇵', Nicaragua: '🇳🇮', Panama: '🇵🇦', 'Papua New Guinea': '🇵🇬',
  Peru: '🇵🇪', Rwanda: '🇷🇼', Tanzania: '🇹🇿', Thailand: '🇹🇭', Timor: '🇹🇱', Uganda: '🇺🇬',
  Vietnam: '🇻🇳', Yemen: '🇾🇪', Zambia: '🇿🇲', Zimbabwe: '🇿🇼',
};

function flagForCountry(country) {
  const first = (country || '').split(/\s*[&,/]\s*/)[0].trim();
  return COUNTRY_FLAGS[first] || '🌍';
}

function coffeeCandidateFromRow(r) {
  return {
    id:             r.id,
    source:         r.source,
    sourceURL:      r.source_url,
    name:           r.name,
    roaster:        r.roaster,
    originCountry:  r.origin_country,
    originRegion:   r.origin_region,
    process:        r.process,
    roastLevel:     r.roast_level,
    flavorTags:     JSON.parse(r.flavor_tags || '[]'),
    tastingNote:    r.tasting_note,
    producer:       r.producer,
    altitude:       r.altitude,
    imageSourceURL: r.image_source_url,
    researchNotes:  r.research_notes,
    status:         r.status,
    coffeeId:       r.coffee_id,
    foundAt:        r.found_at,
    decidedAt:      r.decided_at,
  };
}

// Fields an admin may edit, JSON name → column.
const CANDIDATE_FIELDS = {
  name: 'name', roaster: 'roaster', originCountry: 'origin_country', originRegion: 'origin_region',
  process: 'process', roastLevel: 'roast_level', flavorTags: 'flavor_tags', tastingNote: 'tasting_note',
  producer: 'producer', altitude: 'altitude', imageSourceURL: 'image_source_url',
};

// GET /admin/coffee-candidates
async function handleListCoffeeCandidates(env) {
  const { results } = await env.DB.prepare(
    `SELECT * FROM coffee_candidates
      ORDER BY CASE status WHEN 'pending' THEN 0 ELSE 1 END, roaster, name`
  ).all();
  return json(results.map(coffeeCandidateFromRow));
}

// POST /admin/coffee-candidates/:id { ...fields } — save edits to a pending bean.
async function handleUpdateCoffeeCandidate(request, env, id) {
  let body;
  try { body = await request.json(); } catch { return json({ error: 'Invalid JSON' }, 400); }

  const sets = [], values = [];
  for (const [key, column] of Object.entries(CANDIDATE_FIELDS)) {
    if (!(key in body)) continue;
    let v = body[key];
    if (key === 'flavorTags') {
      if (!Array.isArray(v)) return json({ error: 'flavorTags must be a list' }, 400);
      v = JSON.stringify(v.map((t) => String(t).trim().toLowerCase()).filter(Boolean).slice(0, 12));
    } else if (v === null || v === '') {
      v = null;
    } else if (typeof v !== 'string' || v.length > 1000) {
      return json({ error: `${key} must be text` }, 400);
    } else {
      v = v.trim();
    }
    if (key === 'name' && !v) return json({ error: 'name is required' }, 400);
    if (key === 'process' && v && !PROCESSES.includes(v)) return json({ error: `process must be one of ${PROCESSES.join(', ')}` }, 400);
    if (key === 'roastLevel' && v && !ROAST_LEVELS.includes(v)) return json({ error: `roastLevel must be one of ${ROAST_LEVELS.join(', ')}` }, 400);
    if (key === 'imageSourceURL' && v && !/^https:\/\//.test(v)) return json({ error: 'imageSourceURL must be an https URL' }, 400);
    sets.push(`${column} = ?${values.length + 2}`);
    values.push(v);
  }
  if (!sets.length) return json({ error: 'Nothing to update' }, 400);

  const res = await env.DB.prepare(
    `UPDATE coffee_candidates SET ${sets.join(', ')} WHERE id = ?1 AND status <> 'added'`
  ).bind(id, ...values).run();
  if (!res.meta.changes) return json({ error: 'Unknown bean, or already added' }, 404);
  const row = await env.DB.prepare('SELECT * FROM coffee_candidates WHERE id = ?1').bind(id).first();
  return json(coffeeCandidateFromRow(row));
}

const IMAGE_MAX_BYTES = 5 * 1024 * 1024;

// Copy an image into COFFEE_IMAGES and return its key. Throws on failure.
async function storeCoffeeImage(env, sourceUrl) {
  const resp = await fetch(sourceUrl, { headers: { Accept: 'image/*' } });
  const type = resp.headers.get('Content-Type') || '';
  if (!resp.ok || !type.startsWith('image/')) throw new Error(`image fetch failed (${resp.status} ${type})`);
  const bytes = await resp.arrayBuffer();
  if (bytes.byteLength > IMAGE_MAX_BYTES) throw new Error('image is larger than 5 MB');
  const key = randomHex(16);
  await env.COFFEE_IMAGES.put(`img:${key}`, bytes, { metadata: { type } });
  return key;
}

// POST /admin/coffee-candidates/:id/add — create the coffee (and copy its image).
async function handleAddCoffeeCandidate(request, env, id) {
  const c = await env.DB.prepare('SELECT * FROM coffee_candidates WHERE id = ?1').bind(id).first();
  if (!c) return json({ error: 'Unknown bean' }, 404);
  if (c.status === 'added') return json({ error: 'This bean is already in the app' }, 409);

  const missing = [
    !c.origin_country && 'country',
    !PROCESSES.includes(c.process) && 'process',
    !ROAST_LEVELS.includes(c.roast_level) && 'roast level',
  ].filter(Boolean);
  if (missing.length) return json({ error: `Fill in the ${missing.join(', ')} first` }, 400);

  let imageKey = null;
  if (c.image_source_url) {
    try {
      imageKey = await storeCoffeeImage(env, c.image_source_url);
    } catch (e) {
      console.error('coffee image copy failed for', id, e.message);
      return json({ error: `Couldn't copy the image: ${e.message}` }, 502);
    }
  }

  const coffeeId = crypto.randomUUID().toUpperCase();
  const tags = JSON.parse(c.flavor_tags || '[]');
  const note = c.tasting_note
    || [tags.length ? tags.join(', ').replace(/^./, (s) => s.toUpperCase()) + '.' : '', c.roaster ? `Roasted by ${c.roaster}.` : '']
      .filter(Boolean).join(' ');

  await env.DB.batch([
    env.DB.prepare(
      `INSERT INTO coffees
         (id, name, origin_country, origin_region, origin_flag, process, roast_level, flavor_tags,
          tasting_note, producer, altitude, harvest_season, roaster, image_key)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, NULL, ?12, ?13)`
    ).bind(
      coffeeId, c.name, c.origin_country, c.origin_region, flagForCountry(c.origin_country), c.process,
      c.roast_level, JSON.stringify(tags), note, c.producer, c.altitude, c.roaster, imageKey
    ),
    env.DB.prepare(
      "UPDATE coffee_candidates SET status = 'added', coffee_id = ?2, decided_at = datetime('now') WHERE id = ?1"
    ).bind(id, coffeeId),
  ]);

  const coffee = await env.DB.prepare('SELECT * FROM coffees WHERE id = ?1').bind(coffeeId).first();
  return json(coffeeFromRow(coffee, new URL(request.url).origin));
}

// POST /admin/coffee-candidates/:id/decline — and /restore to undo it.
async function handleSetCoffeeCandidateStatus(env, id, status) {
  const res = await env.DB.prepare(
    `UPDATE coffee_candidates SET status = ?2, decided_at = CASE ?2 WHEN 'pending' THEN NULL ELSE datetime('now') END
      WHERE id = ?1 AND status <> 'added'`
  ).bind(id, status).run();
  if (!res.meta.changes) return json({ error: 'Unknown bean, or already added' }, 404);
  return json({ success: true });
}

// GET /coffee-images/:key — public, immutable (a new image gets a new key).
async function handleGetCoffeeImage(env, key) {
  if (!/^[0-9a-f]{32}$/.test(key)) return json({ error: 'Not found' }, 404);
  const { value, metadata } = await env.COFFEE_IMAGES.getWithMetadata(`img:${key}`, { type: 'stream' });
  if (!value) return json({ error: 'Not found' }, 404);
  return new Response(value, {
    headers: {
      'Content-Type': metadata?.type || 'image/jpeg',
      'Cache-Control': 'public, max-age=31536000, immutable',
      ...CORS,
    },
  });
}

// ── Café discovery (admin) ────────────────────────────────────────────────────
// The dashboard's "Find new cafés" searches Google for cafés that aren't in
// coffee_shops yet and parks them in shop_candidates. An admin then adds or
// declines each one; declined places stay in the table so they never come back.

// Returns null for a signed-in admin, otherwise the error response to send.
async function adminError(request, env) {
  const s = await sessionFromRequest(request, env);
  if (!s) return json({ error: 'Invalid or expired token' }, 401);
  if (!isAdmin(env, s.username)) return json({ error: 'This account is not an admin' }, 403);
  return null;
}

const SEARCH_FIELD_MASK = [
  'places.id',
  'places.displayName',
  'places.formattedAddress',
  'places.location',
  'places.rating',
  'places.userRatingCount',
  'places.editorialSummary',
  'places.googleMapsUri',
  'places.websiteUri',
  'places.businessStatus',
  'nextPageToken',
].join(',');

// Google returns at most 20 places per page and 3 pages per search.
const SEARCH_MAX_PAGES = 3;
// Searches per sync, to stay well under the Worker's 50-subrequest limit.
const SEARCH_MAX_QUERIES = 8;

// One Text Search page.
async function searchGooglePlaces(env, textQuery, pageToken) {
  const resp = await fetch(`${placesApi(env)}/places:searchText`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': env.GOOGLE_MAPS_API_KEY,
      'X-Goog-FieldMask': SEARCH_FIELD_MASK,
    },
    body: JSON.stringify({ textQuery, regionCode: 'NL', languageCode: 'en', pageSize: 20, pageToken }),
  });
  if (!resp.ok) throw new Error(`Places search ${resp.status}: ${(await resp.text()).slice(0, 200)}`);
  return resp.json();
}

// "Pelgrimsstraat 5C, 3029 PA Rotterdam" → "Rotterdam" (Dutch postcode, then city).
function cityFromAddress(address) {
  const m = /\d{4}\s?[A-Z]{2}\s+(.+)$/.exec(address || '');
  return m ? m[1].trim() : null;
}

function candidateFromRow(r) {
  return {
    placeId:         r.google_place_id,
    name:            r.name,
    address:         r.address,
    latitude:        r.latitude,
    longitude:       r.longitude,
    rating:          r.rating,
    userRatingCount: r.user_rating_count,
    summary:         r.summary,
    googleMapsURI:   r.google_maps_uri,
    websiteURI:      r.website_uri,
    searchQuery:     r.search_query,
    status:          r.status,
    shopId:          r.shop_id,
    foundAt:         r.found_at,
    decidedAt:       r.decided_at,
  };
}

// POST /admin/shops/discover { query? } — search Google and queue new cafés.
// Without a query it searches "specialty coffee in <city>" for every city the
// app already has shops in.
async function handleDiscoverShops(request, env) {
  if (!env.GOOGLE_MAPS_API_KEY) return json({ error: 'Places API not configured' }, 503);
  let body = {};
  try { body = await request.json(); } catch { /* empty body is fine */ }

  let queries;
  const custom = typeof body.query === 'string' ? body.query.trim() : '';
  if (custom) {
    if (custom.length > 200) return json({ error: 'query is too long' }, 400);
    queries = [custom];
  } else {
    const { results } = await env.DB.prepare('SELECT address FROM coffee_shops').all();
    const cities = [...new Set(results.map((r) => cityFromAddress(r.address)).filter(Boolean))].sort();
    queries = cities.slice(0, SEARCH_MAX_QUERIES).map((c) => `specialty coffee in ${c}`);
  }

  // Everything we already know about — shops and earlier candidates (any status).
  const { results: known } = await env.DB.prepare(
    `SELECT google_place_id AS id FROM coffee_shops WHERE google_place_id IS NOT NULL
     UNION SELECT google_place_id FROM shop_candidates`
  ).all();
  const knownIds = new Set(known.map((r) => r.id));

  const fresh = new Map();
  let found = 0;
  const errors = [];
  for (const q of queries) {
    let pageToken;
    for (let page = 0; page < SEARCH_MAX_PAGES; page++) {
      let data;
      try {
        data = await searchGooglePlaces(env, q, pageToken);
      } catch (e) {
        console.error('places search failed for', q, e.message);
        errors.push(q);
        break;
      }
      for (const p of data.places || []) {
        found++;
        if (!p.id || !p.location || knownIds.has(p.id) || fresh.has(p.id)) continue;
        if (p.businessStatus && p.businessStatus !== 'OPERATIONAL') continue;
        fresh.set(p.id, { place: p, query: q });
      }
      pageToken = data.nextPageToken;
      if (!pageToken) break;
    }
  }

  if (fresh.size) {
    await env.DB.batch([...fresh.values()].map(({ place: p, query }) => env.DB.prepare(
      `INSERT OR IGNORE INTO shop_candidates
         (google_place_id, name, address, latitude, longitude, rating, user_rating_count,
          summary, google_maps_uri, website_uri, search_query)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)`
    ).bind(
      p.id, p.displayName?.text || 'Unnamed place', p.formattedAddress || '',
      p.location.latitude, p.location.longitude, p.rating ?? null, p.userRatingCount ?? null,
      p.editorialSummary?.text ?? null, p.googleMapsUri ?? null, p.websiteUri ?? null, query
    )));
  }

  return json({ queries, found, added: fresh.size, failedQueries: errors });
}

// GET /admin/shop-candidates — the whole queue, newest first (the dashboard
// splits it by status).
async function handleListCandidates(env) {
  const { results } = await env.DB.prepare(
    `SELECT * FROM shop_candidates
      ORDER BY CASE status WHEN 'pending' THEN 0 ELSE 1 END, found_at DESC, name`
  ).all();
  return json(results.map(candidateFromRow));
}

// POST /admin/shop-candidates/:placeId/add { category? } — turn a candidate into
// a coffee shop. Fetches the full place once for opening hours and tags, and
// stores it in place_details so the app has photos and reviews right away.
async function handleAddCandidate(request, env, placeId) {
  if (!env.GOOGLE_MAPS_API_KEY) return json({ error: 'Places API not configured' }, 503);
  let body = {};
  try { body = await request.json(); } catch { /* empty body is fine */ }
  const category = (typeof body.category === 'string' && body.category.trim()) || 'Coffee Shop';

  const c = await env.DB.prepare('SELECT * FROM shop_candidates WHERE google_place_id = ?1').bind(placeId).first();
  if (!c) return json({ error: 'Unknown candidate' }, 404);

  const existing = await env.DB.prepare('SELECT id FROM coffee_shops WHERE google_place_id = ?1').bind(placeId).first();
  if (existing) {
    await env.DB.prepare(
      "UPDATE shop_candidates SET status = 'added', shop_id = ?2, decided_at = datetime('now') WHERE google_place_id = ?1"
    ).bind(placeId, existing.id).run();
    return json({ error: 'This café is already in the app' }, 409);
  }

  let place;
  try {
    place = await fetchGooglePlace(env, placeId);
  } catch (e) {
    console.error('add candidate: place lookup failed', placeId, e.message);
    return json({ error: 'Google lookup failed. Please try again.' }, 502);
  }
  const details = placeToRow(placeId, place);
  const shopId = crypto.randomUUID().toUpperCase();

  await env.DB.batch([
    env.DB.prepare(
      `INSERT INTO coffee_shops
         (id, name, address, latitude, longitude, category, rating, opening_hours,
          roaster_info, description, tags, google_place_id)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, NULL, ?9, ?10, ?11)`
    ).bind(
      shopId, c.name, c.address, c.latitude, c.longitude, category,
      details.rating ?? c.rating ?? 0, details.weekday_hours, c.summary || '', details.tags, placeId
    ),
    upsertPlaceStmt(env, details),
    env.DB.prepare(
      "UPDATE shop_candidates SET status = 'added', shop_id = ?2, decided_at = datetime('now') WHERE google_place_id = ?1"
    ).bind(placeId, shopId),
  ]);

  const shop = await env.DB.prepare('SELECT * FROM coffee_shops WHERE id = ?1').bind(shopId).first();
  return json(shopFromRow(shop));
}

// POST /admin/shop-candidates/:placeId/decline — and /restore to undo it.
async function handleSetCandidateStatus(env, placeId, status) {
  const res = await env.DB.prepare(
    `UPDATE shop_candidates SET status = ?2, decided_at = CASE ?2 WHEN 'pending' THEN NULL ELSE datetime('now') END
      WHERE google_place_id = ?1 AND status <> 'added'`
  ).bind(placeId, status).run();
  if (!res.meta.changes) return json({ error: 'Unknown candidate, or already added' }, 404);
  return json({ success: true });
}

// ── Entry point ───────────────────────────────────────────────────────────────

export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS });
    }

    const { pathname } = new URL(request.url);
    try {
      if (pathname === '/auth/register' && request.method === 'POST') return handleRegister(request, env);
      if (pathname === '/auth/login'    && request.method === 'POST') return handleLogin(request, env);
      if (pathname === '/auth/verify'   && request.method === 'GET')  return handleVerify(request, env);
      if (pathname === '/auth/logout'   && request.method === 'POST') return handleLogout(request, env);
      if (pathname === '/admin/me'      && request.method === 'GET')  return handleAdminMe(request, env);

      if (pathname === '/coffees'    && request.method === 'GET')  return handleGetCoffees(request, env);
      if (pathname === '/shops'      && request.method === 'GET')  return handleGetShops(env);
      if (pathname === '/my/reviews' && request.method === 'GET')  return handleGetMyReviews(request, env);
      if (pathname === '/reviews'    && request.method === 'POST') return handleCreateReview(request, env);

      const reviewsMatch = pathname.match(/^\/coffees\/([^/]+)\/reviews$/);
      if (reviewsMatch && request.method === 'GET') {
        return handleGetCoffeeReviews(env, decodeURIComponent(reviewsMatch[1]));
      }

      const placeMatch = pathname.match(/^\/shops\/([^/]+)\/place$/);
      if (placeMatch && request.method === 'GET') {
        return handleGetShopPlace(request, env, decodeURIComponent(placeMatch[1]));
      }
      if (pathname === '/place-photo' && request.method === 'GET') {
        return handleGetPlacePhoto(request, env, ctx);
      }

      // Admin: refresh the stalest batch of the place cache (also runs daily via
      // cron). Accepts the ADMIN_TOKEN secret or a dashboard admin session.
      if (pathname === '/admin/refresh-places' && request.method === 'POST') {
        const token = (request.headers.get('Authorization') || '').replace('Bearer ', '').trim();
        if (!env.ADMIN_TOKEN || token !== env.ADMIN_TOKEN) {
          const denied = await adminError(request, env);
          if (denied) return denied;
        }
        const summary = await refreshAllPlaces(env);
        return json(summary);
      }

      const imageMatch = pathname.match(/^\/coffee-images\/([^/]+)$/);
      if (imageMatch && request.method === 'GET') return handleGetCoffeeImage(env, imageMatch[1]);

      // Admin: bean import queue (dashboard Beans page).
      if (pathname.startsWith('/admin/coffee-candidates')) {
        const denied = await adminError(request, env);
        if (denied) return denied;
        if (pathname === '/admin/coffee-candidates' && request.method === 'GET') return handleListCoffeeCandidates(env);
        const m = pathname.match(/^\/admin\/coffee-candidates\/([^/]+?)(?:\/(add|decline|restore))?$/);
        if (m && request.method === 'POST') {
          const id = decodeURIComponent(m[1]);
          if (!m[2]) return handleUpdateCoffeeCandidate(request, env, id);
          if (m[2] === 'add') return handleAddCoffeeCandidate(request, env, id);
          return handleSetCoffeeCandidateStatus(env, id, m[2] === 'decline' ? 'declined' : 'pending');
        }
      }

      // Admin: café discovery and the review queue (dashboard Stores page).
      if (pathname.startsWith('/admin/shop')) {
        const denied = await adminError(request, env);
        if (denied) return denied;
        if (pathname === '/admin/shops/discover' && request.method === 'POST') return handleDiscoverShops(request, env);
        if (pathname === '/admin/shop-candidates' && request.method === 'GET') return handleListCandidates(env);
        const m = pathname.match(/^\/admin\/shop-candidates\/([^/]+)\/(add|decline|restore)$/);
        if (m && request.method === 'POST') {
          const placeId = decodeURIComponent(m[1]);
          if (m[2] === 'add') return handleAddCandidate(request, env, placeId);
          return handleSetCandidateStatus(env, placeId, m[2] === 'decline' ? 'declined' : 'pending');
        }
      }

      return json({ error: 'Not found' }, 404);
    } catch (e) {
      console.error(e);
      return json({ error: 'Internal server error' }, 500);
    }
  },

  // Daily cron (see [triggers] in wrangler.toml): refresh the place cache so the
  // app serves entirely from D1 and each place is fetched from Google once a day.
  async scheduled(event, env, ctx) {
    ctx.waitUntil(refreshAllPlaces(env, PLACES_REFRESH_BATCH, PLACE_DAILY_MIN_AGE));
  },
};
