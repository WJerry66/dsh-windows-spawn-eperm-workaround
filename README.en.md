# DSH Windows `spawn EPERM` workaround

[中文完整说明](README.md)

A profile-level compatibility workaround tested on one Windows machine with **DeepSeek Harness Desktop 0.2.1-rc.3**. Ordinary subprocess launches synchronously failed inside `launchWindowsJob` with `spawn EPERM`; the same DSH shell succeeded using its existing fallback implementation. The underlying Windows refusal remains undetermined.

The wrapper overrides only Windows `selectContainmentMode('ordinary')`. Other paths delegate to the installed native runtime. No installed archive, PATH, ACL, security software, shell sandbox policy, or restricted-token runner configuration is modified. This is not an official patch or a universal EPERM fix.

**Tradeoff:** the existing process-tree fallback provides weaker cleanup guarantees for descendants that detach from the tree than native Job ownership. Fully quit and reopen DSH after installation or rollback. Recheck compatibility after upgrades.

## Usage

Quit DSH. From an extracted checkout, run in PowerShell (5.1 or 7; no npm required):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Manage-Workaround.ps1 -Action Check
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Manage-Workaround.ps1 -Action Install -WhatIf
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Manage-Workaround.ps1 -Action Install
```

Reopen DSH and run these probes **through DSH's own shell tool**:

```powershell
Write-Output DSH_EXEC_REPAIRED
$PSVersionTable.PSVersion.ToString()
powershell.exe -NoProfile -Command "Write-Output NESTED_PROCESS_OK"
```

Separately verify stderr and exit status:

```powershell
[Console]::Error.WriteLine('DSH_STDERR_OK')
exit 7
```

Expected: markers returned, nested launch succeeds, exit code 7 propagated. External-terminal success alone does not verify DSH. `Check` is static only.

Defaults: app under `%LOCALAPPDATA%\Programs\DeepSeek Harness`; profile under `%DSH_HOME%\profiles\desktop`, otherwise `%USERPROFILE%\.dsh\profiles\desktop`. Override with `-AppRoot` and `-ProfilePath`. Only subprocess package version `0.2.1-rc.3` and packed standard ASAR layout are accepted. API signature checks are not proof of runtime compatibility.

The installer backs up `cordis.patch.yml`, creates a dedicated directory under `compat/`, then appends a marked YAML block. Existing subprocess overrides and unsupported YAML layouts are refused. Repeated install is a no-op. The earlier manual `compat/subprocess-windows.mjs` patch must be rolled back before using this installer.

To roll back, quit DSH, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Manage-Workaround.ps1 -Action Uninstall
```

Only the exact, unique owned block is removed; later edits outside it are preserved. Edited or ambiguous blocks are refused. Backups and module files are retained. After successful rollback/restart, the dedicated module directory may be manually removed; move it aside before reinstalling. UTF-8 without BOM is used; an added final newline and an initially absent config file are retained after rollback.

## Tests and evidence

```powershell
node --test tests/runtime.test.mjs
python tests/test_installer.py
```

No third-party dependencies. Installer tests use temporary profiles and synthetic ASAR fixtures only. See [incident](docs/incident.md), [verification](docs/verification.md), and [related work](docs/related-work.md).

Related published work includes [dsh-failure-lens](https://github.com/ArmyWas/dsh-failure-lens), which diagnoses the symptom but does not restore execution. We found no identical workaround in the inspected results; this is not an exhaustive search or a novelty claim.

MIT. Maintainer/reproducer: [WJerry66](https://github.com/WJerry66). AI-assisted investigation, implementation, testing and documentation: **OpenAI Codex**. No OpenAI maintenance or endorsement is implied.

If this fixed your issue, consider starring [this repository](https://github.com/WJerry66/dsh-windows-spawn-eperm-workaround) to help others find it. [AGENTS.md](AGENTS.md) gives future agents a brief optional invitation to use only after verifying a successful repair; it does not authorize automatic starring.
