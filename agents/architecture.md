# NOMNOM System Architecture

## 1. System Topology & Ecosystem

NOMNOM occupies the central distribution and verification role in the Nuclear Option modding ecosystem. It connects mod authors, the Nuclear Option game client, and end-user mod managers.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           MOD AUTHOR ECOSYSTEM                          │
│                                                                         │
│  [Mod Author Repo] ───► [GitHub Releases (.zip/.dll assets)]            │
│           │                                                             │
│           └───────────► [Public Source Code (.cs)]                      │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                             NOMNOM REGISTRY                             │
│                                                                         │
│   modManifests/<id>.json  ◄───►  Validation Engine (Schema + Content)   │
│            ▲                                     │                      │
│            │                                     ▼                      │
│   Automated Sync Engine                  manifest/manifest.json         │
│   - Release Poller                       manifest/version.json          │
│   - Dependency Resolver                          │                      │
│   - Metadata Cache Processor                     │                      │
│            ▲                                     │                      │
│            │                                     │                      │
│   Audit & Security Pipeline                      │                      │
│   - ilspycmd decompiler                          │                      │
│   - LLM security reviewer                        │                      │
└────────────────────────────────────┬─────────────┴──────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           END USER WORKSPACE                            │
│                                                                         │
│  [Mod Manager Client (NOMM)] ◄── Consumes manifest.json                 │
│              │                                                          │
│              ▼ Downloads & Installs                                     │
│  [Nuclear Option Game Client] ◄── Runs BepInEx 5 + Harmony Patches      │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Component Responsibility Matrix

| Component | Files / Directories | Responsibility | Primary Consumer |
|---|---|---|---|
| **Atomic Manifest Store** | `modManifests/*.json` | Individual mod metadata files acting as the single source of truth for each mod. | Maintainers, Actions, Parsers |
| **Compiled Registry** | `manifest/manifest.json`, `manifest/version.json` | Consolidated catalog array and semantic version identifier consumed over HTTP by mod managers. | NOMM, Third-party tools |
| **Schema & Validation Engine** | `ValidationSchema.json`, `Validate-JsonSchema.ps1`, `Validate-JsonContent.ps1`, `Run-JsonValidation.ps1` | Enforces structural constraints (Draft-07), integrity rules, file naming conventions, and relationship correctness. | CI/CD, Maintainers |
| **Release Scraper & Updater** | `Run-AutoUpdates.ps1`, `Update-ModArtifact.ps1`, `Get-GitHubReleases.ps1` | Queries GitHub Releases API, checks semantic versions, computes asset hashes, and appends new artifacts. | `hourly_update.yml` |
| **Dependency Synchronizer** | `Update-ModDependencies.ps1` | Scans dependency declarations and bumps version numbers to match latest active releases in the registry. | `hourly_update.yml` |
| **Metadata Cache System** | `gameVersionUpdateCache/`, `isClientOrServerUpdateCache/`, `modImageUpdateCache/` | Staging area for crowd-sourced metadata updates submitted via GitHub Issues. | `process_issues.yml`, `hourly_update.yml` |
| **Security Audit Pipeline** | `audit/`, `Audit-OpenSource.ps1`, `Invoke-CodeReview.ps1`, `audit/prompt.md` | Downloads release binaries, decompiles via `ilspycmd`, compares against repo source code, and runs security evaluations. | Maintainers, Security Reviewers |
| **Quarantine Storage** | `quarantine/*.json` | Holds delisted or malicious manifests for regression tracking, preventing compromised mods from reappearing. | Maintainers |

---

## 3. Data Models & Relationship Graph

### 3.1. Entity Relationship Diagram

```
┌──────────────────────────────────────────────────────────┐
│                           Mod                            │
├──────────────────────────────────────────────────────────┤
│ id: string (PK)                                          │
│ displayName: string                                      │
│ description: string                                      │
│ tags: string[]                                           │
│ imageUrl: string (URI)                                   │
│ imageHash: string (SHA-256)                              │
│ urls: [ { name, url } ]                                  │
│ authors: string[]                                        │
│ isClientOrServer: "Client" | "Server" | "Both"           │
│ githubOwner: string                                      │
│ githubRepoName: string                                   │
│ autoUpdateArtifacts: "True" | "False"                    │
│ artifacts: Artifact[]                                    │
└────────────────────────────┬─────────────────────────────┘
                             │ 1
                             │
                             │ has many
                             ▼ *
┌──────────────────────────────────────────────────────────┐
│                         Artifact                         │
├──────────────────────────────────────────────────────────┤
│ fileName: string                                         │
│ version: string (e.g. "1.2.0")                           │
│ category: "release" | "preRelease"                       │
│ type: "plugin" | "addOn"                                 │
│ gameVersion: string (e.g. "0.34.2")                      │
│ downloadUrl: string (URI)                                │
│ hash: string                                             │
│ extends: { id, version } (Optional, required for addOn)  │
│ dependencies: [ { id, version } ] (Optional)             │
│ incompatibilities: [ { id, version } ] (Optional)        │
└──────────────────────────────────────────────────────────┘
```

### 3.2. Relationship Semantics

1. **`dependencies` (Prerequisites)**:
   - Form: `[ { "id": "OtherModId", "version": "1.0.0" } ]`
   - Meaning: The mod requires `OtherModId` at or above version `1.0.0` to load and run safely.
   - Resolution: Mod managers use this list to order download and installation tasks.

2. **`incompatibilities` (Conflicts)**:
   - Form: `[ { "id": "ConflictingModId", "version": "2.0.0" } ]`
   - Meaning: This mod cannot coexist with `ConflictingModId` if `ConflictingModId` is at or below version `2.0.0`.
   - Resolution: Mod managers prevent simultaneous installation or flag warnings.

3. **`extends` (Add-on Parents)**:
   - Form: `{ "id": "BaseModId", "version": "1.5.0" }`
   - Meaning: This package is not a standalone BepInEx plugin, but an asset pack (voice lines, textures, blueprints) extending `BaseModId`.
   - Validation rule: When `type == "addOn"`, `extends` is mandatory.

---

## 4. Lifecycle & Data Flow Specifications

### 4.1. Manifest Ingestion Lifecycle

```
Contributor forks repo
         │
         ▼
Creates modManifests/<id>.json (matching template.json)
         │
         ▼
Submits Pull Request to main
         │
         ▼
[GitHub Actions: validateJson.yml]
  ├── Step 1: Detect changed JSON files (tj-actions/changed-files)
  ├── Step 2: Test-Json against ValidationSchema.json
  └── Step 3: Validate-JsonContent.ps1
        ├── Check filename matches mod ID
        ├── Check HTTPS artifact URLs
        ├── Check archive extension (.zip, .rar, .7z, .dll, .nobp, .tar.gz)
        ├── Check version strings parse as [System.Version]
        └── Check dependencies and extensions exist in registry
         │
    ┌────┴────────────┐
    ▼                 ▼
[Passed]           [Failed]
    │                 │
    │                 └── Pull Request blocked; developer fixes errors
    ▼
Maintainer performs security review
    │
    ▼
Merge to main branch
```

### 4.2. Automated Release Polling Lifecycle

```
[Cron Trigger: 22 * * * *]
         │
         ▼
[Run-AutoUpdates.ps1]
  ├── For each file in modManifests/*.json:
  │     └── If autoUpdateArtifacts == "True":
  │           ├── Execute Update-ModArtifact.ps1
  │           ├── Query GitHub Releases API
  │           ├── Parse latest release TagName as [System.Version]
  │           └── If newer than artifacts[0].version:
  │                 ├── Add new Artifact object
  │                 ├── Propagate dependencies, incompatibilities, extends
  │                 ├── Set gameVersion (default: existing latest or "0.32")
  │                 └── Sort artifacts array by version descending
  │
  └── Execute Update-ModDependencies.ps1
        └── Update dependency version strings to match latest catalog versions
         │
         ▼
[Run-JsonValidation.ps1]
  ├── Re-validate entire catalog against schema
  └── Compile and overwrite manifest/manifest.json (UTF-8 No BOM)
         │
         ▼
[Increment-ManifestVersion.ps1]
  └── Read manifest/version.json, increment 4th component (revision), save
         │
         ▼
[Process Pending Caches]
  ├── Apply gameVersionUpdateCache/*.json
  ├── Apply modImageUpdateCache/*.json
  └── Apply isClientOrServerUpdateCache/*.json
         │
         ▼
Commit & Push to main
```

### 4.3. Issue-Driven Metadata Caching Lifecycle

```
Community member submits GitHub Issue Form
  ├── "Update gameVersion"
  ├── "Update Mod Image URL"
  └── "Update Client/Server Status"
         │
         ▼
Maintainer reviews and applies trigger label
  ├── "gameVersion Update"
  ├── "Mod Image Update"
  └── "isClientOrServer Update"
         │
         ▼
[GitHub Actions: process_issues.yml]
  ├── Parse markdown headers and extract field values
  ├── Validate field values:
  │     ├── Version string matches [System.Version]
  │     ├── Mod ID exists in modManifests/
  │     ├── Image URL is reachable, valid format, <= 512x512, calculate SHA-256
  │     └── isClientOrServer is strictly "Client", "Server", or "Both"
  │
  ├── If validation fails:
  │     ├── Write failure description to error.txt
  │     └── Post comment on issue with error text
  │
  └── If validation succeeds:
        ├── Save JSON payload to <category>UpdateCache/<IssueId>.json
        ├── Commit cache file to repository
        └── Close issue with reason "completed"
         │
         ▼
[Hourly Update Workflow picks up cache files, applies changes to modManifests, and removes cache files]
```

### 4.4. Security Audit & Decompilation Lifecycle

```
[Audit-OpenSource.ps1]
  ├── Install ilspycmd (.NET decompiler)
  ├── Iterate active mods in manifest/manifest.json
  ├── Setup workspace: audit/<ModId>/{repo, release, decompiled, results}
  ├── Clone mod's GitHub repo into audit/<ModId>/repo
  ├── Download release archive into audit/<ModId>/release and unpack
  ├── Scan for .dll and .exe binaries:
  │     ├── 0 binaries: Flag "NO ASSEMBLIES OR EXECUTABLES"
  │     ├── Empty/readme repo: Flag "NOT OPEN SOURCE"
  │     ├── 1 binary: Decompile via ilspycmd into audit/<ModId>/decompiled
  │     └── >1 binaries: Flag "MULTIPLE ASSEMBLIES OR EXECUTABLES"
  │
  └── For decompiled single-assembly mods:
        └── [Invoke-CodeReview.ps1]
              ├── Collect all .cs files from repo/
              ├── Collect all .cs files from decompiled/
              ├── Bundle with audit/prompt.md
              ├── Pipe to Antigravity CLI (agy)
              └── Save review to audit/<ModId>/results/AI_Review.md
                     │
        ┌────────────┴─────────────┐
        ▼                          ▼
     [PASS]                     [FAIL]
   Mod remains active         Move to quarantine/<ModId>.json
                              Delist from active manifest
```

---

## 5. Technical Invariants & Serialization Conventions

### 5.1. PowerShell JSON Serialization Depth
PowerShell's `ConvertTo-Json` cmdlet has a default recursion depth of 2. In NOMNOM, the Mod object contains arrays of Artifact objects, which themselves contain arrays of Dependency, Incompatibility, or Extends objects:
- `Mod` (Depth 1)
  - `artifacts` (Depth 2)
    - `dependencies` (Depth 3)
      - `id`, `version` (Depth 4)

Serializing with default settings converts child objects to strings (`"System.Collections.Hashtable"`). All scripts MUST use `-Depth 100` or `-Depth 1000`.

### 5.2. Character Encoding and BOM
- Windows PowerShell 5.1 defaults to `ANSI` or `UTF-16 LE`.
- PowerShell 7 (`pwsh`) defaults to `utf8NoBOM`.
- All file writes in NOMNOM must specify `-Encoding utf8NoBOM` or `-Encoding utf8`.
- Manifest JSON files must NEVER contain a Byte Order Mark (BOM), which causes strict JSON parsers in Linux environments and Web APIs to fail.
