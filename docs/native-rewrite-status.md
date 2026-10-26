# tuichuang 原生重构状态报告

> 分支：`native-rewrite`  
> 基线：0.1.0（`com.tuichuang.tuichuang`）  
> 最近构建：`build-out/native-rewrite/tuichuang-native-0.1.0-unsigned.hap`

## 1. 功能矩阵

| 功能 | 原生实现 | 状态 |
|---|---|---|
| 登录 | Cookie 导入 + 网页登录引导 | 部分 |
| 主页“为你推荐” | GraphQL/REST | 已实现 |
| 主页“正在关注” | REST / GraphQL | 已实现 |
| 主页分页 | cursor | 已实现 |
| 下拉刷新 | `Refresh` | 已实现 |
| 搜索 | `SearchTimeline` | 已实现 |
| 搜索分页 | cursor | 已实现 |
| 通知 | GraphQL + REST 回退 | 已实现 |
| 通知分页 | cursor | 已实现 |
| 我的 | 用户资料 + UserTweets | 已实现 |
| 其他用户主页 | `UserByScreenName` + UserTweets | 已实现 |
| 推文详情 | GraphQL + REST 双通道 | 已实现 |
| 评论 | conversation 解析 | 已实现 |
| 点赞/转推/回复/引用 | GraphQL mutation | 已实现 |
| 发帖 | 原生 ComposeView | 已实现 |
| 折叠屏分栏 | `SideBarContainer` + fold 监听 | 已实现 |
| 悬浮底栏 | 原生 Stack + 拖拽吸附 | 已实现 |
| 图片查看 | 全屏 + 双指缩放 | 已实现 |
| 视频播放 | ArkUI `Video` | 已实现 |
| 详情缓存/预取 | LRU 20 + 前 3 条 | 已实现 |
| 返回栈 | 媒体 → 详情/主页 → Tab → 退出 | 已实现 |
| 底部光带 | 动态渐变 | 已实现 |

## 2. 与 0.1.0 的差异

- 0.1.0 通过 ArkWeb 渲染 X 网页；原生分支所有主界面为 ArkUI。
- 登录仍保留一个 WebView 入口，仅用于首次抓 Cookie 和 queryId。
- 原生不依赖 X DOM，因此不再有顶部空白、重复标签栏、WebView 表面裁剪问题。
- 子窗口底栏已移除，改为同一窗口内悬浮组件。

## 3. 已知风险

1. **queryId 漂移**：`TweetDetail` / `SearchTimeline` / `UserTweets` 有回退常量，但 X 更新后会失效。
2. **REST 下线**：`statuses/show`、`conversation`、`notifications/all` 属于旧接口，可能被 X 关闭。
3. **登录**：纯 Cookie 导入时 queryId 发现依赖 bundle 扫描，首次可能失败；网页登录最稳。
4. **签名**：当前环境无设备可信证书，HAP 未签名，无法直接 `hdc install`。
5. **视觉**：字体、间距、动画曲线尚未逐像素对齐 0.1.0。

## 4. 构建

```bash
scripts/build-native.sh
```

## 5. 实机验证

见 `docs/native-rewrite-verification.md`。重点：

- 网页登录后主页是否加载；
- 折叠/展开详情是否全宽；
- 底栏拖拽与点击是否冲突；
- 详情 GraphQL 失败时 REST 是否可用；
- 通知分页是否继续加载。

## 6. 结论

核心原生链路已经可编译、可运行，主界面不再依赖 ArkWeb；但“完全对齐 0.1.0”仍缺实机验证和视觉打磨，登录 WebView 尚未移除。
