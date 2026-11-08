[CmdletBinding()]
param (
    [string]$CacheDir = "isAiAssistedUpdateCache",
    [string]$ManifestDir = "modManifests"
)

if (-not (Test-Path $CacheDir)) {
    Write-Host "Cache directory '$CacheDir' not found."
    return
}

$CacheFiles = Get-ChildItem -Path $CacheDir -Filter "*.json"

if ($CacheFiles.Count -eq 0) {
    Write-Host "No pending updates found in '$CacheDir'."
    return
}

foreach ($File in $CacheFiles) {
    Write-Host "Processing update from $($File.Name)..."

    $Data = Get-Content $File.FullName -Raw | ConvertFrom-Json
    $IsAiAssisted = $Data.is_ai_assisted

    # Cache files written by the earlier single-mod parser have "mod_id" instead of "mod_id_strings".
    $ModIds = if ($Data.mod_id_strings) { @($Data.mod_id_strings) } else { @($Data.mod_id) }

    foreach ($ModId in $ModIds) {
        $ManifestPath1 = Join-Path $ManifestDir "$ModId.json"
        $ManifestPath2 = Join-Path $ManifestDir "$ModId"

        $ManifestPath = $null
        if (Test-Path $ManifestPath1) {
            $ManifestPath = $ManifestPath1
        } elseif (Test-Path $ManifestPath2) {
            $ManifestPath = $ManifestPath2
        }

        if ($ManifestPath) {
            $Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json

            $Manifest | Add-Member -MemberType NoteProperty -Name "isAiAssisted" -Value $IsAiAssisted -Force

            Write-Host "  [$ModId] Updated isAiAssisted to '$IsAiAssisted'"

            $JsonOut = $Manifest | ConvertTo-Json -Depth 100
            $JsonOut | Set-Content $ManifestPath -Encoding utf8NoBOM
        } else {
            Write-Warning "  [$ModId] Manifest file not found in $ManifestDir."
        }
    }

    Remove-Item $File.FullName -Force
    Write-Host "Successfully processed and deleted $($File.Name)."
}

