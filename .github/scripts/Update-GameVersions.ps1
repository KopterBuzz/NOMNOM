[CmdletBinding()]
param (
    [string]$CacheDir = "gameVersionUpdateCache",
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
    $GameVersion = $Data.version_string
    
    foreach ($ModId in $Data.mod_id_strings) {
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
            
            if ($Manifest.artifacts -and $Manifest.artifacts.Count -gt 0) {
                # Find the latest artifact by parsing the version.
                # We strip off any pre-release tags (e.g., -beta) just for the sake of reliable sorting.
                $LatestArtifact = $Manifest.artifacts | Sort-Object -Property @{
                    Expression = {
                        $ver = $null
                        $cleanVer = $_.version -replace '-.*',''
                        if ([version]::TryParse($cleanVer, [ref]$ver)) { $ver } else { [version]"0.0.0.0" }
                    }; 
                    Descending = $true
                } | Select-Object -First 1
                
                if ($LatestArtifact) {
                    $OldVersion = $LatestArtifact.gameVersion
                    $LatestArtifact.gameVersion = $GameVersion
                    Write-Host "  [$ModId] Updated artifact (v$($LatestArtifact.version)) gameVersion from '$OldVersion' to '$GameVersion'"
                    
                    # Save back the JSON
                    $JsonOut = $Manifest | ConvertTo-Json -Depth 20
                    $JsonOut | Set-Content $ManifestPath -Encoding utf8
                }
            } else {
                Write-Warning "  [$ModId] No artifacts found in manifest."
            }
        } else {
            Write-Warning "  [$ModId] Manifest file not found in $ManifestDir."
        }
    }
    
    # Delete the processed cache file
    Remove-Item $File.FullName -Force
    Write-Host "Successfully processed and deleted $($File.Name)."
}
