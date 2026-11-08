[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$IssueBody,

    [Parameter(Mandatory = $true)]
    [string]$IssueId
)

$Data = [ordered]@{
    mod_id_strings = [System.Collections.Generic.List[string]]::new()
    is_ai_assisted = ""
}

$CurrentSection = $null

foreach ($Line in ($IssueBody -split "`r?`n")) {
    $Trimmed = $Line.Trim()

    # "### Mod ID" is the heading of the earlier single-mod form; keep accepting it.
    if ($Trimmed -eq "### MOD IDs" -or $Trimmed -eq "### Mod ID") {
        $CurrentSection = "Mods"
    }
    elseif ($Trimmed -eq "### AI Assisted") {
        $CurrentSection = "IsAiAssisted"
    }
    elseif ($Trimmed -match "^###\s") {
        $CurrentSection = $null
    }
    elseif ($Trimmed -ne "" -and $Trimmed -ne "_No response_") {
        if ($CurrentSection -eq "Mods" -and -not $Data.mod_id_strings.Contains($Trimmed)) {
            $Data.mod_id_strings.Add($Trimmed)
        }
        elseif ($CurrentSection -eq "IsAiAssisted" -and $Data.is_ai_assisted -eq "") {
            $Data.is_ai_assisted = $Trimmed
        }
    }
}

if ($Data.is_ai_assisted -notin @("True", "False")) {
    $errMsg = "Validation Error: 'isAiAssisted' must be True or False. Got: '$($Data.is_ai_assisted)'"
    Set-Content -Path "error.txt" -Value $errMsg -Encoding utf8
    Write-Error $errMsg
    exit 1
}

if ($Data.mod_id_strings.Count -eq 0) {
    $errMsg = "Validation Error: No Mod IDs were provided."
    Set-Content -Path "error.txt" -Value $errMsg -Encoding utf8
    Write-Error $errMsg
    exit 1
}

foreach ($ModId in $Data.mod_id_strings) {
    $ManifestPath = Join-Path "modManifests" "$ModId.json"
    $ManifestPath2 = Join-Path "modManifests" "$ModId"
    if (-not (Test-Path $ManifestPath) -and -not (Test-Path $ManifestPath2)) {
        $errMsg = "Validation Error: Mod ID '$ModId' does not match any file in the modManifests directory."
        Set-Content -Path "error.txt" -Value $errMsg -Encoding utf8
        Write-Error $errMsg
        exit 1
    }
}

$OutputObj = [ordered]@{
    mod_id_strings = @($Data.mod_id_strings)
    is_ai_assisted = $Data.is_ai_assisted
}

$JsonOutput = $OutputObj | ConvertTo-Json -Depth 5
Write-Output $JsonOutput

$TargetDir = "isAiAssistedUpdateCache"
if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir | Out-Null
}
$FilePath = Join-Path $TargetDir "$IssueId.json"
$JsonOutput | Set-Content -Path $FilePath -Encoding utf8
Write-Host "Saved JSON to $FilePath"

