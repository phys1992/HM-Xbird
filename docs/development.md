# X Harmony（ArkTS 原生，B 方案）

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
cp -a x-harmony /tmp/xh && cd /tmp/xh
export DEVECO_SDK_HOME=/path/to/command-line-tools/sdk
export PATH=/path/to/command-line-tools/bin:/path/to/command-line-tools/tool/node/bin:$PATH
hvigorw assembleHap --mode module -p module=entry@default \
  -p product=default -p buildMode=debug --no-daemon
```

产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`（约 78 KB，
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


## GitHub Actions

`.github/workflows/build-hap.yml` 会在：

- 手动触发（workflow_dispatch）；
- 推送 `v*` tag；

时构建 HAP，并在 tag 构建时创建 GitHub Release。

前置条件：

1. 在仓库 Secrets 中添加 `DEVECO_CLI_URL`，指向 Huawei DevEco command-line-tools 的 zip 下载地址；
   如果 SDK zip 超过 GitHub Release 单文件 2GiB 限制，拆成两部分分别上传，并额外添加 `DEVECO_CLI_URL_2`；
2. zip 内需包含 `bin/`、`sdk/`、`tool/node/`；
3. 不要把 SDK 提交到仓库；
4. 构建产物为未签名 HAP，安装方式见 Release 说明。

版本号会在 tag 构建时自动写入 `AppScope/app.json5` 的 `versionName`。
