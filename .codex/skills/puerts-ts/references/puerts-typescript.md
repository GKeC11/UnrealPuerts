# Puerts TypeScript Reference

## Build and setup

- Initialize Puerts TS support with `node Plugins/Puerts/enable_puerts_module.js` when the project is first set up or the TS layer is being repaired.
- Install dependencies with `npm install`.
- Use `npm run build` for a full build.
- Use `npm run watch` for continuous compilation.

## Compiler expectations

The project relies on:

- `typescript` `~5.3.3`
- `ts-patch`
- `typescript-transform-paths`
- output directory `Content/JavaScript`
- source files under `TypeScript/**/*`

Important compiler constraints:

- Do not switch to TypeScript 5.4+ casually. Puerts `ue` imports can break because of CommonJS interop wrapping.
- Do not replace `tspc` with `tsc`.
- Keep `module: "commonjs"` and `moduleResolution: "node"` for the current toolchain.
- Keep `sourceMap: true` so Unreal debugging maps back to TS files.
- The repository currently works with `strictNullChecks: false`.

## Path conventions

- Normal TS imports use `@root/*` based on `tsconfig.json`.
- Dynamic mixin registration in `MixinDefine.ts` may use `@Root/...` path strings. Treat this as a separate runtime convention and do not normalize it blindly.

## Mixin pattern

Typical structure:

```ts
import * as UE from "ue";
import { PuertsUtil } from "@root/Framework/Util/PuertsUtil";

const TS_TargetClass = PuertsUtil.LoadClass(UE.Game.NoOutsiders.UI.Lobby.WBP_Lobby.WBP_Lobby_C);
interface LobbyView extends UE.Game.NoOutsiders.UI.Lobby.WBP_Lobby.WBP_Lobby_C {}

class LobbyView {
}

PuertsUtil.Mixin(TS_TargetClass, LobbyView);
```

Prefer `PuertsUtil.LoadClass(...)` as the only class-loading entry point for mixins.

- If `ue_bp.d.ts` already exposes the Blueprint type, pass that generated type object.
- If typings are missing or stale, prefer writing the inferred `UE.Game...` type path directly from the asset path anyway, and let later developers regenerate or fix typings.
- Only if the namespace genuinely cannot be inferred should you pass the full asset class path string, for example `"/Game/NoOutsiders/UI/Vote/WBP_Vote.WBP_Vote_C"`.
- Avoid direct `UE.Class.Load(...)` + `blueprint.tojs(...)` in feature code unless you are updating `PuertsUtil` itself.
- If the generated Blueprint type already includes widget members, keep `interface XxxView extends ... { }` empty instead of repeating fields like `HorizontalBox_Vote` or `Button_Start`.

After creating a mixin:

- register it in `TypeScript/Framework/Mixin/MixinDefine.ts`
- verify the Blueprint type path in `Typing/ue/ue_bp.d.ts`

When consuming a mixed widget or object, prefer:

```ts
const widget = rawWidget as LobbyPlayerItemView;
```

Avoid repeating anonymous intersection types unless there is a very specific reason.

## Code-writing conventions

- Repeated UE lookup helpers should be centralized in shared helpers such as `TypeScript/Library/CommonLibrary.ts` instead of being reimplemented in multiple views.
- In this repository, a helper typed as returning a concrete UE/object type may still return `null`; callers are still expected to guard with `if (!value)` where appropriate.
- Because `strictNullChecks` is disabled, prefer plain `return null;` over `null as unknown as SomeType` when following that convention.
- If a UE runtime type already exists in `Typing/ue/ue.d.ts`, use it directly. Do not add local anonymous object shapes or intersection overlays just to restate existing engine APIs.

## Debugging Unreal Editor

The repository already uses a VS Code attach configuration named `Attach Unreal Editor`.

Debug checklist:

1. Ensure `sourceMap` is enabled.
2. Build or start watch mode.
3. Confirm Puerts debugging is enabled in Unreal.
4. Attach with the correct port.

Typical port values:

- editor: `8080`
- server: `9079`
- client processes: `8090`, `8100`, `8110`, ... 

If VS Code shows diagnostics that disagree with `npm run build` / `tspc`, switch VS Code to the workspace TypeScript version from `node_modules/typescript/lib`.

If configuration is needed, `Config/DefaultPuerts.ini` should contain the expected debug settings.

## Common pitfalls

### `@root` casing

Use `@root/...` in regular TypeScript imports. `@Root/...` will fail normal module resolution.

### Blueprint namespaces

Do not guess Blueprint namespace paths from asset folders. Check `Typing/ue/ue_bp.d.ts` first.

### `K2_SetTimer`

`K2_SetTimer` only works with reflected `UFunction` targets. It does not call plain TS methods reliably.

Use:

```ts
setTimeout(() => {
    this.TryBindLobbyGameState();
}, 100);
```

for pure TS callbacks.

### `ts-patch` cache issues

Try:

```powershell
npx ts-patch clear-cache
npx ts-patch install -s
```

If that still fails, reinstall dependencies with `npm install`.

## Logging and comments in UI scripts

For Blueprint Mixins and UI flow scripts, logs should focus on the highest-value transitions:

- `Construct` / `Destruct`
- delegate bind / unbind
- validation failures such as missing widgets, invalid controllers, invalid player state, or widget creation failures
- user actions such as button clicks and confirmed input
- major flow results such as RPC dispatch, widget open success, and widget removal success

Guidelines:

- Use `LogUtil.Log(...)`
- Keep a stable searchable prefix such as `Login View ...` or `Lobby View ...`
- Keep messages short and state-focused

Comment guidelines:

- Add short comments for sequencing, safety guards, or Unreal-specific intent
- Skip comments for obvious null checks, simple property assignment, or trivial getter logic

Example:

```ts
// 先更新本地显示名，再通知服务端同步 PlayerState 名称。
playerState.PlayerNamePrivate = playerName;
playerController.ServerChangeName(playerName);
```
