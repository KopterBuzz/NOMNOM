$manifestVersion = Get-Content .\manifest\version.json | ConvertFrom-Json
[version]$oldVersion = [Version]$manifestVersion
$oldVersion
$major = $oldVersion.Major
$minor = $oldVersion.Minor
$build = $oldVersion.Build
$revision = $oldVersion.Revision
$revision +=1
$version = [version]($($major.ToString() + "." + $minor.ToString() + "." + $build.ToString() + "." + $revision.ToString()))
$version
$version.ToString() | ConvertTo-Json | Out-File .\manifest\version.json