-- ============================================================
-- FitCoach Agent - Supabase Storage 配置
-- 用途：拍照识别卡路里的图片存储
-- 执行位置：Supabase 控制台 → SQL Editor（在 schema.sql 之后执行）
-- ============================================================

-- 1. 创建私有 bucket（仅本人可读写）
insert into storage.buckets (id, name, public)
values ('diet-images', 'diet-images', false)
on conflict (id) do nothing;

-- 2. RLS 策略：用户只能访问 以自己 user_id 命名的第一级目录 下的对象
--    上传路径约定：{user_id}/{timestamp}.jpg

drop policy if exists "diet_images_insert_own" on storage.objects;
create policy "diet_images_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'diet-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "diet_images_select_own" on storage.objects;
create policy "diet_images_select_own" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'diet-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "diet_images_delete_own" on storage.objects;
create policy "diet_images_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'diet-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- 完成
