# FitCoach Agent

[![CI](https://github.com/SuperrrrSpike/fitness-coach-agent/actions/workflows/ci.yml/badge.svg)](https://github.com/SuperrrrSpike/fitness-coach-agent/actions/workflows/ci.yml)

> AI 驱动的私人健身教练平台 —— 一个用户 + 教练两端协作的训练与饮食管理产品。

## 产品定位

FitCoach Agent 不是一个简单的训练记录 App，而是一个 **C 端用户 + B 端教练双角色协作** 的智能健身平台：

| 角色 | 典型场景 | 核心需求 |
|---|---|---|
| **C 端健身者** | 普通用户想科学训练、控制饮食 | 自动生成周计划、动作记录、食物拍照识别、热量追踪 |
| **B 端教练**（规划中） | 私教 / 健身房运营 | 同时管理多名学员、查看训练完成度、远程调整计划 |

当前实现优先 **C 端完整闭环**，B 端教练工作台作为下一步演进方向（数据模型已留好扩展位）。

## 多端体验

| 端 | 形式 | 入口 | 说明 |
|---|---|---|---|
| **Web 控制台** | 桌面浏览器 | `web/dashboard.html` | 主操作界面，数据可视化、打卡、计划编辑 |
| **移动响应式** | 手机浏览器 | 同 URL | Tailwind 响应式布局，训练间隙单手可操作 |
| **推送通道** | Web Push / 微信 | Edge Function（规划） | 训练提醒、计划更新日推送 |

三个端共享同一份 Supabase 后端，登录态通过 JWT 跨端同步。

## 技术栈

**前端**
- **Tailwind CSS**（CDN，国内可访问）
- **Font Awesome 4.7**（图标）
- **Supabase JS SDK v2**（认证 + 数据库 + 存储）
- 纯静态 SPA，零构建步骤，可直接托管在 Netlify / Vercel / 静态服务器

**后端**
- **Supabase**：PostgreSQL + Auth + Storage + Edge Functions（Deno）
- **Edge Function `recognize-food`**：调用通义千问 VL (`qwen-vl-plus`) 拍照识别食物
- **RLS（Row Level Security）**：每个用户只能读写自己的数据

**部署**
- **Netlify** 或 **Vercel** 二选一（均提供 `netlify.toml` / `vercel.json`）
- 部署前用 `scripts/inject-config.sh` 注入 Supabase URL + Anon Key 到前端

## 当前已交付（C 端）

✅ 用户画像（身高/体重/目标/活动量/器械/经验/可用训练日）
✅ 每周训练计划自动生成（基于规则引擎，含渐进负荷）
✅ 训练打卡（每组动作：次数 / 重量 / RPE / 是否 PR）
✅ 饮食记录 + 拍照识别（自动算热量与三大营养素）
✅ 控制台数据卡片（本周训练 / 累计记录 / 今日热量 / 活跃计划）
✅ 邮箱密码登录 + 魔法链接注册
✅ 私有图片上传 + Supabase Edge Function 食物识别链路

## 计划演进（B 端教练）

⏳ 教练工作台：批量查看学员训练完成度与饮食达标率
⏳ 远程调计划：教练端修改 → 学员端实时收到推送
⏳ 训练提醒推送：基于学员周计划时间自动触发
⏳ 数据洞察：周报/月报自动生成，供教练复盘

## 快速上手

### 1. 本地预览

```bash
# 任何静态服务器都可以，例如：
cd web && python3 -m http.server 8000
# 浏览器打开 http://localhost:8000
```

### 2. 配置 Supabase

```bash
# 在 Supabase 控制台执行 supabase/schema.sql 建表
# 部署 Edge Function
supabase functions deploy recognize-food --project-ref <your-ref>
supabase secrets set VISION_API_KEY=sk-xxx

# 注入前端配置
export SUPABASE_URL=https://<your-ref>.supabase.co
export SUPABASE_ANON_KEY=eyJxxx
bash scripts/inject-config.sh
```

### 3. 部署到 Netlify

```bash
# 已配置 netlify.toml，build.publish = "web"
# 注入完配置后直接 netlify deploy --prod
```

## 目录结构

```
fitness-coach-agent/
├── web/                    # 前端静态资源
│   ├── index.html          # 登录 / 注册
│   ├── dashboard.html      # 控制台
│   ├── plan.html           # 训练计划
│   ├── workout.html        # 训练打卡
│   ├── diet.html           # 饮食记录
│   └── js/                 # 业务脚本
├── supabase/
│   ├── schema.sql          # 数据库表结构 + RLS
│   ├── functions/
│   │   └── recognize-food/ # Edge Function（食物拍照识别）
│   └── storage-setup.sql   # Storage 桶策略
├── scripts/
│   └── inject-config.sh    # 部署前注入 Supabase 配置
├── netlify.toml            # Netlify 部署配置
└── vercel.json             # Vercel 部署配置
```

## 安全与隐私

- 所有用户数据由用户本人持有，Supabase RLS 强制隔离
- 拍照识别通过 Edge Function 代理，前端不接触视觉模型密钥
- 静态前端无后端密钥（Supabase Anon Key 是公开的，受 RLS 保护）
- Edge Function 默认要求 Supabase 登录态，视觉模型密钥仅保存在服务端 Secret
- 热量和营养估算仅用于个人记录，不构成医疗或营养诊断

## 测试

```bash
python3 -m unittest discover -s tests -v
```

测试会核对页面、数据库字段、Edge Function 和配置占位符，并扫描常见私钥格式。

## 路线图

- [x] C 端 MVP：训练 + 饮食完整闭环
- [ ] 推送通知（Web Push + 微信）
- [ ] B 端教练工作台
- [ ] 多语言支持（i18n）
- [ ] 智能计划调整（基于完成度自动加重 / 减量）
