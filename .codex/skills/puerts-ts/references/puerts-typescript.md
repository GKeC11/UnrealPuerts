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

### Waiting for state changes

Avoid implementing wait logic with TS timers such as `setTimeout` or `setInterval` just to poll for readiness.

Prefer these patterns instead:

- bind the relevant UE delegate and continue the flow from the callback
- listen for a Gameplay Message when the state transition is already modeled as a channel/message
- keep the delegate handle or message listener handle and unregister it as soon as the wait is fulfilled or the owner is being destroyed
- if the needed event surface does not exist yet, add it in C++ first as a delegate, async action, or Gameplay Message path, then consume that from TS

`Plugins/GameplayMessageRouter` is the reference for message-driven waits. Its `UGameplayMessageSubsystem` registers a typed listener per channel and returns a `FGameplayMessageListenerHandle` that must be explicitly unregistered.

In this repository, the TS-facing Gameplay Message entry points already exist:

- send: `UE.GameplayMessageSubsystem.Generic_BroadcastMessage(Channel, PayloadStruct.StaticStruct(), Payload)`
- listen: `UE.AsyncAction_ListenForGameplayMessage.ListenForGameplayMessages(WorldContextObject, Channel, PayloadStruct.StaticStruct(), MatchType)`
- receive callback: bind `OnMessageReceived`
- read payload: call `GetPayload(...)` inside the receive callback with the matching struct type

This means Puerts gameplay flow should prefer the existing generated `UE.*` APIs instead of adding ad-hoc polling timers or re-wrapping the C++ router unless a new missing capability is actually needed.

When a missing capability is the blocker, the preferred order is:

1. declare the native event source in C++ with the narrowest useful shape
2. expose it through generated `UE.*`, a Puerts native registration, or an existing async-action pattern
3. consume it from TS with clear bind/unbind ownership
4. only consider a TS timer as a temporary fallback if adding the native event is not feasible for the task

Use a TS timer only as a last-resort temporary workaround when there is truly no delegate or message source available and the user accepts that compromise.

### `K2_SetTimer`

`K2_SetTimer` only works with reflected `UFunction` targets. It does not call plain TS methods reliably.

So for Puerts business logic, do not switch from TS timers to `K2_SetTimer` for waiting. The preferred replacement is event-driven flow via delegates or Gameplay Messages.

### Gameplay Message usage notes

When using Gameplay Messages from TS:

- prefer a strongly named payload struct type already generated in `Typing/ue/ue.d.ts`
- keep the channel definition stable and centralized instead of constructing many ad-hoc strings inline
- store the async listener object on the owner if the wait spans multiple frames
- unbind or release the listener when the owner is destructed or the awaited state has been observed
- add logs for listener register, message received, payload parse success/failure, and listener cleanup

When adding native support for TS waits:

- prefer adding a real delegate or Gameplay Message at the gameplay ownership layer instead of a view-local polling helper
- expose only the minimal payload needed by TS
- match the native API style already used by the project, for example `UFUNCTION(BlueprintCallable)` async actions or Puerts native registration for missing static helpers
- keep cleanup explicit so listeners do not survive world teardown, widget destruction, or state completion

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
- message listener register / unregister
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
