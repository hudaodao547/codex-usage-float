---
name: codex-usage-float
description: 在 macOS 安装、打开和管理 Codex 用量透明悬浮窗，显示五小时与每周剩余额度、重置倒计时，支持位置锁定。用于明确请求桌面用量组件的场景；单次查询用量优先使用现有用量工具。
---

# Codex 用量悬浮窗

这是独立的非官方 macOS 应用，源码在 `assets/UsageFloat.swift`。使用者必须已有自己的 Codex 登录；不索取、读取、复制或上传凭据文件。应用经本机 Codex app-server 的 `account/rateLimits/read` 查询额度，不创建聊天或推理任务。

## 安装与打开

1. 运行 `python3 scripts/manage.py check`（路径相对于本 Skill）。需要 macOS 13+；构建还需要 Apple Command Line Tools。缺少时说明安装方式，不自动安装开发工具。
2. 优先使用用户已经取得并确认来源的发布包。若从当前 Skill 构建，运行 `python3 scripts/manage.py build --output <工作目录>/dist`；通用架构包加 `--universal`。构建不会下载依赖。
3. 运行 `python3 scripts/manage.py install --app <构建目录>/Codex用量悬浮窗.app`，默认安装到 `~/Applications`。更新前退出旧应用；只有确认更新同一应用时才加 `--replace`。不要覆盖其他标识的同名应用。
4. 在当前环境的授权规则允许时打开已安装应用，核实实际出现五小时和每周用量，或清楚的连接错误。不把“窗口已打开”说成“数据读取成功”。

本地构建是 ad-hoc 签名，没有 Apple Developer ID 或公证。遇到 macOS 拦截，解释后让使用者通过系统正常安全界面确认；不执行 `xattr -cr`、关闭 Gatekeeper、提权运行应用或代替用户消除安全提示。

## 管理与故障排查

- 拖动背景摆放，点击锁图标锁定或解锁；位置与锁定状态自动保存。默认桌面模式，应用可盖住它；锁定位置与置顶分开。右上角 `···` 可刷新、调透明度、切换始终置顶或退出，显示模式会保存。
- 每分钟读取；不提供开机自启。查询失败保留旧值并显示错误，缺失数据展示 `—`；不把缺失值说成剩余 100%。
- 额度属于账户，可能与当前聊天所用账户不同；要求使用者在 Codex 中自行核实登录。不要输出账户令牌或读取 `auth.json`。
- 连接失败先检查 Codex 桌面版/CLI 是否可用及是否已登录，再手动刷新。使用的是实验性 app-server 协议，版本变化可能需要更新此应用。
- 只支持 macOS。Apple Silicon 已验证；Intel 构建可生成，但应标明尚无实机运行验证。
- 用户只问用量时，用现成只读工具；不要因此安装软件。发布到 GitHub 或官方目录需要独立明确的发布请求。
