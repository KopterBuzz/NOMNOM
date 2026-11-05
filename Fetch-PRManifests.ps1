<#
.SYNOPSIS
    Checks Pull Requests on the repository for newly added .json files in modManifests/
    and generates an audit.csv file matching the schema of aug30.csv.

.DESCRIPTION
    Queries the GitHub REST API for Pull Requests in the target repository.
    Filters for PRs that ADD new manifest files under the 'modManifests/' directory.
    Downloads and parses the manifest JSON content to extract repository details,
    including shared release repository selectors (releaseTagPrefix, releaseAssetName),
    then outputs audit.csv with columns:
    name,url,release,githubOwner,githubRepoName,releaseTagPrefix,releaseAssetName,downloadUrl.

.PARAMETER Repo
    The GitHub repository in 'owner/repo' format. Defaults to detecting from git remote or 'KopterBuzz/NOMNOM'.

.PARAMETER State
    The PR state to check: 'all', 'open', or 'closed'. Defaults to 'open'.

.PARAMETER OutputFile
    The CSV file path to generate. Defaults to 'audit_open.csv'.

.PARAMETER Token
    GitHub Personal Access Token. If omitted, checks $env:GITHUB_TOKEN, $env:GH_TOKEN, or git credentials.

.PARAMETER Concurrency
    Number of parallel threads for inspecting PR files. Defaults to 10.

.PARAMETER IncludeModified
    Also inspect modified manifest files in addition to newly added manifests.

.EXAMPLE
    .\Fetch-PRManifests.ps1
    .\Fetch-PRManifests.ps1 -State open
    .\Fetch-PRManifests.ps1 -State all -OutputFile .\audit.csv
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [ValidateSet('all', 'open', 'closed')]
    [string]$State = 'open',

    [Parameter(Mandatory = $false)]
    [string]$OutputFile = 'audit_open.csv',

    [Parameter(Mandatory = $false)]
    [string]$Token,

    [Parameter(Mandatory = $false)]
    [int]$Concurrency = 10,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeModified = $false
)

# 1. Resolve Target Repository
if (-not $Repo) {
    try {
        $originUrl = git config --get remote.origin.url 2>$null
        if ($originUrl -match 'github\.com[:/]([^/]+)/([^/.]+)(?:\.git)?') {
            $Repo = "$($matches[1])/$($matches[2])"
        }
    }
    catch { }

    if (-not $Repo) {
        $Repo = "KopterBuzz/NOMNOM"
    }
}

# 2. Resolve GitHub Token
if (-not $Token) {
    if ($env:GITHUB_TOKEN) {
        $Token = $env:GITHUB_TOKEN
    }
    elseif ($env:GH_TOKEN) {
        $Token = $env:GH_TOKEN
    }
    else {
        try {
            $fillInput = @("protocol=https", "host=github.com", "") -join "`n"
            $credOutput = $fillInput | git credential fill 2>$null
            foreach ($line in ($credOutput -split "`r?`n")) {
                if ($line -like "password=*") {
                    $Token = $line.Substring(9).Trim()
                    break
                }
            }
        }
        catch { }
    }
}

$headers = @{
    'User-Agent' = 'NOMNOM-Audit-PowerShell'
    'Accept'     = 'application/vnd.github+json'
}
if ($Token) {
    $headers['Authorization'] = "Bearer $Token"
    Write-Host "[*] Authenticated GitHub session active." -ForegroundColor Green
}
else {
    Write-Host "[!] Warning: No GitHub token detected. Unauthenticated API rate limit is 60 req/hr." -ForegroundColor Yellow
}

# Helper function to extract (name, url, release, selectors) from manifest JSON string
function Get-ManifestRecord {
    param([string]$JsonText)

    try {
        $mod = $JsonText | ConvertFrom-Json
    }
    catch {
        return $null
    }

    $owner = if ($mod.githubOwner) { $mod.githubOwner } else { $mod.gitHubOwner }
    $repoName = if ($mod.githubRepoName) { $mod.githubRepoName } else { $mod.gitHubRepoName }
    $modId = $mod.id
    $tagPrefix = $mod.releaseTagPrefix
    $assetName = $mod.releaseAssetName

    # Clean up owner/repo if full URLs were provided
    if ($repoName -and ($repoName -match 'github\.com/([^/]+)/([^/#?]+)')) {
        if (-not $owner) { $owner = $matches[1] }
        $repoName = $matches[2]
    }
    if ($repoName) {
        $repoName = ($repoName -replace '\.git$', '').Trim().Trim('/')
    }
    if ($owner -and ($owner -match 'github\.com/([^/#?]+)')) {
        $owner = $matches[1]
    }
    if ($owner) {
        $owner = $owner.Trim().Trim('/')
    }

    # Fallback to urls if owner or repoName missing
    if (-not ($owner -and $repoName)) {
        if ($mod.urls) {
            foreach ($u in $mod.urls) {
                $uStr = if ($u.url) { $u.url } else { $u.ToString() }
                if ($uStr -match 'github\.com/([^/]+)/([^/#?]+)') {
                    if (-not $owner) { $owner = $matches[1] }
                    if (-not $repoName) { $repoName = ($matches[2] -replace '\.git$', '').Trim() }
                    break
                }
            }
        }
    }

    # Fallback to artifacts downloadUrl if owner or repoName still missing
    if (-not ($owner -and $repoName)) {
        if ($mod.artifacts) {
            foreach ($art in $mod.artifacts) {
                $dUrl = $art.downloadUrl
                if ($dUrl -and ($dUrl -match 'github\.com/([^/]+)/([^/#?]+)')) {
                    if (-not $owner) { $owner = $matches[1] }
                    if (-not $repoName) { $repoName = ($matches[2] -replace '\.git$', '').Trim() }
                    break
                }
            }
        }
    }

    # For shared release repositories, multiple mods share the same repoName,
    # so $name MUST be the unique mod ID. For standalone mods, modId also uniquely
    # identifies the mod. If modId is missing, fall back to repoName.
    $name = if ($modId) { $modId } elseif ($repoName) { $repoName } else { $null }
    if (-not $name) { return $null }

    $url = $null
    if ($owner -and $repoName) {
        $url = "https://github.com/$owner/$repoName"
    }
    elseif ($owner -and $modId) {
        $url = "https://github.com/$owner/$modId"
    }
    else {
        return $null
    }

    # Extract latest artifact downloadUrl if available
    $downloadUrl = $null
    if ($mod.artifacts -and $mod.artifacts.Count -gt 0) {
        $downloadUrl = $mod.artifacts[0].downloadUrl
    }

    # Format release link
    if ($tagPrefix) {
        if ($downloadUrl -and ($downloadUrl -match '/releases/download/([^/]+)/')) {
            $release = "https://github.com/$owner/$repoName/releases/tag/$($matches[1])"
        }
        else {
            $release = "$url/releases"
        }
    }
    else {
        # Matches aug30.csv format with backslash
        $release = "$url\releases\latest"
    }

    return [PSCustomObject]@{
        name             = $name
        url              = $url
        release          = $release
        githubOwner      = $owner
        githubRepoName   = $repoName
        releaseTagPrefix = $tagPrefix
        releaseAssetName = $assetName
        downloadUrl      = $downloadUrl
    }
}

# 3. Fetch all PRs (paginated)
Write-Host "[*] Fetching pull requests (state='$State') for $Repo..." -ForegroundColor Cyan
$allPRs = [System.Collections.Generic.List[object]]::new()
$page = 1
$perPage = 100

do {
    $uri = "https://api.github.com/repos/$Repo/pulls?state=$State&per_page=$perPage&page=$page"
    try {
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        if ($response -and $response.Count -gt 0) {
            $allPRs.AddRange(@($response))
            Write-Host "    Page $page : fetched $($response.Count) PRs (total so far: $($allPRs.Count))"
            $page++
        }
        else {
            break
        }
    }
    catch {
        Write-Error "Failed to fetch PRs: $_"
        break
    }
} while ($response.Count -eq $perPage)

Write-Host "[+] Total PRs retrieved: $($allPRs.Count)" -ForegroundColor Green

if ($allPRs.Count -eq 0) {
    Write-Host "No pull requests found matching criteria."
    return
}

# 4. Inspect files in parallel
$allowedStatuses = if ($IncludeModified) { @('added', 'modified') } else { @('added') }
Write-Host "[*] Checking PR files for modManifests/*.json (status in [$($allowedStatuses -join ',')], concurrency=$Concurrency)..." -ForegroundColor Cyan

$scriptFunctionDef = ${function:Get-ManifestRecord}.ToString()

$matchedRecords = $allPRs | ForEach-Object -Parallel {
    $pr = $_
    $prNum = $pr.number
    $headersLocal = $using:headers
    $repoLocal = $using:Repo
    $allowedStatusesLocal = $using:allowedStatuses
    ${function:Get-ManifestRecord} = [scriptblock]::Create($using:scriptFunctionDef)

    $filesUrl = "https://api.github.com/repos/$repoLocal/pulls/$prNum/files?per_page=100"
    $foundList = @()

    try {
        $page = 1
        do {
            $pagedUrl = "$filesUrl&page=$page"
            $files = Invoke-RestMethod -Uri $pagedUrl -Headers $headersLocal -Method Get
            if (-not $files -or $files.Count -eq 0) { break }

            foreach ($f in $files) {
                $fn = $f.filename.Replace('\', '/')
                if ($fn -like "modManifests/*.json" -and ($f.status -in $allowedStatusesLocal)) {
                    if ($f.raw_url) {
                        try {
                            $rawJson = Invoke-RestMethod -Uri $f.raw_url -Headers $headersLocal -Method Get
                            $jsonText = if ($rawJson -is [string]) { $rawJson } else { $rawJson | ConvertTo-Json -Depth 10 }
                            $rec = Get-ManifestRecord -JsonText $jsonText
                            if ($rec) {
                                $foundList += [PSCustomObject]@{
                                    pr_number        = $prNum
                                    filename         = $fn
                                    name             = $rec.name
                                    url              = $rec.url
                                    release          = $rec.release
                                    githubOwner      = $rec.githubOwner
                                    githubRepoName   = $rec.githubRepoName
                                    releaseTagPrefix = $rec.releaseTagPrefix
                                    releaseAssetName = $rec.releaseAssetName
                                    downloadUrl      = $rec.downloadUrl
                                }
                            }
                        }
                        catch { }
                    }
                }
            }
            $page++
        } while ($files.Count -eq 100)
    }
    catch { }

    return $foundList
} -ThrottleLimit $Concurrency

Write-Host "[+] Found $($matchedRecords.Count) candidate manifests across PRs." -ForegroundColor Green

# 5. Deduplicate and export to CSV matching schema
$deduped = [System.Collections.Generic.List[PSCustomObject]]::new()
$seen = [System.Collections.Generic.HashSet[string]]::new()

foreach ($item in $matchedRecords) {
    $key = "$($item.name)|$($item.url)"
    if ($seen.Add($key)) {
        Write-Host "    [+] PR #$($item.pr_number) added $($item.filename) -> $($item.name) ($($item.url))"
        $deduped.Add([PSCustomObject]@{
                name             = $item.name
                url              = $item.url
                release          = $item.release
                githubOwner      = $item.githubOwner
                githubRepoName   = $item.githubRepoName
                releaseTagPrefix = $item.releaseTagPrefix
                releaseAssetName = $item.releaseAssetName
                downloadUrl      = $item.downloadUrl
            })
    }
}

Write-Host "[+] Exporting $($deduped.Count) unique records to $OutputFile..." -ForegroundColor Cyan

$csvLines = [System.Collections.Generic.List[string]]::new()
$csvLines.Add("name,url,release,githubOwner,githubRepoName,releaseTagPrefix,releaseAssetName,downloadUrl")
foreach ($row in $deduped) {
    $csvLines.Add("$($row.name),$($row.url),$($row.release),$($row.githubOwner),$($row.githubRepoName),$($row.releaseTagPrefix),$($row.releaseAssetName),$($row.downloadUrl)")
}
$targetPath = if ([System.IO.Path]::IsPathRooted($OutputFile)) { $OutputFile } else { Join-Path (Get-Location).Path $OutputFile }
[System.IO.File]::WriteAllLines($targetPath, $csvLines, [System.Text.Encoding]::UTF8)

Write-Host "[SUCCESS] Created $OutputFile with $($deduped.Count) rows!" -ForegroundColor Green
