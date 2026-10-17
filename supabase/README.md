# FitCoach Agent - Supabase 配置指南

本指南帮助你在 10 分钟内完成 Supabase 项目的初始化和数据库部署。

---

## 第 1 步：创建 Supabase 项目

### 1.1 注册

- 访问 https://supabase.com
- 推荐使用 **GitHub 账号** 登录（国内可访问）
- 如果访问困难，可以试试镜像：https://supabase.com/dashboard（也支持国内区域）

### 1.2 创建项目

1. 点击 **"New Project"**
2. 填写：
   - **Name**: `fitcoach-agent`
   - **Database Password**: 设置一个强密码（**务必保存**，后续修改数据库需要）
   - **Region**: 推荐选择 **Singapore** 或 **Tokyo**（国内访问速度较快）
3. 点击 **"Create new project"**
4. 等待 1-2 分钟初始化完成

---

## 第 2 步：执行数据库 Schema

1. 进入项目控制台，点击左侧 **SQL Editor**
2. 点击 **"New query"**
3. 复制 `supabase/schema.sql` 的全部内容
4. 粘贴到编辑器，点击 **"Run"**
5. 看到 `Success. No rows returned` 即成功

> ⚠️ 如果脚本中有 trigger 创建失败提示，可以多次执行（脚本里都用了 `drop trigger if exists` 幂等处理）。

---

## 第 3 步：获取 API 密钥

1. 左侧菜单 → **Settings** → **API**
2. 复制以下两个值：
   - **Project URL**（形如 `https://xxxxxxxxxxxx.supabase.co`）
   - **anon public key**（一长串 `eyJhbGciOi...` 开头）

---

## 第 4 步：配置前端

打开 `web/js/supabase-config.js`，替换占位符：

```javascript
const SUPABASE_CONFIG = {
  url: 'https://xxxxxxxxxxxx.supabase.co',     // ← 替换这里
  anonKey: 'eyJhbGciOi...'                      // ← 替换这里
};
```

---

## 第 5 步：配置认证方式

### 5.1 启用邮箱密码认证

默认已启用。检查路径：**Authentication** → **Providers** → **Email** 应该是 ON。

### 5.2 配置邮件模板（魔法链接必需）

1. **Authentication** → **Email Templates**
2. 选择 **Magic Link** 模板
3. 设置：
   - Subject: `你的 FitCoach 登录链接`
   - Redirect URL: `http://localhost:8080/web/dashboard.html`（本地调试时）
4. 点击保存

### 5.3 关闭"必须邮箱验证"（开发期可选）

- **Authentication** → **Sign In/Up** → **Confirm email**
- 开发期建议设为 **OFF**，方便测试。生产环境设为 **ON**。

### 5.4 配置 Site URL（关键！）

- **Authentication** → **URL Configuration**
- **Site URL**: `http://localhost:8080`
- **Redirect URLs**: 添加
  - `http://localhost:8080/web/dashboard.html`
  - 生产环境再添加线上 URL

---

## 第 6 步：本地启动

### 方式 A：直接打开（最简单）

```bash
open web/index.html
```

⚠️ 部分浏览器对 `file://` 协议有限制，Supabase 调用可能失败。

### 方式 B：本地 HTTP 服务器（推荐）

进入项目目录后执行任一命令：

```bash
# Python 3（macOS 默认有）
cd fitness-coach-agent
python3 -m http.server 8080

# 或 Node.js
npx serve -p 8080
```

浏览器访问 http://localhost:8080/web/index.html

---

## 第 7 步：使用 Trae 调试

如果你用 **Trae** IDE：

1. **File → Open Folder** → 选择 `fitness-coach-agent/`
2. 左侧 Explorer 可看到完整项目结构
3. 在 `web/index.html` 或 `web/dashboard.html` 中按 **⌘ + I**（Mac）打开 AI 对话
4. 可以让 Trae 帮你：
   - 改 UI 样式
   - 增加表单字段
   - 接入新 API
   - 调试 Supabase 调用

---

## 第 8 步：测试场景

### 8.1 注册流程

1. 打开 `index.html`
2. 切到 **"注册"** Tab
3. 输入邮箱 + 密码 → 点击"创建账号"
4. 检查数据库：**Table Editor** → `user_profiles`，应自动新增一行
5. 检查 `auth.users` 表也会新增用户

### 8.2 密码登录

1. 用刚才注册的邮箱 + 密码
2. 切到 **"密码登录"** Tab
3. 成功跳转 `dashboard.html`

### 8.3 魔法链接

1. 切到 **"魔法链接"** Tab
2. 输入邮箱 → 发送
3. 查收邮件（开发期可在 **Authentication** → **Logs** 看到邮件内容）
4. 点击邮件链接 → 自动登录

### 8.4 实时订阅

1. 登录后保持 dashboard.html
2. 在 Supabase 控制台 → **Table Editor** → `training_records`
3. **Insert row** 手动加一条测试记录
4. dashboard 实时日志区会立即出现事件，统计数字自动更新

---

## 常见问题

### Q1：注册报 "Email rate limit exceeded"

Supabase 默认限制每小时 4 封邮件。开发期可以：
- **Authentication** → **Rate Limits** 调整
- 或使用真实邮箱测试

### Q2：报 "Invalid API key"

检查 `supabase-config.js`：
- `url` 必须以 `https://` 开头
- `anonKey` 是 **anon public**（不是 service_role，那个有最高权限，不能放前端）

### Q3：报 "CORS" 错误

Supabase 默认允许所有 origin。但如果你用 `file://` 打开部分浏览器会拦截，**请用 HTTP 服务器**。

### Q4：魔法链接邮件收不到

- 开发期在 **Authentication** → **Logs** 看发送日志
- 生产期需配置自定义 SMTP：Settings → **Auth** → **SMTP Settings**

### Q5：想修改数据库结构怎么办？

修改 `supabase/schema.sql`，在 SQL Editor 重新执行（脚本已写好 `drop if exists`）。

---

## 生产部署（待 V2 实施）

| 项 | 建议 |
|----|------|
| 静态托管 | Vercel / Netlify / 阿里云 OSS + CDN |
| 域名 | 备案后绑定自定义域名 |
| HTTPS | Cloudflare / Let's Encrypt |
| 数据库 | Supabase 免费版够用；高并发升级 Pro |

---

## 参考资料

- Supabase 官方文档：https://supabase.com/docs
- Supabase JS SDK：https://supabase.com/docs/reference/javascript
- Row Level Security：https://supabase.com/docs/guides/auth/row-level-security

---

## 拍照识别卡路里（V2 高级）配置

### 1. 创建 Storage Bucket

在 SQL Editor 执行 `supabase/storage-setup.sql`：
- 创建私有 bucket `diet-images`
- 策略：用户仅能读写自己 user_id 目录下的对象（路径 `{user_id}/{timestamp}.jpg`）

### 2. 部署 Edge Function（推荐方案 A，Key 不进前端）

```bash
# 安装 CLI 后（https://supabase.com/docs/guides/cli）
supabase login
supabase functions deploy recognize-food --project-ref <你的项目ref>

# 配置视觉模型 API Key（环境变量，不进前端）
# 默认使用通义千问 VL（DashScope OpenAI 兼容模式）
# 去 https://dashscope.aliyun.com/ 申请 API Key
supabase secrets set VISION_API_KEY=sk-xxxxxxxx

# 可选：切换其他视觉模型（默认已是通义千问 VL）
supabase secrets set VISION_API_BASE=https://dashscope.aliyuncs.com/compatible-mode/v1
supabase secrets set VISION_PROVIDER=dashscope
supabase secrets set VISION_MODEL=qwen-vl-plus   # 或 qwen-vl-max（更强）
```

> **为什么不用 DeepSeek？** DeepSeek API 目前只有文本模型（V3/R1），没有公开的视觉模型。
> 通义千问 VL 是国内首选的视觉理解模型，支持图片输入，OpenAI 兼容格式。

前端在 diet.html 点击「拍照识别」→ 压缩图片 → 上传 Storage →
调用 `recognize-food` → 返回 `{food_name, estimated_weight_g, confidence}` →
确认后写入 `diet_records`（`ai_recognized=true`）并记录 `diet_recognition_logs`。

---

## 生产上线部署指南

### 第 1 步：Supabase 控制台配置

#### 1.1 执行所有 SQL 脚本

在 Supabase Dashboard → **SQL Editor** 依次执行：
1. `supabase/schema.sql`（6 张表 + RLS + trigger）
2. `supabase/storage-setup.sql`（拍照识别的图片存储 bucket）

#### 1.2 配置 Auth 重定向地址（关键！）

进入 **Authentication** → **URL Configuration**：

- **Site URL**: `https://你的域名`（如 `https://fitcoach.vercel.app`）
- **Redirect URLs** 添加：
  - `https://你的域名/web/dashboard.html`（魔法链接回调）
  - `http://localhost:8080/web/dashboard.html`（本地调试保留）

#### 1.3 部署 Edge Function

```bash
# 安装 Supabase CLI
brew install supabase/tap/supabase

# 登录并关联项目
supabase login
cd fitness-coach-agent
supabase link --project-ref <你的项目ref>

# 部署函数
supabase functions deploy recognize-food

# 设置视觉模型 API Key（去 https://dashscope.aliyun.com 申请）
supabase secrets set VISION_API_KEY=sk-你的通义千问key
```

验证函数是否正常：
```bash
# 替换项目地址、公钥和已登录用户的 access token
curl -X POST https://YOUR-PROJECT-REF.supabase.co/functions/v1/recognize-food \
  -H "apikey: YOUR-ANON-OR-PUBLISHABLE-KEY" \
  -H "Authorization: Bearer USER-ACCESS-TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"imageBase64":"data:image/jpeg;base64,/9j/4AAQ..."}'
# 应返回 {"food_name":"...","estimated_weight_g":...}
```

### 第 2 步：前端静态托管（3 选 1）

#### 方案 A：Vercel（推荐，免费 + 自动 HTTPS + 国内可访问）

```bash
# 安装 Vercel CLI
npm i -g vercel

cd fitness-coach-agent

# 先注入配置（设置环境变量后运行）
export SUPABASE_URL=https://你的项目.supabase.co
export SUPABASE_ANON_KEY=eyJ你的anonKey
bash scripts/inject-config.sh

# 部署
vercel --prod
# 首次会问几个问题，全部回车即可（项目已配好 vercel.json）

# 部署完成后会得到一个 https://xxx.vercel.app 地址
```

#### 方案 B：Netlify

```bash
npm i -g netlify-cli

cd fitness-coach-agent
export SUPABASE_URL=https://你的项目.supabase.co
export SUPABASE_ANON_KEY=eyJ你的anonKey
bash scripts/inject-config.sh

netlify deploy --prod --dir=web
```

#### 方案 C：Cloudflare Pages

1. 在 Cloudflare Dashboard → Pages → Create project → Connect to Git
2. 构建命令：`bash scripts/inject-config.sh`
3. 环境变量设置：
   - `SUPABASE_URL` = 你的 Supabase URL
   - `SUPABASE_ANON_KEY` = 你的 anon key
4. 输出目录：`web`

### 第 3 步：更新 Supabase Auth 白名单

部署拿到域名后，回到 Supabase Dashboard：

**Authentication** → **URL Configuration** → 把 `https://你的域名/web/dashboard.html` 加入 **Redirect URLs**

### 第 4 步：验证上线

| 检查项 | 方法 |
|--------|------|
| 页面可访问 | 打开 `https://你的域名/` 看到登录页 |
| 注册/登录 | 注册一个账号 → 应跳转到 dashboard |
| 引导向导 | 首次进 dashboard 应弹 5 步向导 |
| 数据读写 | 填写画像 → 保存成功 |
| 训练计划 | plan.html → 生成计划 |
| 打卡 | workout.html → 记录一组训练 |
| 饮食记录 | diet.html → 搜索食物 → 添加 |
| 拍照识别 | diet.html → 拍照 → 看到识别结果 |

---

## 常见上线问题

### Q1：魔法链接邮件点开后报 "redirect failed"

检查 Supabase Auth Redirect URLs 是否包含你的生产域名。

### Q2：拍照识别报 "Function not found"

Edge Function 未部署或名称不对。运行 `supabase functions list` 确认。

### Q3：拍照识别报 "VISION_API_KEY 未配置"

忘了执行 `supabase secrets set VISION_API_KEY=sk-xxx`。

### Q4：页面能打开但数据加载失败

检查 `web/js/supabase-config.js` 是否已注入正确的 URL 和 Key（不是占位符）。

### Q5：国内访问 Vercel 慢

Vercel 在国内部分地区可能不稳定，替代方案：
- Cloudflare Pages（国内通常更快）
- 阿里云 OSS + CDN（需 ICP 备案，但国内最快）
- Vercel + 自定义域名（绑定后走 Cloudflare CDN）
