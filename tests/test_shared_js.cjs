const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const configPath = path.join(root, "web/js/supabase-config.js");
const source = fs.readFileSync(configPath, "utf8");

function loadSharedScript(script = source) {
  const context = { window: {} };
  vm.createContext(context);
  vm.runInContext(
    `${script}\n;globalThis.__fitcoach = {` +
      "isSupabaseConfigured, getSupabase, localDateString, computeNutritionTargets };",
    context,
  );
  return { context, api: context.__fitcoach };
}

{
  const { api } = loadSharedScript();
  assert.equal(api.isSupabaseConfigured(), false);
  assert.throws(() => api.getSupabase(), /请先.*配置/);
}

{
  const empty = source
    .replace("https://YOUR-PROJECT-REF.supabase.co", "")
    .replace("YOUR-ANON-PUBLIC-KEY", "");
  const { api } = loadSharedScript(empty);
  assert.equal(api.isSupabaseConfigured(), false);
}

{
  let createCount = 0;
  const configured = source
    .replace("https://YOUR-PROJECT-REF.supabase.co", "https://demo.supabase.co")
    .replace("YOUR-ANON-PUBLIC-KEY", "public-anon-test-value");
  const { context, api } = loadSharedScript(configured);
  const client = { name: "test-client" };
  context.window.supabase = {
    createClient(url, key, options) {
      createCount += 1;
      assert.equal(url, "https://demo.supabase.co");
      assert.equal(key, "public-anon-test-value");
      assert.equal(options.auth.persistSession, true);
      return client;
    },
  };
  assert.equal(api.isSupabaseConfigured(), true);
  assert.equal(api.getSupabase(), client);
  assert.equal(api.getSupabase(), client);
  assert.equal(createCount, 1);
}

{
  const { api } = loadSharedScript();
  assert.equal(api.localDateString(new Date(2026, 9, 18, 23, 30)), "2026-10-18");
  assert.equal(api.computeNutritionTargets({ weight_kg: "", height_cm: 175, age: 25 }), null);

  const muscle = api.computeNutritionTargets({
    weight_kg: 80,
    height_cm: 180,
    age: 30,
    gender: "male",
    activity_level: "moderate",
    goal: "build_muscle",
  });
  assert.deepEqual(JSON.parse(JSON.stringify(muscle)), {
    daily_calorie_target: 3059,
    daily_protein_g: 160,
    daily_carbs_g: 414,
    daily_fat_g: 85,
  });

  const minimum = api.computeNutritionTargets({
    weight_kg: 30,
    height_cm: 150,
    age: 100,
    gender: "female",
    activity_level: "sedentary",
    goal: "lose_fat",
  });
  assert.equal(minimum.daily_calorie_target, 1200);
  assert.ok(minimum.daily_protein_g > 0);
  assert.ok(minimum.daily_carbs_g >= 0);
  assert.ok(minimum.daily_fat_g > 0);
}

console.log("shared JavaScript behavior: ok");
