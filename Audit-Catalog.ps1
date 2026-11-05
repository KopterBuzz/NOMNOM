<#
.SYNOPSIS
    Audits mods by downloading releases and decompiling assemblies.

.DESCRIPTION
    Reads mod metadata directly from manifest\manifest.json (or a specified manifest / CSV file).
    For each mod:
      1. Clones the source repository into Open_PR_Audit/<name>/repo
         - For shared repositories, downloads/clones the repository ONLY ONCE,
           reusing the local clone for all subsequent mods sharing the repository.
      2. Downloads the appropriate release asset for this mod:
         - For shared repositories: selects the release matching releaseTagPrefix
           and downloads only the asset matching releaseAssetName.
         - For standalone repositories: downloads release assets from latest release.
         - Fallback: downloads from direct downloadUrl if GitHub release query fails.
         - Caches GitHub Releases API responses and downloaded assets per shared repository.
      3. Extracts any downloaded archives (.zip, .tar.gz, etc.)
      4. Decompiles all assemblies (.dll, .exe) using ilspycmd into Open_PR_Audit/<name>/decomp/

.PARAMETER ManifestPath
    Path to the manifest.json file to process. Defaults to '.\manifest\manifest.json'.
    Also accepts legacy CSV paths via -CsvPath alias for backwards compatibility.

.PARAMETER OutputDir
    Base directory where audited mods will be organized. Defaults to '.\Open_PR_Audit'.

.PARAMETER Token
    GitHub Personal Access Token for authenticated API requests.

.PARAMETER ModIds
    Optional list of specific Mod IDs to audit. If omitted, all mods in the manifest are processed.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [Alias('CsvPath')]
    [string]$ManifestPath = '.\manifest\manifest.json',

    [Parameter(Mandatory = $false)]
    [string]$OutputDir = '.\audit',

    [Parameter(Mandatory = $false)]
    [string]$Token,

    [Parameter(Mandatory = $false)]
    [string[]]$ModIds
)

if (-not $Token) {
    $Token = $env:GITHUB_TOKEN
    if (-not $Token) { $Token = $env:GH_TOKEN }
}

$headers = @{
    'User-Agent' = 'NOMNOM-Audit-PowerShell'
    'Accept'     = 'application/vnd.github+json'
}
if ($Token) {
    $headers['Authorization'] = "Bearer $Token"
    Write-Host "[*] Authenticated GitHub session active." -ForegroundColor Green
}

# -------------------------------------------------------------------------
# Startup Check: Verify required decompilation tool (ilspycmd)
# -------------------------------------------------------------------------
$hasIlSpy = [bool](Get-Command ilspycmd -ErrorAction SilentlyContinue)
if (-not $hasIlSpy) {
    # Check common .NET global tools directories and add to PATH if present
    $dotnetToolsDir = Join-Path $HOME ".dotnet\tools"
    if ((Test-Path (Join-Path $dotnetToolsDir "ilspycmd.exe")) -or (Test-Path (Join-Path $dotnetToolsDir "ilspycmd"))) {
        $env:PATH = "$dotnetToolsDir;$env:PATH"
        $hasIlSpy = [bool](Get-Command ilspycmd -ErrorAction SilentlyContinue)
    }
}

if ($hasIlSpy) {
    $ilspyVersion = try { (ilspycmd --version 2>&1 | Select-Object -First 1) } catch { "detected" }
    Write-Host "[*] ilspycmd decompilation tool active ($ilspyVersion)." -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "[WARNING] 'ilspycmd' is not installed or not in your PATH!" -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "'ilspycmd' is required to decompile downloaded assemblies (.dll / .exe)" -ForegroundColor Yellow
    Write-Host "into C# source code for the automated security review." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To install ilspycmd, run:" -ForegroundColor Yellow
    Write-Host "    dotnet tool install -g ilspycmd" -ForegroundColor Green
    Write-Host ""
    Write-Host "Ensure the .NET global tools directory is in your PATH environment variable:" -ForegroundColor Yellow
    Write-Host "    Windows:     $HOME\.dotnet\tools" -ForegroundColor DarkGray
    Write-Host "    Linux/macOS: ~/.dotnet/tools" -ForegroundColor DarkGray
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host ""
}

# Resolve helpers if present in workspace
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$helperReleases = Join-Path $scriptDir "Get-GitHubReleases.ps1"
$helperArtifact = Join-Path $scriptDir "Get-ModReleaseArtifact.ps1"

if (Test-Path $helperReleases) {
    . $helperReleases
}
if (Test-Path $helperArtifact) {
    . $helperArtifact
}

if (-not (Test-Path $ManifestPath)) {
    Write-Error "Manifest file not found: $ManifestPath"
    return
}

# Helper function to copy/clone a repository locally without network
function Copy-RepoDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    }

    $gitSuccess = $false
    try {
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        $null = git clone --local $Source $Destination 2>&1
        $ErrorActionPreference = $prevEap
        if ($LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $Destination ".git"))) {
            $gitSuccess = $true
        }
    }
    catch {
        $gitSuccess = $false
    }

    if (-not $gitSuccess) {
        # Fallback to PowerShell Copy-Item
        Copy-Item -Path (Join-Path $Source "*") -Destination $Destination -Recurse -Force
        $sourceGit = Join-Path $Source ".git"
        if (Test-Path $sourceGit) {
            Copy-Item -Path $sourceGit -Destination (Join-Path $Destination ".git") -Recurse -Force
        }
    }
}

# Load input data from JSON manifest or legacy CSV
$data = @()
if ($ManifestPath.EndsWith('.csv', [StringComparison]::OrdinalIgnoreCase)) {
    Write-Host "[*] Loading mod list from CSV: $ManifestPath" -ForegroundColor Cyan
    $data = @(Import-Csv -Path $ManifestPath)
}
else {
    Write-Host "[*] Loading mod manifest catalog from JSON: $ManifestPath" -ForegroundColor Cyan
    $jsonRaw = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json
    $data = @($jsonRaw)
}

# Filter by ModIds if specified
if ($ModIds -and $ModIds.Count -gt 0) {
    $data = @($data | Where-Object { $ModIds -contains $_.id -or $ModIds -contains $_.name })
    Write-Host "[*] Filtered to $($data.Count) requested mod(s)." -ForegroundColor Cyan
}

Write-Host "[*] Total mods to process: $($data.Count)" -ForegroundColor Green

# Shared repository and release caches to eliminate redundant network downloads
$clonedRepos = @{}
$releasesCache = @{}
$assetDownloadsCache = @{}

foreach ($item in $data) {
    $name = if ($item.id) { $item.id } else { $item.name }
    $owner = $item.githubOwner
    $repo = $item.githubRepoName
    $tagPrefix = $item.releaseTagPrefix
    $assetName = $item.releaseAssetName

    $downloadUrl = $null
    if ($item.downloadUrl) {
        $downloadUrl = $item.downloadUrl
    }
    elseif ($item.artifacts -and $item.artifacts.Count -gt 0) {
        $downloadUrl = $item.artifacts[0].downloadUrl
    }

    # Resolve clone URL
    $url = $null
    if ($item.url) {
        $url = $item.url
    }
    elseif ($owner -and $repo) {
        $url = "https://github.com/$owner/$repo"
    }
    else {
        $infoUrl = ($item.urls | Where-Object { $_.name -eq 'info' }).url
        if (-not $infoUrl -and $item.urls -and $item.urls.Count -gt 0) {
            $infoUrl = $item.urls[0].url
        }
        if ($infoUrl) {
            $url = $infoUrl
        }
    }

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "Processing $name..." -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    # If tagPrefix, assetName, or downloadUrl are missing, check for a local manifest
    $localManifestPath = Join-Path $scriptDir "modManifests\$name.json"
    if (Test-Path $localManifestPath) {
        try {
            $localJson = Get-Content $localManifestPath -Raw | ConvertFrom-Json
            if (-not $tagPrefix -and $localJson.releaseTagPrefix) { $tagPrefix = $localJson.releaseTagPrefix }
            if (-not $assetName -and $localJson.releaseAssetName) { $assetName = $localJson.releaseAssetName }
            if (-not $downloadUrl -and $localJson.artifacts -and $localJson.artifacts.Count -gt 0) {
                $downloadUrl = $localJson.artifacts[0].downloadUrl
            }
            if (-not $owner -and $localJson.githubOwner) { $owner = $localJson.githubOwner }
            if (-not $repo -and $localJson.githubRepoName) { $repo = $localJson.githubRepoName }
        }
        catch { }
    }

    # Clean up owner/repo and repository URL
    if (-not ($owner -and $repo)) {
        if ($url -match 'github\.com/([^/]+)/([^/#?]+)') {
            if (-not $owner) { $owner = $matches[1] }
            if (-not $repo) { $repo = $matches[2] -replace '\.(git|zip|rar|7z|tar\.gz|tgz|gz|tar)$', '' }
        }
    }
    if ($owner -and ($owner -match 'github\.com/([^/#?]+)')) {
        $owner = $matches[1]
    }
    if ($owner) { $owner = $owner.Trim().Trim('/') }

    if ($repo -and ($repo -match 'github\.com/([^/]+)/([^/#?]+)')) {
        if (-not $owner) { $owner = $matches[1] }
        $repo = $matches[2]
    }
    if ($repo) { $repo = ($repo -replace '\.git$', '').Trim().Trim('/') }

    if (-not $url -and $owner -and $repo) {
        $url = "https://github.com/$owner/$repo"
    }

    # Compute shared repository key
    $repoKey = if ($owner -and $repo) {
        "$owner/$repo".ToLowerInvariant()
    }
    elseif ($url) {
        $url.ToLowerInvariant()
    }
    else {
        $name.ToLowerInvariant()
    }

    # 1. Create base directory
    $baseDir = Join-Path $OutputDir $name
    New-Item -ItemType Directory -Force -Path $baseDir | Out-Null

    # 2. Clone repo (or reuse already-downloaded shared repository to save bandwidth)
    $repoDir = Join-Path $baseDir "repo"
    $hasExistingRepo = (Test-Path (Join-Path $repoDir ".git")) -or ((Test-Path $repoDir) -and (Get-ChildItem -Path $repoDir -Force -ErrorAction SilentlyContinue).Count -gt 0)

    if (-not $hasExistingRepo) {
        New-Item -ItemType Directory -Force -Path $repoDir | Out-Null

        if ($clonedRepos.ContainsKey($repoKey) -and (Test-Path $clonedRepos[$repoKey])) {
            $cachedSource = $clonedRepos[$repoKey]
            Write-Host "  [*] Reusing shared repository from '$cachedSource' (skipping network download)..." -ForegroundColor Yellow
            Copy-RepoDirectory -Source $cachedSource -Destination $repoDir
        }
        else {
            if ($url) {
                Write-Host "  Cloning repository from $url..."
                try {
                    git clone $url $repoDir
                    if (Test-Path (Join-Path $repoDir ".git")) {
                        $clonedRepos[$repoKey] = $repoDir
                    }
                }
                catch {
                    Write-Host "  Failed to clone repository: $_" -ForegroundColor Red
                }
            }
            else {
                Write-Host "  No repository URL available for $name." -ForegroundColor Yellow
            }
        }
    }
    else {
        Write-Host "  Repository already exists at $repoDir."
        if (-not $clonedRepos.ContainsKey($repoKey)) {
            $clonedRepos[$repoKey] = $repoDir
        }
    }

    # 3. Download release
    $releaseDir = Join-Path $baseDir "release"
    New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
    Write-Host "  Resolving and downloading release assets..."

    $downloadedFiles = @()

    if ($owner -and $repo) {
        $modSelector = [PSCustomObject]@{
            id               = $name
            releaseTagPrefix = if ($tagPrefix) { $tagPrefix.Trim() } else { $null }
            releaseAssetName = if ($assetName) { $assetName.Trim() } else { $null }
        }

        $releaseFound = $false

        try {
            # Try fetching releases via GitHub API (reuse cache for shared repos)
            $releases = $null
            if ($releasesCache.ContainsKey($repoKey)) {
                $releases = $releasesCache[$repoKey]
                Write-Host "    [*] Reusing cached GitHub releases for $owner/$repo..." -ForegroundColor DarkGray
            }
            else {
                if (Get-Command Get-GitHubReleases -ErrorAction SilentlyContinue) {
                    try {
                        $releases = Get-GitHubReleases -Owner $owner -Repository $repo -Token $Token
                    }
                    catch {
                        Write-Host "    Get-GitHubReleases failed: $_" -ForegroundColor Yellow
                    }
                }

                if (-not $releases) {
                    $apiUrl = "https://api.github.com/repos/$owner/$repo/releases?per_page=100"
                    try {
                        $apiReleases = @(Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get)
                        if ($apiReleases -and $apiReleases.Count -gt 0) {
                            $releases = foreach ($rel in $apiReleases) {
                                $assets = foreach ($asset in $rel.assets) {
                                    [PSCustomObject]@{
                                        FileName      = $asset.name
                                        DownloadUrl   = $asset.browser_download_url
                                        Size          = $asset.size
                                        ContentType   = $asset.content_type
                                        DownloadCount = $asset.download_count
                                        digest        = $asset.digest
                                    }
                                }
                                [PSCustomObject]@{
                                    TagName      = $rel.tag_name
                                    ReleaseName  = $rel.name
                                    ReleaseUrl   = $rel.html_url
                                    PublishedAt  = if ($rel.published_at) { [DateTime]$rel.published_at } else { $null }
                                    IsPrerelease = [bool]$rel.prerelease
                                    IsDraft      = [bool]$rel.draft
                                    Body         = $rel.body
                                    Author       = $rel.author.login
                                    Assets       = $assets
                                    AssetCount   = $assets.Count
                                }
                            }
                        }
                    }
                    catch {
                        Write-Host "    GitHub API releases endpoint unavailable: $_" -ForegroundColor Yellow
                    }
                }

                if ($releases) {
                    $releasesCache[$repoKey] = $releases
                }
            }

            if ($releases) {
                if ($modSelector.releaseTagPrefix -or $modSelector.releaseAssetName) {
                    # Shared repository or explicit asset selection
                    foreach ($rel in $releases) {
                        $match = if (Get-Command Get-ModReleaseArtifact -ErrorAction SilentlyContinue) {
                            Get-ModReleaseArtifact -Mod $modSelector -Release $rel -WarningAction SilentlyContinue
                        }
                        else {
                            if ($rel.IsDraft) { continue }
                            $vText = $rel.TagName
                            if ($modSelector.releaseTagPrefix) {
                                if (-not $vText.StartsWith($modSelector.releaseTagPrefix, [StringComparison]::Ordinal)) {
                                    continue
                                }
                                $vText = $vText.Substring($modSelector.releaseTagPrefix.Length)
                            }
                            else {
                                $vText = $vText -replace "v|\-pre|_IL2CPP", ""
                            }
                            [version]$v = $null
                            if (-not [version]::TryParse($vText, [ref]$v)) { continue }
                            if (-not $rel.Assets) { continue }

                            $matchedAsset = if ($modSelector.releaseAssetName) {
                                $rel.Assets | Where-Object { [string]::Equals($_.FileName, $modSelector.releaseAssetName, [StringComparison]::Ordinal) } | Select-Object -First 1
                            }
                            else {
                                $rel.Assets[0]
                            }

                            if ($matchedAsset) {
                                [PSCustomObject]@{
                                    Version = $vText
                                    Asset   = $matchedAsset
                                }
                            }
                        }

                        if ($match) {
                            $releaseFound = $true
                            $targetAsset = $match.Asset
                            $targetFileName = $targetAsset.FileName
                            $destPath = Join-Path $releaseDir $targetFileName

                            if ($assetDownloadsCache.ContainsKey($targetAsset.DownloadUrl) -and (Test-Path $assetDownloadsCache[$targetAsset.DownloadUrl])) {
                                Write-Host "    [*] Reusing cached asset '$targetFileName' from shared download..." -ForegroundColor DarkGray
                                Copy-Item -Path $assetDownloadsCache[$targetAsset.DownloadUrl] -Destination $destPath -Force
                            }
                            else {
                                Write-Host "    Downloading asset '$targetFileName' from tag '$($rel.TagName)'..."
                                Invoke-WebRequest -Uri $targetAsset.DownloadUrl -OutFile $destPath
                                $assetDownloadsCache[$targetAsset.DownloadUrl] = $destPath
                            }

                            $downloadedFiles += $destPath
                            break
                        }
                    }
                }
                else {
                    # Standalone mod: pick first non-draft release
                    $rel = $releases | Where-Object { -not $_.IsDraft } | Select-Object -First 1
                    if ($rel -and $rel.Assets -and $rel.Assets.Count -gt 0) {
                        $releaseFound = $true
                        foreach ($asset in $rel.Assets) {
                            $targetFileName = $asset.FileName
                            $destPath = Join-Path $releaseDir $targetFileName

                            if ($assetDownloadsCache.ContainsKey($asset.DownloadUrl) -and (Test-Path $assetDownloadsCache[$asset.DownloadUrl])) {
                                Write-Host "    [*] Reusing cached asset '$targetFileName' from shared download..." -ForegroundColor DarkGray
                                Copy-Item -Path $assetDownloadsCache[$asset.DownloadUrl] -Destination $destPath -Force
                            }
                            else {
                                Write-Host "    Downloading asset '$targetFileName'..."
                                Invoke-WebRequest -Uri $asset.DownloadUrl -OutFile $destPath
                                $assetDownloadsCache[$asset.DownloadUrl] = $destPath
                            }

                            $downloadedFiles += $destPath
                        }
                    }
                }
            }
        }
        catch {
            Write-Host "    Error resolving GitHub release: $_" -ForegroundColor Yellow
        }
    }

    # Fallback: download directly from downloadUrl if GitHub release search yielded nothing
    if ($downloadedFiles.Count -eq 0) {
        if ($downloadUrl) {
            Write-Host "    Using manifest downloadUrl fallback: $downloadUrl" -ForegroundColor Yellow
            $fallbackFileName = if ($assetName) {
                $assetName
            }
            else {
                try {
                    [System.IO.Path]::GetFileName([uri]$downloadUrl.AbsolutePath)
                }
                catch {
                    "release.zip"
                }
            }
            if (-not $fallbackFileName) { $fallbackFileName = "release.zip" }
            $destPath = Join-Path $releaseDir $fallbackFileName
            try {
                if ($assetDownloadsCache.ContainsKey($downloadUrl) -and (Test-Path $assetDownloadsCache[$downloadUrl])) {
                    Write-Host "    [*] Reusing cached fallback asset '$fallbackFileName'..." -ForegroundColor DarkGray
                    Copy-Item -Path $assetDownloadsCache[$downloadUrl] -Destination $destPath -Force
                    $downloadedFiles += $destPath
                }
                else {
                    Invoke-WebRequest -Uri $downloadUrl -OutFile $destPath
                    $assetDownloadsCache[$downloadUrl] = $destPath
                    $downloadedFiles += $destPath
                    Write-Host "    Downloaded fallback asset '$fallbackFileName' successfully."
                }
            }
            catch {
                Write-Host "    Failed to download from fallback URL: $_" -ForegroundColor Red
            }
        }
        else {
            Write-Host "    No releases found and no downloadUrl specified." -ForegroundColor Yellow
        }
    }

    # Extract any archives
    foreach ($file in $downloadedFiles) {
        if ($file -match '\.zip$') {
            Write-Host "    Extracting $(Split-Path $file -Leaf)..."
            Expand-Archive -Path $file -DestinationPath $releaseDir -Force
        }
        elseif ($file -match '\.(tar\.gz|tgz|tar)$') {
            Write-Host "    Extracting $(Split-Path $file -Leaf) with tar..."
            tar -xf $file -C $releaseDir
        }
    }

    # 4. Decompile
    $decompDir = Join-Path $baseDir "decomp"
    New-Item -ItemType Directory -Force -Path $decompDir | Out-Null
    Write-Host "  Decompiling downloaded assemblies..."

    $assemblies = Get-ChildItem -Path $releaseDir -Recurse -Include *.dll, *.exe
    if ($assemblies.Count -eq 0) {
        Write-Host "    No assemblies (.dll / .exe) found in $releaseDir." -ForegroundColor Yellow
    }
    elseif (-not $hasIlSpy) {
        Write-Host "    Skipping decompilation: 'ilspycmd' is not installed (run 'dotnet tool install -g ilspycmd')." -ForegroundColor Yellow
    }
    else {
        foreach ($asm in $assemblies) {
            Write-Host "    Decompiling $($asm.Name)..."
            $asmDecompDir = Join-Path $decompDir $asm.BaseName
            New-Item -ItemType Directory -Force -Path $asmDecompDir | Out-Null

            try {
                ilspycmd $asm.FullName -p -o $asmDecompDir
            }
            catch {
                Write-Host "    Failed to decompile $($asm.Name): $_" -ForegroundColor Red
            }
        }
    }
}

Write-Host ""
Write-Host "[SUCCESS] Audit preparation complete for all records." -ForegroundColor Green
