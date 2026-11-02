# Changelog

## 0.2.0 — 2026-11-02

- Add plain-language Chinese/English symptom discovery: DSH commands not working, pwsh launch failure, external-terminal success with internal EPERM, file tools working while exec fails.
- Add root Fix-DSH.cmd / Fix-DSH.ps1 entry points for double-click and agent automation.
- Add a file-tool self-repair recipe, matching loader/config templates, and troubleshooting FAQ.
- Keep the validated subprocess 0.2.1-rc.3 version gate and existing fallback behavior unchanged.

## 0.1.0 — 2026-10-29

- Document the observed Windows Job `spawn EPERM` failure and unresolved root cause.
- Add version-scoped profile wrapper using the existing Windows fallback.
- Add dependency-free install/check/rollback with config backups and conflict refusal.
- Add isolated runtime and installer tests, related-work references, and Codex attribution.
