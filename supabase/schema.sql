-- ============================================================
-- FitCoach Agent - 数据库 Schema
-- 用途：用户画像、训练计划、训练记录、饮食记录、食物库
-- 执行位置：Supabase 控制台 → SQL Editor → New query → Run
-- ============================================================

-- 启用必要扩展
create extension if not exists "uuid-ossp";

-- ============================================================
-- 1. 枚举类型
-- ============================================================
do $$ begin
  create type goal_type as enum ('lose_fat', 'build_muscle', 'maintain', 'endurance');
exception when duplicate_object then null; end $$;

do $$ begin
  create type activity_type as enum ('sedentary', 'light', 'moderate', 'active', 'very_active');
exception when duplicate_object then null; end $$;

do $$ begin
  create type experience_type as enum ('beginner', 'intermediate', 'advanced');
exception when duplicate_object then null; end $$;

do $$ begin
  create type meal_type as enum ('breakfast', 'lunch', 'dinner', 'snack');
exception when duplicate_object then null; end $$;

do $$ begin
  create type plan_status as enum ('active', 'completed', 'archived');
exception when duplicate_object then null; end $$;

-- ============================================================
-- 2. 用户画像表（每个注册用户一条）
-- ============================================================
create table if not exists public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  gender text check (gender in ('male', 'female', 'other')),
  age int check (age between 10 and 100),
  height_cm numeric(5,1) check (height_cm between 100 and 250),
  weight_kg numeric(5,1) check (weight_kg between 30 and 250),
  goal goal_type,
  target_weight_kg numeric(5,1),
  activity_level activity_type default 'light',
  experience_level experience_type default 'beginner',
  available_equipment text[] default array['bodyweight']::text[],
  weekly_training_days int default 3 check (weekly_training_days between 1 and 7),
  daily_calorie_target int,
  daily_protein_g int,
  daily_carbs_g int,
  daily_fat_g int,
  onboarding_completed boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================
-- 3. 训练计划表（每周一个计划）
-- ============================================================
create table if not exists public.training_plans (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  week_start_date date not null,
  plan_name text not null,
  goal goal_type,
  total_sessions int default 0,
  plan_data jsonb not null,
  status plan_status default 'active',
  generated_by text default 'rule_engine',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (user_id, week_start_date)
);

create index if not exists idx_training_plans_user_week
  on public.training_plans (user_id, week_start_date desc);

-- ============================================================
-- 4. 训练记录表（每组动作一条）
-- ============================================================
create table if not exists public.training_records (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_id uuid references public.training_plans(id) on delete set null,
  training_date date not null,
  exercise_name text not null,
  muscle_group text,
  set_index int not null check (set_index > 0),
  reps int check (reps >= 0),
  weight_kg numeric(6,1) check (weight_kg >= 0),
  rpe numeric(3,1) check (rpe between 1 and 10),
  is_pr boolean default false,
  notes text,
  created_at timestamptz default now()
);

create index if not exists idx_training_records_user_date
  on public.training_records (user_id, training_date desc);

create index if not exists idx_training_records_exercise
  on public.training_records (user_id, exercise_name, weight_kg desc);

-- ============================================================
-- 5. 饮食记录表
-- ============================================================
create table if not exists public.diet_records (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  meal_date date not null,
  meal_type meal_type not null,
  food_name text not null,
  amount_g numeric(7,1) check (amount_g > 0),
  calories numeric(7,1) default 0,
  protein_g numeric(6,2) default 0,
  carbs_g numeric(6,2) default 0,
  fat_g numeric(6,2) default 0,
  image_url text,
  ai_recognized boolean default false,
  ai_confidence numeric(4,3) check (ai_confidence between 0 and 1),
  notes text,
  created_at timestamptz default now()
);

create index if not exists idx_diet_records_user_date
  on public.diet_records (user_id, meal_date desc);

-- ============================================================
-- 6. AI 识别日志（记录每次拍照识别）
-- ============================================================
create table if not exists public.diet_recognition_logs (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  image_url text not null,
  recognition_result jsonb,
  llm_provider text,
  llm_model text,
  llm_raw_response text,
  latency_ms int,
  created_at timestamptz default now()
);

create index if not exists idx_diet_recognition_logs_user
  on public.diet_recognition_logs (user_id, created_at desc);

-- 兼容已执行旧版 Schema 的项目。
alter table public.diet_records
  add column if not exists ai_confidence numeric(4,3)
  check (ai_confidence between 0 and 1);
alter table public.diet_recognition_logs
  add column if not exists llm_raw_response text;

-- ============================================================
-- 7. 食物营养库（公开表，所有用户可读）
-- ============================================================
create table if not exists public.food_nutrition (
  id uuid primary key default uuid_generate_v4(),
  food_name text unique not null,
  category text,
  calories_per_100g numeric(6,2) not null,
  protein_per_100g numeric(6,2) default 0,
  carbs_per_100g numeric(6,2) default 0,
  fat_per_100g numeric(6,2) default 0,
  source text default 'manual',
  created_at timestamptz default now()
);

-- 种子数据：常见食物
insert into public.food_nutrition (food_name, category, calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g) values
  ('鸡胸肉', '肉类', 165, 31.0, 0, 3.6),
  ('牛肉', '肉类', 250, 26.0, 0, 15.0),
  ('猪肉', '肉类', 242, 27.0, 0, 14.0),
  ('三文鱼', '海鲜', 208, 20.0, 0, 13.0),
  ('虾', '海鲜', 99, 24.0, 0.2, 0.3),
  ('鸡蛋', '蛋类', 155, 13.0, 1.1, 11.0),
  ('牛奶', '乳制品', 42, 3.4, 5.0, 1.0),
  ('酸奶', '乳制品', 59, 10.0, 3.6, 0.4),
  ('白米饭', '主食', 130, 2.7, 28.0, 0.3),
  ('全麦面包', '主食', 247, 13.0, 41.0, 4.2),
  ('燕麦', '主食', 389, 16.9, 66.3, 6.9),
  ('红薯', '主食', 86, 1.6, 20.1, 0.1),
  ('土豆', '主食', 77, 2.0, 17.0, 0.1),
  ('西兰花', '蔬菜', 34, 2.8, 7.0, 0.4),
  ('菠菜', '蔬菜', 23, 2.9, 3.6, 0.4),
  ('胡萝卜', '蔬菜', 41, 0.9, 9.6, 0.2),
  ('番茄', '蔬菜', 18, 0.9, 3.9, 0.2),
  ('黄瓜', '蔬菜', 16, 0.7, 3.6, 0.1),
  ('苹果', '水果', 52, 0.3, 14.0, 0.2),
  ('香蕉', '水果', 89, 1.1, 23.0, 0.3),
  ('橙子', '水果', 47, 0.9, 12.0, 0.1),
  ('杏仁', '坚果', 579, 21.2, 21.6, 49.9),
  ('花生', '坚果', 567, 25.8, 16.1, 49.2),
  ('豆腐', '豆制品', 76, 8.1, 1.9, 4.8),
  ('豆浆', '豆制品', 54, 3.3, 6.3, 1.8)
on conflict (food_name) do nothing;

-- ============================================================
-- 8. 触发器：updated_at 自动更新
-- ============================================================
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_user_profiles_updated_at on public.user_profiles;
create trigger trg_user_profiles_updated_at
  before update on public.user_profiles
  for each row execute function public.set_updated_at();

drop trigger if exists trg_training_plans_updated_at on public.training_plans;
create trigger trg_training_plans_updated_at
  before update on public.training_plans
  for each row execute function public.set_updated_at();

-- ============================================================
-- 9. 触发器：注册时自动创建 profile
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
security definer
set search_path = public
as $$
begin
  insert into public.user_profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)))
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_on_auth_user_created on auth.users;
create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- 10. 启用 RLS
-- ============================================================
alter table public.user_profiles enable row level security;
alter table public.training_plans enable row level security;
alter table public.training_records enable row level security;
alter table public.diet_records enable row level security;
alter table public.diet_recognition_logs enable row level security;
alter table public.food_nutrition enable row level security;

-- ============================================================
-- 11. RLS 策略
-- ============================================================

-- user_profiles：只能读写自己的档案
drop policy if exists "profiles_select_own" on public.user_profiles;
create policy "profiles_select_own" on public.user_profiles
  for select using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.user_profiles;
create policy "profiles_insert_own" on public.user_profiles
  for insert with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.user_profiles;
create policy "profiles_update_own" on public.user_profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- training_plans
drop policy if exists "plans_select_own" on public.training_plans;
create policy "plans_select_own" on public.training_plans
  for select using (auth.uid() = user_id);

drop policy if exists "plans_insert_own" on public.training_plans;
create policy "plans_insert_own" on public.training_plans
  for insert with check (auth.uid() = user_id);

drop policy if exists "plans_update_own" on public.training_plans;
create policy "plans_update_own" on public.training_plans
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "plans_delete_own" on public.training_plans;
create policy "plans_delete_own" on public.training_plans
  for delete using (auth.uid() = user_id);

-- training_records
drop policy if exists "records_select_own" on public.training_records;
create policy "records_select_own" on public.training_records
  for select using (auth.uid() = user_id);

drop policy if exists "records_insert_own" on public.training_records;
create policy "records_insert_own" on public.training_records
  for insert with check (auth.uid() = user_id);

drop policy if exists "records_update_own" on public.training_records;
create policy "records_update_own" on public.training_records
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "records_delete_own" on public.training_records;
create policy "records_delete_own" on public.training_records
  for delete using (auth.uid() = user_id);

-- diet_records
drop policy if exists "diet_select_own" on public.diet_records;
create policy "diet_select_own" on public.diet_records
  for select using (auth.uid() = user_id);

drop policy if exists "diet_insert_own" on public.diet_records;
create policy "diet_insert_own" on public.diet_records
  for insert with check (auth.uid() = user_id);

drop policy if exists "diet_update_own" on public.diet_records;
create policy "diet_update_own" on public.diet_records
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "diet_delete_own" on public.diet_records;
create policy "diet_delete_own" on public.diet_records
  for delete using (auth.uid() = user_id);

-- diet_recognition_logs
drop policy if exists "logs_select_own" on public.diet_recognition_logs;
create policy "logs_select_own" on public.diet_recognition_logs
  for select using (auth.uid() = user_id);

drop policy if exists "logs_insert_own" on public.diet_recognition_logs;
create policy "logs_insert_own" on public.diet_recognition_logs
  for insert with check (auth.uid() = user_id);

-- food_nutrition：所有登录用户可读，仅 service_role 可写
drop policy if exists "food_select_authenticated" on public.food_nutrition;
create policy "food_select_authenticated" on public.food_nutrition
  for select to authenticated using (true);

-- ============================================================
-- 完成
-- ============================================================
