[CmdletBinding()]
param (
    [string]$CacheDir = "isClientOrServerUpdateCache",
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
    $ModId = $Data.mod_id
    $IsClientOrServer = $Data.is_client_or_server
    
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
        
        $Manifest | Add-Member -MemberType NoteProperty -Name "isClientOrServer" -Value $IsClientOrServer -Force
        
        Write-Host "  [$ModId] Updated isClientOrServer to '$IsClientOrServer'"
        
        $JsonOut = $Manifest | ConvertTo-Json -Depth 20
        $JsonOut | Set-Content $ManifestPath -Encoding utf8
    } else {
        Write-Warning "  [$ModId] Manifest file not found in $ManifestDir."
    }
    
    Remove-Item $File.FullName -Force
    Write-Host "Successfully processed and deleted $($File.Name)."
}
