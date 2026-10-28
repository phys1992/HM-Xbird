# HM-Xbird

HM-Xbird 是一个使用 ArkTS / ArkUI 构建的 HarmonyOS 原生应用，面向 HarmonyOS NEXT，提供时间线、搜索、通知、个人资料、发帖、草稿、图片与视频附件等原生界面，并适配折叠屏分栏。

> 当前版本：**1.0.0**
>
> 发布者：**phys1992**
>
> 包名：**io.github.phys1992.hmxbird**
>
> 开源许可：**MIT**
>
> 仓库：**https://github.com/phys1992/HM-Xbird**

本应用为非官方个人项目，与任何商标权利人无隶属或授权关系。

## 版本说明

- **1.0.0**：当前原生重构基线版本，使用 ArkTS / ArkUI 实现主要界面与交互。
- **0.1.0**：早期 ArkWeb 原型，已归档，不再维护。

### 0.1.0 历史说明

`0.1.0` 使用旧的应用名称与旧包名：

```text
应用名称：tuichuang
包名：com.tuichuang.tuichuang
```

`1.0.0` 起使用：

```text
应用名称：HM-Xbird
包名：io.github.phys1992.hmxbird
```

两者包名不同，不能直接覆盖升级。已安装 0.1.0 的用户如需使用 1.0.0，需要卸载旧版后重新安装；旧版登录态、设置和草稿不会迁移。

0.1.0 的 HAP 保留在对应 Release 中作为历史归档，不重新构建，也不替换附件。

## 功能

- 主页时间线：为你推荐 / 正在关注；
- 搜索、趋势、通知；
- 推文详情、回复、引用、转帖；
- 个人主页、关注/关注者列表、资料编辑入口；
- 发帖：文字、表情、图片/视频、系统图片编辑、媒体压缩；
- 草稿：自动保存、冷启动恢复、单条草稿；
- 账号：Cookie 登录、网页登录、已保存账号与系统认证；
- 主题：浅色 / 深色 / 跟随系统；
- 折叠屏展开时左右分栏，折叠时单栏浏览；
- 原生悬浮底栏、手势返回、系统标准过渡动画。

## 技术架构

- ArkTS / ArkUI 原生页面与组件；
- ArkWeb 仅用于网页登录和官方资料编辑页；
- 内部 API 封装位于 `entry/src/main/ets/api`；
- 账号 Cookie 使用 Asset Store Kit 保存，读取前要求系统认证；
- 主题、草稿、媒体设置使用 Preferences 持久化；
- 图片处理使用 ImageKit / MediaCompressor。

## 构建

环境：

- HarmonyOS SDK / DevEco Studio；
- hvigor；
- Node.js（随 command-line-tools 提供）。

构建脚本：

```bash
scripts/build-native.sh
```

或手动构建：

```bash
hvigorw assembleHap \
  --mode module \
  -p module=entry@default \
  -p product=default \
  -p buildMode=debug \
  --no-daemon
```

产物：

```text
entry/build/default/outputs/default/HM-Xbird-unsigned.hap
build-out/native-rewrite/HM-Xbird-1.0.0-unsigned.hap
```

构建脚本会读取 `AppScope/app.json5` 中的版本号并复制产物。

## 版本与分支

- `main`：稳定版本；
- `develop`：开发版本；
- `v1.0.0`：首个原生重构 release tag。

## 开源许可

本项目使用 [MIT License](LICENSE)。

第三方组件、HarmonyOS / ArkUI 与 OpenHarmony 相关组件遵循其各自许可。

## 发布者

- GitHub：[@phys1992](https://github.com/phys1992)
- 包名：`io.github.phys1992.hmxbird`
- 版权：© 2026 phys1992

## 免责声明

本应用为非官方个人项目，与任何商标权利人无隶属、合作或授权关系。使用者应自行遵守所访问平台的服务条款与当地法律法规。
