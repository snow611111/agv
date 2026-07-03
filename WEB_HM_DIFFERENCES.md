# Web → HarmonyOS 移植差异记录

## 无法保留的 Web 特性（需人工确认）

### 1. Element Plus UI 组件库 — 全部丢失

Web 版大量使用 Element Plus 组件，HM 版全部用 ArkUI 原生组件替代：

| Web (Element Plus) | HM (ArkUI) | 丢失的能力 |
|---|---|---|
| `el-table` (排序/筛选/分页) | `List` + `ListItem` | 列排序、筛选、拖拽调整列宽、固定列 |
| `el-pagination` (完整分页器) | 简单 Row + Button | 每页条数选择器、页码跳转 |
| `el-date-picker` (日期选择器) | 未实现 | 日期范围选择 → 改为 TextInput 手动输入 |
| `el-dialog` (动画弹窗) | Stack 遮罩 | 出入动画、拖拽、层级管理 |
| `el-card` (卡片容器) | Column + borderRadius | shadow 阴影样式 |
| `el-descriptions` (描述列表) | 手动 Text 行 | 自动对齐、响应式列数 |
| `el-tag` (标签) | Text + borderRadius | 内置颜色类型 |
| `el-upload` (拖拽上传) | 未实现 | 拖拽区域、进度条、缩略图预览 |
| `el-switch` (开关) | 未实现 | → 暂用 Radio 替代 |
| `el-slider` (滑块) | `Slider` 组件 | 基本可用 |
| `el-breadcrumb` (面包屑) | 未实现 | 导航层级 |
| `el-alert` (警告条) | 手动 Text + backgroundColor | 内置图标、关闭按钮、类型 |
| `el-radio-group` (单选组) | `Radio` 组件 | 按钮样式 |
| `@element-plus/icons-vue` (图标库) | Emoji / 无 | 全部 1500+ 图标 |

### 2. FLV 视频流解码 — WebView 方案

- Web: 使用 `mpegts.js` (MSE API) 在浏览器中解码 FLV → `<video>` 播放
- HM: ArkUI `Video` 组件不原生支持 FLV → 改用 WebView 加载 `rawfile/player.html`
- 风险: WebView 内 JS 性能可能不如原生浏览器，EasyPlayer WASM 可能无法正常运行
- 建议: 实测验证 WebView 方案；如不可行，需要后端加转码层 (FLV → HLS)

### 3. Vue 响应式系统 — 不同范式

| Web (Vue) | HM (ArkTS) |
|---|---|
| `ref()` / `reactive()` 自动追踪依赖 | `@State` / `@Prop` / `@Link` 手动声明 |
| `computed()` 自动缓存 | 需手动实现 getter |
| `watch()` 监听变化 | 需在 setter 中手动触发逻辑 |
| `v-model` 双向绑定 | `onChange` 回调手动同步 |
| 模板 `{{ }}` 插值 | ArkUI 声明式 build() |

### 4. CSS 样式系统 — 不同模型

- Web: CSS 类 (scoped)、Flexbox、Grid、动画、过渡、媒体查询
- HM: 链式 `.attribute()` 方法，部分样式需手写组件
- 丢失: `transition` 动画、`box-shadow`、`text-overflow: ellipsis`(可用 .textOverflow 替代)、CSS Grid (用 Flex 替代)

### 5. 运行时动态脚本加载

- Web: `loadScript(src)` 动态注入 `<script>` 标签加载 JS 库
- HM: 无此机制 — 所有资源必须预先放在 rawfile 中，通过 WebView 加载

---

## 功能对比: Web vs HM

| 功能 | Web | HM | 状态 |
|---|---|---|---|
| 系统自检 (4 项检查) | ✅ | ✅ | 完整移植 |
| 任务列表 + 搜索 | ✅ | ✅ (简化) | 缺日期筛选、编辑任务、分页跳转 |
| 任务 CRUD | ✅ | ✅ (简化) | 缺编辑任务弹窗 |
| 新建任务 + 启动 | ✅ | ✅ | 完整移植 |
| 系统设置 | ✅ | ✅ (简化) | 缺摄像头 RTSP 配置 UI |
| 巡检执行 - 视频 | ✅ (mpegts.js) | ⚠️ (WebView) | 需实测验证 |
| 巡检执行 - 车辆控制 | ✅ | ✅ | 完整移植 |
| 巡检执行 - 心跳 | ✅ | ✅ | 完整移植 |
| 巡检执行 - 缺陷列表 | ✅ | ✅ | 完整移植 |
| 巡检执行 - 刻度条 | ✅ | ✅ (简化) | 缺 CSS 动画 |
| Dify AI 缺陷分析 | ✅ | ✅ | 完整移植 |
| AI 巡检报告 | ✅ | ✅ | 需配置 API 地址 |
| 巡检历史 - 图片预览 | ✅ | ✅ | 完整移植 |
| 巡检历史 - 缺陷表 | ✅ | ✅ | 完整移植 |
| 摄像头调试 (2x2 网格) | ✅ | ✅ (简化) | 缺详细统计 |
| EasyPlayer 模式 | ✅ | ⚠️ (WebView) | 需实测验证 |

---

## 需要你手动做的事

1. **DevEco Studio 自动签名**: File → Project Structure → Signing Configs → 勾选自动签名
2. **配置 AI 服务**: 编辑 `AppConfig.ets` 中的 `REPORT_AI_API_URL` 和 `REPORT_AI_API_KEY`
3. **实测视频**: 运行后确认 WebView 中 FLV/HLS 播放是否正常
4. **连接巡线车网络**: 电脑需要连 `inhand` WiFi 才能访问 `192.168.2.57` 后端
