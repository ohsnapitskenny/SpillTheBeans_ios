// Resolves a Google Place ID (and current Google rating) for every coffee shop
// in the live database, then emits SQL to store them.
//
// Usage:
//   GOOGLE_MAPS_API_KEY=<key> node backfill-place-ids.js > place-ids.sql
//   npx wrangler d1 execute spillthebeans-db --remote --file place-ids.sql
//
// Matching strategy: Places Text Search with the shop's name + address, biased
// to a 250 m circle around the coordinates we already verified against OSM.
// Anything Google can't match is reported on stderr and left untouched.

const API_KEY = process.env.GOOGLE_MAPS_API_KEY;
if (!API_KEY) {
  console.error('Set GOOGLE_MAPS_API_KEY in the environment.');
  process.exit(1);
}

const SHOPS_URL = 'https://spillthebeans-auth.hk-lam.workers.dev/shops';

const q = (v) => `'${String(v).replace(/'/g, "''")}'`;

async function findPlace(shop) {
  const resp = await fetch('https://places.googleapis.com/v1/places:searchText', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': API_KEY,
      'X-Goog-FieldMask':
        'places.id,places.displayName,places.formattedAddress,places.rating,places.location',
    },
    body: JSON.stringify({
      textQuery: `${shop.name}, ${shop.address}`,
      locationBias: {
        circle: {
          center: { latitude: shop.latitude, longitude: shop.longitude },
          radius: 250.0,
        },
      },
      maxResultCount: 1,
    }),
  });
  if (!resp.ok) throw new Error(`searchText ${resp.status}: ${await resp.text()}`);
  const data = await resp.json();
  return data.places?.[0] ?? null;
}

// Rough distance in metres — enough to reject matches in the wrong street.
function distM(aLat, aLon, bLat, bLon) {
  const dLat = (aLat - bLat) * 111_320;
  const dLon = (aLon - bLon) * 111_320 * Math.cos((aLat * Math.PI) / 180);
  return Math.hypot(dLat, dLon);
}

const shops = await (await fetch(SHOPS_URL)).json();
console.error(`Resolving place IDs for ${shops.length} shops…`);

let matched = 0;
for (const shop of shops) {
  try {
    const place = await findPlace(shop);
    if (!place) {
      console.error(`NO MATCH   ${shop.name}`);
      continue;
    }
    const d = place.location
      ? Math.round(distM(shop.latitude, shop.longitude, place.location.latitude, place.location.longitude))
      : null;
    if (d !== null && d > 500) {
      console.error(`REJECTED   ${shop.name} -> ${place.displayName?.text} (${d} m away)`);
      continue;
    }
    matched++;
    console.error(`OK ${d ?? '?'}m  ${shop.name} -> ${place.displayName?.text} [${place.id}]`);

    const sets = [`google_place_id=${q(place.id)}`];
    if (typeof place.rating === 'number') sets.push(`rating=${place.rating}`);
    console.log(`UPDATE coffee_shops SET ${sets.join(', ')} WHERE id=${q(shop.id)};`);
  } catch (e) {
    console.error(`ERROR      ${shop.name}: ${e.message}`);
  }
  await new Promise((r) => setTimeout(r, 120)); // stay well under QPS limits
}
console.error(`Done: ${matched}/${shops.length} matched.`);
