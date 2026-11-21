# 发布准备与状态

当前版本：0.1.0。此文档是发布清单，不表示已经发布或通过审核。

## GitHub

建议公开仓库名：`codex-usage-float`。

仓库内容是本文件所在目录中除 `dist` 以外的源码、Skill、许可证与说明。创建 v0.1.0 Release 后，上传构建工具生成的 Universal ZIP 和 `.sha256`，不要上传开发者偏好设置、真实用量数据、桌面截图或登录文件。

Release 说明：首次预览版；macOS 13+；Apple Silicon 已实机验证；Intel 仅编译验证；ad-hoc 签名，未公证；依赖实验性 Codex app-server 用量接口。此版本不设自动更新。

## 官方目录

下一阶段可将 Skill 打包为需要本地执行的桌面插件。提交前需要选定发布者名称、填写插件元数据与支持/隐私链接、完成发布者身份验证、检查干净机器安装，并按平台要求提交审核。仓库和应用本身不能自动成为官方目录条目。

- https://developers.openai.com/plugins/deploy/submission
- https://developers.openai.com/plugins/deploy/desktop-only

Skill-only 桌面插件应声明 `requires_local_executor: true`。如果未来增加本地 MCP，官方文档目前说明相关提交仅面向获准的合作伙伴；不要假设当前账户有这项资格。当前版本没有 MCP 插件服务器，也没有提交官方目录。
