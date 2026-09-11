[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$IssueBody,

    [Parameter(Mandatory = $true)]
    [string]$IssueId
)

# Initialize an ordered dictionary to keep the JSON output structure clean
$Data = [ordered]@{
    mod_id    = ""
    image_url = ""
}

$CurrentSection = $null

# Issue forms split the inputs by Markdown headers corresponding to their labels
foreach ($Line in ($IssueBody -split "`r?`n")) {
    $Trimmed = $Line.Trim()
    
    if ($Trimmed -eq "### Mod ID") {
        $CurrentSection = "ModId"
    }
    elseif ($Trimmed -eq "### Image URL") {
        $CurrentSection = "ImageUrl"
    }
    elseif ($Trimmed -match "^###\s") {
        # Unrecognized section
        $CurrentSection = $null
    }
    elseif ($Trimmed -ne "" -and $Trimmed -ne "_No response_") {
        # Collect data based on the current active section
        if ($CurrentSection -eq "ModId" -and $Data.mod_id -eq "") {
            $Data.mod_id = $Trimmed
        }
        elseif ($CurrentSection -eq "ImageUrl" -and $Data.image_url -eq "") {
            $Data.image_url = $Trimmed
        }
    }
}

# Validation: Image URL string must be a valid URI
try {
    $null = [System.Uri]::new($Data.image_url)
    if ($Data.image_url -notmatch ".jpg$|.png$|.webp$|.svg$") {
        $errMsg = "Validation Error: '$($Data.image_url)' must end in a valid image file extension."
        Write-Error $errMsg
        Set-Content -Path "error.txt" -Value $errMsg -Encoding utf8
        exit 1
    }
}
catch {
    $errMsg = "Validation Error: '$($Data.image_url)' is not a valid URL."
    Write-Error $errMsg
    Set-Content -Path "error.txt" -Value $errMsg -Encoding utf8
    exit 1
}

# Validation: Mod ID must match files in the modManifests directory
$ManifestPath = Join-Path "modManifests" "$($Data.mod_id).json"
$ManifestPath2 = Join-Path "modManifests" "$($Data.mod_id)"
if (-not (Test-Path $ManifestPath) -and -not (Test-Path $ManifestPath2)) {
    $errMsg = "Validation Error: Mod ID '$($Data.mod_id)' does not match any file in the modManifests directory."
    Write-Error $errMsg
    Set-Content -Path "error.txt" -Value $errMsg -Encoding utf8
    exit 1
}

# Download image and compute SHA256
$TempFile = New-TemporaryFile
try {
    Invoke-WebRequest -Uri $Data.image_url -OutFile $TempFile.FullName -ErrorAction Stop
    $Hash = (Get-FileHash -Path $TempFile.FullName -Algorithm SHA256).Hash.ToLower()

    # Check Image Resolution natively
    $Width = 0
    $Height = 0
    if ($IsWindows) {
        Add-Type -AssemblyName System.Drawing
        $img = [System.Drawing.Image]::FromFile($TempFile.FullName)
        $Width = $img.Width
        $Height = $img.Height
        $img.Dispose()
    } else {
        $fileOut = file $TempFile.FullName
        if ($fileOut -match ",\s*(\d+)\s*x\s*(\d+)(?:,|$)") {
            $Width = [int]$matches[1]
            $Height = [int]$matches[2]
        } else {
            # Let it pass if we truly can't parse it to avoid blocking blindly, or throw error
            Write-Warning "Could not parse resolution from file output: $fileOut"
        }
    }

    if ($Width -gt 512 -or $Height -gt 512) {
        $errMsg = "Validation Error: Image exceeds maximum dimensions of 512x512! Detected: ${Width}x${Height}"
        Write-Error $errMsg
        Set-Content -Path "error.txt" -Value $errMsg -Encoding utf8
        Remove-Item $TempFile.FullName -Force
        exit 1
    }
}
catch {
    $errMsg = "Validation Error: Failed to download image from '$($Data.image_url)'."
    Write-Error $errMsg
    Set-Content -Path "error.txt" -Value $errMsg -Encoding utf8
    Remove-Item $TempFile.FullName -Force
    exit 1
}
Remove-Item $TempFile.FullName -Force

# Convert the list to a standard array for correct JSON formatting
$OutputObj = [ordered]@{
    mod_id     = $Data.mod_id
    image_url  = $Data.image_url
    image_hash = $Hash
}

# Print as JSON
$JsonOutput = $OutputObj | ConvertTo-Json -Depth 5
Write-Output $JsonOutput

# Save to cache directory
$TargetDir = "modImageUpdateCache"
if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir | Out-Null
}
$FilePath = Join-Path $TargetDir "$IssueId.json"
$JsonOutput | Set-Content -Path $FilePath -Encoding utf8
Write-Host "Saved JSON to $FilePath"
