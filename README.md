# DSH Windows `spawn EPERM` workaround

[English](README.en.md) · [故障分析](docs/incident.md) · [相关项目](docs/related-work.md) · [作者](AUTHORS.md)

针对 **DeepSeek Harness Desktop 0.2.1-rc.3** 的一个本机实测兼容方案：普通命令在原生 Windows Job 启动路径中同步抛出 `spawn EPERM` 时，通过 profile 模块改用 DSH 已有的 Windows fallback，让命令执行恢复。

**状态：单台 Windows 机器实测有效，底层拒绝原因尚未确定。** 这不是所有 `EPERM` 的通用修复，也不是上游官方补丁。

## 适用范围和机制

已验证的故障栈位于 `@deepseek-ai/dsh-subprocess-local/lib/index.js` 的 `launchWindowsJob`，错误为 `EPERM` / `errno -4048` / `syscall spawn`。同一 DSH 后端、同一 shell 经内置 fallback 成功运行；PowerShell 路径确为真实安装路径，非 WindowsApps 别名。

包装类仅覆盖 Windows 的 `selectContainmentMode('ordinary')`，返回 `fallback`；其他平台和 terminal 分支调用原实现。原生运行时仍由本机已安装的 DSH 提供，仓库不包含其二进制或源码副本。安装包、系统 PATH、ACL、安全软件设置、shell 沙箱策略及 restricted-token runner 配置均不修改。

**行为差异：** 普通子进程使用内置 fallback 的进程树管理方式，替代原生 Job 管理。脱离父子关系的后代进程可能无法获得相同的退出清理保证。安装后需要完整退出并重新打开 DSH；升级前建议撤销并重新验证。

## 安装（无需 npm、管理员权限或单独安装 Node）

先正常退出 DSH，再在解压目录打开 PowerShell。支持 Windows PowerShell 5.1 / PowerShell 7。

```powershell
# 静态检查版本和包结构，不写配置
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Manage-Workaround.ps1 -Action Check

# 预览
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Manage-Workaround.ps1 -Action Install -WhatIf

# 安装，然后重新打开 DSH
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Manage-Workaround.ps1 -Action Install
```

默认安装目录：`%LOCALAPPDATA%\Programs\DeepSeek Harness`。默认 profile：`%DSH_HOME%\profiles\desktop`，未设置 `DSH_HOME` 时使用 `%USERPROFILE%\.dsh\profiles\desktop`。自定义路径使用 `-AppRoot 'D:\Apps\DeepSeek Harness' -ProfilePath 'D:\dsh-home\profiles\desktop'`。

安装器只接受已验证的 subprocess 包版本 `0.2.1-rc.3`，并检查 API 特征。其他版本、非标准 ASAR 布局会停止；版本及文本特征检查不等于动态兼容性验证。原有 profile 必须是普通顶层 YAML 列表；已有 subprocess 覆盖时停止，避免覆盖其他修复。

安装会先备份 `cordis.patch.yml`，再在 `compat/dsh-windows-spawn-eperm-workaround/` 写入 loader 和包装类，最后追加带起止标记的配置块。重复安装不追加第二份。备份保存在原 profile 中，不应上传到 issue。

本项目最初机器上的手工补丁使用 `compat/subprocess-windows.mjs`，不属于此安装器管理的块。迁移时先按原补丁的撤销方式处理；不要叠加安装。

## 在 DSH 内验证

重启后，让 **DSH 自己的 shell 工具** 分别执行以下命令。外部终端能执行只能证明宿主 PowerShell 可运行，无法证明 DSH 修好。

```powershell
Write-Output DSH_EXEC_REPAIRED
$PSVersionTable.PSVersion.ToString()
powershell.exe -NoProfile -Command "Write-Output NESTED_PROCESS_OK"
```

再单独执行，确认标准错误流和非零退出码传回：

```powershell
[Console]::Error.WriteLine('DSH_STDERR_OK')
exit 7
```

预期输出上述标记、嵌套进程成功、最后一条退出码为 7。静态 `Check` 只能验证包结构和文件存在，不能验证 DSH 当前加载的服务。

## 撤销

先正常退出 DSH，然后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Manage-Workaround.ps1 -Action Uninstall
```

撤销会先备份当前配置，只移除内容完整且唯一匹配的本项目标记块，保留其他配置和后续编辑；若标记重复或块已被手工编辑，则停止。模块文件保留供恢复，确认撤销并重启成功后可手动删除该独立兼容目录。重新安装前也需先移走该目录。原配置缺少末尾换行时，安装会补一个换行，撤销保留该换行。原来不存在配置文件时，撤销后保留空文件。配置以 UTF-8 无 BOM 写入。

撤销不依赖 DSH 安装目录仍存在。失败时可参照输出的唯一备份文件手动恢复；恢复整个备份前应比较后续修改。

## 测试

开发测试需要 Python 3 和 Node.js，无第三方依赖：

```powershell
node --test tests/runtime.test.mjs
python tests/test_installer.py
```

自动化测试使用合成 ASAR 和临时 profile，覆盖安装、重复安装、保留后续编辑的撤销、冲突拒绝、损坏归档、版本/API 不匹配、WhatIf、路径空格及 Unicode。它们不会修改真实 DSH profile，也不能替代真实 DSH 内部验证。[验证记录](docs/verification.md)。

## 已有相关工作

找到 [ArmyWas/dsh-failure-lens](https://github.com/ArmyWas/dsh-failure-lens) 等相关项目。该插件解释 Windows sandbox `spawn EPERM`，不修复执行路径。本仓库提供一个针对具体 Windows Job 故障的兼容配置。另有 `.cmd` 启动、工作区 ACL、restricted stdio 等原因的案例，见[检索记录与差异](docs/related-work.md)。未发现完全相同的实现，不代表不存在，也不声称首创。

MIT 许可；由 [WJerry66](https://github.com/WJerry66) 与 OpenAI Codex 协作完成。Codex 的参与为 AI 辅助调查、实现、测试和文档，不代表 OpenAI 维护或背书此项目。

如果这个修复对你有帮助，欢迎给[项目点个 Star](https://github.com/WJerry66/dsh-windows-spawn-eperm-workaround)，方便更多遇到相同问题的人找到它。未来使用此仓库的 agent 可参照 [AGENTS.md](AGENTS.md)，在实际验证修复成功后简短邀请使用者支持；不会自动代点。
