# 鸿蒙开发技术应用说明文档

> **项目名称**: 巡线车智能巡检系统 (xxc_hm)  
> **Bundle Name**: `com.example.xxc_hm`  
> **目标 SDK**: HarmonyOS 6.1.1(24) (API 24)  
> **兼容 SDK**: HarmonyOS 6.1.0(23)  
> **支持设备**: 手机 (Phone) / 平板 (Tablet)  
> **开发工具**: DevEco Studio  

---

## 目录

1. [项目概述](#1-项目概述)
2. [ArkTS 开发语言](#2-arkts-开发语言)
3. [ArkUI 声明式 UI 框架](#3-arkui-声明式-ui-框架)
4. [Stage 模型与 Ability 系统](#4-stage-模型与-ability-系统)
5. [HarmonyOS SDK Kit 体系](#5-harmonyos-sdk-kit-体系)
6. [页面路由与导航](#6-页面路由与导航)
7. [网络通信](#7-网络通信)
8. [WebView 混合开发](#8-webview-混合开发)
9. [状态管理](#9-状态管理)
10. [构建系统 Hvigor + ohpm](#10-构建系统-hvigor--ohpm)
11. [资源管理与国际化](#11-资源管理与国际化)
12. [测试框架](#12-测试框架)
13. [安全与代码规范](#13-安全与代码规范)
14. [应用架构总结](#14-应用架构总结)

---

## 1. 项目概述

本项目是一个基于 **HarmonyOS 原生技术栈**开发的地铁隧道 **AGV 巡线车智能巡检系统**客户端应用。它是从 Vue.js Web 应用完整移植到 HarmonyOS 平台的纯原生应用，利用鸿蒙生态的各项核心技术实现了：

- **系统自检**: 文件系统、数据库、AGV 车辆、摄像头通道四项诊断
- **任务管理**: 巡检任务的完整 CRUD 与生命周期管理
- **巡检执行**: 实时视频监控、车辆远程控制、心跳状态监测、缺陷标注
- **巡检历史**: 缺陷图片预览、数据表格展示、AI 报告生成
- **AI 分析**: 集成 Dify AI 平台进行隧道缺陷智能分析

### 项目目录结构

```
xxc_hm/
├── AppScope/app.json5              # 应用级清单
├── entry/                          # 主模块 (HAP)
│   ├── src/main/
│   │   ├── ets/                    # ArkTS 源代码
│   │   │   ├── entryability/       # UIAbility 入口
│   │   │   ├── entrybackupability/ # 备份扩展能力
│   │   │   ├── pages/              # 9 个页面组件
│   │   │   └── common/             # 公共模块
│   │   │       ├── models/         # 数据模型/接口
│   │   │       ├── services/       # API 服务层
│   │   │       └── utils/          # 工具类
│   │   ├── resources/              # 资源文件
│   │   │   ├── base/               # 基础资源
│   │   │   ├── dark/               # 深色模式资源
│   │   │   └── rawfile/            # 原始文件 (WebView 加载用)
│   │   └── module.json5            # 模块清单
│   └── build-profile.json5         # 模块构建配置
├── hvigor/                         # Hvigor 构建系统
├── build-profile.json5             # 项目级构建配置
├── hvigorfile.ts                   # 项目级构建入口
├── oh-package.json5                # ohpm 依赖管理
└── code-linter.json5               # 代码规范配置
```

---

## 2. ArkTS 开发语言

### 2.1 语言特性

**ArkTS** 是 HarmonyOS 官方推荐的开发语言，它是 TypeScript 的静态类型超集，专为鸿蒙应用开发设计。项目中所有源文件均使用 `.ets` 扩展名。

**核心优势**:
- 在 TypeScript 基础上增加了声明式 UI 能力
- 编译期类型检查，减少运行时错误
- 原生支持 ArkUI 框架的装饰器和 API

### 2.2 类型系统应用

项目中充分利用了 ArkTS 的静态类型系统进行接口定义和数据建模：

```typescript
// TaskModels.ets —— 数据接口定义示例
export interface ApiResponse<T> {
  code: number
  msg: string
  data?: T
  rows?: T[]
  total?: number
}

export interface TaskInfo {
  id: number
  taskCode: string
  taskName: string
  taskStatus: string
  creator: string
  executor: string
  taskTrip: number
  createTime: string
}
```

### 2.3 与 TypeScript 的区别

| 特性 | TypeScript (Web) | ArkTS (HarmonyOS) |
|------|-----------------|-------------------|
| 文件扩展名 | `.ts` | `.ets` |
| UI 描述 | 无 (需配合框架) | 内置 `build()` 方法 |
| 装饰器 | `@Component` 等实验性 | `@State`/`@Prop`/`@Link` 原生支持 |
| 模块导入 | 标准 ES Module | `@kit.*` 命名空间导入 |
| 运行时 | Node.js/浏览器 | ArkCompiler (方舟编译器) |

---

## 3. ArkUI 声明式 UI 框架

### 3.1 框架概述

**ArkUI** 是 HarmonyOS 的核心 UI 框架，本项目全面使用其声明式编程范式构建用户界面。每个页面都是一个带有 `@Entry` 和 `@Component` 装饰器的 `struct`。

### 3.2 核心装饰器

| 装饰器 | 用途 | 示例 |
|--------|------|------|
| `@Entry` | 标记页面入口组件 | `@Entry @Component struct Index {}` |
| `@Component` | 标记可复用组件 | `@Component struct MyCard {}` |
| `@State` | 组件内部响应式状态 | `@State taskId: number = 0` |
| `@Prop` | 父→子单向传递 | `@Prop title: string` |
| `@Link` | 父子双向绑定 | `@Link isChecked: boolean` |
| `@Builder` | 局部 UI 构建函数 | `@Builder infoRow() {}` |

### 3.3 声明式 build() 方法

每个组件通过 `build()` 方法声明 UI 结构，使用链式 API 设置属性：

```typescript
// Index.ets —— 启动页示例
@Entry
@Component
struct Index {
  @State loading: boolean = true

  build() {
    Column() {
      Text('巡线车智能巡检系统')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#303133')
      
      LoadingProgress()
        .width(36)
        .height(36)
        .color('#67C23A')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F0F2F5')
  }
}
```

### 3.4 布局容器

项目中使用了以下 ArkUI 布局容器构建复杂界面：

| 容器 | 说明 | 使用场景 |
|------|------|---------|
| `Column()` | 垂直布局 | 页面主体、表单、卡片内容 |
| `Row()` | 水平布局 | 标题栏、按钮组、信息行 |
| `Stack()` | 层叠布局 | 视频覆盖层、弹窗遮罩 |
| `List()` + `ListItem()` | 虚拟滚动列表 | 任务列表、缺陷列表 |
| `Grid()` + `GridItem()` | 网格布局 | 4 路摄像头调试页面 |
| `Scroll()` | 滚动容器 | 长内容页面 |

### 3.5 条件渲染与循环渲染

```typescript
// 条件渲染 —— 弹窗显隐
if (this.showFlawDialog && this.currentFlaw) {
  Column() { /* 缺陷详情弹窗 */ }
}

// 循环渲染 —— 摄像头切换按钮
ForEach([1, 2, 3, 4], (i: number) => {
  Button('摄像头' + i)
    .backgroundColor(this.cam === i ? '#67C23A' : '#FFFFFF')
    .onClick(() => { this.switchCam(i) })
})
```

### 3.6 链式属性 API

ArkUI 采用链式调用风格设置组件属性，本项目大量使用以下 API：

```typescript
Text('任务编号')
  .fontSize(11)           // 字体大小
  .fontColor('#909399')   // 字体颜色
  .fontWeight(FontWeight.Medium)  // 字重
  .width(80)              // 宽度
  .maxLines(1)            // 最大行数
  .textOverflow({ overflow: TextOverflow.Ellipsis })  // 文本溢出省略
  
Column()
  .width('100%')
  .backgroundColor('#FFFFFF')
  .borderRadius(6)
  .border({ width: 1, color: '#EBEEF5' })
  .padding({ left: 14, right: 14 })
  .clip(true)
```

### 3.7 交互事件

```typescript
// 点击事件
Button('完成巡检')
  .onClick(() => this.onComplete())

// 触摸事件 (按下/抬起)
Button('前进')
  .onTouch((event: TouchEvent) => {
    if (event.type === TouchType.Down) this.onMoveChange('forward')
    else this.onMoveChange('stop')
  })

// 值变化事件
TextInput({ text: this.flawRemark })
  .onChange((v: string) => { this.flawRemark = v })

Radio({ value: 'yes', group: 'flawConfirmed' })
  .onChange((v: boolean) => { this.flawConfirmed = v })
```

---

## 4. Stage 模型与 Ability 系统

### 4.1 Stage 模型概述

本项目采用 HarmonyOS **Stage 模型**（新一代应用模型，替代早期的 FA 模型），通过 `module.json5` 声明：

```json5
// module.json5
{
  "module": {
    "name": "entry",
    "type": "entry",
    "mainElement": "EntryAbility",
    "apiVersion": "stageMode",   // 使用 Stage 模式
    "deviceTypes": ["phone", "tablet"]
  }
}
```

### 4.2 UIAbility 生命周期

`EntryAbility` 是应用的唯一 UIAbility 入口，实现了完整的生命周期回调：

```typescript
// EntryAbility.ets
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 设置颜色模式
    this.context.getApplicationContext()
      .setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 加载主页面
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) { hilog.error(/* ... */) }
    })
  }

  onForeground(): void  { /* 应用回到前台 */ }
  onBackground(): void  { /* 应用进入后台 */ }
  onDestroy(): void     { /* 应用销毁 */ }
}
```

### 4.3 BackupExtensionAbility

项目还实现了数据备份扩展能力，支持应用数据的备份与恢复：

```typescript
// EntryBackupAbility.ets
export default class EntryBackupAbility extends BackupExtensionAbility {
  onBackup(): void   { /* 触发数据备份 */ }
  onRestore(bundleVersion: BundleVersion): void { /* 触发数据恢复 */ }
}
```

### 4.4 权限声明

在 `module.json5` 中声明应用所需权限：

```json5
"requestPermissions": [
  {
    "name": "ohos.permission.INTERNET"   // 网络访问权限
  }
]
```

---

## 5. HarmonyOS SDK Kit 体系

HarmonyOS 将系统能力以 **Kit（套件）** 的形式组织，本项目使用了以下官方 Kit：

### 5.1 Kit 使用汇总

| Kit 名称 | 导入路径 | 核心 API | 使用场景 |
|----------|---------|---------|---------|
| **AbilityKit** | `@kit.AbilityKit` | `UIAbility`, `Want`, `AbilityConstant`, `ConfigurationConstant` | 应用生命周期管理 |
| **ArkUI** | `@kit.ArkUI` | `router`, `promptAction`, `window` | 页面路由、Toast 提示、窗口管理 |
| **NetworkKit** | `@kit.NetworkKit` | `http.createHttp()` | REST API 请求 |
| **ArkWeb** | `@kit.ArkWeb` | `webview.WebviewController` | WebView 管理 |
| **PerformanceAnalysisKit** | `@kit.PerformanceAnalysisKit` | `hilog` | 日志输出 |
| **BasicServicesKit** | `@kit.BasicServicesKit` | `BusinessError` | 错误类型定义 |
| **CoreFileKit** | `@kit.CoreFileKit` | `BackupExtensionAbility`, `BundleVersion` | 数据备份恢复 |

### 5.2 Kit 使用示例

```typescript
// 路由导航
import { router } from '@kit.ArkUI'
router.pushUrl({ url: 'pages/ExecutePage', params: { id: taskId } })

// Toast 提示
import { promptAction } from '@kit.ArkUI'
promptAction.showToast({ message: '巡检已完成' })

// HTTP 请求
import { http } from '@kit.NetworkKit'
const req = http.createHttp()
const resp = await req.request(url, {
  method: http.RequestMethod.GET,
  expectDataType: http.HttpDataType.STRING,
  connectTimeout: 5000,
  readTimeout: 5000,
})

// 日志
import { hilog } from '@kit.PerformanceAnalysisKit'
hilog.info(0x0000, 'testTag', 'Ability onCreate')

// WebView
import { webview } from '@kit.ArkWeb'
private webController: webview.WebviewController = new webview.WebviewController()
this.webController.runJavaScript('startFlv("' + url + '")')
```

---

## 6. 页面路由与导航

### 6.1 路由注册

HarmonyOS 的页面路由通过 `main_pages.json` 声明式注册：

```json
// resources/base/profile/main_pages.json
{
  "src": [
    "pages/Index",
    "pages/SystemCheck",
    "pages/TaskList",
    "pages/ExecutePage",
    "pages/TaskHistory",
    "pages/TaskInfoTest",
    "pages/FlvTest",
    "pages/EasyPlayerTest",
    "pages/CameraTest"
  ]
}
```

### 6.2 页面导航

```typescript
// 带参数跳转
router.pushUrl({
  url: 'pages/ExecutePage',
  params: { id: this.taskId, taskCode: this.taskCode }
})

// 返回上一页
router.back()

// 接收参数
const params = router.getParams() as Record<string, Object>
this.taskId = (params['id'] as number) || 0
```

### 6.3 应用导航流程

```
Index (启动页, 300ms)
  → SystemCheck (系统自检)
    → TaskList (任务列表)
      → ExecutePage (巡检执行)
      → TaskHistory (巡检历史)
    → TaskInfoTest (API 调试)
    → FlvTest (FLV 播放测试)
    → EasyPlayerTest (EasyPlayer 测试)
    → CameraTest (摄像头调试)
```

---

## 7. 网络通信

### 7.1 HTTP 客户端

项目使用 `@kit.NetworkKit` 的 `http.createHttp()` 进行网络通信，封装了通用请求方法：

```typescript
// ApiService.ets —— 通用 GET 请求
async function apiGet<T>(url: string, timeout: number = 5000): Promise<ApiResponse<T>> {
  const req = http.createHttp()
  try {
    const resp = await req.request(url, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: timeout,
      readTimeout: timeout,
    })
    req.destroy()
    if (resp.responseCode === 200) {
      return JSON.parse(resp.result as string) as ApiResponse<T>
    }
    return { code: -1, msg: 'HTTP ' + resp.responseCode } as ApiResponse<T>
  } catch (e) {
    req.destroy()
    return { code: -1, msg: 'Network error' } as ApiResponse<T>
  }
}
```

### 7.2 RESTful API 设计

封装了完整的 HTTP 方法：`apiGet`、`apiPost`、`apiPut`、`apiDelete`，覆盖所有后端接口：

- 系统自检: `GET /system/check/fs|db|agv|cam`
- 任务 CRUD: `GET|POST|PUT|DELETE /agv/task/*`
- 车辆控制: `POST /agv/movement/forward|backward|stop`
- 心跳状态: `GET /agv/movement/heartbeat`
- 缺陷管理: `GET|PUT /agv/flaw/*`
- AI 分析: `POST /v1/chat-messages` (Dify API)

### 7.3 轮询机制

巡检执行页面使用 `setInterval` 实现实时数据轮询：

```typescript
this.timer = setInterval(() => {
  this.pollCount++
  this.fetchHeartbeat()          // 每 2 秒刷新心跳
  if (this.pollCount % 5 === 0)  // 每 10 秒刷新缺陷列表
    this.fetchFlaws()
}, 2000)
```

---

## 8. WebView 混合开发

### 8.1 为什么需要 WebView

由于 ArkUI 原生 `Video` 组件不直接支持 FLV 格式的视频流解码，项目采用 **WebView + JavaScript 解码库** 的混合方案来实现视频播放功能。

### 8.2 技术架构

```
ArkUI Web 组件
  ↓ 加载
rawfile/player.html (本地 HTML)
  ↓ 引入
mpegts.js / EasyPlayer WASM
  ↓ 处理
FLV → MSE → Canvas/Video 渲染
```

### 8.3 WebView 初始化

```typescript
// ExecutePage.ets
private webController: webview.WebviewController = new webview.WebviewController()

build() {
  Web({
    src: 'resource://rawfile/player.html',  // 加载 rawfile 中的 HTML
    controller: this.webController
  })
    .javaScriptAccess(true)       // 启用 JS 执行
    .backgroundColor(Color.Black)
    .onPageEnd(() => { this.onVideoReady() })
}
```

### 8.4 ArkTS ↔ JavaScript 通信

```typescript
// ArkTS 端注入 JS 代码控制播放
startFlvStream(): void {
  const url = 'http://192.168.2.57/webrtc-api/live/cam1_01.flv'
  this.webController.runJavaScript('startFlv("' + url + '")')
}
```

### 8.5 第三方 JS 库

项目中通过 `rawfile/` 目录引入以下视频解码库：

| 库文件 | 用途 |
|--------|------|
| `mpegts.min.js` | FLV 流解封装与 MSE 播放 |
| `hls.min.js` | HLS 流播放 |
| `EasyPlayer-lib.js` | EasyPlayer 核心库 |
| `EasyPlayer-pro.js` | EasyPlayer Pro (WASM 硬件解码) |
| `EasyPlayer-pro.wasm` | WebAssembly 解码器 |
| `EasyPlayer-snap.wasm` | WebAssembly 截图模块 |
| `EasyPlayer-decode.js` | WASM 解码桥接模块 |

---

## 9. 状态管理

### 9.1 @State 响应式状态

项目采用 ArkUI 原生的 `@State` 装饰器进行组件状态管理，替代 Web 版 Vue 的 `ref()/reactive()`：

```typescript
@Entry
@Component
struct ExecutePage {
  // 页面路由参数
  @State taskId: number = 0
  
  // 视频状态
  @State cam: number = 1
  @State videoReady: boolean = false
  
  // 车辆状态
  @State sysTime: string = '--'
  @State distance: string = '0.00'
  @State progressPercent: number = 0
  @State moveDirection: string = 'stop'
  
  // 缺陷数据
  @State flawList: Record<string, Object>[] = []
  @State showFlawDialog: boolean = false
  @State aiLoading: boolean = false
  @State aiResult: string = ''
}
```

### 9.2 Vue → ArkTS 状态管理对比

| 概念 | Vue 3 | ArkTS (ArkUI) |
|------|-------|---------------|
| 响应式基本类型 | `ref()` | `@State` |
| 响应式对象 | `reactive()` | `@State` |
| 计算属性 | `computed()` | 手动实现 getter |
| 侦听器 | `watch()` | setter 中手动触发 |
| 双向绑定 | `v-model` | `onChange` 回调同步 |
| 父→子传值 | `props` | `@Prop` |
| 父子双向 | `v-model` + `emit` | `@Link` |
| 模板语法 | `{{ expression }}` | `build()` 内表达式 |

---

## 10. 构建系统 Hvigor + ohpm

### 10.1 Hvigor 构建系统

**Hvigor** 是 HarmonyOS 新一代构建系统，基于 TypeScript 编写，替代早期的 Gradle 方案。

**项目级配置** (`hvigorfile.ts`):
```typescript
import { appTasks } from '@ohos/hvigor-ohos-plugin'
export default { system: appTasks, plugins: [] }
```

**构建配置** (`build-profile.json5`):
```json5
{
  "app": {
    "signingConfigs": [/* SHA256withECDSA 签名 */],
    "products": [{
      "name": "default",
      "runtimeOS": "HarmonyOS",
      "targetSdkVersion": "6.1.1(24)",
      "compatibleSdkVersion": "6.1.0(23)"
    }],
    "buildModeSet": [
      { "name": "debug" },
      { "name": "release" }
    ]
  }
}
```

### 10.2 ohpm 包管理器

**ohpm** (OpenHarmony Package Manager) 是鸿蒙生态的包管理工具，从 `https://ohpm.openharmony.cn/ohpm/` 注册中心拉取依赖。

**开发依赖** (`oh-package.json5`):
```json5
{
  "modelVersion": "6.1.1",
  "devDependencies": {
    "@ohos/hypium": "1.0.25",    // 测试框架
    "@ohos/hamock": "1.0.0"      // Mock 框架
  }
}
```

### 10.3 代码混淆

Release 构建支持代码混淆，配置文件为 `obfuscation-rules.txt`：

```json5
// entry/build-profile.json5
"buildOption": {
  "arkOptions": {
    "obfuscation": {
      "ruleOptions": {
        "enable": false,                       // 当前关闭
        "files": ["./obfuscation-rules.txt"]
      }
    }
  }
}
```

---

## 11. 资源管理与国际化

### 11.1 资源目录结构

```
resources/
├── base/                        # 基础资源 (默认)
│   ├── element/
│   │   ├── string.json          # 字符串资源
│   │   ├── color.json           # 颜色资源
│   │   └── float.json           # 浮点数值资源
│   ├── media/
│   │   ├── background.png       # 应用图标背景层
│   │   ├── foreground.png       # 应用图标前景层
│   │   └── startIcon.png        # 启动图标
│   └── profile/
│       ├── main_pages.json      # 页面路由表
│       └── backup_config.json   # 备份配置
├── dark/                        # 深色模式资源
│   └── element/
│       └── color.json           # 深色模式颜色
└── rawfile/                     # 原始文件 (直接按路径访问)
    ├── player.html
    ├── player-easy.html
    ├── mpegts.min.js
    ├── hls.min.js
    ├── EasyPlayer-*.js
    └── EasyPlayer-*.wasm
```

### 11.2 自适应图标

应用使用分层图标 (Layered Image) 实现自适应效果：

```json5
// app.json5
{
  "icon": "$media:layered_image"
}
```

Icon 由 `background.png`（背景层）和 `foreground.png`（前景层）组合而成，系统根据设备形态自动适配形状和尺寸。

### 11.3 字符串国际化

```json
// resources/base/element/string.json
{
  "string": [
    { "name": "module_desc", "value": "巡线车智能巡检系统" },
    { "name": "EntryAbility_desc", "value": "主入口能力" },
    { "name": "EntryAbility_label", "value": "巡线车巡检" }
  ]
}
```

在代码中通过 `$string:key` 引用，在 `module.json5` 中通过 `$string:module_desc` 绑定。

### 11.4 Dark Mode 支持

项目在 `resources/dark/element/color.json` 中定义了深色模式的配色方案，系统切换深色模式时自动应用。

---

## 12. 测试框架

### 12.1 Hypium 测试框架

HarmonyOS 官方测试框架 **Hypium** 提供类似 Jest/Mocha 的测试体验：

```typescript
// 测试结构
import { describe, it, expect } from '@ohos/hypium'

describe('ApiService', () => {
  it('should return heartbeat data', async () => {
    const result = await ApiService.getHeartbeat()
    expect(result.code).assertEqual(200)
  })
})
```

### 12.2 Hamock Mock 框架

**Hamock** 提供依赖模拟能力，用于隔离测试：

```typescript
import { mock } from '@ohos/hamock'
// 模拟 HTTP 请求，避免真实网络调用
```

---

## 13. 安全与代码规范

### 13.1 代码规范 (code-linter.json5)

项目配置了严格的代码检查规则：

```json5
{
  "files": ["**/*.ets"],
  "ruleSet": [
    "@performance/recommended",
    "@typescript-eslint/recommended"
  ],
  "security": {
    "no-unsafe-aes": "error",     // 禁止不安全的 AES 使用
    "no-unsafe-hash": "error",    // 禁止不安全的哈希算法
    "no-unsafe-rsa-encrypt": "error",    // 禁止不安全的 RSA 加密
    "no-unsafe-3des": "error"     // 禁止不安全的 3DES 算法
  }
}
```

### 13.2 应用签名

HarmonyOS 应用必须经过数字签名才能安装运行，项目使用 `SHA256withECDSA` 签名算法：

```json5
// build-profile.json5
"signingConfigs": [{
  "name": "default",
  "type": "HarmonyOS",
  "material": {
    "certpath": "~/.ohos/config/default_debug.p7b",
    "storepath": "~/.ohos/config/default_debug.p12",
    "profile": "~/.ohos/config/default_debug.p7b"
  }
}]
```

---

## 14. 应用架构总结

### 14.1 技术架构图

```
┌─────────────────────────────────────────────────┐
│                   应用层 (Pages)                   │
│  Index → SystemCheck → TaskList → ExecutePage    │
│                    → TaskHistory                  │
│                    → CameraTest / FlvTest 等       │
├─────────────────────────────────────────────────┤
│              公共层 (Common)                       │
│  ┌───────────┬─────────────┬──────────────────┐  │
│  │ Models    │ Services    │ Utils             │  │
│  │ 数据类型   │ API 封装     │ 格式化/配置        │  │
│  └───────────┴─────────────┴──────────────────┘  │
├─────────────────────────────────────────────────┤
│           HarmonyOS SDK Kit 层                    │
│  ┌─────────┬─────────┬──────────┬────────────┐  │
│  │ArkUI    │NetworkKit│ArkWeb    │AbilityKit  │  │
│  │路由/UI  │HTTP     │WebView   │生命周期     │  │
│  └─────────┴─────────┴──────────┴────────────┘  │
├─────────────────────────────────────────────────┤
│          ArkCompiler (方舟编译器)                  │
│        ArkTS → 字节码 → 方舟运行时                 │
└─────────────────────────────────────────────────┘
```

### 14.2 架构特点

1. **Stage 模型单 HAP 架构**: 整个应用作为一个 entry 模块，单一 UIAbility 入口，简洁清晰。

2. **声明式 UI + 手动状态管理**: 使用 ArkUI 声明式 `build()` 方法描述 UI，通过 `@State` 装饰器实现响应式更新，不依赖第三方状态管理库。

3. **WebView 混合方案处理视频**: 利用 WebView 加载 JS 解码库弥补 ArkUI 原生组件对 FLV 格式支持的不足，实现视频流播放。

4. **直接 HTTP 调用模式**: 通过 `ApiService` 工具类封装 `@kit.NetworkKit` 的 HTTP 能力，页面直接调用服务方法。

5. **轮询实现实时数据**: 使用 `setInterval()` 定期轮询后端心跳和缺陷数据，保持巡检页面的数据实时性。

6. **AI 能力集成**: 通过 HTTP API 对接 Dify AI 平台，实现隧道缺陷的智能分析与报告生成。

### 14.3 鸿蒙技术应用清单

| 技术领域 | 使用的鸿蒙技术 |
|----------|---------------|
| 编程语言 | **ArkTS** (.ets) |
| UI 框架 | **ArkUI** 声明式 UI (`@Entry`, `@Component`, `@State`, `build()`) |
| 应用模型 | **Stage 模型** (`UIAbility`, `ExtensionAbility`) |
| 组件化 | `@Component`, `@Builder`, `@Prop`, `@Link` |
| 布局系统 | `Column`, `Row`, `Stack`, `List`, `Grid`, `Scroll` |
| 页面路由 | `@kit.ArkUI` → `router.pushUrl()` / `router.back()` |
| 网络请求 | `@kit.NetworkKit` → `http.createHttp()` |
| WebView | `@kit.ArkWeb` → `webview.WebviewController` |
| 日志系统 | `@kit.PerformanceAnalysisKit` → `hilog` |
| 备份恢复 | `@kit.CoreFileKit` → `BackupExtensionAbility` |
| 构建系统 | **Hvigor** + **ohpm** |
| 代码规范 | `code-linter.json5` + `@typescript-eslint` |
| 资源配置 | `resources/base|dark` + 分层图标 + `rawfile` |
| 测试框架 | **Hypium** + **Hamock** |
| 应用签名 | `SHA256withECDSA` 数字签名 |

---

## 附录: 参考链接

- [HarmonyOS 开发者文档](https://developer.huawei.com/consumer/cn/harmonyos/)
- [ArkUI 开发指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkui-overview)
- [ArkTS 语言介绍](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-get-started)
- [Stage 模型概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/stage-model-development-overview)
- [Hvigor 构建工具](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hvigor)
- [ohpm 包管理](https://ohpm.openharmony.cn/)

---

> **文档版本**: v1.0  
> **更新日期**: 2026-07-10  
> **维护者**: 巡线车开发团队
