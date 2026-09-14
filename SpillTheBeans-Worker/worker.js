// Spill the Beans — API Worker
// Auth endpoints:
//   POST /auth/register  { username, password, displayName?, email? }
//   POST /auth/login     { username, password }
//   GET  /auth/verify    Authorization: Bearer <token>
//   POST /auth/logout    Authorization: Bearer <token>
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
//   POST /admin/refresh-places    — force a full refresh (Authorization: Bearer ADMIN_TOKEN)
//
// The place cache (D1 table `place_details`) is refreshed once a day by the
// scheduled() cron handler, so normal app traffic hits Google zero times.
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

// ── Data handlers (D1) ────────────────────────────────────────────────────────

// Row mappers reshape flat D1 rows into the exact JSON the iOS models decode.

function coffeeFromRow(r) {
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

async function handleGetCoffees(env) {
  const { results } = await env.DB.prepare(
    'SELECT * FROM coffees ORDER BY created_at DESC, name'
  ).all();
  return json(results.map(coffeeFromRow));
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
// bundle. Place details are stored in D1 (table `place_details`) and refreshed
// once a day by the scheduled (cron) handler, so browsing the app makes no
// Google Places API calls — only the daily refresh (and a one-off self-heal for
// a place the cron hasn't reached yet) does.

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

// Fetch the raw place from the Google Places API. Throws on a non-200.
async function fetchGooglePlace(env, placeId) {
  const resp = await fetch(
    `https://places.googleapis.com/v1/places/${encodeURIComponent(placeId)}`,
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
async function refreshAllPlaces(env) {
  if (!env.GOOGLE_MAPS_API_KEY) {
    console.error('places refresh: GOOGLE_MAPS_API_KEY not set');
    return { ok: 0, failed: 0, total: 0 };
  }
  const { results } = await env.DB.prepare(
    "SELECT DISTINCT google_place_id FROM coffee_shops WHERE google_place_id IS NOT NULL AND google_place_id <> ''"
  ).all();

  let ok = 0, failed = 0;
  for (const { google_place_id: placeId } of results) {
    try {
      const place = await fetchGooglePlace(env, placeId);
      await upsertPlaceStmt(env, placeToRow(placeId, place)).run();
      if (typeof place.rating === 'number') {
        await env.DB.prepare('UPDATE coffee_shops SET rating = ?1 WHERE google_place_id = ?2')
          .bind(place.rating, placeId).run();
      }
      ok++;
    } catch (e) {
      failed++;
      console.error('places refresh failed for', placeId, e.message);
    }
  }
  console.log(`places refresh: ${ok} ok, ${failed} failed of ${results.length}`);
  return { ok, failed, total: results.length };
}

async function handleGetShopPlace(request, env, ctx, shopId) {
  const shop = await env.DB.prepare(
    'SELECT id, google_place_id FROM coffee_shops WHERE id = ?1 COLLATE NOCASE'
  ).bind(shopId).first();
  if (!shop) return json({ error: 'Unknown shop' }, 404);
  if (!shop.google_place_id) return json({ error: 'Shop has no linked Google place' }, 404);

  const origin = new URL(request.url).origin;

  // Primary path: serve from our own D1 cache (no Google call).
  let row = await env.DB.prepare(
    'SELECT * FROM place_details WHERE google_place_id = ?1'
  ).bind(shop.google_place_id).first();

  // Self-heal: a place the daily cron hasn't populated yet is fetched once and
  // stored, so it's cached for everyone from then on.
  if (!row) {
    if (!env.GOOGLE_MAPS_API_KEY) return json({ error: 'Places API not configured' }, 503);
    try {
      const place = await fetchGooglePlace(env, shop.google_place_id);
      row = placeToRow(shop.google_place_id, place);
      ctx.waitUntil(upsertPlaceStmt(env, row).run());
      if (typeof row.rating === 'number') {
        ctx.waitUntil(
          env.DB.prepare('UPDATE coffee_shops SET rating = ?1 WHERE id = ?2')
            .bind(row.rating, shop.id).run()
        );
      }
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

      if (pathname === '/coffees'    && request.method === 'GET')  return handleGetCoffees(env);
      if (pathname === '/shops'      && request.method === 'GET')  return handleGetShops(env);
      if (pathname === '/my/reviews' && request.method === 'GET')  return handleGetMyReviews(request, env);
      if (pathname === '/reviews'    && request.method === 'POST') return handleCreateReview(request, env);

      const reviewsMatch = pathname.match(/^\/coffees\/([^/]+)\/reviews$/);
      if (reviewsMatch && request.method === 'GET') {
        return handleGetCoffeeReviews(env, decodeURIComponent(reviewsMatch[1]));
      }

      const placeMatch = pathname.match(/^\/shops\/([^/]+)\/place$/);
      if (placeMatch && request.method === 'GET') {
        return handleGetShopPlace(request, env, ctx, decodeURIComponent(placeMatch[1]));
      }
      if (pathname === '/place-photo' && request.method === 'GET') {
        return handleGetPlacePhoto(request, env, ctx);
      }

      // Admin: force a full refresh of the place cache (also runs daily via cron).
      if (pathname === '/admin/refresh-places' && request.method === 'POST') {
        const token = (request.headers.get('Authorization') || '').replace('Bearer ', '').trim();
        if (!env.ADMIN_TOKEN || token !== env.ADMIN_TOKEN) {
          return json({ error: 'Unauthorized' }, 401);
        }
        const summary = await refreshAllPlaces(env);
        return json(summary);
      }

      return json({ error: 'Not found' }, 404);
    } catch (e) {
      console.error(e);
      return json({ error: 'Internal server error' }, 500);
    }
  },

  // Daily cron (see [triggers] in wrangler.toml): refresh the place cache so the
  // app serves entirely from D1 and Google is queried at most once per day.
  async scheduled(event, env, ctx) {
    ctx.waitUntil(refreshAllPlaces(env));
  },
};
