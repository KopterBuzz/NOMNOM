# Release selection regression tests

Run with PowerShell 7 from the repository root:

```powershell
pwsh -NoProfile -File ./tests/ReleaseSelection.Tests.ps1
```

No module installation, GitHub token or network access is required. The tests cover legacy tag/first-asset behaviour, independent per-mod tag prefixes, exact asset selection, invalid/missing packages, schema validation, and the real updater's artifact metadata, sorting and download counts.

Updater integration checks run in temporary directories with a fixture-backed GitHub provider. They do not change `modManifests/` or the compiled catalog. The temporary directories are removed afterwards. The suite throws on a failed assertion and returns a nonzero process exit code.
