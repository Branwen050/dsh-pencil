# dsh-pencil

[中文](README.md) | **English**

dsh-pencil is a client plugin for the DSH (DeepSeek Harness) desktop application. DeepSeek Harness is an extensible desktop client for DeepSeek AI models that structures conversation histories as append-only event logs. Because past assistant turns cannot be overwritten in place, editing requires branching the session. dsh-pencil injects an edit button beneath each assistant response; saving your edits forks a new session version from that point in time, preserving the original conversation log in its entirety.

## Features

- **Inline Edit Entrypoint**: Injects a pencil icon into the assistant action bar. Clicking the button opens an editing dialog pre-populated with the full text of that response.
- **Session Version Forking**: Saving an edit creates a new session branching from that turn, updates the target response with the edited text, and allows the model to continue generating from the new prompt context.
- **Full History Preservation**: The original session remains intact and accessible in the session list for seamless switching.

## Project Structure

The plugin is partitioned into a client interface layer and a host service layer:

- `lib/index.mjs` - Host plugin: provides HTTP endpoints and session branching/forking logic.
- `lib/client.js` - Client plugin: injects the pencil button and edit dialog into the desktop interface.
- `cordis.patch.yml` - Cordis configuration patch for mounting the host plugin.

## Installation

### Local Development Installation

Run the automated installation script to link dependencies and register the bundle into your profile:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\31319\Desktop\dsh-pencil\install.ps1
```

Running this script executes the following three manual steps:

1. Link the local repository using Desktop's bundled pnpm shim:

```powershell
$profile = "$env:APPDATA\dsh-desktop\harness\profiles\web"
& "$env:APPDATA\dsh-desktop\harness\.desktop-bin\pnpm.cmd" add "link:C:\Users\31319\Desktop\dsh-pencil" --prefer-offline
```

Executing `pnpm add "link:..."` creates an NTFS junction at `node_modules\dsh-pencil` pointing to the source directory. Subsequent source changes take effect upon restarting the application without requiring reinstallation. You must invoke `.desktop-bin\pnpm.cmd`; the `node` binary in the system `PATH` is Desktop's embedded Electron Node runtime, which causes execution failures when invoked directly as a package manager.

2. Register the plugin in the profile bundle manifest:

```powershell
node C:\Users\31319\Desktop\dsh-pencil\add-bundle.mjs
```

pnpm only writes dependency declarations to the `dependencies` field of `package.json`. DSH loads plugins based on the `dsh.profile.bundles` array; omitting this step prevents DSH from mounting the plugin at startup.

3. Fully exit and relaunch DSH Desktop:

Right-click the DSH Desktop tray icon in the Windows notification area, select Exit to terminate the process, and launch the application again.

After installation, the profile environment contains the following changes:

- `profiles\web\package.json` (`dependencies`): `"dsh-pencil": "link:C:/.../dsh-pencil"`
- `profiles\web\package.json` (`dsh.profile.bundles`): `"dsh-pencil"`
- `profiles\web\pnpm-lock.yaml`: link resolution record
- `profiles\web\node_modules\dsh-pencil`: NTFS junction pointing to the source directory

### Installing from npm

> Not published to npm yet — use the GitHub installation below instead.

Install the published npm package into the profile directory and register its bundle entry:

```powershell
$profile = "$env:APPDATA\dsh-desktop\harness\profiles\web"
& "$env:APPDATA\dsh-desktop\harness\.desktop-bin\pnpm.cmd" --dir $profile add dsh-pencil
node "$profile\node_modules\dsh-pencil\add-bundle.mjs"
```

### Installing from GitHub

Install the repository from GitHub into the profile directory and register its bundle entry:

```powershell
$profile = "$env:APPDATA\dsh-desktop\harness\profiles\web"
& "$env:APPDATA\dsh-desktop\harness\.desktop-bin\pnpm.cmd" --dir $profile add "github:Branwen050/dsh-pencil"
node "$profile\node_modules\dsh-pencil\add-bundle.mjs"
```

## Uninstallation

Run the automated uninstallation script to remove the package and clean up bundle registrations:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\31319\Desktop\dsh-pencil\uninstall.ps1
```

Remove the package dependency and deregister the bundle entry manually:

```powershell
$profile = "$env:APPDATA\dsh-desktop\harness\profiles\web"
& "$env:APPDATA\dsh-desktop\harness\.desktop-bin\pnpm.cmd" remove dsh-pencil
node C:\Users\31319\Desktop\dsh-pencil\remove-bundle.mjs dsh-pencil
```

When uninstalling, also delete the `node_modules\dsh-pencil` directory. DSH Desktop inspects physical directories under `node_modules` during startup and automatically registers discovered plugins back into `package.json`. If you remove the entry from `package.json` while the physical directory remains on disk, Desktop restores the entry and reloads the plugin on the next launch.

## Technical Implementation and Host Contracts

### Architecture: Reusing the Host and Rewriting the Client

The host implementation adapts proven version-forking logic from upstream `dsh-message-edit`, including version effect pairs (`message-edit/version`), inverse lineage tracking (`inverse.sessionId`), `agents.create({seed})` transactions, and error rollback handling. On top of this foundation, the host incorporates the following adaptations:

- **Collision Prevention**: The plugin identifier is renamed to `dsh-pencil` and the endpoint route is changed to `/pencil`.
- **Targeted Message Matching**: Added `messageId` to assistant items returned by `editableMessages()`, allowing the client component to match slot props accurately.
- **Event Log Compatibility for 0.2.x**: DSH 0.1.x stored events under `session.events`, whereas 0.2.x stores them in `session.log` and exposes them through `snapshotEvents()`. The host introduces `eventsOf(session)` to call `snapshotEvents()` safely across versions.
- **Version-tree Diagnostics**: Error messages from the version tree now carry counts (`currentIndex`, `logs.length`, `lineage.length`) so an empty layer is identifiable at a glance.

The client implementation was written entirely from scratch to satisfy DSH 0.2.x contracts, resolving fatal loading failures that rendered upstream client code non-functional under 0.2.x.

### DSH 0.2.x Contract Requirements

- **Client Module Seed Word Restrictions**: DSH 0.2.x no longer ships `@deepseek-ai/dsh-client-runtime` (including its `/client` subpath). The client module loader restricts imports to a fixed allowlist of seed words (`react`, `react-dom`, `@deepseek-ai/cordis`, `dsh-client-store`, `dsh-client-ui-slots`, `dsh-client-ui-primitives`, etc.). This client plugin imports only `react`.
- **Injected Service Renaming**: The UI conversation service was renamed from `conversation` to `uiConversation` in DSH 0.2.x. Declaring nonexistent dependencies causes the plugin fiber to remain in an unresolved pending state, silently halting initialization. This client plugin injects only `slots` and `sessions`.
- **Slot Registration Timing**: DSH 0.2.x requires extensions to await slot availability via `ctx.slots.inject` before registering UI components: `ctx.slots.inject("conversation.chat.assistant-actions", () => ctx.slots.register(...))`. Calling `ctx.slots.register` without `ctx.slots.inject` fails validation at load time.

### Service and Route Dependencies

- Client injected services: `slots`, `sessions`
- Host injected services: `sessions`, `agents`, `sessionPersistence`, `sessionQuery`, `workspaceRegistry`, `webServer`
- Host HTTP routes: `GET /pencil?sessionId=` retrieves editable message objects; `POST /pencil` executes `edit`, `reroll`, or `retry` operations.

## Known Limitations

- Only assistant response text is editable; reasoning blocks and user messages do not have an edit entry point yet.
- Editing produces a new forked session rather than modifying conversation history in place; DSH session logs are strictly append-only, leaving no mechanism for in-place modification.
- Editing truncates conversation turns subsequent to the edited turn (`cascade: "truncate"`).
- Failure modes are contained: the client occupies a single slot entry, and host exceptions return structured JSON errors without causing the Desktop application to enter Safe Mode.

## Troubleshooting

Inspect the harness log file to verify that the plugin was loaded by DSH Desktop:

```powershell
Select-String "$env:APPDATA\dsh-desktop\logs\harness.log" -Pattern "dsh-pencil"
```

Check the harness log file to confirm that the host HTTP route registered successfully:

```powershell
Select-String "$env:APPDATA\dsh-desktop\logs\harness.log" -Pattern "/pencil"
```

Host route registration requires all six host services to be initialized before the route becomes active.

## Attribution and License

- `lib/index.mjs` is adapted from [Moeblack/dsh-message-edit](https://github.com/Moeblack/dsh-message-edit) under the MIT License.
- `lib/client.js` is an original implementation.

When distributing or using this plugin, retain `LICENSE` and the upstream attribution and modification audit log documented in [CREDITS.md](CREDITS.md).
