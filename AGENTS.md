# FitCoach Agent 开发约定

## 范围

- `web/` 是无构建步骤的静态前端。
- `supabase/` 保存数据库、存储策略和 Edge Function。
- 不提交真实 Supabase 配置或视觉模型密钥。

## 验证

```bash
python3 -m unittest discover -s tests -v
node tests/test_shared_js.cjs
bash -n scripts/inject-config.sh
deno check supabase/functions/recognize-food/index.ts
```

本机未安装 Deno 时，可由 GitHub Actions 完成最后一项。修改前端公共逻辑或配置注入脚本时，必须同步补充行为测试。
