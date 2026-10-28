# HM-Xbird（ArkTS 原生）

不依赖 Flutter 的纯 ArkTS 客户端。当前完成第一里程碑：

- 纯 ArkTS 工程，`hvigorw assembleHap` 可直接构建；
- 登录页使用系统 ArkWeb 组件打开 `x.com/i/flow/login`；
- 通过 `webview.WebCookieManager.fetchCookie('https://x.com')` 读取 Cookie
  （包含 HttpOnly 的 `auth_token`，解决 Flutter 方案里账号存不下的问题）；
- Cookie 存入 Preferences，重启后保持登录；
- 登录后进入 X 风格四标签壳：Home / Search / Notifications / Messages；
- 退出登录会清空 Cookie。

## 构建

工程路径不能含中文，需要复制到 ASCII 路径构建：

```bash
cp -a HM-Xbird /tmp/HM-Xbird-build && cd /tmp/xh
export DEVECO_SDK_HOME=/path/to/command-line-tools/sdk
export PATH=/path/to/command-line-tools/bin:/path/to/command-line-tools/tool/node/bin:$PATH
hvigorw assembleHap --mode module -p module=entry@default \
  -p product=default -p buildMode=debug --no-daemon
```

产物：`entry/build/default/outputs/default/HM-Xbird-unsigned.hap`（约 78 KB，
未签名）。

## 第二里程碑（2026-10-26）

- `api/QueryIds.ets`：抓取已登录的 x.com 页面与 JS bundle，按 operation 名解析 `queryId`；
- `api/XApi.ets`：请求 `HomeLatestTimeline`（GraphQL，读取 features），解析推文；
- `model/TweetItem.ets`：原生推文模型；
- `view/HomeView.ets`：原生时间线列表（头像、昵称、正文、图片、互动数、下拉/触底加载、刷新）；
- 构建产物约 128 KB。

## 下一步

1. `api/QueryIds.ets`：运行时从 x.com 页面 JS 解析 GraphQL queryId；
2. `api/XApi.ets`：请求 `HomeLatestTimeline`，解析推文；
3. 原生 Home 列表 / 推文卡片 / 详情页；
4. 点赞、转推、发推、回复、引用（移植 Dart 的写接口逻辑）；
5. `x-client-transaction-id` 的 ArkTS 移植；
6. 折叠屏双栏、Mate X7 悬停。


## 本地构建与发布

本项目不使用在线 CI，发布产物在本地编译后手动上传 GitHub Release：

```bash
hvigorw assembleHap --mode module -p module=entry@default   -p product=default -p buildMode=debug --no-daemon

cp entry/build/default/outputs/default/HM-Xbird-unsigned.hap    build-out/HM-Xbird-<version>-unsigned.hap
```

然后在 GitHub 仓库的 Releases 页面手动上传 HAP 和用户说明。

