# NOMNOM Invariants & Agent Rules

This document outlines mandatory invariants, constraints, and policies that autonomous agents and human developers must follow when interacting with the NOMNOM repository.

---

## 1. File & Format Invariants

### 1.1. Character Encoding: UTF-8 Without BOM
- All files (JSON, Markdown, PowerShell, YAML) must be saved using **UTF-8 without BOM** (`utf8NoBOM` in PowerShell).
- Files saved with a UTF-16 or UTF-8 BOM cause parsing errors in Linux GitHub Actions runners and web clients.
- In PowerShell, always specify:
  ```powershell
  $Content | Set-Content -Path $Path -Encoding utf8NoBOM
  # Or in PowerShell 7:
  $Content | Out-File -FilePath $Path -Encoding utf8
  ```

### 1.2. JSON Serialization Depth
- When serializing manifest objects with PowerShell, always pass `-Depth 100` or higher:
  ```powershell
  $data | ConvertTo-Json -Depth 100
  ```
- Failure to pass depth results in nested objects (such as `dependencies`, `artifacts`, and `urls`) being truncated into strings like `"System.Collections.Hashtable"`.

### 1.3. Mod ID and File Naming
- Every mod manifest inside `modManifests/` must be named exactly `<id>.json`, where `<id>` matches the `id` string inside the file.
- The `id` should be the BepInEx assembly name or conform to `ModAssemblyName.UniqueString`.
- Case sensitivity: Although Windows file systems are case-preserving, Linux CI environments are strictly case-sensitive. The casing of the filename must match the `id` field exactly.

### 1.4. Version Strings
- All version fields (`version`, `gameVersion`, and dependency `version`) must parse as valid .NET versions via `[System.Version]`.
- Valid formats:
  - `Major.Minor` (e.g., `1.0`)
  - `Major.Minor.Build` (e.g., `1.0.0`)
  - `Major.Minor.Build.Revision` (e.g., `1.0.0.0`)
- Never prefix version strings with `v` or append suffixes like `-beta` in manifest files. Strip these before writing.

### 1.5. Archive Formats and Protocols
- `downloadUrl` must use the `https://` protocol.
- `fileName` and `downloadUrl` must end with a supported archive extension:
  - `.zip`
  - `.rar`
  - `.7z`
  - `.dll`
  - `.nobp` (Nuclear Option Blueprint)
  - `.tar.gz`

---

## 2. Policy Enforcement & Zero Tolerance

All manifests registered on NOMNOM must adhere to the Mod Submission Acceptance Policy defined in `README.md`. Agents must not approve or add mods that breach these terms:

### 2.1. Open-Source Mandate
- Any mod containing custom `.dll` or executable files must have publicly available, unobfuscated source code.
- Repositories that are empty or contain only documentation (e.g., a single `README.md`) fail this mandate.

### 2.2. Zero Tolerance Clauses
Mods containing any of the following are subject to immediate delisting and quarantine:
- Obfuscated code.
- Malicious logic or spyware.
- Unwarranted file system modifications outside standard BepInEx config paths (`Paths.ConfigPath`).
- Deliberate interference with Nuclear Option startup or runtime (e.g., infinite loops in `Awake`/`Start`, crash hooks, `Application.Quit()`, `Process.Kill()`).
- Unauthorized network calls (HTTP requests, raw sockets) outside authorized multiplayer netcode (`Mirage` or Steamworks).

### 2.3. Licensing & Attribution
- Mods utilizing third-party assets (3D models, audio, ripped assets) must demonstrate appropriate licenses or explicit permission from copyright holders.
- In-game assets ripped directly from Nuclear Option require explicit permission from Shockfront Studios.

---

## 3. Repository Branching & Contribution Hygiene

### 3.1. Target Branches
- **`main`**: Target branch for mod manifest submissions (`modManifests/*.json`), automated hourly syncs, and issue-driven cache merges.
- **`dev`**: Target branch for architectural modifications, automation scripts (`.ps1`), schema updates, and GitHub Actions workflow changes.

### 3.2. Automated Commit Messages
- Hourly updates use the standardized message:
  `Automated update: YYYY-MM-DD HH:MM:SS UTC`
- Issue cache updates use:
  `Update <category> cache for issue #<issue_number>`

---

## 4. Agent Checklist Before Committing Changes

Before completing any task in this repository, verify:

1. [ ] Did you preserve UTF-8 No BOM encoding?
2. [ ] Does the filename in `modManifests/` match the `id` field?
3. [ ] Are all version strings parseable by `[System.Version]`?
4. [ ] Did you pass `-Depth 100` if modifying or exporting JSON?
5. [ ] Did you run `pwsh -NoProfile -Command ".\Run-JsonValidation.ps1"` to verify the entire catalog?
6. [ ] If updating `manifest/version.json`, did you increment the 4th revision integer?
7. [ ] Are all URLs HTTPS?
