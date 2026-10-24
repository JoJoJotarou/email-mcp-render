# 在 Render 免费版上部署 email-mcp（远程 MCP，Streamable HTTP）

本仓库把 [codefuturist/email-mcp](https://github.com/codefuturist/email-mcp) v0.6.0 官方镜像包了一层，
让它能在 **一个 Render 免费 Web Service** 上运行，供 AI 智能体通过 MCP Streamable HTTP 远程连接，
聚合 QQ 邮箱、163/126 邮箱、公司邮箱和 Gmail。

- MCP 地址：`https://<服务名>.onrender.com/mcp`（必须带 `Authorization: Bearer <令牌>`）
- 健康检查/保活地址：`https://<服务名>.onrender.com/healthz`（无需令牌，仅 GET，返回 `{"status":"ok"}`）
- 默认 **只读**：不能发信、不能删信、不能移动/改标签（写工具全部不注册）。

## 仓库里需要有的文件

| 文件 | 作用 |
|---|---|
| `Dockerfile` | `FROM ghcr.io/codefuturist/email-mcp:0.6.0`，加入启动脚本 |
| `render-entrypoint.sh` | 启动脚本：检查令牌、生成 config.toml、监听 `0.0.0.0:$PORT` |
| `render.yaml` | Render Blueprint（可选，用 Blueprint 方式创建时需要） |
| `config.example.toml` | 配置模板（只含占位符，**不要**写真实密码） |
| `make-config-b64.sh` | 把你本地的 config.toml 转成一行 base64 |
| `.gitignore` / `.dockerignore` | 防止误提交真实配置 |
| `README-zh.md` | 本说明 |

> ⚠️ 真实的 `config.toml`、授权码、令牌 **永远不要提交到 GitHub**。它们只放在 Render 的环境变量里。

---

## 第 1 步：准备各邮箱的授权码（不是登录密码）

| 邮箱 | 操作 | IMAP / SMTP |
|---|---|---|
| QQ 邮箱 | 网页版 → 设置 → 账号 → 开启「IMAP/SMTP 服务」→ 生成**授权码** | imap.qq.com:993 / smtp.qq.com:465 |
| 163 邮箱 | 设置 → POP3/SMTP/IMAP → 开启 IMAP/SMTP → 新增**授权密码** | imap.163.com:993 / smtp.163.com:465 |
| 126 邮箱 | 同 163 | imap.126.com:993 / smtp.126.com:465 |
| Gmail | Google 账号先开「两步验证」→ 安全性 → **应用专用密码**（16 位） | imap.gmail.com:993 / smtp.gmail.com:465 |
| 公司邮箱 | 问 IT 要 IMAP/SMTP 地址、端口、是否需要单独的客户端密码 | 视情况 |
| Outlook/Hotmail | 微软已禁用密码登录，只能 OAuth2，**暂不配置** | — |

网易（163/126）要求客户端发送 IMAP `ID` 命令，否则报 “Unsafe Login”。本程序使用的 imapflow 库会自动发送，无需额外设置。

## 第 2 步：准备 config.toml（在你自己电脑上）

1. 复制 `config.example.toml` 为 `config.toml`（这个文件**不要提交**）。
2. 把每个账户的 `email` 改成你的真实邮箱地址；用不到的账户整段删掉。
3. 密码一栏保持 `password = "env:QQ_MAIL_AUTH_CODE"` 这种写法 —— 程序会在启动时从同名环境变量读取，配置文件里就没有任何密码。
4. 转成一行 base64：
   - macOS / Linux：`./make-config-b64.sh config.toml`
   - Windows PowerShell：`[Convert]::ToBase64String([IO.File]::ReadAllBytes("config.toml"))`
   
   复制输出的那一长串，下一步要用。

## 第 3 步：生成访问令牌（Bearer Token）

至少 32 个字符的随机串，例如：
- macOS / Linux：`openssl rand -hex 32`
- Windows PowerShell：`-join ((1..32) | % { '{0:x2}' -f (Get-Random -Max 256) })`

（用 Blueprint 方式创建时 Render 会自动生成，可以跳过。）

## 第 4 步：把本仓库放到你自己的 GitHub

1. 登录 GitHub → New repository（公开或私有都可以；本仓库不含秘密）。
2. 上传上表中的文件。

## 第 5 步：在 Render 上创建服务

1. 打开 https://render.com → **Get Started**，建议直接用 GitHub 账号登录（免费版无需信用卡）。
2. 二选一：

**方式 A：普通 Web Service（推荐，最直观）**
- Dashboard → **New +** → **Web Service** → 选中你的 GitHub 仓库（私有仓库需先授权 Render 访问）。
- Language / Runtime：**Docker**
- Region：**Singapore**（离国内最近）
- Instance Type：**Free**
- Advanced → Health Check Path：`/healthz`
- Docker Command：留空

**方式 B：Blueprint**
- Dashboard → **New +** → **Blueprint** → 选仓库，Render 读取 `render.yaml` 自动创建。

3. 环境变量（Environment）里添加：

| Key | Value |
|---|---|
| `EMAIL_MCP_HTTP_TOKEN` | 第 3 步的令牌（Blueprint 会自动生成） |
| `EMAIL_MCP_CONFIG_TOML_B64` | 第 2 步的 base64 串 |
| `QQ_MAIL_AUTH_CODE` | QQ 授权码 |
| `NETEASE163_AUTH_CODE` | 163 授权密码 |
| `NETEASE126_AUTH_CODE` | 126 授权密码 |
| `GMAIL_APP_PASSWORD` | Gmail 应用专用密码 |
| `WORK_MAIL_PASSWORD` | 公司邮箱密码 |

> 备选：不设 `EMAIL_MCP_CONFIG_TOML_B64`，而在 Environment → **Secret Files** 新建文件名 `config.toml`，内容粘贴整份配置（会挂载到 `/etc/secrets/config.toml`，启动脚本自动读取）。
>
> 不要同时设置 `MCP_EMAIL_ADDRESS` / `MCP_EMAIL_IMAP_HOST` 等单账户变量，否则程序会忽略 config.toml。

4. 点 **Create Web Service / Deploy**。几分钟后日志里出现
   `Streamable HTTP on http://0.0.0.0:10000/mcp — bearer-token auth ON` 即成功。
   若某个邮箱密码错误，日志会出现 `[watcher] IDLE connect failed for <账户>`，其他账户不受影响。

## 第 6 步：得到的地址 & 如何连接

- MCP 端点：`https://<服务名>.onrender.com/mcp`
- 请求头：`Authorization: Bearer <你的令牌>`

常见 MCP 客户端配置示例（JSON）：
```json
{
  "mcpServers": {
    "email": {
      "type": "http",
      "url": "https://<服务名>.onrender.com/mcp",
      "headers": { "Authorization": "Bearer <你的令牌>" }
    }
  }
}
```
自测：
```bash
curl https://<服务名>.onrender.com/healthz                     # 200 {"status":"ok"}
curl -X POST https://<服务名>.onrender.com/mcp -d '{}'          # 401 unauthorized（说明鉴权生效）
```

## 第 7 步：保活（免费实例 15 分钟无访问会休眠）

用外部定时器每 10 分钟 **GET**（不要用 HEAD，HEAD 会返回 404）：
`https://<服务名>.onrender.com/healthz`
例如 cron-job.org（免费）。注意：IMAP 的出站连接**不会**阻止休眠，只有入站 HTTP 请求才算。

免费额度每月 750 实例小时，一个服务 24×31=744 小时，刚好够用；不要再开第二个免费服务一直在线。

## 功能说明与安全默认值

- **只读模式**（`read_only = true`）：只暴露读取类工具（列出/搜索/阅读邮件、线程、附件下载、统计、验证码提取等，共约 31 个）。发信、回复、转发、移动、删除、批量删除、删文件夹/标签、草稿、定时发送全部不可用。
  v0.6.0 **没有**「发信前确认」或「允许发信但禁止删除」的细粒度开关；改成 `read_only = false` 会同时开放发信和删除，请谨慎。
- **IDLE 实时监听**（`[settings.watcher]`）：已开启，每个账户一条长连接。
- **验证码捕获**：`get_verification_code` 工具随时可用；剪贴板/桌面通知在服务器上无意义，已关闭。
- **Webhook 提醒**：把 `webhook_url` 设为如 `https://ntfy.sh/<随机主题>`，新邮件到达时会推送一条 JSON（账户、发件人、主题）到手机 ntfy App。飞书/钉钉/企业微信机器人需要特定格式，不能直接用。
- **缓存**：本地 SQLite 镜像放在临时磁盘，重启/重新部署后会重新同步（已限制为最近 30 天、每邮箱 100 封正文）。
- 免费实例重启后，定时发送队列等状态会丢失（只读模式下不涉及）。

## 常见问题

- **QQ/网易提示异地登录或拒绝登录**：Render 服务器在海外（新加坡），首次登录可能触发安全提醒，在邮箱网页/手机端确认即可；必要时重新生成授权码。
- **403 Invalid Host**：如果你给服务绑定了自定义域名，加环境变量 `EMAIL_MCP_HTTP_ALLOWED_HOSTS=你的域名`。
- **令牌泄露**：在 Render 修改 `EMAIL_MCP_HTTP_TOKEN` 后重新部署即可作废旧令牌。
