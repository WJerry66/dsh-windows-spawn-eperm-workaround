# 相关项目和检索记录

检索日期：2026-10-29。通过 GitHub 公共 REST API 获取仓库、README、issue 和 PR 正文。查询结果只反映当时索引；没有进行需认证的 GitHub 全局代码搜索，没有逐一阅读所有广泛查询结果。

## 已阅读的相关材料

| 项目 / 案例 | 内容与本包的区别 |
| --- | --- |
| [ArmyWas/dsh-failure-lens](https://github.com/ArmyWas/dsh-failure-lens) | 最接近的诊断项目：识别 Windows sandbox `spawn EPERM` 并改善客户端解释；README 明确不更改权限、不重新执行、不修复命令路径。与本包服务端 Windows Job → 内置 fallback 的配置覆盖不同。Apache-2.0；本包未复制其代码。 |
| [deepseek-harness-plugin-mcp PR #4](https://github.com/bobleer/deepseek-harness-plugin-mcp/pull/4) | 避免直接 spawn `.cmd/.bat`，改用打包 Electron host 与 CLI JS；针对 Node 批处理启动限制，是不同机制。 |
| [dataelement/dsh-desktop #579](https://github.com/dataelement/dsh-desktop/issues/579) | 工作区 ACL / `SetNamedSecurityInfoW` Win32 5，并讨论 restricted Node 的 piped stdio EPERM；不能直接视为本例原生 Job 分支的根因。安装器不包含该 issue 提到的 ACL 改动。 |
| [Cherry Studio #19929](https://github.com/CherryHQ/cherry-studio/issues/19929) | 其他应用 Windows Agent 启动也出现 `EPERM/-4048/spawn`；仅错误签名相同，未证明同因。 |
| [DeepSeek Harness 上游](https://github.com/deepseek-ai/deepseek-harness) | 本包装类使用本机上游运行时，未捆绑它。 |

failure-lens README 还链接到 [上游讨论 #3193](https://github.com/deepseek-ai/deepseek-harness/discussions/3193)；此次未获取或阅读该讨论正文，不能将其列为已验证的修复证据。

## 查询范围

| GitHub search API 查询 | 当时总结果数 | 阅读范围 |
| --- | ---: | --- |
| Issues: `repo:deepseek-ai/deepseek-harness "spawn EPERM"` | 0 | 无匹配 issue |
| Issues: `repo:deepseek-ai/deepseek-harness Windows Job` | 0 | 无匹配 issue |
| Issues: `"deepseek" "spawn EPERM"` | 177 | 前 15 个条目的摘要，相关正文另外获取 |
| Issues: `"deepseek-harness" "EPERM"` | 512 | 前 15 个条目的摘要，相关正文另外获取 |
| Repositories: `deepseek harness windows EPERM` | 1 | failure-lens README |
| Repositories: `dsh windows spawn eperm` | 1 | failure-lens README |

响应均为 HTTP 200，`incomplete_results=false`。后者表示搜索响应未因查询执行超时标记不完整，不表示已经人工查看所有条目，也不覆盖 discussions 或代码搜索。

**结论：已有相同症状的公开项目和报告；在实际检查的材料中未发现与本包完全相同的实现。** 因此以独立、明确版本范围的兼容包发布，并公开列出相关工作，不声称首创。
