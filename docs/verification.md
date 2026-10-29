# 验证记录

日期：2026-10-29。

## 真实 DSH（现场手工版模块）

完整重启后的真实后端验证：

| 检查 | 观测结果 |
| --- | --- |
| provider | `WindowsCompatibleSubprocessRuntime` |
| ordinary containment | `fallback` |
| stdout | `DSH_EXEC_REPAIRED` |
| shell version | PowerShell `7.4.6` |
| 嵌套 Windows PowerShell | `NESTED_PROCESS_OK` |
| Docker CLI 进程 | `docker ps` 成功，容器详情未发布 |
| stderr | `DSH_STDERR_OK` |
| 退出码 | 正常命令 `0`，显式失败 `7` |

普通子进程可用不代表 terminal、取消、超时、脱离进程清理、其他 Windows 机器或其他 DSH 版本全部通过。尤其未实测与原生 Job 相同的清理保证。

## 发布版自动化

本地发布前验证通过：**3 项 Node 运行时测试、8 项 Python 安装器集成测试（全部通过）**。Node `24.22.1`、Python `3.11.9`，安装器集成测试调用 Windows PowerShell 5.1。测试入口为：

```text
node --test tests/runtime.test.mjs
python tests/test_installer.py
```

测试在 Windows 上运行：Node 测试覆盖模式选择、委托、服务静态属性继承、API 不兼容；Python 测试调用 Windows PowerShell 5.1，使用临时 profile 和合成 ASAR，验证安装/撤销、重复调用、后续编辑保留、WhatIf、版本及结构拒绝。发布脚本还对本机真实 ASAR 执行只读 `Check`，验证解析器能读取实际安装布局。未用发布版安装器再次修改现场配置。

公开记录只包含必要标记与版本信息，未打包原始诊断日志。
