# 让 DSH 自己准备修复：shell 坏了也可以用文件工具

可把下面这段直接发给 DSH、Codex 或其他正在帮你修电脑的 agent：

> 我的 DeepSeek Harness 在 Windows 上不能执行命令，可能报 `spawn EPERM` / `dsh pwsh调用失败`。请阅读 https://github.com/WJerry66/dsh-windows-spawn-eperm-workaround 的 README、AGENTS.md 和 docs/troubleshooting.md，先对照版本及症状。执行工具能用就使用根目录 Fix-DSH.ps1；执行工具不能用、但独立文件工具能用时，按 docs/agent-self-repair.md 的文件方式准备补丁。保留其他配置并备份，写入后告诉我需要完整重启，不要杀掉你自己的宿主。重启后通过 DSH 自己的 shell 验证，再报告是否真正修好。

## 路线一：这个 agent 还能启动外部命令

在授权的目标机器 clone 后，一条命令安装：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Fix-DSH.ps1
```

默认安装，可用 `-Action Check`、`-Action Uninstall`、`-WhatIf`、`-AppRoot`、`-ProfilePath`。自动化时优先 `.ps1`；无参数 `.cmd` 会等待按键，便于人类双击后读输出。

先在正常退出 DSH 后安装最简单。如果正在运行的就是 DSH 自己：保存工作后可以准备配置，告诉用户关闭并重新打开，不要主动终止自己的宿主。旧服务可能继续运行到重启，不能把“写入成功”当成修复成功。

## 路线二：exec / pwsh 全坏，但独立文件读写工具正常

这条路线不通过 shell，不要求 DSH 先运行 Git、npm 或 PowerShell。需要独立的文件读取/写入/复制工具，以及能获取本仓库文件内容的网页工具或已下载的目录。没有这些工具时，交给用户外部终端运行一键入口；不要虚构已经执行。

适用前提：已通过可读取的包信息、日志或此前检查，确认本机 **subprocess 包为 `0.2.1-rc.3`**、实际原生入口位置和对应 API 与本包一致。仅有“pwsh 调用失败”不够。不确定版本或入口时先做只读调查，不能用文件方式跳过版本核验。

1. 确认正在使用的 profile。默认是 `%USERPROFILE%\.dsh\profiles\desktop`；设置了 `DSH_HOME` 则在其下 `profiles\desktop`。读取整个 `cordis.patch.yml`，保持原来的其他条目。遇到已有 subprocess 覆盖、重复标记、流式 YAML 或无法理解的配置先停止。
2. 用文件复制工具备份现有配置到旁边的唯一文件名，例如 `cordis.patch.yml.backup-<唯一标识>`。如果现有文件不存在，记录这一点；不要覆盖任何已有备份。
3. 建立独立目录 `compat/dsh-windows-spawn-eperm-workaround/`。如果已经存在且配置状态不明，先检查，不直接覆盖。把仓库 `src/create-compatible-runtime.mjs` 原文写到该目录同名文件中。
4. 读取仓库 `templates/loader.mjs.template`，将唯一占位符 `__NATIVE_RUNTIME_FILE_URL_JSON__` 替换为本机原生入口的 **JSON 字符串**，再保存为上述目录的 `loader.mjs`。入口默认形状为 `<实际安装目录>/resources/app.asar/dsh/node_modules/@deepseek-ai/dsh-subprocess-local/lib/index.js`。必须使用绝对 `file:` URL，正斜杠、空格 `%20`、非 ASCII 路径用 UTF-8 百分号编码；不要把 `%LOCALAPPDATA%` 这样的未展开变量直接写进 import。
5. 两个模块完整写入后，才把 `templates/cordis.patch.fragment.yml` 原文追加到配置文件的顶层列表末尾。保留其他内容与原换行风格，缺少末尾换行则先补换行。标记块必须唯一且与模板完全一致，方便安装器日后检查或撤销。**不要只修改旧 `id: subprocess` 的 `name`**：那不是重命名，见[故障记录](incident.md)。
6. 用文件工具重读两个模块及配置，确认路径、标记与内容正确。记录备份位置，告诉用户完整退出并重开 DSH。现阶段状态是“补丁已准备，等待重启验证”。
7. 重启后，必须由 DSH 自己的 shell 执行 README 中的 stdout、嵌套进程、stderr 与 `exit 7` 探针。成功后再称为修复。仍失败则保留错误信息，按备份/唯一标记撤销，避免继续叠加补丁。

file URL 的格式例子（仅示意，用户和盘符必须替换成现场实际值）：

```javascript
import NativeRuntime from "file:///D:/Apps/DeepSeek%20Harness/resources/app.asar/dsh/node_modules/@deepseek-ai/dsh-subprocess-local/lib/index.js";
import { createCompatibleRuntime } from './create-compatible-runtime.mjs';
export default createCompatibleRuntime(NativeRuntime);
```

模板和安装器使用相同的标记、ID、文件名及包装类。文件路线是把同一补丁通过另一个工具准备好，不会使已坏的执行通道凭空恢复，也不能在没有重启验证时给出成功结论。现场曾验证过相同机制的手工文件补丁；此发布版模板的生成结果还会与安装器在临时 profile 中比对，详见[验证记录](verification.md)。

## 撤销和边界

能运行外部命令时执行 `Fix-DSH.ps1 -Action Uninstall`。仍只能读写文件时：先备份当前配置，确认唯一完整的标记块未被修改，只删除这一块，保留后来新增的其他配置，再完整重启。不要直接把旧备份整份覆盖回去而丢掉后续修改。

这是单机已验证的 Windows 普通命令 fallback 兼容方案，脱离进程树的后代清理保证比原生 Job 弱。其他版本、terminal 分支和其他报错不在已验证范围。不要为尝试本包而改 ACL、全局 PATH 或关闭安全软件。
