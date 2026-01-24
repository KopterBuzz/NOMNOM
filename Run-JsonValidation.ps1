$currentManifest = (get-content ".\manifest\manifest.json" | ConvertFrom-Json) | Group-Object name -AsHashTable

$modManifestFiles = Get-ChildItem ".\modManifests" -Filter "*.json"


foreach ($mod in $modManifestFiles)
{
    .\Validate-JsonSchema.ps1 -JsonPath $mod.FullName -SchemaPath .\ValidationSchema.json
    .\Validate-JsonContent.ps1 -Path $mod.FullName -ModManifestHashTable $currentManifest
}