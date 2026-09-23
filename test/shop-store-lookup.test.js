import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { applyStoreLookupResult, callStoreLookup } from '../admin-web/src/pages/shopStoresPage.js';

const source = readFileSync(new URL('../supabase/functions/shop-store-lookup/index.ts', import.meta.url), 'utf8')
  .replace(/^import .*\r?\n/gm, '')
  .split('serve(async (req) => {')[0];
const makeLookup = new Function('fetch', stripTypeScriptTypes(source, { mode: 'strip' }) +
  '\nreturn { findFromLink, findFromPoint, openingHoursFromPlace };');

const place = {
  name: 'บ้านเฮาซุปเปอร์มาร์เก็ต',
  formatted_address: '5WM8+926 ตำบล ปัว อำเภอ ปัว น่าน 55120',
  geometry: { location: { lat: 19.1834234, lng: 100.9150303 } },
  url: 'https://maps.google.com/?cid=15946509698373983889',
  opening_hours: {
    periods: Array.from({ length: 7 }, (_, day) => ({
      open: { day, time: '0800' }, close: { day, time: '2100' },
    })),
  },
};

function googleResponse(body) {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { 'content-type': 'application/json' },
  });
}

test('short Maps link uses matching feature CID and fills name and weekly hours', async () => {
  const calls = [];
  const fetchMock = async (input) => {
    const url = new URL(input);
    calls.push(url.pathname);
    if (url.hostname === 'maps.app.goo.gl') {
      return new Response(null, { status: 302, headers: {
        location: `https://www.google.com/maps?q=${encodeURIComponent('5WM8 926 บ้านเฮาซุปเปอร์มาร์เก็ต')}&ftid=0x3127e10d7209046d:0xdd4d62151ae71e91`,
      } });
    }
    if (url.pathname === '/maps') return new Response('', { status: 200 });
    if (url.pathname.endsWith('/place/textsearch/json')) {
      return googleResponse({ status: 'OK', results: [{ place_id: 'matching-place-id' }] });
    }
    if (url.pathname.endsWith('/place/details/json')) return googleResponse({ status: 'OK', result: place });
    throw new Error(`Unexpected request: ${url.pathname}`);
  };
  const { findFromLink } = makeLookup(fetchMock);
  const result = await findFromLink('https://maps.app.goo.gl/qJbBZFQSLd6Rs8z86?g_st=ic', 'dummy-key');
  assert.equal(result.name, place.name);
  assert.equal(result.source, 'place');
  assert.deepEqual(result.openingHours.mon, [{ open: '08:00', close: '21:00' }]);
  assert.deepEqual(result.openingHours.sun, [{ open: '08:00', close: '21:00' }]);
  assert.ok(calls.some((path) => path.endsWith('/place/details/json')));
});

test('a full Maps place link with data feature ID uses the named place rather than viewport coordinates', async () => {
  const calls = [];
  const fetchMock = async (input) => {
    const url = new URL(input);
    calls.push(url.pathname);
    if (url.pathname.includes('/maps/place/')) return new Response('', { status: 200 });
    if (url.pathname.endsWith('/place/textsearch/json')) {
      return googleResponse({ status: 'OK', results: [{ place_id: 'matching-place-id' }] });
    }
    if (url.pathname.endsWith('/place/details/json')) return googleResponse({ status: 'OK', result: place });
    throw new Error(`Unexpected request: ${url.pathname}`);
  };
  const { findFromLink } = makeLookup(fetchMock);
  const link = 'https://www.google.com/maps/place/%E0%B8%9A%E0%B9%89%E0%B8%B2%E0%B8%99%E0%B9%80%E0%B8%AE%E0%B8%B2%E0%B8%8B%E0%B8%B8%E0%B8%9B%E0%B9%80%E0%B8%9B%E0%B8%AD%E0%B8%A3%E0%B9%8C%E0%B8%A1%E0%B8%B2%E0%B8%A3%E0%B9%8C%E0%B9%80%E0%B8%81%E0%B9%87%E0%B8%95/@19.1831029,100.9153346,18z/data=!4m5!3m4!1s0x3127e10d7209046d:0xdd4d62151ae71e91!8m2!3d19.1834234!4d100.9150303';
  const result = await findFromLink(link, 'dummy-key');
  assert.equal(result.name, place.name);
  assert.equal(result.lat, place.geometry.location.lat);
  assert.equal(result.lng, place.geometry.location.lng);
  assert.equal(result.source, 'place');
  assert.ok(calls.some((path) => path.endsWith('/place/details/json')));
});

test('the supplied full Maps link selects the final place, not the earlier 7-Eleven feature', async () => {
  const fetchMock = async (input) => {
    const url = new URL(input);
    if (url.pathname.includes('/maps/place/')) return new Response('', { status: 200 });
    if (url.pathname.endsWith('/place/textsearch/json')) {
      return googleResponse({ status: 'OK', results: [{ place_id: 'matching-place-id' }] });
    }
    if (url.pathname.endsWith('/place/details/json')) return googleResponse({ status: 'OK', result: place });
    throw new Error(`Unexpected request: ${url.pathname}`);
  };
  const { findFromLink } = makeLookup(fetchMock);
  const link = 'https://www.google.com/maps/place/5WM8%2B926+%E0%B8%9A%E0%B9%89%E0%B8%B2%E0%B8%99%E0%B9%80%E0%B8%AE%E0%B8%B2%E0%B8%8B%E0%B8%B8%E0%B8%9B%E0%B9%80%E0%B8%9B%E0%B8%AD%E0%B8%A3%E0%B9%8C%E0%B8%A1%E0%B8%B2%E0%B8%A3%E0%B9%8C%E0%B9%80%E0%B8%81%E0%B9%87%E0%B8%95+%E0%B8%95%E0%B8%B3%E0%B8%9A%E0%B8%A5+%E0%B8%9B%E0%B8%B1%E0%B8%A7+%E0%B8%AD%E0%B8%B3%E0%B9%80%E0%B8%A0%E0%B8%AD+%E0%B8%9B%E0%B8%B1%E0%B8%A7+%E0%B8%99%E0%B9%88%E0%B8%B2%E0%B8%99+55120/@19.1831029,100.9153346,18z/data=!4m14!1m7!3m6!1s0x3127e10d43c2f259:0x208e13c3796d68ad!2zNVdNNys3SlAgNy1FbGV2ZW4g4Liq4Liy4LiC4LiyIOC4leC4peC4suC4lOC4m-C4seC4pyAyICgwNTM0MikgMTA4MCDguJXguLPguJrguKUg4Lib4Lix4LinIOC4reC4s-C5gOC4oOC4rSDguJvguLHguKcg4LiZ4LmI4Liy4LiZIDU1MTIw!8m2!3d19.1832079!4d100.9140829!16s%2Fg%2F11c6dvdg7s!3m5!1s0x3127e10d7209046d:0xdd4d62151ae71e91!8m2!3d19.1834234!4d100.9150303!16s%2Fg%2F1hm3md1nj';
  const result = await findFromLink(link, 'dummy-key');
  assert.equal(result.name, place.name);
  assert.equal(result.lat, place.geometry.location.lat);
  assert.equal(result.lng, place.geometry.location.lng);
});

test('missing opening hours are omitted; overnight and 24-hour schedules convert safely', () => {
  const { openingHoursFromPlace } = makeLookup(async () => { throw new Error('No network expected'); });
  assert.equal(openingHoursFromPlace(undefined), null);
  assert.deepEqual(openingHoursFromPlace({ periods: [{
    open: { day: 1, time: '1800' }, close: { day: 2, time: '0200' },
  }] }).openingHours.mon, [{ open: '18:00', close: '02:00' }]);
  assert.equal(openingHoursFromPlace({ periods: [{
    open: { day: 1, time: '1800' }, close: { day: 3, time: '0200' },
  }] }), null);
  assert.equal(openingHoursFromPlace({ periods: [{ open: { day: 0, time: '0000' } }] }).is24h, true);
});

test('clicking a named Google place uses its place coordinates rather than the clicked map pixel', async () => {
  const fetchMock = async (input) => {
    const url = new URL(input);
    if (url.pathname.endsWith('/place/nearbysearch/json')) return googleResponse({ status: 'OK', results: [{
      place_id: 'matching-place-id', types: ['establishment'], geometry: { location: place.geometry.location },
    }] });
    if (url.pathname.endsWith('/place/details/json')) return googleResponse({ status: 'OK', result: place });
    throw new Error(`Unexpected request: ${url.pathname}`);
  };
  const { findFromPoint } = makeLookup(fetchMock);
  const clickedLat = place.geometry.location.lat + 0.00002;
  const clickedLng = place.geometry.location.lng;
  const result = await findFromPoint(clickedLat, clickedLng, 'dummy-key');
  assert.equal(result.name, place.name);
  assert.equal(result.lat, place.geometry.location.lat);
  assert.equal(result.lng, place.geometry.location.lng);
});

test('a coordinate link without a place ID marks a nearby search match for confirmation', async () => {
  const fetchMock = async (input) => {
    const url = new URL(input);
    if (url.pathname === '/maps') return new Response('', { status: 200 });
    if (url.pathname.endsWith('/place/textsearch/json')) return googleResponse({ status: 'OK', results: [{ place_id: 'nearby-place-id' }] });
    if (url.pathname.endsWith('/place/details/json')) return googleResponse({ status: 'OK', result: place });
    throw new Error(`Unexpected request: ${url.pathname}`);
  };
  const { findFromLink } = makeLookup(fetchMock);
  const result = await findFromLink(`https://www.google.com/maps?q=${encodeURIComponent(place.name)}&center=19.1834234,100.9150303`, 'dummy-key');
  assert.equal(result.source, 'unverified_search');
  assert.equal(result.lat, place.geometry.location.lat);
  assert.equal(result.lng, place.geometry.location.lng);
});

test('form imports hours when supplied and preserves them when a place has none', () => {
  const previousDocument = globalThis.document;
  const fields = new Map();
  const get = (id) => {
    if (!fields.has(id)) fields.set(id, { value: '', checked: false, textContent: '' });
    return fields.get(id);
  };
  globalThis.document = { getElementById: (id) => id === 'ss_google_map' ? null : get(id) };
  try {
    get('h_mon_o').value = '09:00';
    get('h_mon_c').value = '17:00';
    applyStoreLookupResult({ name: place.name, address: place.formatted_address,
      lat: 19.1834234, lng: 100.9150303, source: 'place',
      openingHours: { mon: [{ open: '08:00', close: '21:00' }] }, is24h: false });
    assert.equal(get('ss_name').value, place.name);
    assert.equal(get('h_mon_o').value, '08:00');
    assert.equal(get('h_mon_c').value, '21:00');
    applyStoreLookupResult({ name: 'ร้านไม่มีเวลา', address: 'ที่อยู่',
      lat: 19.1780892, lng: 100.9150833, source: 'place' });
    assert.equal(get('ss_name').value, 'ร้านไม่มีเวลา');
    assert.equal(get('ss_lat').value, 19.1780892);
    assert.equal(get('ss_lng').value, 100.9150833);
    assert.equal(get('h_mon_o').value, '08:00');
    assert.equal(get('h_mon_c').value, '21:00');
    applyStoreLookupResult({ name: 'ร้าน 24 ชั่วโมง', address: 'ที่อยู่',
      lat: 19.1834234, lng: 100.9150303, source: 'place', is24h: true, openingHours: {} });
    assert.equal(get('ss_24h').checked, true);
    assert.equal(get('ss_lat').value, 19.1834234);
    assert.equal(get('ss_lng').value, 100.9150303);
    assert.equal(get('h_mon_o').value, '');
    assert.equal(get('h_mon_c').value, '');
  } finally {
    globalThis.document = previousDocument;
  }
});

test('lookup displays the Edge Function error body instead of the generic non-2xx message', async () => {
  const previousSupabase = globalThis.supabase;
  globalThis.supabase = { functions: { invoke: async () => ({
    data: null,
    error: {
      message: 'Edge Function returned a non-2xx status code',
      context: new Response(JSON.stringify({ error: 'ไม่พบข้อมูลร้านที่ตรงกับหมุดในลิงก์' }), {
        status: 400,
        headers: { 'content-type': 'application/json' },
      }),
    },
  }) } };
  try {
    await assert.rejects(callStoreLookup({ mode: 'url', url: 'https://www.google.com/maps/place/test' }),
      /ไม่พบข้อมูลร้านที่ตรงกับหมุดในลิงก์/);
  } finally {
    globalThis.supabase = previousSupabase;
  }
});
