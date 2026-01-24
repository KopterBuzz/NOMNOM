param(
    [Parameter(Mandatory)]
    [string]$JsonPath,

    [Parameter(Mandatory)]
    [string]$SchemaPath
)

$json = Get-Content $JsonPath -Raw
$schema = Get-Content $SchemaPath -Raw

try {
    $result = Test-Json -Json $json -Schema $schema -ErrorAction Stop
    if ($result) {
        Write-Host "JSON SCHEMA is valid." -ForegroundColor Green
    }
    else {
        Write-Host "JSON SCHEMA is invalid!" -ForegroundColor Red
    }
}
catch {
    Write-Host "Validation failed:" -ForegroundColor Red
    Write-Host $_
}