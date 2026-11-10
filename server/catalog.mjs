import { readFileSync, statSync } from 'node:fs';

const snapshot = new URL('../assets/spoonacular.json', import.meta.url);
let cached;
let pending;
let expires = 0;
export async function loadCatalog(translate) {
  if (!cached) {
    cached = JSON.parse(readFileSync(snapshot, 'utf8'));
    expires = statSync(snapshot).mtimeMs + 86400000;
  }
  if (Date.now() >= expires && !pending) {
    pending = fetchCatalog(translate).then(rows => {
      cached = rows;
      expires = Date.now() + 86400000;
    }).catch(() => {
      expires = Date.now() + 60000;
    }).finally(() => { pending = undefined; });
  }
  return cached;
}

async function fetchCatalog(translate) {
  const url = new URL('https://api.spoonacular.com/recipes/complexSearch');
  url.search = new URLSearchParams({number: '8', addRecipeInformation: 'true',
    addRecipeNutrition: 'true', fillIngredients: 'true', instructionsRequired: 'true'});
  const response = await fetch(url, {headers: {'x-api-key': process.env.SPOONACULAR_API_KEY},
    signal: AbortSignal.timeout(30000)});
  if (!response.ok) throw new Error('Spoonacular HTTP ' + response.status);
  const {results} = await response.json();
  const recipes = results.map(r => {
    const steps = r.analyzedInstructions.flatMap(group => group.steps.map(s => s.step));
    const nutrients = Object.fromEntries(r.nutrition.nutrients.map(n => [n.name, n.amount]));
    return {id: r.id, title: r.title, image: r.image, source: r.sourceName || 'Spoonacular',
      category: r.dishTypes[0] || 'Dish', time: r.readyInMinutes, servings: r.servings,
      nutrients, steps, ingredients: r.extendedIngredients.map(i => ({
        name: i.nameClean || i.name, unit: i.measures.metric.unitShort, amount: i.measures.metric.amount
      }))};
  }).filter(r => r.steps.length && r.ingredients.length && r.servings > 0);
  if (!recipes.length) throw new Error('Spoonacular returned no usable recipes');
  const phrases = [...new Set(recipes.flatMap(r => [r.title, r.category, ...r.steps,
    ...r.ingredients.flatMap(i => [i.name, i.unit])]).filter(Boolean))];
  const dictionary = new Map();
  const batches = Array.from({length: Math.ceil(phrases.length / 16)}, (_, i) => phrases.slice(i * 16, i * 16 + 16));
  for (let offset = 0; offset < batches.length; offset += 3) {
    await Promise.all(batches.slice(offset, offset + 3).map(async batch => {
      const translated = await translate('Translate each culinary string to Vietnamese. Preserve order, units, numbers and temperatures. Return exactly one translation per input. ' + JSON.stringify(batch),
        {type: 'ARRAY', items: {type: 'STRING'}, minItems: batch.length, maxItems: batch.length});
      if (translated.length !== batch.length || translated.some(s => typeof s !== 'string' || !s.trim())) throw new Error('Incomplete translation');
      batch.forEach((s, i) => dictionary.set(s, translated[i]));
    }));
  }
  return recipes.map(r => ({...r, title: dictionary.get(r.title), category: dictionary.get(r.category),
    steps: r.steps.map(s => dictionary.get(s)), ingredients: r.ingredients.map(i => ({
      ...i, name: dictionary.get(i.name), unit: dictionary.get(i.unit) || ''
    }))}));
}
