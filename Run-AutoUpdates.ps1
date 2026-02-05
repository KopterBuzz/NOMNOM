Param($token)
$modManifestFiles = Get-ChildItem ".\modManifests" -Filter "*.json"


foreach ($mod in $modManifestFiles)
{
    .\Update-ModArtifact.ps1 -modPath $mod -gitHubToken $token -test $false
}

$allModsHashTable = ((Get-ChildItem ".\modManifests\" -Filter "*.json").FullName | foreach {Get-Content $_ | ConvertFrom-Json -Depth 100}) | group id -AsHashTable
foreach ($mod in $modManifestFiles)
{
    .\Update-ModDependencies.ps1 -modPath $mod -allModsHashTable $allModsHashTable -gitHubToken $token -test $false
}


try {
    $newManifestData = @()
    foreach ($mod in $modManifestFiles)
    {
        $data = Get-Content $mod | ConvertFrom-Json -Depth 1000
        $newManifestData+=$data
        Clear-Variable data
    }
    #$newManifestData | ConvertTo-Json -Depth 100 | Set-Content -Path ".\manifest\manifest.json" -Encoding utf8NoBOM -Force
    Write-Host AUTO UPDATE SUCCEEDED SUCCEEDED! -ForegroundColor Green
}
catch 
{
    Write-Error "Failed to generate new manifest"
    Exit 1
}

Exit 0
