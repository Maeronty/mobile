import assert from 'node:assert/strict';
import test from 'node:test';
import { recognize, suggest, withGeminiKey } from './food.mjs';

test('skips rate-limited keys during cooldown and stops when all are limited', async () => {
  const blocked = new Map();
  const calls = [];
  const limit = Object.assign(new Error(), {upstreamStatus: 429, retryMs: 60000});
  const call = async k => { calls.push(k); if (k === 'a') throw limit; return 'ok'; };
  assert.equal(await withGeminiKey(['a','b'], call, blocked), 'ok');
  await withGeminiKey(['a','b'], call, blocked);
  assert.deepEqual(calls, ['a','b','b']);
  await assert.rejects(withGeminiKey(['a','b'], async () => {throw limit;}, blocked), {status: 429});
});

test('looks up English ingredients and returns ranked Vietnamese matches grounded in Spoonacular IDs', async () => {
  const dish = { id: 42, title: 'Trứng luộc', reason: 'Dùng trứng sẵn có.', used: ['1 quả trứng'], missing: [] };
  const generate = async prompt => prompt.includes('Convert only') ? ['egg'] : [{id: 99}, dish, dish];
  const search = async terms => {
    assert.deepEqual(terms, ['egg']);
    return [{ id: 42, title: 'Boiled egg', usedIngredients: [{original: '1 egg'}], missedIngredients: [] }];
  };
  assert.deepEqual(await suggest(['trứng'], generate, search), [dish]);
  assert.deepEqual(await suggest(['trứng'], generate, async () => []), []);
  await assert.rejects(suggest([], generate, search), {status: 400});
});

test('passes the image to the vision model and permits a no-food result', async () => {
  assert.deepEqual(await recognize({ mime: 'image/jpeg', data: '/9j/' }, async (_, schema, image) => {
    assert.equal(schema.type, 'ARRAY');
    assert.deepEqual(image, { mime_type: 'image/jpeg', data: '/9j/' });
    return [];
  }), []);
  await assert.rejects(recognize({mime: 'text/html', data: 'abc'}), {status: 400});
});
