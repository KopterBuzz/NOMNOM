param($modPath,$gitHubToken = $(Get-Content ".\testing_gitignore.token"), [bool]$test)
. .\Get-GitHubReleases.ps1
Function SaveAndClose($mod_,[bool]$test_)
{

        $output = ConvertTo-Json $mod -Depth 100
        #write-host $output
        if ($test_)
        {
            $path = ".\test\$($mod_.id).json"
        } else {
            $path = ".\modManifests\$($mod_.id).json"
        }
        try {
            $output | out-file -FilePath $path  -Encoding utf8NoBOM
            Exit 0
        } 
        catch {
            Exit 1
        }
}

Function SortByVersion($artifacts_)
{
    $output = @()
    foreach ($artifact in $artifacts_)
    {
        $version = [version]$artifact.version
        $obj = [PSCustomObject]@{
            version = $version
            artifact = $artifact
        }
        $output+=$obj
        remove-variable obj
    }
    return ($output | sort version -Descending | select -ExpandProperty artifact)
}

$mod = $null
try {
    $mod = get-content $modPath | ConvertFrom-Json
} catch {
    $error[0]
    Exit 1
}

if (!$mod)
{
    Write-Host $modPath not found!
    Exit 1
}

$downloadCount = 0

if ($($mod.autoUpdateArtifacts) -ne "True") {
    SaveAndClose -mod_ $mod -test_ $test
}

$artifacts = @($mod.artifacts)
$artifacts.Values
if (!$mod.githubOwner) {
    Write-Host "GitHub Owner for $($mod.id) $($mod.githubOwner) $($mod.githubRepoName) Unavailable"
    SaveAndClose -mod_ $mod -test_ $test
}
if (!$mod.githubRepoName) {
    Write-Host "GitHub Repo Name for $($mod.id) $($mod.githubOwner) $($mod.githubRepoName) Unavailable"
    SaveAndClose -mod_ $mod -test_ $test
}
$releases = $null
Try {
    $releases = Get-GitHubReleases -Owner $mod.githubOwner -Repository $mod.githubRepoName -Token $gitHubToken
} Catch {
    Write-Host "Failed to Fetch GitHub Releases for $($mod.id) $($mod.githubOwner) $($mod.githubRepoName)"
    $mod | convertto-json -Depth 100 | out-file ".\test\$($mod.id).json" -Encoding utf8NoBOM
}
write-host $releases.count

$extends = $artifacts[0].extends
$dependencies = $artifacts[0].dependencies
$incompatibilities = $artifacts[0].incompatibilities
$gameVersion = $(if ($artifacts){$artifacts[0].gameVersion}else{"0.32"})
$type = $(if ($artifacts[0].type){$artifacts[0].type}else{"unknown"})

if ($releases)
{
    foreach ($release in $releases)
    {
        $ErrorActionPreference = 'SilentlyContinue'
        if ($release.IsDraft){continue}
        
        $version = [version]($release.TagName -replace "v|\-pre|_IL2CPP","")
        if (($version -gt [version]($artifacts[0].version) -and $($mod.autoUpdateArtifacts) -eq "True") -or !$artifacts)
        {
            $obj = [PSCustomObject]@{
                fileName = $release.Assets[0].fileName
                version = $release.TagName -replace "v|\-pre|_IL2CPP",""
                category = $(if ($release.IsPrerelease){"preRelease"}else{"release"})
                type = $type
                gameVersion = $gameVersion
                downloadUrl = $release.Assets[0].DownloadUrl
                hash = $null #this will have to be removed later, thanks github api
            }
            if ($extends)
            {
                $obj | Add-Member -MemberType NoteProperty -Name "extends" -Value $extends
            }
            if ($dependencies)
            {
                $obj | Add-Member -MemberType NoteProperty -Name "dependencies" -Value $dependencies
            }
            if ($incompatibilities)
            {
                $obj | Add-Member -MemberType NoteProperty -Name "incompatibilities" -Value $incompatibilities
            }
            $artifacts+=$obj
            Remove-Variable obj
        }

        $downloadCount+=$release.Assets[0].downloadCount
    }
    $ErrorActionPreference = 'Continue'
    $mod.artifacts = @(SortByVersion -artifacts_ $artifacts)
}
if ($mod.downloadCount) {
    $mod.downloadCount = $downloadCount
} else {
    $mod | Add-Member -MemberType NoteProperty -Name "downloadCount" -Value $downloadCount -Force
}

if ($mod -eq $null) {Write-Host "$($mod.id) NULL CHECK"}

SaveAndClose -mod_ $mod -test_ $test



