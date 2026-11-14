# Offline regression tests. Run with PowerShell 7 from any directory.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
. (Join-Path $repo 'Get-ModReleaseArtifact.ps1')
$script:checks = 0

function Assert-Equal($Expected, $Actual, [string]$Name) {
    $expectedJson = ConvertTo-Json -InputObject $Expected -Depth 100 -Compress
    $actualJson = ConvertTo-Json -InputObject $Actual -Depth 100 -Compress
    if ($expectedJson -cne $actualJson) {
        throw "$Name`: expected $expectedJson, got $actualJson"
    }
    $script:checks++
    Write-Host "PASS: $Name"
}

function New-Asset([string]$Name, [int]$Count = 1, [string]$Hash = ('a' * 64)) {
    [PSCustomObject]@{
        FileName = $Name
        DownloadUrl = "https://example.com/$Name"
        digest = 'sha256:' + $Hash
        DownloadCount = $Count
    }
}

function New-Release([string]$Tag, [object[]]$Assets, [bool]$Draft = $false, [bool]$Prerelease = $false) {
    [PSCustomObject]@{
        TagName = $Tag
        Assets = $Assets
        IsDraft = $Draft
        IsPrerelease = $Prerelease
    }
}

function New-Mod([string]$Id, [string]$Version) {
    [PSCustomObject]@{
        id = $Id
        displayName = $Id
        description = 'Release selector test fixture'
        authors = @('Example Author')
        isAiAssisted = 'False'
        urls = @(@{ name = 'info'; url = 'https://example.com' })
        githubOwner = 'example-author'
        githubRepoName = 'shared-releases'
        autoUpdateArtifacts = 'True'
        artifacts = @([PSCustomObject]@{
            version = $Version
            fileName = "$Id.zip"
            downloadUrl = "https://example.com/old/$Id.zip"
            category = 'release'
            type = 'plugin'
            gameVersion = '0.34.2'
            hash = 'sha256:' + ('b' * 64)
            dependencies = @(@{ id = 'example.dependency'; version = '1.0.0' })
            incompatibilities = @(@{ id = 'example.conflict'; version = '1.0.0' })
            extends = @{ id = 'example.base'; version = '1.0.0' }
        })
    }
}

$legacy = New-Mod 'Legacy' '1.0.0'
foreach ($tag in @('1.2.3', 'v1.2.3', 'v1.2.3-pre', 'v1.2.3_IL2CPP')) {
    $selected = Get-ModReleaseArtifact $legacy (New-Release $tag @((New-Asset 'first.zip'), (New-Asset 'second.zip')))
    Assert-Equal '1.2.3' $selected.Version "legacy tag $tag"
    Assert-Equal 'first.zip' $selected.Asset.FileName "legacy first asset $tag"
}

$units = New-Mod 'NuclearUnits' '1.2.1'
$units | Add-Member releaseTagPrefix 'NuclearUnits-v'
$units | Add-Member releaseAssetName 'NuclearUnits.zip'
$matching = New-Release 'NuclearUnits-v1.2.2' @((New-Asset 'notes.zip' 100 ('c' * 64)), (New-Asset 'NuclearUnits.zip' 5))
$selected = Get-ModReleaseArtifact $units $matching
Assert-Equal '1.2.2' $selected.Version 'strip exact tag prefix'
Assert-Equal 'NuclearUnits.zip' $selected.Asset.FileName 'select named asset after unrelated first asset'
Assert-Equal 5 $selected.Asset.DownloadCount 'selected asset count'
$reordered = New-Release 'NuclearUnits-v1.2.2' @($matching.Assets[1], $matching.Assets[0])
Assert-Equal $selected (Get-ModReleaseArtifact $units $reordered) 'asset order does not affect configured selection'
Assert-Equal $null (Get-ModReleaseArtifact $units (New-Release 'NuclearSounds-v9.0.0' $matching.Assets)) 'ignore another mod tag'
Assert-Equal $null (Get-ModReleaseArtifact $units (New-Release 'nuclearunits-v1.2.2' $matching.Assets)) 'prefix is case-sensitive'
Assert-Equal $null (Get-ModReleaseArtifact $units (New-Release 'NuclearUnits-v1.2.2' $matching.Assets $true)) 'ignore draft'

$warnings = @()
$result = Get-ModReleaseArtifact $units (New-Release 'NuclearUnits-v1.2.2' @((New-Asset 'notes.zip'))) -WarningAction SilentlyContinue -WarningVariable warnings
Assert-Equal $null $result 'missing named asset does not fall back'
Assert-Equal 1 $warnings.Count 'missing asset produces warning'
Assert-Equal $null (Get-ModReleaseArtifact $units (New-Release 'NuclearUnits-v1.2.2' @((New-Asset 'nuclearunits.zip'))) -WarningAction SilentlyContinue) 'asset name is case-sensitive'
foreach ($tag in @('NuclearUnits-vgarbage', 'NuclearUnits-v1.2.2-pre', 'NuclearUnits-v')) {
    Assert-Equal $null (Get-ModReleaseArtifact $units (New-Release $tag $matching.Assets) -WarningAction SilentlyContinue) "skip invalid numeric suffix $tag"
}
Assert-Equal $null (Get-ModReleaseArtifact $legacy (New-Release 'v1.2.3' @()) -WarningAction SilentlyContinue) 'empty asset list is skipped'
Assert-Equal $null (Get-ModReleaseArtifact $legacy (New-Release 'v1.2.3' $null) -WarningAction SilentlyContinue) 'null assets from GitHub provider are skipped without errors'

$prefixOnly = New-Mod 'PrefixOnly' '1.0.0'
$prefixOnly | Add-Member releaseTagPrefix 'PrefixOnly-v'
Assert-Equal 'first.zip' (Get-ModReleaseArtifact $prefixOnly (New-Release 'PrefixOnly-v1.1.0' @((New-Asset 'first.zip')))).Asset.FileName 'prefix selector works independently'
$assetOnly = New-Mod 'AssetOnly' '1.0.0'
$assetOnly | Add-Member releaseAssetName 'selected.zip'
Assert-Equal '1.1.0' (Get-ModReleaseArtifact $assetOnly (New-Release 'v1.1.0' @((New-Asset 'other.zip'), (New-Asset 'selected.zip')))).Version 'asset selector retains legacy tag parsing'

$schema = Join-Path $repo 'ValidationSchema.json'
Assert-Equal $true (Test-Json -Json ($units | ConvertTo-Json -Depth 100) -SchemaFile $schema) 'schema accepts configured selectors'
Assert-Equal $true (Test-Json -Json ($legacy | ConvertTo-Json -Depth 100) -SchemaFile $schema) 'schema accepts existing manifests'
foreach ($field in @('releaseTagPrefix', 'releaseAssetName')) {
    foreach ($value in @('', 123)) {
        $bad = New-Mod 'Invalid' '1.0.0'
        $bad | Add-Member -NotePropertyName $field -NotePropertyValue $value
        Assert-Equal $false (Test-Json -Json ($bad | ConvertTo-Json -Depth 100) -SchemaFile $schema -ErrorAction SilentlyContinue) "schema rejects invalid $field ($value)"
    }
}

# Run the real updater in a child process: its SaveAndClose intentionally exits.
# Only the GitHub provider is replaced, so tests never call the network or edit the catalog.
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('nomnom-release-tests-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path (Join-Path $sandbox 'test') | Out-Null
foreach ($file in @('Update-ModArtifact.ps1', 'Get-ModReleaseArtifact.ps1', 'Validate-JsonContent.ps1')) {
    Copy-Item (Join-Path $repo $file) $sandbox
}
@'
function Get-GitHubReleases {
    param($Owner, $Repository, $Token)
    if (Test-Path (Join-Path $PSScriptRoot 'fail-fetch')) { throw 'Fixture GitHub failure' }
    Get-Content (Join-Path $PSScriptRoot 'releases.json') -Raw | ConvertFrom-Json
}
'@ | Set-Content (Join-Path $sandbox 'Get-GitHubReleases.ps1') -Encoding utf8NoBOM

function Invoke-FixtureUpdater($Mod, [object[]]$Releases, [bool]$FailFetch = $false) {
    $Mod | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $sandbox 'input.json') -Encoding utf8NoBOM
    ConvertTo-Json -InputObject $Releases -Depth 100 | Set-Content (Join-Path $sandbox 'releases.json') -Encoding utf8NoBOM
    $failureFile = Join-Path $sandbox 'fail-fetch'
    if ($FailFetch) { Set-Content -LiteralPath $failureFile -Value 'fixture' }
    elseif (Test-Path -LiteralPath $failureFile) { Remove-Item -LiteralPath $failureFile }
    Push-Location $sandbox
    try {
        $output = & (Join-Path $PSHOME 'pwsh') -NoProfile -Command '$ErrorActionPreference = "Stop"; & ./Update-ModArtifact.ps1 -modPath ./input.json -gitHubToken "fixture" -test $true' 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Updater failed: $output" }
        Get-Content (Join-Path $sandbox "test/$($Mod.id).json") -Raw | ConvertFrom-Json
    } finally {
        Pop-Location
    }
}

function Invoke-FixtureValidator($Mod, [object[]]$Catalog, [string]$RelativePath) {
    $path = Join-Path $sandbox $RelativePath
    New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
    # Relations are covered separately; keep these fixtures focused on IDs.
    foreach ($artifact in $Mod.artifacts) {
        $artifact.dependencies = @()
        $artifact.incompatibilities = @()
        $artifact.extends = $null
    }
    $Mod | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path -Encoding utf8NoBOM
    ConvertTo-Json -InputObject $Catalog -Depth 100 | Set-Content (Join-Path $sandbox 'catalog.json') -Encoding utf8NoBOM
    Push-Location $sandbox
    try {
        $escapedPath = $RelativePath.Replace("'", "''")
        $command = '$map = (Get-Content ./catalog.json -Raw | ConvertFrom-Json) | Group-Object id -AsHashTable; & ./Validate-JsonContent.ps1 -Path ''' + $escapedPath + ''' -ModManifestHashTable $map'
        $output = & (Join-Path $PSHOME 'pwsh') -NoProfile -Command $command 2>&1
        return $LASTEXITCODE
    } finally { Pop-Location }
}

try {
    $sounds = New-Mod 'NuclearSounds' '0.1.0'
    $sounds | Add-Member releaseTagPrefix 'NuclearSounds-v'
    $sounds | Add-Member releaseAssetName 'NuclearSounds.zip'
    $releases = @(
        (New-Release 'NuclearSounds-v0.1.2' @((New-Asset 'NuclearSounds.zip' 7))),
        (New-Release 'NuclearUnits-v1.3.0' @((New-Asset 'wrong.zip' 999))),
        (New-Release 'NuclearUnits-v1.2.2-pre' $matching.Assets),
        $matching,
        (New-Release 'NuclearUnits-v0.8.0' @((New-Asset 'NuclearUnits.zip' 3))),
        (New-Release 'NuclearUnits-v1.4.0' $matching.Assets $true),
        (New-Release 'NuclearSounds-v0.1.1' @((New-Asset 'NuclearSounds.zip' 4)))
    )
    $updatedUnits = Invoke-FixtureUpdater $units $releases
    Assert-Equal @('1.2.2', '1.2.1') @($updatedUnits.artifacts.version) 'updater filters tags, drafts, invalid suffixes, missing assets and older versions'
    Assert-Equal 8 $updatedUnits.downloadCount 'updater counts only this mod assets, including older releases'
    Assert-Equal $matching.Assets[1].DownloadUrl $updatedUnits.artifacts[0].downloadUrl 'updater uses selected download URL'
    Assert-Equal $matching.Assets[1].digest $updatedUnits.artifacts[0].hash 'updater uses selected hash'
    Assert-Equal $units.artifacts[0].dependencies $updatedUnits.artifacts[0].dependencies 'dependencies preserved'
    Assert-Equal $units.artifacts[0].incompatibilities $updatedUnits.artifacts[0].incompatibilities 'incompatibilities preserved'
    Assert-Equal $units.artifacts[0].extends $updatedUnits.artifacts[0].extends 'extends preserved'
    Assert-Equal '0.34.2' $updatedUnits.artifacts[0].gameVersion 'game compatibility preserved'
    Assert-Equal $true (Test-Json -Json ($updatedUnits | ConvertTo-Json -Depth 100) -SchemaFile $schema) 'generated manifest validates'

    $updatedSounds = Invoke-FixtureUpdater $sounds $releases
    Assert-Equal @('0.1.2', '0.1.1', '0.1.0') @($updatedSounds.artifacts.version) 'shared repository keeps independent versions and sorts artifacts'
    Assert-Equal 11 $updatedSounds.downloadCount 'other mod has its own download count'

    $updatedLegacy = Invoke-FixtureUpdater $legacy @(
        (New-Release 'v2.0.0' $null),
        (New-Release 'v1.1.0' @((New-Asset 'legacy.zip' 2), (New-Asset 'other.zip' 99)) $false $true)
    )
    Assert-Equal 'legacy.zip' $updatedLegacy.artifacts[0].fileName 'legacy updater still selects first asset'
    Assert-Equal '1.1.0' $updatedLegacy.artifacts[0].version 'legacy updater numeric version unchanged'
    Assert-Equal 'preRelease' $updatedLegacy.artifacts[0].category 'prerelease flag preserved'
    Assert-Equal 2 $updatedLegacy.downloadCount 'legacy download count unchanged'

    $disabled = New-Mod 'Disabled' '1.0.0'
    $disabled.autoUpdateArtifacts = 'False'
    $disabled | Add-Member releaseTagPrefix 'NuclearUnits-v'
    $disabled | Add-Member releaseAssetName 'NuclearUnits.zip'
    $disabled | Add-Member downloadCount 99
    $olderArtifact = $disabled.artifacts[0] | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    $olderArtifact.version = '0.9.0'
    $disabled.artifacts = @($olderArtifact, $disabled.artifacts[0])
    $updatedDisabled = Invoke-FixtureUpdater $disabled $releases
    Assert-Equal 8 $updatedDisabled.downloadCount 'manual release mode refreshes only matching asset download counts'
    Assert-Equal $disabled.artifacts $updatedDisabled.artifacts 'manual releases preserve versions, order, URLs, hashes and dependencies'
    $expectedManual = $disabled | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    $expectedManual.downloadCount = 8
    Assert-Equal $expectedManual $updatedDisabled 'manual release mode changes only downloadCount'

    $missingCount = New-Mod 'MissingCounter' '1.0.0'
    $missingCount.autoUpdateArtifacts = 'False'
    $updatedMissing = Invoke-FixtureUpdater $missingCount @((New-Release 'v9.0.0' @((New-Asset 'package.zip' 12))))
    Assert-Equal 12 $updatedMissing.downloadCount 'manual manifest gets its missing downloadCount'
    Assert-Equal $missingCount.artifacts $updatedMissing.artifacts 'newer release is not adopted in manual mode'
    Assert-Equal 'False' $updatedMissing.autoUpdateArtifacts 'manual release flag remains disabled'

    $emptyManual = New-Mod 'EmptyManual' '1.0.0'
    $emptyManual.autoUpdateArtifacts = 'False'
    $emptyManual.artifacts = @()
    $updatedEmpty = Invoke-FixtureUpdater $emptyManual @((New-Release 'v9.0.0' @((New-Asset 'package.zip' 4))))
    Assert-Equal @() $updatedEmpty.artifacts 'manual manifest with no artifacts does not acquire a release'
    Assert-Equal 4 $updatedEmpty.downloadCount 'manual manifest can count releases without adopting them'

    $noFlag = New-Mod 'NoFlag' '1.0.0'
    $noFlag.PSObject.Properties.Remove('autoUpdateArtifacts')
    $updatedNoFlag = Invoke-FixtureUpdater $noFlag @((New-Release 'v2.0.0' @((New-Asset 'package.zip' 3))))
    Assert-Equal $noFlag.artifacts $updatedNoFlag.artifacts 'missing opt-in flag does not enable release updates'
    Assert-Equal 3 $updatedNoFlag.downloadCount 'missing opt-in flag does not block download statistics'

    Assert-Equal $disabled (Invoke-FixtureUpdater $disabled @() $true) 'failed fetch preserves manual release metadata and previous count'
    Assert-Equal $missingCount (Invoke-FixtureUpdater $missingCount @() $true) 'failed fetch does not invent a zero for an unknown count'
    $knownAutomatic = $units | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    $knownAutomatic | Add-Member downloadCount 88
    Assert-Equal $knownAutomatic (Invoke-FixtureUpdater $knownAutomatic @() $true) 'failed fetch preserves automatic release metadata and previous count'

    $emptyResult = Invoke-FixtureUpdater $disabled @()
    Assert-Equal 0 $emptyResult.downloadCount 'successful empty release list is a real zero'
    Assert-Equal $disabled.artifacts $emptyResult.artifacts 'successful empty release list preserves manual artifacts'
    Assert-Equal @('1.2.1') @((Invoke-FixtureUpdater $units @()).artifacts.version) 'no releases preserves existing artifacts'

    $catalog = @([PSCustomObject]@{id = 'Existing'})
    Assert-Equal 0 (Invoke-FixtureValidator (New-Mod 'NewMod' '1.0.0') $catalog 'modManifests/NewMod.json') 'new unique catalog ID is accepted'
    Assert-Equal 0 (Invoke-FixtureValidator (New-Mod 'Existing' '2.0.0') $catalog 'modManifests/Existing.json') 'existing mod may update its own canonical manifest'
    Assert-Equal 1 (Invoke-FixtureValidator (New-Mod 'Existing' '2.0.0') $catalog 'other/Existing.json') 'existing ID in another file is rejected'
    Assert-Equal 1 (Invoke-FixtureValidator (New-Mod 'existing' '2.0.0') $catalog 'modManifests/existing.json') 'case-variant duplicate ID is rejected'
    Assert-Equal 1 (Invoke-FixtureValidator (New-Mod 'Existing' '2.0.0') $catalog 'modManifests/existing.json') 'case-variant duplicate filename is rejected'
    Assert-Equal 1 (Invoke-FixtureValidator (New-Mod 'Existing' '2.0.0') @($catalog[0], $catalog[0]) 'modManifests/Existing.json') 'already duplicated catalog ID is rejected'
} finally {
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $resolvedSandbox = [IO.Path]::GetFullPath($sandbox)
    if ([IO.Path]::GetDirectoryName($resolvedSandbox) -ne $tempRoot -or [IO.Path]::GetFileName($resolvedSandbox) -notlike 'nomnom-release-tests-*') {
        throw "Refusing to remove an unexpected test directory: $resolvedSandbox"
    }
    Remove-Item -LiteralPath $resolvedSandbox -Recurse -Force
}

Write-Host "$script:checks release selection checks passed."
# Expected failing child-process cases must not become GitHub's final native
# exit code after every assertion has passed.
exit 0
