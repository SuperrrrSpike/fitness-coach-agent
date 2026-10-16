#!/bin/bash
# ============================================================
# FitCoach Agent - 生产部署配置注入脚本
# 在静态托管部署前运行，将环境变量注入 supabase-config.js
#
# 用法：
#   export SUPABASE_URL=https://xxx.supabase.co
#   export SUPABASE_ANON_KEY=eyJxxx
#   bash scripts/inject-config.sh
# ============================================================
set -euo pipefail

CONFIG_FILE="web/js/supabase-config.js"

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "错误：请先设置环境变量 SUPABASE_URL 和 SUPABASE_ANON_KEY"
  echo "  export SUPABASE_URL=https://xxx.supabase.co"
  echo "  export SUPABASE_ANON_KEY=eyJxxx"
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "错误：找不到 $CONFIG_FILE"
  exit 1
fi

echo "注入 Supabase 配置到 $CONFIG_FILE ..."

# 用 perl 进行安全替换（避免 sed 对特殊字符的问题）
perl -i -pe "s|https://YOUR-PROJECT-REF\.supabase\.co|\${SUPABASE_URL}|g" "$CONFIG_FILE"
perl -i -pe "s|YOUR-ANON-PUBLIC-KEY|\${SUPABASE_ANON_KEY}|g" "$CONFIG_FILE"

echo "✅ 配置注入完成"
echo "   URL: $SUPABASE_URL"
echo "   Anon key: 已配置（不在终端回显）"
