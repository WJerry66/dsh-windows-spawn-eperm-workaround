# 故障报告（已脱敏）

## 现象

DSH 内部命令和新会话的命令启动同步失败，错误签名为 `Error: spawn EPERM`、`code: EPERM`、`errno: -4048`、`syscall: spawn`。外部终端中同一真实 PowerShell 能输出 `hi`。读写文件与启动子进程是不同通道，前者成功不足以证明后者正常。

## 环境

- DSH executable FileVersion：`0.2.1-rc.3`；ProductVersion：`0.2.1.0`。
- `@deepseek-ai/dsh-subprocess-local`：`0.2.1-rc.3`。
- 嵌入 Node：`24.21.0`；PowerShell：`7.4.6`。
- Windows 单机案例；Windows build 未记录，不作支持版本推断。
- 文件/命令授权配置已允许相应操作，故障仍出现。

## 证据与因果范围

1. 在真实 DSH 后端内确认 shell 选择的是已安装的 `PowerShell\7\pwsh.exe`，且 PATH 中已经存在它。此前“只要安装 MSI 或刷新 PATH 即可修好”的解释不符合后续观测。
2. 失败栈落在 subprocess-local 的 `launchWindowsJob`，普通子进程原生 Job 启动路径同步抛出错误；对应打包文件中约为第 775 行，具体行号随构建变化。
3. 同一执行服务改走它自带的 Windows fallback 后，stdout、stderr、嵌套进程和非零退出码都成功传递。
4. 通过 profile 插入替代服务，完整重启后，实际 provider 为 `WindowsCompatibleSubprocessRuntime`，containment 为 `fallback`，真实 DSH shell 再次通过验证。

这些证据定位到发生故障的启动分支，但没有确定底层 Windows API、端点软件或环境中哪一项导致拒绝。不能据此断言 AppContainer、杀毒软件、缺少 PowerShell、WindowsApps 别名或 ACL 是本例根因。

## 修复

继承本机的 subprocess-local 默认类，仅对 Windows ordinary 模式返回 `fallback`。仍调用原 `warnFallback`，沿用原实现的输出、退出、取消及进程树清理逻辑。取消/脱离进程的完整动态行为未在本次真实机器验证，不作等价保证。

Cordis profile 中，既有条目的 `name` 是匹配断言，不能用来重命名服务。因此补丁禁用 `id: subprocess` 并通过 `insert` 新增唯一 `subprocess-windows-compat` 条目。只给旧 ID 换 `name` 的尝试没有生效。profile 修改需完整重启后核验，不能依赖热加载。

本仓库将现场手工模块整理成便携安装器，使用相同覆盖机制；现场真实 DSH 验证对象是手工版，发布版安装/撤销在隔离夹具中验证。未在本次重新覆盖正常工作的现场配置。

## 范围之外

未执行此前对话中的模型下载、导入或 phase2 工作流。仓库未包含原始会话、完整环境变量、用户配置、进程转储、容器名称或安全软件日志。临时诊断 inspector 已关闭。
