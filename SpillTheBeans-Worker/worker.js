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
//   GET  /shops/:id/place         — live Places details (rating, hours, photos)
//   GET  /place-photo?name=&w=    — streams a Places photo through the worker
//
// Bindings (set in wrangler.toml):
//   USERS    (KV) — user records keyed by username
//   SESSIONS (KV) — session tokens with 90-day TTL
//   PLACES   (KV) — 24h cache of Google Places details
//   DB       (D1) — coffees, coffee_shops, reviews tables
//
// Secrets:
//   GOOGLE_MAPS_API_KEY — Places API key (wrangler secret put GOOGLE_MAPS_API_KEY)

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
// bundle and lets us cache responses for 24h so 61 shops don't hammer billing.

const PLACE_CACHE_TTL = 60 * 60 * 24;   // seconds

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

async function handleGetShopPlace(request, env, ctx, shopId) {
  if (!env.GOOGLE_MAPS_API_KEY) {
    return json({ error: 'Places API not configured' }, 503);
  }

  const shop = await env.DB.prepare(
    'SELECT id, google_place_id FROM coffee_shops WHERE id = ?1 COLLATE NOCASE'
  ).bind(shopId).first();
  if (!shop) return json({ error: 'Unknown shop' }, 404);
  if (!shop.google_place_id) return json({ error: 'Shop has no linked Google place' }, 404);

  // v2: response gained tags + reviews — new key so old cached shapes expire out.
  const cacheKey = `place:v2:${shop.google_place_id}`;
  const cached = await env.PLACES.get(cacheKey);
  if (cached) return json(JSON.parse(cached));

  const resp = await fetch(
    `https://places.googleapis.com/v1/places/${encodeURIComponent(shop.google_place_id)}`,
    {
      headers: {
        'X-Goog-Api-Key': env.GOOGLE_MAPS_API_KEY,
        'X-Goog-FieldMask': PLACE_FIELD_MASK,
      },
    }
  );
  if (!resp.ok) {
    console.error('Places API error', resp.status, await resp.text());
    return json({ error: 'Places lookup failed' }, 502);
  }
  const place = await resp.json();

  const origin = new URL(request.url).origin;
  const details = {
    rating: place.rating ?? null,
    userRatingCount: place.userRatingCount ?? null,
    openNow: place.currentOpeningHours?.openNow ?? null,
    weekdayHours: weekdayDescriptionsToHours(
      place.currentOpeningHours?.weekdayDescriptions ??
      place.regularOpeningHours?.weekdayDescriptions
    ),
    photos: (place.photos || []).slice(0, 8).map(
      (p) => `${origin}/place-photo?name=${encodeURIComponent(p.name)}&w=1000`
    ),
    tags: TAG_ATTRIBUTES.filter(([key]) => place[key] === true).map(([, label]) => label),
    reviews: (place.reviews || [])
      .map((r) => ({
        author: r.authorAttribution?.displayName || 'Google user',
        authorPhotoURI: r.authorAttribution?.photoUri ?? null,
        rating: r.rating ?? null,
        relativeTime: r.relativePublishTimeDescription || '',
        text: r.text?.text || '',
      }))
      .filter((r) => r.text)
      .slice(0, 5),
    googleMapsURI: place.googleMapsUri ?? null,
    websiteURI: place.websiteUri ?? null,
  };

  ctx.waitUntil(env.PLACES.put(cacheKey, JSON.stringify(details), { expirationTtl: PLACE_CACHE_TTL }));

  // Keep the list view's rating column converging on the live Google rating.
  if (typeof details.rating === 'number') {
    ctx.waitUntil(
      env.DB.prepare('UPDATE coffee_shops SET rating = ?1 WHERE id = ?2')
        .bind(details.rating, shop.id).run()
    );
  }

  return json(details);
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

      return json({ error: 'Not found' }, 404);
    } catch (e) {
      console.error(e);
      return json({ error: 'Internal server error' }, 500);
    }
  },
};
