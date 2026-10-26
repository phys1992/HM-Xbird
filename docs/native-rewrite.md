# tuichuang 原生重构（ArkTS / ArkUI）

> 分支：`native-rewrite`  
> 基线：`v0.1.0`（`com.tuichuang.tuichuang`）  
> 目标：去掉 ArkWeb 界面封装，用 ArkTS/ArkUI 原生实现同等功能与界面。

## 1. 当前 0.1.0 功能盘点

| 模块 | 现有实现 | 用户可见行为 |
|---|---|---|
| 登录 | ArkWeb 加载 X 登录页，保存 Cookie + 抓取 GraphQL queryId | 登录一次后保持状态 |
| 主页 | 两个 WebView（为你推荐 / 正在关注）放入 Swiper | 左右滑动切换，系统动画 |
| 搜索 | 独立 WebView | 搜索页 |
| 通知 | 独立 WebView | 通知列表 |
| 我的 | 右侧抽屉 + 原生分栏设置 | 设置、分栏开关 |
| 推文详情 | 右栏 WebView | 展开时左列表/右详情评论 |
| 折叠屏 | 折叠角度/状态 + SideBarContainer | 折叠单栏、展开双栏 |
| 悬浮底栏 | 独立透明子窗口 `BarWindow` | 5 项、选中态、左右移动、模糊光感 |
| 发帖 | 原生 ComposeView + CreateTweet | 纯文本发帖 |
| 返回 | UIAbility/页面/子窗口返回桥接 | 右栏→左栏→主页→退出 |
| 缓存 | 多 WebView 保留 + prefetchPage + LRU 20 | 减少重复加载 |
| 图片/视频 | X 网页原生渲染 | 图片、视频、引用、广告 |

## 2. 现有界面结构

```text
状态栏
┌─────────────────────────────┐
│ 原生标签栏 30px             │  为你推荐 / 正在关注
├──────────────┬──────────────┤
│ 左栏时间线   │ 右栏推文详情 │  展开态
│              │ 与评论       │
├──────────────┴──────────────┤
│ 悬浮底栏：主页 搜索 + 通知 我的 │
└─────────────────────────────┘

折叠态：单栏时间线，底栏悬浮
```

视觉要点：

- 白底、细分割线、蓝色 `#1D9BF0` 选中态；
- 底部胶囊 320vp、圆角 30、白色半透明 + 模糊 + 光带；
- 选中项图标/文字变蓝，底部 4vp 圆点；
- 折叠屏展开时左右各 50%，中间可拖动；
- 页面切换使用系统动画曲线。

## 3. 原生重构架构

```text
ArrowTS UI
├─ pages/NativeIndex.ets          应用壳
├─ view/NativeShell.ets           底部导航 + 折叠分栏
├─ view/feed/HomeFeed.ets         时间线
├─ view/tweet/TweetDetail.ets     详情 + 评论
├─ view/search/SearchPage.ets
├─ view/notifications/NotifyPage.ets
├─ view/profile/MePage.ets
├─ view/compose/ComposePage.ets
└─ component/                      推文卡片、媒体、操作栏

数据层
├─ api/GraphqlClient.ets          Cookie + queryId + 统一请求
├─ api/TimelineApi.ets            首页/关注/搜索/详情/评论
├─ api/TweetActions.ets           点赞/转推/回复/书签
├─ model/Tweet.ets                统一数据模型
├─ store/SessionStore.ets         Cookie / queryId / 设置
└─ store/TimelineCache.ets        分页缓存 + LRU + 内存回收

平台能力
├─ display 折叠状态/角度
├─ SideBarContainer / Navigation 分栏
├─ AVPlayer / Image 媒体
├─ preferences / relationalStore 本地缓存
└─ UIAbility 返回
```

## 4. 关键设计

### 4.1 登录

完全原生登录需要复刻 X 的登录 Flow，易触发风控。建议二选一：

1. **一次性 ArkWeb 登录**：只用于拿 Cookie，登录后立即销毁，不参与任何界面；
2. **Cookie 导入**：用户从浏览器手动导入 `auth_token`/`ct0`，完全无 WebView。

原生重构的 UI 不依赖 ArkWeb；登录通道单独隔离。

### 4.2 数据

- 统一 `GraphqlClient`，维护 queryId 缓存；
- 时间线、详情、评论、搜索、通知全部映射到强类型 `Tweet`；
- 分页 cursor、去重、错误重试；
- 图片/视频 URL 从实体中提取，原生渲染；
- 广告/推荐条目按类型过滤或占位。

### 4.3 折叠屏

- `display.getFoldStatus()` + `foldAngleChange` 决定单/双栏；
- 双栏用 `SideBarContainer`，左列表右详情；
- 底部导航用普通 ArkUI `Stack` 悬浮，不再使用子窗口；
- 返回：右详情栈 → 左列表 → 主页 → 退出。

### 4.4 缓存与预取

- 内存缓存按页面/游标保存 `Tweet`；
- 预取详情评论 = 提前请求 GraphQL，不再用 WebView prefetch；
- LRU 上限 + `onMemoryLevel` 清理；
- 列表滚动锚点保留在数据层，不依赖 DOM。

## 5. 避免的坑

| 已踩坑 | 原生方案 |
|---|---|
| X DOM 结构频繁变化 | 不再依赖 DOM |
| ArkWeb 双 WebView 表面不裁剪 | 不适用 |
| 子窗口 z-order 盖住底栏 | 底栏在同一 ArkUI 层 |
| 顶部空白/标签栏重复 | 原生布局直接计算 |
| 注入时机导致白屏/隐藏内容 | 无注入 |
| safe area 写死 | 用 `AvoidArea` + `onAreaChange` |
| 返回历史无限 | 显式页面栈 |
| WebView 内存增长 | 数据缓存 + LRU + 系统内存回调 |
| 页面滚动位置漂移 | 原生列表保留 Index/offset |

## 6. 分阶段实施

### Phase 1：可运行原生壳

- 原生底部悬浮栏、4 个 Tab；
- 原生 Home 时间线（复用 `XApi`）；
- 折叠屏单/双栏；
- Cookie 登录态读取；
- 保留 ArkWeb 仅作为登录入口（可移除）。

### Phase 2：详情与交互

- 推文详情 + 评论；
- 点赞/转推/回复/引用；
- 图片/视频/链接卡片；
- 右栏返回栈。

### Phase 3：完整页面

- 搜索、通知、个人主页；
- 发帖、设置、分栏开关；
- 缓存、预取、内存回收；
- 视觉打磨与无障碍。

### Phase 4：移除登录 WebView

- 原生 Cookie 导入或完整登录；
- 删除 ArkWeb 依赖与权限；
- 回归测试折叠屏、返回、媒体、弱网。

## 7. 验收标准

- 应用启动不依赖任何网页；
- 折叠/展开不白屏、不重置滚动；
- 底栏始终在最上层；
- 返回层级明确；
- 20 条列表 + 详情评论可缓存；
- 与原 0.1.0 视觉一致（颜色、间距、选中态、动画）。


## 9. Phase 2 进展

- 原生 `XApi.tweetDetail` 接入 GraphQL `TweetDetail`；
- 展开态右栏显示主推文 + 评论列表；
- 折叠态详情占满单栏，可返回；
- 搜索页推文支持打开详情；
- 详情内支持点赞、转推、回复、引用入口；
- 详情接口失败时展示错误和重试，不白屏。
