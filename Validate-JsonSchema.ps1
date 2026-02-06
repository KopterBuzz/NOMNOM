param(
    [Parameter(Mandatory)]
    [string]$JsonPath,

    [Parameter(Mandatory)]
    [string]$SchemaPath
)

$json = Get-Content $JsonPath -Raw
$schema = Get-Content $SchemaPath -Raw
write-host $JsonPath
try {
    $result = Test-Json -Json $json -Schema $schema -ErrorAction Stop
    if ($result) {
        Write-Host "JSON SCHEMA is valid." -ForegroundColor Green
        Exit 0
    }
    else {
        Write-Host "JSON SCHEMA is invalid!" -ForegroundColor Red
        Exit 1
    }
}
catch {
    Write-Host "Validation failed:" -ForegroundColor Red
    Write-Host $_
    Exit 1
}