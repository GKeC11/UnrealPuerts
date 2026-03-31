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

## `tsconfig.json` 配置示例

为了让路径别名正常工作，并在编译后正确替换输出的路径，请在项目根目录的 `tsconfig.json` 中添加如下配置：

```json
{
    "compilerOptions": {
        "target": "esnext",
        "module": "commonjs",
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

## 蓝图 Mixin 开发流程

### 1. 编写 Mixin 模板

当你需要为蓝图编写 TypeScript 逻辑时，可以参考以下 Mixin 模板（以 `LobbyView` 为例）：

```typescript
import * as UE from "ue";
import { PuertsUtil } from "@root/Framework/Util/PuertsUtil";

// 1. 加载目标蓝图类的 Class 对象
const TS_TargetClass = PuertsUtil.LoadClass(UE.Game.Game.UMG.Lobby.WBP_Lobby.WBP_Lobby_C);

// 2. 声明 Mixin 接口并继承蓝图类，保留完整代码提示（IntelliSense）
interface LobbyView extends UE.Game.Game.UMG.Lobby.WBP_Lobby.WBP_Lobby_C { }

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
    ["@UI", "./TypeScript/UI"],
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
        "@UI/LobbyView",
    ]
}
```