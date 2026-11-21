# Codex 用量悬浮窗 · Codex Usage Float

非官方 macOS 桌面小组件，用透明圆角小窗显示 Codex **五小时与每周剩余额度**。白色文字、白色进度条，可拖动、置顶、调透明度、锁定位置；每分钟自动更新，正常时不显示更新说明。

这是独立应用，并附带帮助 Codex 安装和管理它的 Skill。并非 OpenAI 官方产品，也不代表已经获官方插件目录审核。

## 适用环境

- macOS 13 或更新版本。
- Apple Silicon 已在开发者当前 Mac 上实际验证；发布包含 Intel 架构，但尚未在 Intel Mac 上实际运行验证。
- 已安装并登录 Codex 桌面版或 Codex CLI。应用优先寻找桌面版内置 CLI，再查找常见安装目录与 PATH。
- 用量接口可能不为所有账户、套餐或模型提供这两种额度。缺失时显示 `—`。
- 依赖实验性 Codex app-server 协议；未来版本可能需要适配。

## 普通用户安装

1. 从 [Releases 发布页面](https://github.com/hudaodao547/codex-usage-float/releases) 下载 `codex-usage-float-v0.1.0-macos-universal.zip`，可用随附的 `.sha256` 核对完整性。
2. 解压，将“Codex用量悬浮窗.app”拖入“应用程序”（也可以放在自己的 `~/Applications`）。
3. 双击打开。首次查询可能需要几十秒。
4. 将它拖到喜欢的位置，点击右上角锁图标固定。锁定后不再随手误拖，退出重开仍恢复原位。需要换位置时再次点击解锁。
5. `···` 菜单可立即刷新、调透明度、置顶或退出。重置时间使用电脑本地时区。

**签名说明：** 当前发布包只有本地 ad-hoc 签名，没有购买 Apple Developer ID，也没有 Apple 公证。macOS 可能拦截。请先核实来源；若决定继续，按“系统设置 → 隐私与安全性”中的系统提示处理。不要关闭系统安全保护或执行移除隔离属性的命令。校验值只能验证文件完整性，不能保证软件无风险。

**当前不会开机自动启动。** 重启电脑后从“应用程序”再次打开即可。

## 在 Codex 中使用 Skill

将本仓库 `skills/codex-usage-float` 文件夹安装为 Codex Skill，或通过 skill-installer 安装 [此 GitHub Skill 目录](https://github.com/hudaodao547/codex-usage-float/tree/main/skills/codex-usage-float)。然后输入：

> 使用 $codex-usage-float 帮我安装并打开 Codex 用量悬浮窗。

Skill 包含源码和本地构建工具，不包含凭据、登录状态或用户的用量快照。

## 从源码构建

需要 Python 3 与 Apple Command Line Tools。没有开发工具时，先自行运行 `xcode-select --install` 并完成 Apple 安装界面。

```bash
python3 skills/codex-usage-float/scripts/manage.py check
python3 skills/codex-usage-float/scripts/manage.py build --output dist --universal
```

生成 Universal 应用与 ZIP，包含 `arm64` 和 `x86_64`。不加 `--universal` 只编译当前 Mac 的架构。构建依赖系统 Cocoa、Swift、codesign、lipo 和 ditto，不下载第三方库。

可选，安装到用户的应用程序文件夹：

```bash
python3 skills/codex-usage-float/scripts/manage.py install --app dist/Codex用量悬浮窗.app
```

脚本不会自动启动应用。更新时先从 `···` 退出旧版；确认更新后加 `--replace`。重命名同名但不同标识的旧应用后再安装，不会覆盖其他软件。

## 用量和隐私

应用只通过本机 Codex 的 `account/rateLimits/read` 获取数据，不创建聊天或模型生成任务，不读取聊天记录。查询依赖 Codex 连接 OpenAI，仍有正常网络流量和系统资源消耗。Codex 自身的数据处理与日志由其设置和服务政策决定。

用量只存在应用运行内存中；位置、透明度及锁定状态保存在本机偏好设置中。没有开发者服务器、广告、额外分析或自动更新服务。详见 [PRIVACY.md](PRIVACY.md)。

失败时可能暂时显示上次数据，并给出错误提醒。重置倒计时到零后不会擅自将剩余额度改为 100%，需要等待服务返回新数据。用量来自本机 CLI 当前账户，请与 Codex 内账户核对。

## 移除

先退出悬浮窗，再把应用移到废纸篓。若安装过 Skill，可在 Codex 中移除该 Skill。偏好设置不是登录凭据，删除应用不会退出 Codex 账户。

## 分享和后续发布

可自由分享源码与发布包，按 [MIT 许可证](LICENSE) 使用。准备提交官方插件目录时还需要插件元数据、发布者身份与审核；此仓库不声称已获官方批准。参见 [PUBLISHING.md](PUBLISHING.md)。

## English

An unofficial macOS floating widget for Codex five-hour and weekly remaining quota. Frosted transparent background, white text, position locking, always-on-top, and one-minute refresh. Requires macOS 13+, a working signed-in Codex installation, and availability of its experimental app-server usage endpoint. Universal builds contain Apple Silicon and Intel; only Apple Silicon has been runtime-tested. Releases are ad-hoc signed, not Developer ID signed or notarized. No developer-operated backend or credential collection. See the build commands above and the privacy statement before installing.
