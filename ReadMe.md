# Puerts 路径别名配置指南

本项目在 Puerts 环境下，依赖 `ts-patch` 和 `typescript-transform-paths` 两个库来实现相对路径/别名导入（Alias Import）的功能。

## ⚠️ TypeScript 版本要求

**必须使用 TypeScript `5.3.x`（推荐 `~5.3.3`），不可使用 5.4 及以上版本。**

从 TypeScript 5.4 开始，`import * as X from "module"` 语法在 CommonJS 模式下会生成 `__importStar` 辅助函数来包装 `require()` 的结果。该辅助函数会通过 `Object.getOwnPropertyNames` 枚举模块属性并创建代理对象，但 PuerTS 的 `ue` 等原生 C++ 模块的属性是通过 native binding 延迟解析的，无法被正常枚举，最终导致：

- `UE.XXXClass` 变为 `undefined`
- 继承时抛出 `TypeError: Class extends value undefined is not a constructor or null`

```jsonc
// package.json 中锁定版本
{
  "dependencies": {
    "typescript": "~5.3.3"
  }
}
```

当前项目最终使用的根目录 `package.json` 如下：

```json
{
    "name": "nooutsiders-ts",
    "private": true,
    "scripts": {
        "postinstall": "ts-patch install -s",
        "build": "tspc -p tsconfig.json",
        "watch": "tspc --watch -p tsconfig.json"
    },
    "dependencies": {
        "typescript": "~5.3.3"
    },
    "devDependencies": {
        "ts-patch": "^3.3.0",
        "typescript-transform-paths": "^3.5.2"
    }
}
```

## `tsconfig.json` 配置示例

为了让路径别名正常工作，并在编译后正确替换输出的路径，请在项目根目录的 `tsconfig.json` 中添加如下配置：

```json
{
    "compilerOptions": {
        "target": "esnext",
        "module": "commonjs",
        "moduleResolution": "node",
        "noImplicitAny": false,
        "noImplicitOverride": true,
        "noImplicitReturns": true,
        "strictBindCallApply": true,
        "noImplicitThis": true,
        "allowJs": true,
        "checkJs": false,
        "skipLibCheck": true,
        "resolveJsonModule": true,
        "forceConsistentCasingInFileNames": false,
        "experimentalDecorators": true,
        "emitDecoratorMetadata": true,
        "sourceMap": true,
        "baseUrl": ".",
        "typeRoots": [
            "Typing",
            "./node_modules/@types"
        ],
        "outDir": "Content/JavaScript",
        "rootDir": "./",
        "paths": {
            "@root/*": [
                "./TypeScript/*"
            ]
        },
        "plugins": [
            // 编译时转换输出内容中的路径 (作用于 .js 文件)
            {
                "transform": "typescript-transform-paths"
            },
            // 如果你需要输出类型声明文件 (.d.ts)，请加上下面的配置
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

当前项目实际使用的根目录 `tsconfig.json`：

```json
{
    "compilerOptions": {
        "target": "esnext",
        "module": "commonjs",
        "moduleResolution": "node",
        "noImplicitAny": false,
        "noImplicitOverride": true,
        "noImplicitReturns": true,
        "strictBindCallApply": true,
        "noImplicitThis": true,
        "allowJs": true,
        "checkJs": false,
        "skipLibCheck": true,
        "resolveJsonModule": true,
        "forceConsistentCasingInFileNames": false,
        "experimentalDecorators": true,
        "emitDecoratorMetadata": true,
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

## VSCode Tasks 配置示例

VSCode 还需要配置 Task，用于监视 ts 文件的自动编译，以下是 Task 示例：

> **注意：** 必须使用 `tspc`（ts-patch 编译器）而不是 `tsc`。`tsc` 不会加载 `plugins` 中配置的 `typescript-transform-paths` 插件，`@root/*` 路径别名将不会被转换为相对路径。

```json
{
    // See https://go.microsoft.com/fwlink/?LinkId=733558
    // for the documentation about the tasks.json format
    "version": "2.0.0",
    "tasks": [
        {
            "label": "ts-patch watch - project",
            "type": "shell",
            "command": "npx tspc --watch",
            "group": "build",
            "problemMatcher": [
                "$tsc-watch"
            ],
            "detail": "ts-patch build whole project"
        }
    ]
}
```

当前项目使用的 `.vscode/tasks.json`：

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

## 当前项目落地步骤

1. 首次配置 TS 环境时，先在项目根目录执行一次 `node Plugins/Puerts/enable_puerts_module.js`。
2. 在项目根目录创建或调整 `package.json`、`tsconfig.json` 和 `.vscode/tasks.json`。
3. 执行 `npm install`，让 `postinstall` 自动运行 `ts-patch install -s`。
4. 执行 `npm run build` 验证一次完整编译。
5. 日常开发时运行 `npm run watch`，或者在 VS Code 中执行 `ts-patch watch - project`。

### 为什么要先运行 `enable_puerts_module.js`

这个脚本建议在项目第一次接入 Puerts TypeScript 环境时执行一次：

- 会把 `Plugins/Puerts/Content/JavaScript` 复制到项目根目录 `Content/JavaScript`
- 会在缺失时生成根目录 `tsconfig.json`
- 会在缺失时生成 `Config/DefaultPuerts.ini`
- 会在缺失时创建根目录 `TypeScript` 文件夹
- 会在缺失时为 `PuertsEditor` 执行一次 `npm install`

命令示例：

```powershell
node Plugins/Puerts/enable_puerts_module.js
```

如果项目已经有自己维护过的 `tsconfig.json`，脚本会提示该文件已存在，此时保留项目当前配置即可，不需要强行覆盖。

## 常见问题

### 1. `@root` 大小写要统一

`tsconfig.json` 中配置的是 `@root/*`，所以代码里也必须统一写成：

```typescript
import { PuertsUtil } from "@root/Framework/Util/PuertsUtil";
```

不要写成 `@Root`，否则编译阶段会出现模块找不到的错误。

### 2. 蓝图类型路径要以 `Typing/ue/ue_bp.d.ts` 为准

蓝图生成的 TypeScript 命名空间不一定和资源目录的直觉路径完全一致，实际开发时应先去 `Typing/ue/ue_bp.d.ts` 查真实命名空间。

例如当前项目里的 `WBP_Lobby` 和 `WBP_LobbyPlayerItem`，正确写法是：

```typescript
const TS_TargetClass = PuertsUtil.LoadClass(UE.Game.NoOutsiders.UI.Lobby.WBP_Lobby.WBP_Lobby_C);
interface LobbyView extends UE.Game.NoOutsiders.UI.Lobby.WBP_Lobby.WBP_Lobby_C { }
```

而不是：

```typescript
UE.Game.Game.UMG.Lobby.WBP_Lobby.WBP_Lobby_C
```

### 3. `ts-patch` 缓存异常时的处理

如果遇到类似下面的问题：

- `Could not acquire lock to write file`
- `Cannot find backup cache file for tsc.js`

可以按下面顺序处理：

1. 执行 `npx ts-patch clear-cache`
2. 执行 `npx ts-patch install -s`
3. 如果还是不行，删除根目录 `node_modules` 后重新执行 `npm install`

## 蓝图 Mixin 开发流程

### 1. 编写 Mixin 模板

当你需要为蓝图编写 TypeScript 逻辑时，可以参考以下 Mixin 模板（以 `LobbyView` 为例）：

```typescript
import * as UE from "ue";
import { PuertsUtil } from "@root/Framework/Util/PuertsUtil";

// 1. 加载目标蓝图类的 Class 对象
const TS_TargetClass = PuertsUtil.LoadClass(UE.Game.NoOutsiders.UI.Lobby.WBP_Lobby.WBP_Lobby_C);

// 2. 声明 Mixin 接口并继承蓝图类，保留完整代码提示（IntelliSense）
interface LobbyView extends UE.Game.NoOutsiders.UI.Lobby.WBP_Lobby.WBP_Lobby_C { }

// 3. 实现自定义的 Mixin 逻辑类
class LobbyView {

}

// 4. 将 TS 类的方法注销混入到 UE 蓝图类中
PuertsUtil.Mixin(TS_TargetClass, LobbyView);
```

### 2. 注册 Mixin 路径

Mixin 代码编写完成后，需要前往 `MixinDefine.ts` 脚本中注册该 TS 文件的路径映射与分组配置，示例如下：

```typescript
export const PathConfig: Map<string, string> = new Map([
    ["@Root", "./TypeScript"],
    ["@Game", "./TypeScript/Game"],
])

type MixinGroupConfigType = {
    [Index in number]: string[];
}

export enum MixinGroupType
{
    Common,
}

export const MixinGroupConfig: MixinGroupConfigType = {
    [MixinGroupType.Common]: [
        "@Root/UI/LobbyView",
        "@Root/UI/LobbyPlayerItemView",
    ]
}
```
