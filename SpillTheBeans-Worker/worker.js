// Spill the Beans — Auth Worker
// Endpoints:
//   POST /auth/register  { username, password, displayName?, email? }
//   POST /auth/login     { username, password }
//   GET  /auth/verify    Authorization: Bearer <token>
//   POST /auth/logout    Authorization: Bearer <token>
//
// KV bindings (set in wrangler.toml):
//   USERS    — stores user records keyed by username
//   SESSIONS — stores session tokens with 90-day TTL

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

// ── Entry point ───────────────────────────────────────────────────────────────

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS });
    }

    const { pathname } = new URL(request.url);
    try {
      if (pathname === '/auth/register' && request.method === 'POST') return handleRegister(request, env);
      if (pathname === '/auth/login'    && request.method === 'POST') return handleLogin(request, env);
      if (pathname === '/auth/verify'   && request.method === 'GET')  return handleVerify(request, env);
      if (pathname === '/auth/logout'   && request.method === 'POST') return handleLogout(request, env);
      return json({ error: 'Not found' }, 404);
    } catch (e) {
      console.error(e);
      return json({ error: 'Internal server error' }, 500);
    }
  },
};
