# 来源与改编说明

本插件不是从零发明，`lib/index.mjs`（host 半）是**在 `dsh-message-edit@0.2.3` 的 host 实现基础上改编**而来。作者与许可如下：

| 项目 | 值 |
|---|---|
| 上游 | [Moeblack/dsh-message-edit](https://github.com/Moeblack/dsh-message-edit) |
| 上游版本 | 0.2.3（npm 最新） |
| 上游许可 | MIT |
| 改编范围 | `lib/index.mjs` |
| 全新编写 | `lib/client.js`、安装脚本、README |

## 为什么改编而不是重写

上游的 host 已经把「把一次编辑变成一个可分叉的版本会话」这件事做完了：版本效果对（`message-edit/version`）、逆链（`inverse.sessionId`）、`agents.create({seed})` 事务缝、失败回滚。这些是几万字的边界处理，重写只会引入新 bug。

上游真正坏掉的是**客户端**：它按 0.1.x 的契约写，在 0.2.x 上加载失败（详见下）。所以本项目的做法是——**保留 host，重写 client**。

## 对 host 的改动（全部可审计）

| 改动 | 原因 |
|---|---|
| 插件名 `message-edit` → `dsh-pencil` | 避免与上游插件同时安装时注册冲突 |
| 路由 `/message-edit` → `/pencil` | 同上 |
| `editableMessages()` 的 assistant 条目补 `messageId` | 客户端只能从 slot props 拿到 `messageId`，没有它无法精确匹配到是哪条回复 |
| 新增 `eventsOf(session)`，替换三处 `session.events` 读取 | 0.1.x 用 `session.events`；0.2.x 事件在 `session.log`，对外只有 `snapshotEvents()`。原实现在 0.2.x 取到 `undefined`，导致版本树永远是空的（报「当前版本不在版本树中」） |
| 版本树报错补诊断数字 | 出错时能直接看出是 `currentIndex`、`logs.length` 还是 `lineage.length` 为空 |

## 上游 client 为什么不能用

上游 `client.js` 有三处 0.1.x 假设，在 DSH Desktop 0.11.1 / `@deepseek-ai/dsh` 0.2.0-rc.2 上逐条撞墙：

1. `require("@deepseek-ai/dsh-client-runtime/client")` —— 该包在 0.2.x 已不存在，客户端模块表只有 `react`、`react-dom`、`@deepseek-ai/cordis`、`dsh-client-store`、`dsh-client-ui-slots`、`dsh-client-ui-primitives`、`dsh-client-ui-dockkit` 等种子词
2. `inject = ["slots", "conversation", "connection", "sessions"]` —— 0.2.x 的 UI 服务改名（`conversation` → `uiConversation`），不存在的依赖会让 fiber 永久 pending，`apply()` 静默不执行
3. 裸 `ctx.slots.register(...)` —— 0.2.x 要求先 `ctx.slots.inject(slot, () => register(...))` 等 slot 被父条目声明，否则加载期校验直接拒绝

`lib/client.js` 按 0.2.x 契约重写，因此只依赖 `react` 与 `slots`/`sessions` 两个服务。

## 上游许可义务

分发本插件时，`lib/index.mjs` 属于上游的衍生作品，需保留上游的 MIT 声明与作者署名。本项目已在 `LICENSE` 末尾与本文档中声明。若你要二次分发，请同样保留。
