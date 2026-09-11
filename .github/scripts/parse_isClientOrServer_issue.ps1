[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$IssueBody,

    [Parameter(Mandatory = $true)]
    [string]$IssueId
)

$Data = [ordered]@{
    mod_id = ""
    is_client_or_server = ""
}

$CurrentSection = $null

foreach ($Line in ($IssueBody -split "`r?`n")) {
    $Trimmed = $Line.Trim()
    
    if ($Trimmed -eq "### Mod ID") {
        $CurrentSection = "ModId"
    }
    elseif ($Trimmed -eq "### Client or Server") {
        $CurrentSection = "IsClientOrServer"
    }
    elseif ($Trimmed -match "^###\s") {
        $CurrentSection = $null
    }
    elseif ($Trimmed -ne "" -and $Trimmed -ne "_No response_") {
        if ($CurrentSection -eq "ModId" -and $Data.mod_id -eq "") {
            $Data.mod_id = $Trimmed
        }
        elseif ($CurrentSection -eq "IsClientOrServer" -and $Data.is_client_or_server -eq "") {
            $Data.is_client_or_server = $Trimmed
        }
    }
}

if ($Data.is_client_or_server -notin @("Client", "Server", "Both")) {
    $errMsg = "Validation Error: 'isClientOrServer' must be Client, Server, or Both. Got: '$($Data.is_client_or_server)'"
    Write-Error $errMsg
    Set-Content -Path "error.txt" -Value $errMsg -Encoding utf8
    exit 1
}

$ManifestPath = Join-Path "modManifests" "$($Data.mod_id).json"
$ManifestPath2 = Join-Path "modManifests" "$($Data.mod_id)"
if (-not (Test-Path $ManifestPath) -and -not (Test-Path $ManifestPath2)) {
    $errMsg = "Validation Error: Mod ID '$($Data.mod_id)' does not match any file in the modManifests directory."
    Write-Error $errMsg
    Set-Content -Path "error.txt" -Value $errMsg -Encoding utf8
    exit 1
}

$OutputObj = [ordered]@{
    mod_id              = $Data.mod_id
    is_client_or_server = $Data.is_client_or_server
}

$JsonOutput = $OutputObj | ConvertTo-Json -Depth 5
Write-Output $JsonOutput

$TargetDir = "isClientOrServerUpdateCache"
if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir | Out-Null
}
$FilePath = Join-Path $TargetDir "$IssueId.json"
$JsonOutput | Set-Content -Path $FilePath -Encoding utf8
Write-Host "Saved JSON to $FilePath"
