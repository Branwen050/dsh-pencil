# dsh-pencil

**中文** | [English](README.en.md)

dsh-pencil 是 DSH（DeepSeek Harness）桌面端的客户端插件。DSH 的会话日志采用 append-only 机制，无法原地修改已生成的模型回复。该插件在助手回复底部添加编辑按钮，用户修改回复正文并保存后，会从当前回合分叉（fork）出一个新的会话版本，并将修改后的文本写入新会话历史，原会话则完整保留。

## 功能

- 编辑入口：在助手回复操作栏注入铅笔按钮，点击后弹出编辑浮层并预填当前回复的正文。
- 版本分叉：保存修改后，以该回复所在回合为界分叉生成新 session，新 session 中该条回复更新为编辑后的内容，模型后续对话基于新文本继续生成。
- 历史保留：原 session 完整保留，可随时切回。

## 结构

项目由 client 交互层与 host 服务层组成：

```text
lib/index.mjs     host 插件：提供 HTTP 路由与会话版本分叉逻辑
lib/client.js     client 插件：注入铅笔按钮与编辑浮层交互界面
cordis.patch.yml  host 插件挂载配置
```

## 安装

### 本地开发安装

执行安装脚本完成依赖链接与 bundle 注册：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\31319\Desktop\dsh-pencil\install.ps1
```

该脚本等价于执行以下三个手动步骤：

使用 Desktop 内置的 pnpm shim 以 link 方式添加依赖：

```powershell
$profile = "$env:APPDATA\dsh-desktop\harness\profiles\web"
& "$env:APPDATA\dsh-desktop\harness\.desktop-bin\pnpm.cmd" add "link:C:\Users\31319\Desktop\dsh-pencil" --prefer-offline
```

以 `pnpm add "link:..."` 方式安装后，`node_modules\dsh-pencil` 会创建为指向源码目录的 junction，后续修改源码只需重启应用即可生效，无需重新安装。执行时必须调用 `.desktop-bin\pnpm.cmd`。PATH 里的 `node` 是 DSH Desktop 自带的 Electron node，直接用它跑 pnpm 会出现执行异常。

运行脚本将插件登记到 profile 的 bundle 清单：

```powershell
node C:\Users\31319\Desktop\dsh-pencil\add-bundle.mjs
```

pnpm 仅负责处理依赖声明（写入 `dependencies`），不会修改 `dsh.profile.bundles` 字段。DSH 依据 `dsh.profile.bundles` 加载插件，缺少此步骤插件不会被加载。

彻底退出 DSH Desktop 后重新启动：

在系统托盘右键退出 DSH Desktop 进程，随后重新打开应用。

安装完成后的文件变动位置如下：

| 位置 | 内容 |
| --------------------------------------------------- | ---------------------------------------- |
| `profiles\web\package.json` → `dependencies`        | `"dsh-pencil": "link:C:/.../dsh-pencil"` |
| `profiles\web\package.json` → `dsh.profile.bundles` | `"dsh-pencil"`                           |
| `profiles\web\pnpm-lock.yaml`                       | link 记录                                  |
| `profiles\web\node_modules\dsh-pencil`              | junction → 源码目录                          |

### 从 npm 安装

包已发布到 npm，安装时给出包名即可（省略版本号则取最新）：

```powershell
$profile = "$env:APPDATA\dsh-desktop\harness\profiles\web"
& "$env:APPDATA\dsh-desktop\harness\.desktop-bin\pnpm.cmd" --dir $profile add dsh-pencil
node "$profile\node_modules\dsh-pencil\add-bundle.mjs"
```

需要锁死版本时，在包名后加版本号：

```powershell
& "$env:APPDATA\dsh-desktop\harness\.desktop-bin\pnpm.cmd" --dir $profile add dsh-pencil@0.1.2
```

### 直接从 GitHub 安装

使用 Desktop 内置 pnpm 安装 GitHub 仓库并注册 bundle：

```powershell
$profile = "$env:APPDATA\dsh-desktop\harness\profiles\web"
& "$env:APPDATA\dsh-desktop\harness\.desktop-bin\pnpm.cmd" --dir $profile add "github:Branwen050/dsh-pencil"
node "$profile\node_modules\dsh-pencil\add-bundle.mjs"
```

## 卸载

执行卸载脚本完成清理：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\31319\Desktop\dsh-pencil\uninstall.ps1
```

该脚本等价于执行以下卸载与清理命令：

```powershell
$profile = "$env:APPDATA\dsh-desktop\harness\profiles\web"
& "$env:APPDATA\dsh-desktop\harness\.desktop-bin\pnpm.cmd" remove dsh-pencil
node C:\Users\31319\Desktop\dsh-pencil\remove-bundle.mjs dsh-pencil
```

卸载时必须连带删除 `node_modules` 下的对应目录。DSH Desktop 在启动时会依据 `node_modules` 物理目录自动补登记插件，若仅从 `package.json` 清单中移除而残留物理目录，应用下次启动时仍会被自动写回并加载。

## 技术实现与宿主契约

### 架构设计：为什么 host 复用上游、client 重写

本项目的 host 实现复用了上游 `dsh-message-edit` 经过验证的版本分叉逻辑，包括版本状态标记、逆链记录、`agents.create({seed})` 事务以及失败回滚机制。在此基础上，本项目对 host 进行了适配：
- 避免命名冲突：插件名调整为 `dsh-pencil`，路由调整为 `/pencil`。
- 补充消息标识：在 `editableMessages()` 的 assistant 条目中补充 `messageId`，便于 client 依据 slot props 进行精确匹配。
- 适配 0.2.x 事件日志：0.1.x 使用 `session.events`，而 0.2.x 的事件存储于 `session.log`，通过封装 `eventsOf(session)` 调用 `snapshotEvents()` 读取。

client 实现则完全基于 DSH 0.2.x 契约全新编写，解决了上游在 0.2.x 环境下无法加载的问题。

### 0.2.x 契约关键技术事实

- 模块种子词限制：0.2.x 不再提供 `@deepseek-ai/dsh-client-runtime`（含其 `/client` 子路径），客户端模块表只放行 `react`、`react-dom`、`@deepseek-ai/cordis`、`dsh-client-store`、`dsh-client-ui-slots`、`dsh-client-ui-primitives` 等固定种子词。本插件 client 只引入 `react`。
- inject 服务名变更：UI 服务中的 `conversation` 在 0.2.x 中已更名为 `uiConversation`。若声明不存在的依赖服务，会导致 fiber 永久处于 pending 状态，阻断插件初始化。本插件仅注入 `slots` 与 `sessions`。
- 注册时序包裹：0.2.x 要求先通过 `ctx.slots.inject` 等待 slot 就绪再执行注册，即 `ctx.slots.inject("conversation.chat.assistant-actions", () => ctx.slots.register(...))`。未通过 `ctx.slots.inject` 包裹的直接 `register` 调用会被加载期校验拒绝。

### 服务与路由依赖

- client 依赖服务：`slots`、`sessions`
- host 依赖服务：`sessions`、`agents`、`sessionPersistence`、`sessionQuery`、`workspaceRegistry`、`webServer`
- host 路由：`GET /pencil?sessionId=` 用于获取可编辑消息，`POST /pencil` 用于提交 `edit` / `reroll` / `retry` 操作

## 已知边界

- 只暴露助手回复正文；`reasoning` 块与用户消息暂未开放编辑入口
- 编辑产生的是新会话，不是原地改写历史——DSH 的会话日志 append-only，原地改没有合法路径
- 编辑会截断该回合之后的内容（`cascade: "truncate"`）
- 失败模式受控：客户端只占一个 slot 条目，host 异常统一转成 JSON 错误；不会把 App 拖进安全模式

## 排查

检查插件是否在 Desktop 日志中成功加载：

```powershell
Select-String "$env:APPDATA\dsh-desktop\logs\harness.log" -Pattern "dsh-pencil"
```

检查 host 路由是否成功注册（需 host 六个依赖服务均就绪）：

```powershell
Select-String "$env:APPDATA\dsh-desktop\logs\harness.log" -Pattern "/pencil"
```

## 署名与许可

- `lib/index.mjs` 改编自 [Moeblack/dsh-message-edit](https://github.com/Moeblack/dsh-message-edit)（MIT 许可）。
- `lib/client.js` 为原创实现。

分发与使用本插件时，请保留 `LICENSE` 以及 [CREDITS.md](CREDITS.md) 中的上游署名与改动审计记录。
