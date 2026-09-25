# NOMNOM Agent Guide

## 1. Executive Overview

NOMNOM (Nuclear Option Managed & Neatly Organised Manifest) is a centralized, automated package manifest registry for mods in the combat flight simulator *Nuclear Option* (developed by Shockfront Studios).

NOMNOM acts as the authoritative catalog consumed by Nuclear Option mod managers, primarily:
- **NOMM (Nuclear Option Mod Manager)** (https://github.com/Combat787/NuclearOptionModManager)

The repository provides:
1. An atomic, versioned catalog of all community mods, plugins, addons, aircraft blueprints, and utilities.
2. Metadata detailing versioning, dependencies, incompatibilities, extension relationships, and client/server compatibility.
3. Automated polling of mod author GitHub releases to discover and index new releases without manual intervention.
4. Issue-driven automation pipelines to update game compatibility versions, preview images, and client/server execution flags.
5. An open-source security audit and decompilation pipeline to ensure mod binaries match public source code and contain no malicious logic.

NOMNOM is a community-driven project and is not officially affiliated with Shockfront Studios.

---

## 2. Repository Layout

```
NOMNOM/
├── .github/
│   ├── ISSUE_TEMPLATE/           # GitHub issue forms for community updates
│   │   ├── template_gameVersion.yml
│   │   ├── template_isClientOrServer.yml
│   │   └── template_modImageUrl.yml
│   ├── scripts/                  # Automation scripts for issue processing and cache application
│   │   ├── parse_issue.ps1
│   │   ├── parse_isClientOrServer_issue.ps1
│   │   ├── parse_mod_image_issue.ps1
│   │   ├── Update-GameVersions.ps1
│   │   ├── Update-IsClientOrServer.ps1
│   │   └── Update-ModImageUrls.ps1
│   └── workflows/                # GitHub Actions workflows
│       ├── hourly_update.yml     # Hourly auto-update and cache processing loop
│       ├── process_issues.yml    # Issue ingestion, validation, and cache staging
│       └── validateJson.yml      # Pull Request JSON schema and content validation
├── agents/                       # AI Agent and automated contributor documentation
│   ├── README.md                 # Primary system manual (this file)
│   ├── architecture.md           # Deep architectural breakdown and data flow
│   ├── workflows.md              # Operational runbooks and execution guides
│   └── rules.md                  # Strict invariants, schema constraints, and policies
├── audit/                        # Mod security inspection workspace
│   ├── <ModId>/                  # Cloned repo, release archive, decompiled code, and reports
│   ├── prompt.md                 # LLM system prompt for binary vs. source security auditing
│   └── *_auditFindingMessage.txt # Audit finding templates for mod authors
├── gameVersionUpdateCache/       # Pending gameVersion updates parsed from issues
├── isClientOrServerUpdateCache/  # Pending client/server flag updates parsed from issues
├── modImageUpdateCache/          # Pending image URL and hash updates parsed from issues
├── manifest/
│   ├── manifest.json             # Monolithic compiled array of all active mods
│   └── version.json              # 4-part semantic version of the compiled manifest
├── modManifests/                 # Source of truth: atomic JSON file for each mod (<id>.json)
├── quarantine/                   # Delisted, compromised, or policy-violating manifests
├── Audit-OpenSource.ps1          # Clones repos, unpacks releases, and runs ilspycmd decompilation
├── Compile-Manifest.ps1          # Aggregates modManifests/*.json into manifest/manifest.json
├── Get-GitHubReleases.ps1        # GitHub REST API client function for fetching release assets
├── Increment-ManifestVersion.ps1 # Increments 4th revision integer in manifest/version.json
├── Invoke-CodeReview.ps1         # Pipes repo + decompiled C# source to LLM security auditor
├── Run-AutoUpdates.ps1           # Iterates mods and runs artifact/dependency updates
├── Run-JsonValidation.ps1        # Validates all manifests against schema and rebuilds manifest.json
├── Update-ModArtifact.ps1        # Evaluates GitHub releases for a mod and appends new artifacts
├── Update-ModDependencies.ps1    # Synchronizes dependency versions against latest catalog state
├── Validate-JsonContent.ps1      # Validates business logic, URLs, filenames, and relationships
├── Validate-JsonSchema.ps1       # Validates JSON against ValidationSchema.json via Test-Json
├── ValidationSchema.json         # JSON Schema Draft-07 specification for mod manifests
└── template.json                 # Boilerplate template for new mod manifests
```

---

## 3. Core Data Architecture

The registry centers around two primary entities defined in `ValidationSchema.json`:

### 3.1. Mod Object (`modManifests/<id>.json`)
Each mod has an independent file named exactly `<id>.json` inside `modManifests/`.

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | Yes | Unique identifier. BepInEx assembly name or format `ModAssemblyName.UniqueString`. File name must match `<id>.json`. |
| `displayName` | string | Yes | Human-readable mod name. |
| `description` | string | Yes | Overview of functionality. |
| `tags` | string[] | No | Categorization tags (`QoL`, `Art`, `Aircraft`, `Terrain`, `Flavor`, `Server`). |
| `imageUrl` | string (URI) | No | Direct URL to mod icon or banner (JPG, PNG, WEBP, SVG; max 512x512). |
| `imageHash` | string | No | SHA-256 hash of the image content. |
| `urls` | object[] | Yes | Array of `{ name: string, url: string }`. Must contain at least an `"info"` URL. |
| `authors` | string[] | Yes | List of author display names. |
| `isClientOrServer` | string | No | Execution environment: `"Client"`, `"Server"`, or `"Both"`. |
| `githubOwner` | string | Conditional | GitHub user/organization owning the release repository (required for auto-updates). |
| `githubRepoName` | string | Conditional | GitHub repository name hosting releases (required for auto-updates). |
| `autoUpdateArtifacts` | string | Conditional | Set to `"True"` to enable automated hourly release scraping. |
| `artifacts` | object[] | Yes | Sorted array of versioned release packages. |

### 3.2. Artifact Object
Represents a specific downloadable release version of a mod.

| Field | Type | Required | Description |
|---|---|---|---|
| `fileName` | string | Yes | Filename of the asset (must end in `.zip`, `.rar`, `.7z`, `.dll`, `.nobp`, or `.tar.gz`). |
| `version` | string | Yes | Version number parseable by .NET `[System.Version]`. Must match binary metadata for DLLs. |
| `category` | string | Yes | `"release"` or `"preRelease"`. |
| `type` | string | Yes | Mod type: `"plugin"` (BepInEx plugin) or `"addOn"` (extension/asset pack). |
| `gameVersion` | string | Yes | Supported Nuclear Option game version (e.g. `"0.34.2"`). |
| `downloadUrl` | string (URI) | Yes | Direct HTTPS download URL to the release asset. |
| `hash` | string | Yes | Asset checksum or GitHub asset digest. |
| `extends` | object | Conditional | Required for `type: "addOn"`. Contains `{ id: string, version: string }`. |
| `dependencies` | object[] | No | Array of prerequisite mod objects `{ id: string, version: string }`. |
| `incompatibilities` | object[] | No | Array of conflicting mod objects `{ id: string, version: string }`. |

---

## 4. How the System Operates

NOMNOM operates on four major pipelines:

```
[Mod Authors: GitHub Releases]
         │
         ▼
[Hourly Action: Run-AutoUpdates.ps1] ───► [Update-ModArtifact.ps1] ───► [modManifests/*.json]
         │                                                                   │
         ▼                                                                   ▼
[Hourly Action: Update-*-Cache.ps1] ◄── [Issue Form Caches]          [Run-JsonValidation.ps1]
                                                                             │
                                                                             ▼
[Compiled Registry: manifest/manifest.json & version.json] ◄─────────────────┘
         │
         ▼
[Mod Managers: NOMM Client]
```

### 4.1. Hourly Update Pipeline (`hourly_update.yml`)
Runs automatically at minute 22 of every hour:
1. **Scrape Releases (`Run-AutoUpdates.ps1`)**:
   - Loops over all files in `modManifests/`.
   - If `autoUpdateArtifacts == "True"`, executes `Update-ModArtifact.ps1`.
   - Queries `https://api.github.com/repos/{Owner}/{Repository}/releases` via `Get-GitHubReleases.ps1`.
   - Cleans the tag (`v`, `-pre`, `_IL2CPP` stripped) and checks if the version is newer than `artifacts[0].version`.
   - If newer, prepends/inserts the new artifact, carries over `dependencies`, `incompatibilities`, or `extends` definitions, defaults `gameVersion` to the previous release or `"0.32"`, sorts the artifacts array by version descending, and saves back to disk in UTF-8 without BOM.
   - Executes `Update-ModDependencies.ps1` to update dependency version references to point to the newest active versions across the catalog.
2. **Validate & Compile (`Run-JsonValidation.ps1`)**:
   - Validates all files against `ValidationSchema.json` via `Validate-JsonSchema.ps1`.
   - Validates business logic via `Validate-JsonContent.ps1`.
   - Aggregates all manifests into `manifest/manifest.json`.
3. **Bump Manifest Version (`Increment-ManifestVersion.ps1`)**:
   - Reads `manifest/version.json` (e.g. `1.1.0.2827`), increments the 4th revision integer (`1.1.0.2828`), and saves it back.
4. **Process Queued Metadata Caches**:
   - `.github/scripts/Update-GameVersions.ps1`: Updates `gameVersion` for specified mod IDs from `gameVersionUpdateCache/`.
   - `.github/scripts/Update-ModImageUrls.ps1`: Updates `imageUrl` and `imageHash` from `modImageUpdateCache/`.
   - `.github/scripts/Update-IsClientOrServer.ps1`: Updates `isClientOrServer` flags from `isClientOrServerUpdateCache/`.
   - Cleans up processed cache files.
5. **Commit and Push**:
   - Commits changes using `github-actions[bot]` with message `Automated update: YYYY-MM-DD HH:MM:SS UTC`.

### 4.2. Issue Automation Pipeline (`process_issues.yml`)
Community members update mod metadata by opening structured GitHub issues. When a maintainer applies an approved label, `process_issues.yml` executes:
- **`gameVersion Update`**: Runs `parse_issue.ps1`. Validates that the version string parses as a valid .NET version and each mod ID exists in `modManifests/`. Writes validated payload to `gameVersionUpdateCache/<IssueId>.json` and closes the issue.
- **`Mod Image Update`**: Runs `parse_mod_image_issue.ps1`. Validates the image URL, downloads the file to verify format (JPG, PNG, WEBP, SVG) and max dimensions (512x512), calculates the SHA-256 hash, writes to `modImageUpdateCache/<IssueId>.json`, and closes the issue.
- **`isClientOrServer Update`**: Runs `parse_isClientOrServer_issue.ps1`. Validates that status is `Client`, `Server`, or `Both` and that the mod ID exists. Writes to `isClientOrServerUpdateCache/<IssueId>.json` and closes the issue.
- If validation fails at any point, an error report is posted directly as an issue comment and the issue remains open.

### 4.3. Pull Request Validation Pipeline (`validateJson.yml`)
Runs on PRs targeting `main`, `dev`, or `staging` modifying `**/modManifests/*.json`:
- Uses `tj-actions/changed-files` to isolate modified files.
- Validates each modified file against `ValidationSchema.json` via `Validate-JsonSchema.ps1`.
- Validates business logic via `Validate-JsonContent.ps1`.

### 4.4. Security Audit & Decompilation Pipeline (`Audit-OpenSource.ps1` & `Invoke-CodeReview.ps1`)
Enforces the repository's strict Mod Submission Acceptance Policy:
1. `Audit-OpenSource.ps1` installs `ilspycmd` (`dotnet tool install -g ilspycmd`).
2. Clones the source repository into `audit/<ModId>/repo`.
3. Downloads the release binary into `audit/<ModId>/release` and extracts the archive.
4. Identifies all `.dll` and `.exe` binaries.
5. Flags empty/readme-only repositories as `NOT OPEN SOURCE`.
6. Decompiles matching assemblies into `audit/<ModId>/decompiled` using `ilspycmd`.
7. `Invoke-CodeReview.ps1` bundles repo source code, decompiled source code, and `audit/prompt.md` into a structured prompt and evaluates it using an AI agent via the Antigravity CLI (`agy`).
8. The evaluation checks five critical security criteria:
   - Build Integrity (Source code vs. decompiled binary equivalence; flags hidden classes/obfuscation).
   - File System Modifications (Flags any file operations outside standard BepInEx config directories).
   - Application Launch Prevention (Flags startup deadlocks or crash hooks).
   - Application Termination (Flags unauthorized `Application.Quit` or process termination).
   - Network & Web Operations (Flags unauthorized HTTP/sockets outside Mirage or Steamworks netcode).
9. Malicious, obfuscated, or non-compliant mods are moved to `quarantine/`.

---

## 5. Key Agent Instructions & Invariants

When creating or modifying files in this repository, agents must adhere to the following rules:

1. **Character Encoding**:
   Always write files in **UTF-8 without BOM**. PowerShell default encoding on Windows can introduce a UTF-16 LE BOM or ANSI encoding, breaking GitHub Actions and JSON parsers. Always specify `-Encoding utf8NoBOM` or `-Encoding utf8`.

2. **JSON Serialization Depth**:
   When using PowerShell to serialize manifest structures, always pass `-Depth 100` or higher (`ConvertTo-Json -Depth 100`). The default depth in PowerShell is 2, which silently truncates child objects such as `artifacts`, `urls`, and `dependencies`.

3. **Mod ID and File Naming Invariant**:
   The JSON file inside `modManifests/` must match the mod's `id` property verbatim: `modManifests/<id>.json`.

4. **Version String Invariant**:
   All version values (`version`, `gameVersion`, and dependency `version`) must strictly parse via .NET `[System.Version]`. Standard formats: `Major.Minor`, `Major.Minor.Build`, or `Major.Minor.Build.Revision`.

5. **Never Bypass Validation**:
   Before committing changes to manifests or automation scripts, run `Run-JsonValidation.ps1` via `pwsh` to confirm schema and structural validity.

---

## 6. Further Documentation

- For architectural diagrams and data flow specifications, see `agents/architecture.md`.
- For CLI runbooks, manual execution guides, and common operations, see `agents/workflows.md`.
- For strict coding standards, policies, and invariants, see `agents/rules.md`.
