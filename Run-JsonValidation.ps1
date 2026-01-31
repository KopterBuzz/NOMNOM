$currentManifest = (get-content ".\manifest\manifest.json" | ConvertFrom-Json -Depth 1000) | Group-Object id -AsHashTable

$modManifestFiles = Get-ChildItem ".\modManifests" -Filter "*.json"


foreach ($mod in $modManifestFiles)
{
    try
    {
        .\Validate-JsonSchema.ps1 -JsonPath $mod.FullName -SchemaPath .\ValidationSchema.json
        .\Validate-JsonContent.ps1 -Path $mod.FullName -ModManifestHashTable $currentManifest
    } catch
    {
        Exit 1
    }

}
try {
    $newManifestData = @()
    foreach ($mod in $modManifestFiles)
    {
        $data = Get-Content $mod | ConvertFrom-Json -Depth 1000
        $newManifestData+=$data
        Clear-Variable data
    }
    $newManifestData | ConvertTo-Json -Depth 100 | Set-Content -Path ".\manifest\test.json" -Encoding utf8NoBOM
}
catch 
{
    Write-Error "Failed to generate new manifest"
    Exit 1
}
Exit 0