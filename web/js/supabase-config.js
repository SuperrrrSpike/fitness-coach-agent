// ============================================================
// Supabase 客户端配置
// ============================================================
// 在 Supabase 控制台 Project Settings → API 中获取以下两个值：
//   - Project URL（如 https://xxxxxxxx.supabase.co）
//   - anon public key（eyJ... 开头的长字符串）
//
// 两种配置方式（二选一）：
//
// 方式 A（简单直接）：把 URL 和 Key 填到下面的 SUPABASE_CONFIG 对象
// 方式 B（推荐生产用）：在托管平台设置环境变量
//   - SUPABASE_URL
//   - SUPABASE_ANON_KEY
//   部署时运行 scripts/inject-config.sh 注入到本文件（见 README 部署章节）
// ============================================================

const SUPABASE_CONFIG = {
  url: 'https://YOUR-PROJECT-REF.supabase.co',
  anonKey: 'YOUR-ANON-PUBLIC-KEY'
};

function isSupabaseConfigured() {
  return /^https:\/\/[a-z0-9-]+\.supabase\.co\/?$/.test(SUPABASE_CONFIG.url)
    && SUPABASE_CONFIG.anonKey.length >= 20
    && !SUPABASE_CONFIG.anonKey.startsWith('YOUR-');
}

let supabaseClient = null;

function getSupabase() {
  if (!supabaseClient) {
    if (!isSupabaseConfigured()) {
      throw new Error('请先在 js/supabase-config.js 中配置 url 和 anonKey');
    }
    if (typeof window.supabase === 'undefined') {
      throw new Error('Supabase SDK 未加载，请检查网络连接');
    }
    supabaseClient = window.supabase.createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.anonKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true
      }
    });
  }
  return supabaseClient;
}

// ============================================================
// 共享工具：本地日期（避免 toISOString 的 UTC 偏移问题）
// ============================================================
function localDateString(d) {
  const dt = d ? new Date(d) : new Date();
  return dt.getFullYear() + '-' +
    String(dt.getMonth() + 1).padStart(2, '0') + '-' +
    String(dt.getDate()).padStart(2, '0');
}

// ============================================================
// 规则引擎：根据用户画像计算每日热量与宏量素目标
// ============================================================
function computeNutritionTargets(profile) {
  const weight = parseFloat(profile.weight_kg);
  const height = parseFloat(profile.height_cm);
  const age = parseInt(profile.age);
  if (!weight || !height || !age) return null;

  const bmr = 10 * weight + 6.25 * height - 5 * age +
    (profile.gender === 'female' ? -161 : 5);
  const factors = { sedentary: 1.2, light: 1.375, moderate: 1.55, active: 1.725, very_active: 1.9 };
  const tdee = bmr * (factors[profile.activity_level] || 1.375);

  const adjust = { lose_fat: -500, build_muscle: 300, maintain: 0, endurance: 0 };
  const calories = Math.max(1200, Math.round(tdee + (adjust[profile.goal] || 0)));

  const proteinPerKg = goal => (goal === 'lose_fat' ? 2.2 : goal === 'build_muscle' ? 2.0 : 1.6);
  const protein = Math.round(weight * proteinPerKg(profile.goal));
  const fat = Math.round((calories * 0.25) / 9);
  const carbs = Math.max(0, Math.round((calories - protein * 4 - fat * 9) / 4));

  return {
    daily_calorie_target: calories,
    daily_protein_g: protein,
    daily_carbs_g: carbs,
    daily_fat_g: fat
  };
}
