# DSH 执行不了命令？pwsh 调用失败？先看是不是这个问题

这里的 DSH 指 **DeepSeek Harness / DeepSeek Harness Desktop**。如果你搜的是“dsh pwsh调用失败”“DeepSeek Harness 终端不能用”“DSH shell 一直失败”“spawn EPERM 怎么修”，可以先对照下面的表现。

## 和本例相似的症状

| 你看到的现象或搜索词 | 本例发生了什么 |
| --- | --- |
| DSH 无法执行命令 / DSH 命令执行失败 / agent 跑不了脚本 | 连 `Write-Output hi` 这样的命令也启动失败，命令正文没有机会运行。 |
| dsh pwsh 调用失败 / PowerShell 启动失败 / shell tool failed | DSH 实际已选中真实的 `pwsh.exe`，仍在启动子进程时失败。 |
| 外部终端能跑，DSH 里不能跑 / cmd 能输出 hi | 同一个 PowerShell 在外部能运行，DSH 后端里的启动分支却报错。 |
| `spawn EPERM` / `Error: spawn EPERM` | 本例的核心错误；`code: EPERM`、`errno: -4048`、`syscall: spawn`。 |
| `EXEC_BROKEN: spawn EPERM` / 进程创建被拒绝 | `EXEC_BROKEN` 是对话中 agent 给失败起的标签，不一定是 DSH 自带错误码。应同时找原始 `EPERM` 错误。 |
| 能读写文件，但不能执行 / 文件工具正常，exec 坏了 | 本例也是如此；不同工具走不同通道。能写文件不表示能启动 shell。 |
| npm、git、docker 在 DSH 里全都跑不起来 | shell 自己起不来时，所有这些命令都会受影响，不一定是 npm / git / Docker 各自坏了。 |
| 新会话、新 agent 也失败，重启还没好 | 本例换会话和重启没有解决。重试次数不是根因证据。 |
| 装了 PowerShell 7、MSI，调整 PATH 仍然失败 | 本例装好真实 pwsh 后仍失败，最终靠更换 DSH 内部启动分支恢复。 |
| 日志有 `launchWindowsJob`、`dsh-subprocess-local` | 更贴近本包处理的位置：DSH 普通命令的 Windows Job 启动分支。 |

**症状相似只是排查入口，不代表原因一定相同。** 本包只验证过 Desktop subprocess `0.2.1-rc.3`；目前不自动兼容其他版本。

## 最快修复入口

先保存 DSH 中的工作、正常退出它。在 Windows 自己的 PowerShell 中执行：

```powershell
git clone https://github.com/WJerry66/dsh-windows-spawn-eperm-workaround.git
cd dsh-windows-spawn-eperm-workaround
.\Fix-DSH.cmd
```

已经 clone 过的目录中直接运行 `Fix-DSH.cmd` 即可。没有 Git？在[仓库页面](https://github.com/WJerry66/dsh-windows-spawn-eperm-workaround)点 **Code → Download ZIP**，解压后双击 `Fix-DSH.cmd`。不要只保存这一个文件：它需要仓库内的脚本和 src 文件一起工作。

成功后完整重新打开 DSH，让它自己执行 `Write-Output DSH_EXEC_REPAIRED`。仅看到“Installed”表示配置已写好，还不能证明命令执行恢复。

## 为什么不用坏掉的 pwsh 来修 pwsh？

一键入口用 Windows 自带的 `powershell.exe` 运行安装器，不要求单独安装 `pwsh`、npm、Node 或 Python。但它需要从**能启动进程的通道**运行：Windows 外部终端、双击，或其他正常的 agent 执行工具。

如果 DSH 自己的 shell 起不来，在那个 shell 里运行修复脚本也会失败。这时让 DSH 用独立文件工具准备补丁，参照[DSH 自修说明](agent-self-repair.md)，最后由你正常关闭并重新打开 DSH。不能执行命令时，也不能要求 DSH 先用 shell 去 clone 仓库。

## 一键入口报错怎么办？

| 输出 / 现象 | 下一步 |
| --- | --- |
| `Unsupported runtime version` | 版本不在本次验证范围内。记录具体版本和原始错误，不要去掉版本检查强行安装。 |
| 找不到 `resources\app.asar` / 路径不存在 | 安装位置可能不同，用 `Fix-DSH.cmd -AppRoot "D:\Apps\DeepSeek Harness"`。 |
| profile 路径不对 | 使用 `-ProfilePath "D:\dsh-home\profiles\desktop"`，先确认这是正在使用的 desktop profile。 |
| `Existing subprocess override detected` | 已有手工补丁或其他 subprocess 覆盖。先看配置和备份，避免叠加；本包不会替你覆盖。 |
| `Compatibility directory already exists` | 上次撤销保留了模块，或上次安装中断。先比较配置、备份和目录；确认未被使用后移走保留目录，再安装。 |
| `Already installed` | 已有本包标记；完整重启 DSH 后在其内部验证，不必重复安装。 |
| `Owned patch block was edited` / `Ambiguous patch markers` | 配置块被改过或重复。比较备份，保留其他修改后再处理，不要整份覆盖。 |
| 外部 `powershell.exe` 也无法启动 | 这个安装器也运行不了，不能据此认定与本例同因；先检查外部命令的原始错误。 |

只检查不安装：`Fix-DSH.cmd -Action Check`。撤销：`Fix-DSH.cmd -Action Uninstall`，之后完整重启。

## 常见误判

- **“where pwsh 只出现 WindowsApps，所以肯定就是它。”** 本例最后确认真实 PowerShell 和 PATH 都正常。可先验证真实路径，不要只看别名就认定根因。
- **“终端输出 hi，所以一定是 AppContainer / 杀毒软件。”** 外部能执行只缩小范围，不能直接确定谁拦了 DSH。
- **“npm 不能用，所以先重装 Node。”** 先试最简单的 shell 命令；shell 都起不来时，重装 npm 可能无关。
- **“开更多子 agent / 反复重启就能绕开。”** 它们可能共用同一执行路径；本例需要改路径选择。

其他原因也会出现类似报错：直接 spawn `.cmd/.bat` 的限制、工作区 ACL、restricted stdio 等。[已有案例](related-work.md)能帮助区分。`ENOENT` / 找不到命令、网络下载失败、`DeepSeek Messages transport failed` / `TRANSPORT`，本包没有证据能修复它们。

## 发 issue 时带什么？

写清 DSH 版本、Windows 版本、外部 PowerShell 是否能跑、DSH 的原始错误、`Check` 输出，以及重启后的内部探针结果。只贴必要片段，删掉凭据、私人路径和完整会话。这样的报告也能让其他用户通过相同错误词找到解决过程。
