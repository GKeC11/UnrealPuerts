---
name: puerts-ts
description: Write, debug, and maintain Puerts TypeScript code for this Unreal project. Use when Codex needs to work in `TypeScript/`, `Content/JavaScript`, `Typing/ue`, `Plugins/Puerts`, or `MixinDefine.ts`, including implementing gameplay/UI scripts, fixing Puerts runtime issues, maintaining Blueprint Mixins, setting up build or watch commands, or attaching the VS Code debugger to Unreal Editor.
---

# Puerts TS

Use this skill for the project's Puerts TypeScript layer. Keep the workflow centered on source files in `TypeScript/`; treat `Content/JavaScript` as compiler output unless the user explicitly asks to touch generated JS.

## Workflow

1. Inspect the relevant TS source plus `package.json`, `tsconfig.json`, and `Plugins/Puerts/ReadMe.md` when build, debug, or mixin behavior matters.
2. Edit TypeScript in `TypeScript/` or related typings/config files. Do not hand-edit generated JS by default.
3. Compile with `npm run build` for one-shot validation or `npm run watch` for iterative work.
4. When the task involves Blueprint Mixins or Unreal runtime behavior, verify the target blueprint type in `Typing/ue/ue_bp.d.ts` and confirm the mixin path is registered in `TypeScript/Framework/Mixin/MixinDefine.ts`.
5. When debugging is requested, use the existing VS Code attach flow and keep source maps enabled.

## Non-Negotiables

- Keep TypeScript on `~5.3.3`. Do not upgrade to 5.4+ unless the user explicitly wants a migration.
- Compile with `tspc`, not plain `tsc`.
- Keep `compilerOptions.module` as `commonjs`, `compilerOptions.moduleResolution` as `node`, and `sourceMap` enabled unless the user asks for a config change.
- Keep path imports consistent with `tsconfig.json`: business code uses `@root/*`, while mixin dynamic registration may still use `@Root/...` entries inside `MixinDefine.ts`.
- Treat `Content/JavaScript/**/*.js` as generated output from `TypeScript/`. Do not hand-edit generated JS unless the user explicitly asks to change generated artifacts.
- Check `Typing/ue/ue_bp.d.ts` before assuming Blueprint namespace paths.
- Treat `Typing/ue/ue.d.ts` as the source of truth for UE runtime classes, methods, and delegates. If a UE type is already declared there, use it directly and do not re-declare it in business TS via local `type`, anonymous object shapes, or intersection overlays.
- In project TypeScript, do not use leading underscores for private field names; prefer plain `camelCase` such as `displayIndex` or `bindRetryTimer`.
- Respect the project's `strictNullChecks: false` setup. In this codebase it is acceptable for functions typed as returning a concrete UE/object type to return `null`, and callers may still perform `if (!value)` guards.

## Code Writing Rules

- Prefer small helper functions in shared libraries such as `TypeScript/Library/CommonLibrary.ts` when the same UE lookup logic is repeated across views/widgets.
- In this project, do not add `| undefined` to every UE-returning helper by default. If the codebase convention for that helper is a concrete return type, it may still return `null` and let callers perform null checks.
- When following the concrete-return-type convention in this repository, prefer plain `return null;` over noisy casts like `null as unknown as Foo` because `strictNullChecks` is disabled.
- Keep business TS aligned with the generated UE typings. If a UE class, method, or delegate exists in `Typing/ue/ue.d.ts`, use that type directly instead of recreating local wrapper shapes.
- If a Blueprint function library API is already present on `UE.*`, call it directly, for example `UE.DMPuertsLibrary.DiagnoseBlueprintClassLoad(path)`, and do not add `as any` just to bypass typings.
- Avoid editing generated `Content/JavaScript` output unless the user explicitly asks for generated JS changes.
- For UI/gameplay flow scripts, add targeted `LogUtil.Log(...)` calls at key transitions such as widget construct/destruct, delegate bind/unbind, validation failures, user actions, RPC dispatch, and major success/failure branches.
- Keep log messages concise and searchable with a stable prefix like `Login View ...` or `Lobby View ...`.
- Add short comments only when they explain sequencing, safety guards, or Unreal-specific intent that is not obvious from the code itself.

## Mixin Rules

- Build Blueprint Mixins with `PuertsUtil.LoadClass(...)`, declare an interface extending the generated UE type, define the TS class, and call `PuertsUtil.Mixin`.
- If the generated Blueprint type already contains widget members, keep the interface empty instead of re-declaring fields.
- Prefer `PuertsUtil.LoadClass(...)` over direct `UE.Class.Load(...)`.
- When UE runtime typings are missing or stale, prefer updating/regenerating `Typing/ue/ue.d.ts` instead of patching local business code with handcrafted UE type overlays.
- If `ue_bp.d.ts` does not yet expose the Blueprint type, still prefer writing the inferred `UE.Game...` type path directly in code when the asset path is clear. Do not proactively downgrade to `CommonUserWidget`, `any`, or string-path loading just because typings are temporarily missing.
- Only fall back to a full asset class path string when the UE namespace truly cannot be inferred or the task is explicitly a temporary experiment.
- After adding a new mixin file, register its path in `TypeScript/Framework/Mixin/MixinDefine.ts`.
- When consuming an already-mixed Blueprint instance, cast to the concrete mixin class instead of repeating anonymous intersection types.
- If scheduling pure TS logic, use `setTimeout` or `setInterval` instead of `K2_SetTimer`.

## Debugging Rules

- Use `npm run build` or `npm run watch` before attaching the debugger.
- Use the VS Code configuration `Attach Unreal Editor` and keep its port aligned with Puerts `DebugPort`.
- Remember multi-process offsets: editor default `8080`, server `9079`, clients `8090`, `8100`, `8110`, and so on.
- If VS Code diagnostics disagree with `tspc`, make sure VS Code is using the workspace TypeScript SDK from `node_modules/typescript/lib` instead of a newer bundled version.

## Read More

Read [references/puerts-typescript.md](references/puerts-typescript.md) when you need the detailed project conventions, common failure modes, or the exact mixin/debug setup.
