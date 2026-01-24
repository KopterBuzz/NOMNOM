Param($Path,$ModManifestHashTable)
 
$errorString = $null
if (!$(Test-Path $Path))
{
    LogError("Unable to access $Path")
}

function LogError()
{
    Param([string]$errorString)
    Write-Error $errorString
}
function Validate-URL
{
    Param([string]$URL,[bool]$artifact)
    $isURL = [uri]::IsWellFormedUriString($URL, 'Absolute') -and ([uri] $URL).Scheme -eq 'https'
    if ($artifact) {
        $isSupportedArchive = $URL -match ".zip\z|.rar\z|.7z\z"
        if ($isURL -and $isSupportedArchive)
        {
            return $true
        }
        LogError("Artifact $URL failed URL validation!")
        return $false
    }
    if ($isURL)
    {
        return $true
    }
    LogError("$URL failed URL validation!")
    return $false
}
function Validate-FileName
{
    Param([string]$fileName)

    $isSupportedArchive = $fileName -match ".zip\z|.rar\z|.7z\z"
    if ($isSupportedArchive)
    {
        return $true
    }
    LogError("$fileName is unsupported!")
    return $false

}
function Validate-DependencyOrExtension
{
    Param($DependencyOrExtensionInfo)
    $Dependency = $ModManifestHashTable[$DependencyOrExtensionInfo.name]
    if (!$Dependency) {
        LogError("$($DependencyOrExtensionInfo.name) is not found in Managed Mod List!")
        return $false
    }
    $foundVersion = $ModManifestHashTable[$DependencyOrExtensionInfo.name].artifacts.version -match $DependencyOrExtensionInfo.minimumVersion
    if (!$foundVersion)
    {
        LogError("$($DependencyOrExtensionInfo.name) version $($DependencyOrExtensionInfo.minimumVersion) is not found in Managed Mod List!")
        return $false
    }
    return $true
}
function Validate-Version
{
    Param(
        [string]$versionString
        )
    [Version]$version = $null
    $result = $false
    Try {
        $version = [Version]($versionString)
        $result = $true
        return $result
    }
    Catch 
    {
        LogError("$versionString is not of valid Version Format!")
    }
    return $result

}

function Validate-FileHashFormat
{
    Param([string]$hashString)
    $looksLikeSha256 = $hashString -match "^sha256:[A-Fa-f0-9]{64}$"
    if (!$looksLikeSha256)
    {
        LogError("$hashString does not match the required pattern!")
        return $false
    }
    return $true

}

$parsedMod = Get-Content $Path | ConvertFrom-Json
Write-Host "Validating $($parsedMod.name)..."
$parsedMod

Write-Host "Validating infoUrl $($parsedMod.infoURL): $(Validate-URL -URL $parsedMod.infoURL -artifact $false)"
Write-Host "Validating supportedVersion $($parsedMod.supportedVersion): $(Validate-Version -versionString $parsedMod.supportedVersion)"
Write-Host "Validating dependencies..."
foreach ($dependency in $parsedMod.dependencies)
{
    Write-Host "Validating dependency $($dependency.name): $(Validate-DependencyOrExtension -DependencyOrExtensionInfo $dependency)"
}
Write-Host "Validating artifacts..."
foreach ($artifact in $parsedMod.artifacts)
{
    Write-Host "Validating fileName: $(Validate-FileName -fileName $artifact.fileName)"
    Write-Host "Validating artifactUrl: $(Validate-URL -URL $artifact.artifactUrl -artifact $true)"
    Write-Host "Validating fileHash: $(Validate-FileHashFormat -hashString $artifact.hash)"
    foreach ($extendable in $artifact.extends)
    {
        Write-Host "Validating extends: $(Validate-DependencyOrExtension -DependencyOrExtensionInfo $extendable)"
    }
}
