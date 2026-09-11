Param($Path,$ModManifestHashTable)
 
$errorString = $null
if (!$(Test-Path $Path))
{
    LogError("Unable to access $Path")
}

function LogError()
{
    Param([string]$errorString)
    Write-Host $errorString
    Exit 1
}
function Validate-ArtifactURL
{
    Param([string]$URL)
    $isURL = [uri]::IsWellFormedUriString($URL, 'Absolute') -and ([uri] $URL).Scheme -eq 'https'

    $isSupportedArchive = $URL -match ".zip\z|.rar\z|.7z\z|.dll\z|.nobp\z|.tar.gz\z"
    if ($isURL -and $isSupportedArchive)
    {
        return $true
    }
    LogError("Artifact $URL failed URL validation!")
    return $false
}

function Validate-urls
{
    Param($urls)
    foreach ($url in $urls)
    {
        $isURL = [uri]::IsWellFormedUriString($url.url, 'Absolute') -and ([uri]$url.url).Scheme -eq 'https'
        if (!$isURL)
        {
            LogError("$URL failed URL validation!")
            return $false
        }
    }
    return $true
}
function Validate-FileName
{
    Param([string]$fileName)

    $isSupportedArchive = $fileName -match ".zip\z|.rar\z|.7z\z|.dll\z|.nobp\z|.tar.gz\z"
    if ($isSupportedArchive)
    {
        return $true
    }
    LogError("$fileName is unsupported!")
    return $false

}

function Validate-RelationId
{
    Param($id)
    $check = $ModManifestHashTable["$id"]
    if (!$check){
        return $false
    }
    return $true
}

function Validate-IdMatchesFileName
{
    Param($id)
    $idMatchesFilename = ((get-item $Path).Name -replace ".json","") -eq $id
    if (!$idMatchesFilename){
        return $false
    }
    return $true
}

function Validate-IdAlreadyExists
{
    Param($id)
    $check = $ModManifestHashTable["$id"]
    if ($check){
        return $false
    }
    return $true
}

function Validate-Relation
{
    Param(
        [Object]
        $RelationObject
    )

    $idValid = Validate-RelationId -id $RelationObject.id
    $versionValid = Validate-Version -versionString $RelationObject.Version
    if (!$idValid)
    {
        LogError("$($RelationObject.id) is invalid!")
        return $false
    }
    if (!$versionValid)
    {
        LogError("$($RelationObject.version) is invalid!")
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
        LogError($error[0])
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

try
{
    $parsedMod = Get-Content $Path | ConvertFrom-Json
    Write-Host "Validating $($parsedMod.id)..."
    #$parsedMod

    Write-Host "Validating Id matches file name: $($parsedMod.id) $((get-item $Path).Name): $(Validate-IdMatchesFileName -id $parsedMod.id)"
    $isIdUnique = Validate-IdAlreadyExists -id $parsedMod.Id
    Write-Host "Validating Id is Unique: $($parsedMod.id): $isIdUnique"
    if (!$isIdUnique)
    {
        Write-Host $("Id $($parsedMod.id) is NOT UNIQUE!")
        Exit 1
    }
    Write-Host "Validating urls $($parsedMod.urls): $(Validate-urls -urls $parsedMod.urls)"
    Write-Host "Validating dependencies..."

    Write-Host "Validating artifacts..."
    foreach ($artifact in $parsedMod.artifacts)
    {
        Write-Host "Validating $($parsedMod.id) artifact version $($artifact.version)"
        $artifact
        $result = Validate-FileName -fileName $artifact.fileName
        Write-Host "Validating fileName: $($result)"
        if (!$result)
        {
            Write-Host $("$($artifact.fileName) IS INVALID!")
            Exit 1
        }
        $result = Validate-ArtifactURL -URL $artifact.downloadUrl
        Write-Host "Validating artifactUrl: $($result)"
        if (!$result)
        {
            Write-Host $("$($artifact.downloadUrl) IS INVALID!")
            Exit 1
        }
        #Write-Host "Validating fileHash: $(Validate-FileHashFormat -hashString $artifact.hash)"
        $result = Validate-Version -versionString $artifact.version
        Write-Host "Validating version: $($result)"
        if (!$result)
        {
            Write-Host $("$($artifact.version) IS INVALID!")
            Exit 1
        }
        $result = Validate-Version -versionString $artifact.gameVersion
        Write-Host "Validating gameVersion: $($result)"
        if (!$result)
        {
            Write-Host $("$($artifact.gameVersion) IS INVALID!")
            Exit 1
        }        
        if ($artifact.dependencies)
        {
            Write-Host "Validating $($parsedMod.id) artifact version $($artifact.version) DEPENDENCIES:"

            foreach ($dependency in $artifact.dependencies)
            {
                $dependency
                Write-Host "Validating dependency $($dependency.name): $(Validate-Relation -RelationObject $dependency)"
            }
        }
        if ($artifact.incompatibilities)
        {
            Write-Host "Validating $($parsedMod.id) artifact version $($artifact.version) INCOMPATIBILITIES:"

            foreach ($incompatibility in $artifact.incompatibilities)
            {
                $incompatibility
                Write-Host "Validating dependency $($incompatibility.name): $(Validate-Relation -RelationObject $incompatibility)"
            }
        }
        if ($artifact.extends)
        {
            Write-Host "Validating $($parsedMod.id) artifact version $($artifact.version) EXTENDS:"
            $artifact.extends

            Write-Host "Validating extends: $(Validate-Relation -RelationObject $artifact.extends)"
        }
    }
    Exit 0
}
catch
{
    Exit 1
}
Exit 1
