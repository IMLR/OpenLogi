# IMLR 的 OpenLogi 分支

基于上游 [AprilNEA/OpenLogi](https://github.com/AprilNEA/OpenLogi) `master`（v0.9.1-beta.144），分支 `imlr/custom`。

## 与上游的区别

- **拇指滚轮切换应用**：新增动作「下一个应用」「上一个应用」，以及拇指滚轮预设「上一个／下一个应用」。转动时按住 Command 并逐格按 Tab，停止 0.7 秒后松开，与 Logi Options+「在应用之间导航」一致。实现在 `crates/openlogi-inject/src/inject/app_switcher.rs`。
- **拇指滚轮灵敏度全程有效**：上游超过 27 后单次动作不再变快。现在 27 以下仍由触发阈值决定，27 以上把两次触发的最短间隔从 200 毫秒逐步缩短到 100 时的 40 毫秒（`ThumbwheelSensitivity::action_cooldown`）。
- **通用灵敏度滑块会生效**：「设置 → 通用」里的拇指滚轮灵敏度会同时清除各设备的单独设置；设备页的滑块仍可单独设置。
- **不自动检查更新**：上游的更新会覆盖本分支，所以启动时不再检查；手动「检查更新」仍可用，但安装官方版本会替换掉本分支。
- **本机签名**：打包脚本支持用本机证书签名正式通道的应用（`OPENLOGI_LOCAL_PRODUCTION_IDENTITY`）。

## 构建与安装

需要 Xcode（含 Metal Toolchain）和 rustup。

```sh
scripts/fork-install-macos.sh
```

脚本会构建 `target/release/bundle/osx/OpenLogi.app`，用本机第一个 Apple Development 证书签名，替换 `/Applications/OpenLogi.app`，并重启后台服务。证书不变时，「辅助功能」和「输入监控」权限在重新构建后保留。

## 限制

官方版本的后台服务带有苹果特批的 `com.apple.developer.hid.virtual.device` 权限，可以通过虚拟 HID 键盘发送按键。本分支没有对应的描述文件，后台服务改用 `CGEventPost` 发送按键（上游 0.8 及更早版本的方式）。依赖虚拟键盘的「按住修饰键」（HoldModifier）对其他设备的输入不起作用，其他动作不受影响。

## 同步上游

```sh
git fetch upstream
git rebase upstream/master
scripts/fork-install-macos.sh
```
