window.__ModuleLoader__.load({
	id: "dsh-pencil",
	platform: "web",
	factory: (require) => {
		var module = { exports: {} };
		var exports = module.exports;
		Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });

		var React = require("react");

		/** Host 路由：GET 取可编辑消息，POST 执行编辑（生成新版本会话）。 */
		var PENCIL_PATH = "/pencil";

		/** 只依赖确实存在的客户端服务：slots 与 sessions。 */
		var inject = ["slots", "sessions"];

		var COLORS = {
			line: "var(--dsw-alias-border-l1, rgba(127,127,127,.28))",
			bg: "var(--dsw-alias-bg-layer-2, #1b1d22)",
			fg: "var(--dsw-alias-label-primary, #e8eaed)",
			dim: "var(--dsw-alias-label-secondary, #9aa0a6)",
			accent: "var(--dsw-alias-brand-primary, #ffb464)",
		};

		function PencilGlyph(size) {
			return React.createElement(
				"svg",
				{ width: size, height: size, viewBox: "0 0 16 16", fill: "none", "aria-hidden": "true" },
				React.createElement("path", {
					d: "M11.2 1.8a1.6 1.6 0 0 1 2.3 0l.7.7a1.6 1.6 0 0 1 0 2.3l-7.4 7.4-3.4.9.9-3.4 6.9-7.9Z",
					stroke: "currentColor",
					strokeWidth: "1.3",
					strokeLinejoin: "round",
				}),
			);
		}

		function errorText(error) {
			return error && error.message ? String(error.message) : String(error);
		}

		/** 消息底部的铅笔按钮 + 编辑浮层。 */
		function PencilButton(props) {
			var sessionId = props.sessionId;
			var messageId = props.messageId;
			var openSession = props.openSession;

			var openState = React.useState(false);
			var open = openState[0];
			var setOpen = openState[1];
			var textState = React.useState("");
			var text = textState[0];
			var setText = textState[1];
			var targetState = React.useState(null);
			var target = targetState[0];
			var setTarget = targetState[1];
			var busyState = React.useState(false);
			var busy = busyState[0];
			var setBusy = busyState[1];
			var errorState = React.useState(null);
			var error = errorState[0];
			var setError = errorState[1];
			var newIdState = React.useState(null);
			var newId = newIdState[0];
			var setNewId = newIdState[1];
			var hoverState = React.useState(false);
			var hover = hoverState[0];
			var setHover = hoverState[1];

			var close = function () {
				setOpen(false);
				setError(null);
				setNewId(null);
				setText("");
				setTarget(null);
			};

			var startEdit = function () {
				setOpen(true);
				setBusy(true);
				setError(null);
				setNewId(null);
				fetch(PENCIL_PATH + "?sessionId=" + encodeURIComponent(String(sessionId)), {
					headers: { accept: "application/json" },
				})
					.then(function (response) {
						return response.json().then(function (data) {
							if (!response.ok) throw new Error(data && data.error ? data.error : "HTTP " + response.status);
							return data;
						});
					})
					.then(function (data) {
						var messages = data && Array.isArray(data.messages) ? data.messages : [];
						var responses = messages.filter(function (item) {
							return item && item.kind === "assistant.response";
						});
						var hit = null;
						if (messageId) {
							hit = responses.find(function (item) {
								return item.messageId === messageId;
							});
						}
						if (!hit && responses.length > 0) hit = responses[responses.length - 1];
						if (!hit) throw new Error("这条消息不在可编辑范围内（流式中、或历史已被改写）");
						setTarget(hit);
						setText(typeof hit.text === "string" ? hit.text : "");
					})
					.catch(function (e) {
						setError(errorText(e));
					})
					.finally(function () {
						setBusy(false);
					});
			};

			var save = function () {
				if (!target || !text.trim()) return;
				setBusy(true);
				setError(null);
				fetch(PENCIL_PATH, {
					method: "POST",
					headers: { "content-type": "application/json" },
					body: JSON.stringify({
						action: "edit",
						sessionId: sessionId,
						eventSeq: target.eventSeq,
						blockIndex: target.blockIndex,
						text: text,
						cascade: "truncate",
					}),
				})
					.then(function (response) {
						return response.json().then(function (data) {
							if (!response.ok) throw new Error(data && data.error ? data.error : "HTTP " + response.status);
							return data;
						});
					})
					.then(function (data) {
						var id = data && (data.sessionId || data.id);
						if (typeof id === "string" && id.length > 0) setNewId(id);
						else setNewId("done");
					})
					.catch(function (e) {
						setError(errorText(e));
					})
					.finally(function () {
						setBusy(false);
					});
			};

			var button = React.createElement(
				"button",
				{
					type: "button",
					title: "编辑这条回复",
					"aria-label": "编辑这条回复",
					onMouseEnter: function () {
						setHover(true);
					},
					onMouseLeave: function () {
						setHover(false);
					},
					onClick: startEdit,
					style: {
						display: "inline-flex",
						alignItems: "center",
						justifyContent: "center",
						width: 24,
						height: 24,
						borderRadius: 6,
						border: "none",
						cursor: "pointer",
						color: hover ? COLORS.accent : COLORS.dim,
						background: hover ? "rgba(127,127,127,.14)" : "transparent",
						opacity: hover ? 1 : 0.55,
						transition: "opacity .12s ease, color .12s ease, background .12s ease",
						padding: 0,
					},
				},
				PencilGlyph(14),
			);

			if (!open) return button;

			var body;
			if (newId) {
				body = React.createElement(
					"div",
					{ style: { display: "flex", flexDirection: "column", gap: 12 } },
					React.createElement("div", { style: { color: COLORS.fg, fontSize: 13 } }, "已按编辑内容生成新版本会话。"),
					React.createElement(
						"div",
						{ style: { display: "flex", gap: 8, justifyContent: "flex-end" } },
						React.createElement(
							"button",
							{
								type: "button",
								onClick: function () {
									if (newId !== "done" && typeof openSession === "function") {
										try {
											openSession(newId);
										} catch (e) {
											/* 打开失败时保持当前会话，不影响版本已创建的事实 */
										}
									}
									close();
								},
								style: {
									padding: "6px 14px",
									borderRadius: 8,
									border: "none",
									cursor: "pointer",
									background: COLORS.accent,
									color: "#1a1207",
									fontSize: 13,
									fontWeight: 600,
								},
							},
							newId !== "done" ? "打开新版本" : "知道了",
						),
					),
				);
			} else {
				body = React.createElement(
					"div",
					{ style: { display: "flex", flexDirection: "column", gap: 10 } },
					React.createElement("textarea", {
						value: text,
						onChange: function (event) {
							setText(event.target.value);
						},
						spellCheck: false,
						disabled: busy,
						placeholder: busy ? "正在读取原文…" : "编辑这条回复的正文",
						style: {
							width: "100%",
							minHeight: 180,
							maxHeight: "46vh",
							resize: "vertical",
							padding: 10,
							borderRadius: 8,
							border: "1px solid " + COLORS.line,
							background: "transparent",
							color: COLORS.fg,
							fontSize: 13,
							lineHeight: 1.6,
							boxSizing: "border-box",
							outline: "none",
							fontFamily: "inherit",
						},
					}),
					React.createElement(
						"div",
						{ style: { fontSize: 12, color: COLORS.dim } },
						"保存会从这条回复所在回合分叉出一个新版本会话，原会话保留。",
					),
					error
						? React.createElement("div", { style: { fontSize: 12, color: "#ff6b6b", wordBreak: "break-word" } }, error)
						: null,
					React.createElement(
						"div",
						{ style: { display: "flex", gap: 8, justifyContent: "flex-end" } },
						React.createElement(
							"button",
							{
								type: "button",
								onClick: close,
								disabled: busy,
								style: {
									padding: "6px 14px",
									borderRadius: 8,
									border: "1px solid " + COLORS.line,
									background: "transparent",
									color: COLORS.fg,
									cursor: busy ? "default" : "pointer",
									fontSize: 13,
								},
							},
							"取消",
						),
						React.createElement(
							"button",
							{
								type: "button",
								onClick: save,
								disabled: busy || !target,
								style: {
									padding: "6px 14px",
									borderRadius: 8,
									border: "none",
									cursor: busy || !target ? "default" : "pointer",
									background: COLORS.accent,
									color: "#1a1207",
									fontSize: 13,
									fontWeight: 600,
									opacity: busy || !target ? 0.5 : 1,
								},
							},
							busy ? "处理中…" : "保存并分叉",
						),
					),
				);
			}

			var overlay = React.createElement(
				"div",
				{
					onClick: function (event) {
						if (event.target === event.currentTarget) close();
					},
					style: {
						position: "fixed",
						inset: 0,
						zIndex: 60,
						display: "flex",
						alignItems: "center",
						justifyContent: "center",
						background: "rgba(0,0,0,.45)",
						padding: 24,
					},
				},
				React.createElement(
					"div",
					{
						style: {
							width: "min(640px, 92vw)",
							maxHeight: "82vh",
							overflow: "auto",
							padding: 18,
							borderRadius: 12,
							border: "1px solid " + COLORS.line,
							background: COLORS.bg,
							boxShadow: "0 18px 48px rgba(0,0,0,.45)",
							display: "flex",
							flexDirection: "column",
							gap: 12,
							boxSizing: "border-box",
						},
					},
					React.createElement(
						"div",
						{ style: { fontSize: 14, fontWeight: 600, color: COLORS.fg } },
						"编辑回复",
					),
					body,
				),
			);

			return React.createElement(React.Fragment, null, button, overlay);
		}

		function apply(ctx) {
			var disposers = [];

			var dispose = ctx.slots.inject("conversation.chat.assistant-actions", function () {
				return ctx.slots.register(
					{
						name: "conversation.chat.assistant-actions",
						id: "dsh-pencil-edit",
						order: 20,
						inject: function () {
							return {
								openSession: function (id) {
									try {
										ctx.sessions.open(id);
									} catch (e) {
										/* 打开失败不抛出：版本已经创建，用户可手动切换 */
									}
								},
							};
						},
					},
					PencilButton,
				);
			});
			if (typeof dispose === "function") disposers.push(dispose);

			ctx.effect(function () {
				return function () {
					for (var i = 0; i < disposers.length; i += 1) {
						try {
							disposers[i]();
						} catch (e) {
							/* 卸载期忽略 */
						}
					}
					disposers.length = 0;
				};
			}, "dsh-pencil: slot contributions");

			console.info("[dsh-pencil] apply ready");
		}

		exports.apply = apply;
		exports.inject = inject;
		return module.exports;
	},
});
