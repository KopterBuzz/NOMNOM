[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$IssueBody,

    [Parameter(Mandatory = $true)]
    [string]$IssueId
)

# Initialize an ordered dictionary to keep the JSON output structure clean
$Data = [ordered]@{
    version_string = ""
    mod_id_strings = [System.Collections.Generic.List[string]]::new()
}

$CurrentSection = $null

# Issue forms split the inputs by Markdown headers corresponding to their labels
foreach ($Line in ($IssueBody -split "`r?`n")) {
    $Trimmed = $Line.Trim()
    
    if ($Trimmed -eq "### Version number") {
        $CurrentSection = "Version"
    }
    elseif ($Trimmed -eq "### MOD IDs") {
        $CurrentSection = "Mods"
    }
    elseif ($Trimmed -match "^###\s") {
        # Unrecognized section
        $CurrentSection = $null
    }
    elseif ($Trimmed -ne "" -and $Trimmed -ne "_No response_") {
        # Collect data based on the current active section
        if ($CurrentSection -eq "Version" -and $Data.version_string -eq "") {
            $Data.version_string = $Trimmed
        }
        elseif ($CurrentSection -eq "Mods") {
            $Data.mod_id_strings.Add($Trimmed)
        }
    }
}

# Validation: Version string must be castable to [version]
try {
    $null = [version]$Data.version_string
}
catch {
    $errMsg = "Validation Error: '$($Data.version_string)' is not a valid version string."
    Write-Error $errMsg
    Set-Content -Path "error.txt" -Value $errMsg -Encoding utf8
    exit 1
}

# Validation: Mod IDs must match files in the modManifests directory
foreach ($ModId in $Data.mod_id_strings) {
    $ManifestPath = Join-Path "modManifests" "$ModId.json"
    
    if (-not (Test-Path $ManifestPath)) {
        $errMsg = "Validation Error: Mod ID '$ModId' does not match any file in the modManifests directory."
        Write-Error $errMsg
        Set-Content -Path "error.txt" -Value $errMsg -Encoding utf8
        exit 1
    }
}

# Convert the list to a standard array for correct JSON formatting
$OutputObj = [ordered]@{
    version_string = $Data.version_string
    mod_id_strings = @($Data.mod_id_strings)
}

# Print as JSON
$JsonOutput = $OutputObj | ConvertTo-Json -Depth 5
Write-Output $JsonOutput

# Save to cache directory
$TargetDir = "gameVersionUpdateCache"
if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir | Out-Null
}
$FilePath = Join-Path $TargetDir "$IssueId.json"
$JsonOutput | Set-Content -Path $FilePath -Encoding utf8
Write-Host "Saved JSON to $FilePath"
