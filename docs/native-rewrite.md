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


## 10. Phase 2/3 进展

- 原生详情缓存 `DetailCache`（LRU 20），打开详情优先读缓存；
- 时间线加载后预取前 3 条详情；
- Tab 切换保留 Home/Search/Me 页面状态，不再重新加载；
- 悬浮底栏支持展开态左右移动，`Curve.Friction` 动画；
- 底栏增加模糊、半透明、描边，接近原 0.1.0 光感；
- 搜索、主页点击推文都打开原生详情。


## 11. Phase 3 进展

- 原生通知页：`NotificationsTimeline` GraphQL，展示消息与作者；
- 通知点击可打开对应推文详情；
- 详情缓存接入系统内存回调，内存压力时清空；
- 时间线前 3 条详情预取。


## 12. Phase 3 追加

- 原生时间线分页 cursor 修复，滚动到底加载下一页；
- 底部加载提示；
- “我的”页恢复原生分栏开关，持久化；
- 分栏关闭时展开态只显示单栏。


## 13. 媒体与引用推文

- `TweetItem` 增加视频、媒体类型、引用推文字段；
- 解析 `extended_entities.media` 的 video/animated_gif，选择最高码率 mp4；
- 解析 `quoted_status_result`，原生渲染引用推文卡片；
- 视频暂时展示封面 + 播放标识，播放器下一阶段接入。


## 14. 原生视频

- 列表视频封面点击进入全屏播放；
- 使用 ArkUI `Video` 组件 + `VideoController`；
- 支持 HLS/MP4 直链、自动播放、系统控件；
- 详情页视频同样可播放；
- 返回键优先关闭播放器。


## 15. 登录与媒体查看

- 新增原生 Cookie 导入登录页；
- 仍保留网页登录入口用于首次获取 Cookie 与 queryId；
- 图片点击进入原生全屏查看器，返回关闭；
- 视频点击进入原生播放器；
- 列表滚动索引写入 AppStorage，重新加载后恢复大致位置。


## 16. queryId 回退

- 无网页登录缓存时，`TweetDetail` / `SearchTimeline` / `CreateTweet` 使用已知 queryId 回退；
- 有网页登录抓取时仍优先使用实时 queryId；
- 减少纯 Cookie 登录后的首次失败等待。


## 17. 我的页资料

- 原生 `UserByRestId` 请求，从 Cookie `twid` 解析当前用户；
- 我的页显示头像、昵称、@handle、简介、关注/粉丝数；
- queryId 回退 `mxaYWwt52eAb6OAzYHMVzg`；
- 分栏开关和退出登录保持原生。


## 18. 底栏光感与资料页

- 底栏增加动态光带（`linearGradient` + `blur`，2.6s 往返）；
- 底栏保持 320vp 悬浮胶囊、模糊、描边、阴影；
- 我的页加载原生用户资料；
- queryId 回退支持 UserByRestId。


## 19. queryId 自动发现增强

- 扫描已登录入口 bundle 时，递归展开 `assets/*.js` 懒加载 chunk；
- 最多 40 个脚本，避免无限抓取；
- 目标：纯 Cookie 登录时也能自动发现 HomeTimeline / SearchTimeline / TweetDetail 等 queryId；
- 已知 queryId 仍作为最后回退。


## 20. 详情 REST 回退

- `TweetDetail` GraphQL 失败时回退 REST：
  - `statuses/show.json` 取主推文；
  - `2/timeline/conversation/<id>.json` 取评论；
- 避免 queryId 变化导致详情完全不可用。


## 21. 纯 Cookie 主页回退

- `QueryIds.hasBundles()` 判断是否有网页登录抓取的 JS；
- 没有 JS 缓存时，For You 直接优先 REST `home_timeline`，避免等待 queryId 扫描；
- REST 失败再走 GraphQL；
- 详情已有 GraphQL + REST 双通道。


## 22. 通知 REST 回退

- `NotificationsTimeline` GraphQL 失败时回退 `1.1/notifications/all.json`；
- 解析 `timeline.instructions.addEntries.notification`；
- 支持数字 ID 转字符串；
- 从 `globalObjects.users` 补全作者信息；
- 通知与详情都不再单点依赖 queryId。


## 23. 引用推文跳转与通知回退

- 引用推文卡片可点击，打开被引用推文详情；
- 通知 GraphQL 失败回退 REST；
- 引用推文详情复用详情缓存。


## 24. 图片缩放

- 图片查看器支持双指缩放 1x–4x；
- 单击重置为 1x；
- 返回键优先关闭查看器。


## 25. 我的帖子

- 新增 `UserTweets` GraphQL，queryId 回退 `OdBLACRZ0-9NikpJotaT7g`；
- 我的页加载当前用户最近帖子；
- 帖子支持详情、点赞、转推、回复、引用、媒体查看；
- 资料和帖子都使用原生组件。


## 26. 搜索分页

- `SearchTimeline` 支持 cursor；
- 搜索结果滚动到底自动加载下一页；
- cursor-bottom 正确解析；
- 保留 Top 产品类型。
