# Puerts TypeScript 接入与调试指南

本文档基于当前仓库的实际配置整理，目标是说明 4 件事：

- 如何初始化 Puerts TypeScript 环境
- 如何正确编译和 watch TypeScript
- 如何在 VS Code 中附加调试 Unreal Editor 里的 TS 代码
- 如何注册和维护 Blueprint Mixin

## 1. 版本要求

当前项目要求使用 TypeScript `5.3.x`，建议锁定为 `~5.3.3`。

原因是从 TypeScript `5.4` 开始，`CommonJS` 下的 `import * as X from "module"` 生成逻辑发生变化，会对 `require()` 结果包一层 `__importStar`。Puerts 的 `ue` 模块依赖 native binding 延迟解析属性，这种包装会导致以下问题：

- `UE.XXX` 变成 `undefined`
- 蓝图类继承时报错：`TypeError: Class extends value undefined is not a constructor or null`

当前项目根目录 [package.json](/d:/Workspace/NoOutsiders/package.json) 的关键配置如下：

```json
{
    "dependencies": {
        "typescript": "~5.3.3"
    },
    "devDependencies": {
        "ts-patch": "^3.3.0",
        "typescript-transform-paths": "^3.5.2"
    }
}
```

## 2. 初始化项目

首次接入或重新整理 Puerts TypeScript 环境时，在项目根目录执行：

```powershell
node Plugins/Puerts/enable_puerts_module.js
```

这个脚本会做几件事：

- 初始化 `Content/JavaScript`
- 在缺失时生成 `tsconfig.json`
- 在缺失时生成 `Config/DefaultPuerts.ini`
- 在缺失时创建 `TypeScript/`
- 在缺失时为 `PuertsEditor` 执行一次 `npm install`

如果项目里已经有自己的 `tsconfig.json`，脚本会提示文件已存在，不会强行覆盖。

## 3. TypeScript 编译配置

当前项目使用 `ts-patch` + `typescript-transform-paths` 来支持路径别名，并在输出 JS 时把别名改写成真实相对路径。

根目录 [tsconfig.json](/d:/Workspace/NoOutsiders/tsconfig.json) 的关键配置如下：

```json
{
    "compilerOptions": {
        "target": "esnext",
        "module": "commonjs",
        "moduleResolution": "node",
        "sourceMap": true,
        "baseUrl": ".",
        "typeRoots": [
            "Typing",
            "./node_modules/@types"
        ],
        "rootDir": "./",
        "outDir": "Content/JavaScript",
        "paths": {
            "@root/*": [
                "./TypeScript/*"
            ]
        },
        "plugins": [
            {
                "transform": "typescript-transform-paths"
            },
            {
                "transform": "typescript-transform-paths",
                "afterDeclarations": true
            }
        ]
    },
    "include": [
        "TypeScript/**/*"
    ]
}
```

注意：

- 必须通过 `tspc` 编译，不能直接用 `tsc`
- `sourceMap` 必须保持开启，否则 TS 断点无法回映到源码
- 输出目录是 `Content/JavaScript`

## 4. 常用命令

安装依赖：

```powershell
npm install
```

完整构建：

```powershell
npm run build
```

持续监听：

```powershell
npm run watch
```

## 5. VS Code Tasks

当前仓库已经有 [tasks.json](/d:/Workspace/NoOutsiders/.vscode/tasks.json)：

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "ts-patch watch - project",
            "type": "shell",
            "command": "npx",
            "args": [
                "tspc",
                "--watch"
            ],
            "options": {
                "cwd": "${workspaceFolder}"
            },
            "group": "build",
            "problemMatcher": [
                "$tsc-watch"
            ],
            "detail": "ts-patch build whole project"
        }
    ]
}
```

日常开发建议先启动这个 watch task，再进入编辑器验证脚本行为。

## 6. VS Code 调试配置

当前项目已补充 [launch.json](/d:/Workspace/NoOutsiders/.vscode/launch.json)，用于附加 Unreal Editor 中的 Puerts 调试端口。

默认调试端口来自 `UPuertsSetting::DebugPort`，默认值是 `8080`，定义见 [PuertsSetting.h](/d:/Workspace/NoOutsiders/Plugins/Puerts/Source/Puerts/Private/PuertsSetting.h#L33)。

### 6.1 调试前提

需要满足以下条件：

- `tsconfig.json` 开启了 `sourceMap`
- Unreal Editor 中启用了 Puerts 调试
- 编辑器实际使用的端口与 `launch.json` 保持一致

如果你通过配置文件开启调试，可以在 `Config/DefaultPuerts.ini` 中补充：

```ini
[/Script/Puerts.PuertsSetting]
AutoModeEnable=True
DebugEnable=True
DebugPort=8080
WaitDebugger=False
```

### 6.2 启动方式

1. 运行 `npm run build` 或开启 `ts-patch watch - project`
2. 启动 Unreal Editor
3. 确认 Puerts 调试端口已开启，默认是 `8080`
4. 在 VS Code 里运行 `Attach Unreal Editor`

### 6.3 多进程端口说明

Puerts 在多进程场景下会基于默认端口做偏移：

- Server 进程：`8080 -> 9079`
- Client 进程：`8080 -> 8090`、`8100`、`8110` ...

如果你不是连主编辑器进程，需要把 `launch.json` 里的端口改成对应值，或者新增多个 attach 配置。

## 7. Blueprint Mixin 开发流程

### 7.1 编写 Mixin

以 `LobbyView` 为例：

```typescript
import * as UE from "ue";
import { PuertsUtil } from "@root/Framework/Util/PuertsUtil";

const TS_TargetClass = PuertsUtil.LoadClass(UE.Game.NoOutsiders.UI.Lobby.WBP_Lobby.WBP_Lobby_C);
interface LobbyView extends UE.Game.NoOutsiders.UI.Lobby.WBP_Lobby.WBP_Lobby_C { }

class LobbyView {
}

PuertsUtil.Mixin(TS_TargetClass, LobbyView);
```

项目里优先统一使用 `PuertsUtil.LoadClass(...)` 获取蓝图类，而不是直接手写 `UE.Class.Load(...)` + `blueprint.tojs(...)`。  
默认优先写“推导出来的 UE 类型路径”，不要因为当前 `ue_bp.d.ts` 里暂时没刷出来，就主动降级成通用类型或字符串路径。先把标准写法落进代码，后续由开发者补齐 typings。

常见写法：

1. `ue_bp.d.ts` 里已经有生成类型时，直接传类型对象：

```typescript
const TS_TargetClass = PuertsUtil.LoadClass(UE.Game.NoOutsiders.UI.Lobby.WBP_Lobby.WBP_Lobby_C);
```

2. 如果你确认资源路径能稳定推导出类型名，但当前 typings 还没刷新，也先按推导结果直接写：

```typescript
const TS_TargetClass = PuertsUtil.LoadClass(UE.Game.NoOutsiders.UI.Vote.WBP_Vote.WBP_Vote_C);
interface VoteView extends UE.Game.NoOutsiders.UI.Vote.WBP_Vote.WBP_Vote_C { }
```

3. 只有在确实没法合理推导 UE 命名空间，或者只是做临时验证时，才退回完整蓝图类路径字符串：

```typescript
const TS_TargetClass = PuertsUtil.LoadClass("/Game/NoOutsiders/UI/Vote/WBP_Vote.WBP_Vote_C");
```

这样可以把蓝图加载逻辑统一收口在 `PuertsUtil` 里，同时保持业务代码尽量接近最终规范。

如果蓝图生成类型里已经带有控件成员，就不要在 mixin 的 `interface` 里重复声明这些字段，保持空接口即可：

```typescript
interface VoteView extends UE.Game.NoOutsiders.UI.Vote.WBP_Vote.WBP_Vote_C { }
```

另外，`Typing/ue/ue.d.ts` 里的 UE 运行时类型同样是唯一准绳。  
如果 `UE.NOMatchGameState`、`UE.NOMatchPlayerController` 这类类型、方法、委托已经在 `ue.d.ts` 里存在，就直接使用，不要在业务代码里再手写一层匿名结构类型、交叉类型或本地 `type` 去“补定义”。

推荐写法：

```typescript
const matchGameState = UE.GameplayStatics.GetGameState(this) as UE.NOMatchGameState | undefined;
const matchPlayerController = owningPlayer as UE.NOMatchPlayerController | undefined;
```

不推荐写法：

```typescript
type MatchGameState = UE.NOMatchGameState & {
    GetVoteBallotCounts(): number[];
};
```

如果你发现实际 C++/蓝图已经有某个成员，但 `ue.d.ts` 里还没有，优先更新或重新生成 typings，而不是在业务 TS 里临时补一套本地类型。

### 7.2 注册 Mixin

Mixin 文件写完后，还需要在 [MixinDefine.ts](/d:/Workspace/NoOutsiders/TypeScript/Framework/Mixin/MixinDefine.ts) 里注册路径：

```typescript
export const PathConfig: Map<string, string> = new Map([
    ["@Root", "./TypeScript"],
    ["@Game", "./TypeScript/Game"],
])

export const MixinGroupConfig = {
    [MixinGroupType.Common]: [
        "@Root/UI/LobbyView",
        "@Root/UI/LobbyPlayerItemView",
    ]
}
```

注意这里的 `@Root` 只是 Mixin 动态加载路径前缀，和业务代码里 `import` 使用的 `@root/*` 不是同一层概念，不要混写。

### 7.3 Mixin 实例类型断言写法

当你通过 `Create`、`GetWidgetFromName` 或其他方式拿到一个已经被 Mixin 过的蓝图对象时，推荐直接断言成对应的 TS Mixin 类。

例如 `LobbyPlayerItemView` 的正确写法是：

```typescript
const lobbyPlayerItemWidget = playerItemWidget as LobbyPlayerItemView;
```

不推荐写成匿名结构类型：

```typescript
const lobbyPlayerItemWidget = playerItemWidget as UE.Game.NoOutsiders.UI.Lobby.WBP_LobbyPlayerItem.WBP_LobbyPlayerItem_C & {
    SetupPlayerItem(playerName: string): void;
};
```

原因是：

- 直接断言成 `LobbyPlayerItemView` 更符合 Mixin 的实际使用方式
- 类型更集中，后续方法补充时不需要到处重复匿名声明
- 可读性更好，也更方便 IDE 跳转和补全

前提是对应的 Mixin 文件已经正确加载并注册。

## 8. 常见问题

### 8.0 TypeScript 命名风格

Puerts TypeScript 代码里的私有字段不要使用前导下划线命名，例如不要写 `__displayIndex`、`_timerHandle`。

统一使用普通 `camelCase`：

```typescript
private displayIndex = -1;
private voteButtonClickedHandler?: () => void;
```

这样做的原因是：

- 和当前项目里绝大多数 TypeScript 写法保持一致
- 避免把 C++/其他语言里的私有字段习惯直接带进 TS
- 让 Mixin/UI 脚本在阅读时更自然，减少无意义前缀噪音

### 8.1 `@root` 大小写问题

`tsconfig.json` 中配置的是 `@root/*`，所以 TypeScript 代码里的导入也必须写成：

```typescript
import { PuertsUtil } from "@root/Framework/Util/PuertsUtil";
```

不要写成 `@Root/...`，否则编译阶段会找不到模块。

### 8.2 UE 类型定义以 `Typing/ue/ue.d.ts` 和 `Typing/ue/ue_bp.d.ts` 为准

写 Puerts TypeScript 时，先查 typings，再写业务代码：

- 运行时类、方法、委托，以 [ue.d.ts](/d:/Workspace/NoOutsiders/Typing/ue/ue.d.ts) 为准
- 蓝图生成命名空间和蓝图类路径，以 [ue_bp.d.ts](/d:/Workspace/NoOutsiders/Typing/ue/ue_bp.d.ts) 为准

不要绕过 typings 在业务代码里重复造一套 UE 类型声明。

例如当前项目里 `WBP_Lobby` 的写法是：

```typescript
const TS_TargetClass = PuertsUtil.LoadClass(UE.Game.NoOutsiders.UI.Lobby.WBP_Lobby.WBP_Lobby_C);
interface LobbyView extends UE.Game.NoOutsiders.UI.Lobby.WBP_Lobby.WBP_Lobby_C { }
```

### 8.3 `K2_SetTimer` 不能调用纯 TypeScript 方法

`UE.KismetSystemLibrary.K2_SetTimer(Object, "FunctionName", ...)` 底层是按 `UFunction` 名称查找并调用函数，所以它只适用于：

- C++ `UFUNCTION`
- 蓝图函数

它不适用于纯 TypeScript Mixin 方法。比如下面这种写法就是无效的：

```typescript
UE.KismetSystemLibrary.K2_SetTimer(this, "TryBindLobbyGameState", 0.1, false);
```

如果 `TryBindLobbyGameState` 只是 TS 类中的普通方法，而不是 `UFunction`，`K2_SetTimer` 不会正确调用它。

这类场景应该改用 TS 自己的定时器：

```typescript
setTimeout(() => {
    this.TryBindLobbyGameState();
}, 100);
```

简而言之：

- 需要按函数名调用 Unreal 反射函数时，用 `K2_SetTimer`
- 需要调纯 TS 逻辑时，用 `setTimeout` / `setInterval`

### 8.4 `ts-patch` 缓存异常

如果遇到以下报错：

- `Could not acquire lock to write file`
- `Cannot find backup cache file for tsc.js`

按下面顺序处理：

```powershell
npx ts-patch clear-cache
npx ts-patch install -s
```

如果还不行，再删除 `node_modules` 后重新执行：

```powershell
npm install
```

## 9. 推荐工作流

1. 运行 `node Plugins/Puerts/enable_puerts_module.js`
2. 运行 `npm install`
3. 运行 `npm run build` 做一次完整检查
4. 启动 `ts-patch watch - project`
5. 如需断点调试，在 VS Code 中执行 `Attach Unreal Editor`

## 10. 插件内置 Skill

仓库内已经附带 Codex skill，位置在 [puerts-ts](Plugins/Puerts/.codex/skills/puerts-ts/SKILL.md)。

如果你希望插件和 skill 一起分发，可以直接保留这个目录结构；把插件拷到别的项目时，连同 `.codex/skills/puerts-ts` 一起带走即可。
