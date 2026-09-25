# NOMNOM Operational Workflows & Runbooks

This document provides concrete operational runbooks and PowerShell commands for developers and automated agents working on NOMNOM.

All commands assume PowerShell 7 (`pwsh`), which is the standard shell in CI/CD runners and modern Windows workstations.

---

## 1. Local Validation Workflow

Before submitting changes or committing new manifests, run the full validation suite locally.

### 1.1. Validate Entire Catalog
Runs schema and business logic checks against all manifests in `modManifests/`:

```powershell
pwsh -NoProfile -Command ".\Run-JsonValidation.ps1"
```

Expected output:
```text
C:\code\NOMNOM\modManifests\<mod>.json
JSON SCHEMA is valid.
Validating <mod>...
...
ALL VALIDATIONS CHECKS SUCCEEDED!
```

### 1.2. Validate a Single Manifest File
To validate a single modified manifest without checking the entire directory:

```powershell
pwsh -NoProfile -Command {
    $ModPath = ".\modManifests\com.example.mod.json"
    $SchemaPath = ".\ValidationSchema.json"
    $CurrentManifest = (Get-Content ".\manifest\manifest.json" | ConvertFrom-Json) | Group-Object id -AsHashTable

    .\Validate-JsonSchema.ps1 -JsonPath $ModPath -SchemaPath $SchemaPath
    .\Validate-JsonContent.ps1 -Path $ModPath -ModManifestHashTable $CurrentManifest
}
```

---

## 2. Adding a New Mod Manifest

### 2.1. Procedure
1. Create a copy of `template.json`:
   ```powershell
   Copy-Item .\template.json .\modManifests\<YourModId>.json
   ```
2. Populate the required properties:
   - `id`: Must match the BepInEx assembly name or unique naming standard, and MUST match the filename `<YourModId>.json`.
   - `displayName`: Human-readable title.
   - `description`: Summary of what the mod does.
   - `authors`: Array of contributor names.
   - `urls`: Must contain at least an entry with `"name": "info"`.
   - `isClientOrServer`: `"Client"`, `"Server"`, or `"Both"`.
   - `artifacts`: Array containing at least one release object.
3. If auto-updating via GitHub Releases is desired:
   - Set `"githubOwner"` to the repository owner.
   - Set `"githubRepoName"` to the repository name.
   - Set `"autoUpdateArtifacts"` to `"True"`.
4. Validate the new file:
   ```powershell
   pwsh -NoProfile -Command ".\Run-JsonValidation.ps1"
   ```

---

## 3. Manifest Compilation & Versioning

### 3.1. Recompiling `manifest/manifest.json`
To manually regenerate `manifest/manifest.json` from the current contents of `modManifests/`:

```powershell
pwsh -NoProfile -Command ".\Compile-Manifest.ps1 -inputPath .\modManifests -outputPath .\manifest"
```

### 3.2. Incrementing Manifest Version
`manifest/version.json` stores the 4-part semantic version consumed by mod managers to detect changes. Increment the revision component:

```powershell
pwsh -NoProfile -Command ".\Increment-ManifestVersion.ps1"
```

Verification:
```powershell
Get-Content .\manifest\version.json
```

---

## 4. Automated Release Scraper Workflows

### 4.1. Test Auto-Updates on a Single Mod
To test whether GitHub release scraping works for a specific mod without altering the real manifest:

```powershell
# Requires GitHub personal access token to avoid rate limiting
$Token = "ghp_your_token_here"
pwsh -NoProfile -Command ".\Update-ModArtifact.ps1 -modPath .\modManifests\NO_Tactitools.json -gitHubToken '$Token' -test `$true"
```
When `-test $true` is specified, output is written to `.\test\<modId>.json`.

### 4.2. Run Full Catalog Auto-Update
To poll all mods with `autoUpdateArtifacts: "True"` and resolve dependencies across the catalog:

```powershell
$Token = "ghp_your_token_here"
pwsh -NoProfile -Command ".\Run-AutoUpdates.ps1 -token '$Token'"
```

---

## 5. Processing Pending Metadata Caches

When GitHub issues are processed via `process_issues.yml`, intermediate JSON requests are staged in cache directories. You can apply them manually or locally using these commands:

### 5.1. Apply Game Version Updates
```powershell
pwsh -NoProfile -Command ".\.github\scripts\Update-GameVersions.ps1 -CacheDir .\gameVersionUpdateCache -ManifestDir .\modManifests"
```

### 5.2. Apply Mod Image Updates
```powershell
pwsh -NoProfile -Command ".\.github\scripts\Update-ModImageUrls.ps1 -CacheDir .\modImageUpdateCache -ManifestDir .\modManifests"
```

### 5.3. Apply Client/Server Status Updates
```powershell
pwsh -NoProfile -Command ".\.github\scripts\Update-IsClientOrServer.ps1 -CacheDir .\isClientOrServerUpdateCache -ManifestDir .\modManifests"
```

---

## 6. Security Audit & Decompilation Runbook

### 6.1. Prerequisites
Ensure .NET 8/9 SDK and the `ilspycmd` decompiler tool are installed:
```powershell
dotnet tool install -g ilspycmd
```

### 6.2. Run Repository & Binary Scraping
To clone repositories, download release archives, extract binaries, and decompile assemblies for all active mods:

```powershell
pwsh -NoProfile -Command ".\Audit-OpenSource.ps1"
```

This populates `audit/<ModId>/`:
- `repo/`: Cloned Git source code.
- `release/`: Extracted release binary files (`.dll`, `.exe`).
- `decompiled/`: C# decompiled source code generated by `ilspycmd`.
- `results/ReleaseAudit.txt`: Status flags (`Ready For Automated Code Review`, `NOT OPEN SOURCE`, `MULTIPLE ASSEMBLIES`).

### 6.3. Execute AI Security Review
To analyze code discrepancies between source repository and distributed binary:

```powershell
# Requires Antigravity CLI (agy) installed and configured
pwsh -NoProfile -Command ".\Invoke-CodeReview.ps1 -ModId 'com.example.mod' -PromptFilePath '.\audit\prompt.md'"
```

The output report will be written to `.\audit\<ModId>\results\AI_Review.md`.

---

## 7. Quarantining a Compromised or Delisted Mod

If a mod breaches the Mod Submission Acceptance Policy (e.g. contains obfuscated code, unauthorized file writes, hidden network calls, or game-crashing routines):

1. **Move Manifest to Quarantine**:
   ```powershell
   Move-Item -Path ".\modManifests\<OffendingModId>.json" -Destination ".\quarantine\<OffendingModId>.json" -Force
   ```
2. **Re-validate and Recompile Manifest**:
   ```powershell
   pwsh -NoProfile -Command ".\Run-JsonValidation.ps1"
   ```
3. **Increment Manifest Version**:
   ```powershell
   pwsh -NoProfile -Command ".\Increment-ManifestVersion.ps1"
   ```
4. **Commit the Quarantine Action**:
   ```powershell
   git add quarantine/ modManifests/ manifest/
   git commit -m "Quarantine <OffendingModId>: violation of acceptance policy"
   ```

---

## 8. Troubleshooting Common Validation Errors

| Error | Root Cause | Resolution |
|---|---|---|
| `JSON SCHEMA is invalid!` | File does not conform to `ValidationSchema.json` (missing required fields like `authors`, `urls`, `type`). | Inspect output from `Validate-JsonSchema.ps1`. Check `required` fields against `SCHEMA.md`. |
| `Id <modId> does not match file name!` | The filename `modManifests/<file>.json` does not match the `id` value inside the JSON. | Rename the file or adjust the `id` string so they are identical. |
| `Artifact <URL> failed URL validation!` | The `downloadUrl` is not HTTPS or does not end in a supported archive extension. | Ensure URL uses `https://` and ends in `.zip`, `.rar`, `.7z`, `.dll`, `.nobp`, or `.tar.gz`. |
| `<version> is not of valid Version Format!` | The version string cannot be cast to `[System.Version]`. | Remove non-numeric characters (e.g., `v1.0.0` -> `1.0.0`). .NET versions require integer segments (`Major.Minor[.Build[.Revision]]`). |
| `Relation <id> is invalid!` | A mod referenced in `dependencies`, `incompatibilities`, or `extends` does not exist in the manifest. | Confirm the target `id` exists in `modManifests/` and that the filename matches. |
| Child objects serialized as `"System.Collections.Hashtable"` | PowerShell `ConvertTo-Json` default recursion depth was used. | Re-run with `-Depth 100` (`$data | ConvertTo-Json -Depth 100`). |
