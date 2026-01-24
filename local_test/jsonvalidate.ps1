function Validate-JsonSchema($jsonbject)
{
    $result = $false
    $result = $jsonObject.PSObject.Properties.name -contains "name"
    $result = $jsonObject.PSObject.Properties.name -contains "description"
    $result = $jsonObject.PSObject.Properties.name -contains "artifacts"
    foreach ($articact in @($jsonObject.artifacts))
    {
        
    }
}

$json = get-content "..\manifest\manifest.json"
$parsed = $null
Try {
    $parsed = $json | ConvertFrom-Json
} catch {
    Write-Error "IT'S JSON BOURNE!!!!"
}

