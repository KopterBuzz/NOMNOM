$modManifestFiles = Get-ChildItem ".\modManifests" -Filter "*.json"


foreach ($mod in $modManifestFiles)
{
    .\Update-ModArtifact.ps1 -modPath $mod -gitHubToken $(Get-Content ".\testing_gitignore.token") -test $false
}

$allModsHashTable = ((Get-ChildItem ".\test\" -Filter "*.json").FullName | foreach {Get-Content $_ | ConvertFrom-Json -Depth 100}) | group id -AsHashTable
foreach ($mod in $modManifestFiles)
{
    .\Update-ModDependencies.ps1 -modPath $mod -allModsHashTable $allModsHashTable -gitHubToken $(Get-Content ".\testing_gitignore.token") -test $false
}


try {
    $newManifestData = @()
    foreach ($mod in $modManifestFiles)
    {
        $data = Get-Content $mod | ConvertFrom-Json -Depth 1000
        $newManifestData+=$data
        Clear-Variable data
    }
    $newManifestData | ConvertTo-Json -Depth 100 | Set-Content -Path ".\manifest\manifest.json" -Encoding utf8NoBOM -Force
    Write-Host AUTO UPDATE SUCCEEDED SUCCEEDED! -ForegroundColor Green
}
catch 
{
    Write-Error "Failed to generate new manifest"
    Exit 1
}

.\Increment-ManifestVersion.ps1

Exit 0
