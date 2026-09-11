dotnet tool install -g ilspycmd

$mods = get-content .\manifest\manifest.json | ConvertFrom-Json

cd .\audit

$notOpenSource = @()
$readyForCodeReview = @()
$multipleAssemblies = @()

foreach ($mod in $mods) {

    mkdir $mod.id
    mkdir ".\$($mod.id)\repo"
    mkdir ".\$($mod.id)\release"
    mkdir ".\$($mod.id)\decompiled"
    mkdir ".\$($mod.id)\results"

    $repo = "https://github.com/$($mod.gitHubOwner)/$($mod.gitHubRepoName)"
    $release = "https://github.com/$($mod.gitHubOwner)/$($mod.gitHubRepoName)\releases\latest"
    git clone $repo ".\$($mod.id)\repo"

    $outFile = ".\$($mod.id)\release\$($mod.artifacts[0].fileName)"
    try {
        Invoke-WebRequest -Uri $mod.artifacts[0].downloadUrl -OutFile $outFile
    }
    catch {
        $("ERROR DOWNLOADING RELEASE:`n$($error[0] | select *)") | out-file ".\$($mod.id)\results\ReleaseAudit.txt"
        continue
    }
    

    try {
        if ($outFile -match '\.(zip|rar|7z|tar\.gz|tgz|gz|tar)$') {
            if ($outFile -match '\.zip$') {
                Expand-Archive -Path $outFile -DestinationPath ".\$($mod.id)\release" -Force
            }
            else {
                tar -xf $outFile -C ".\$($mod.id)\release"
            }
            Remove-Item -Path $outFile -Force
        }
    }
    catch {
        $("ERROR UNPACKING RELEASE:`n$($error[0] | select *)") | out-file ".\$($mod.id)\results\ReleaseAudit.txt"
        continue
    }


    $files = get-childitem ".\$($mod.id)\release" -Recurse | select -expandproperty fullname | where { $_ -match "\.dll$|\.exe$" }
    if ($files.count -eq 0) {
        $("NO ASSEMBLIES OR EXECUTABLES`nFiles:`n$($(get-childitem ".\$($mod.id)\release" -Recurse | select -expandproperty fullname) -join "`n")") | out-file ".\$($mod.id)\results\ReleaseAudit.txt"
        continue
    }

    $repoFiles = get-childitem ".\$($mod.id)\repo" -Recurse -File
    if ($repoFiles.Count -eq 0 -or ($repoFiles.Count -eq 1 -and $repoFiles[0].Name -match '(?i)^readme(\.md|\.txt)?$')) {
        $("NOT OPEN SOURCE: Repo is empty or only contains a readme file.`nAssemblies found:`n$($files -join "`n")") | out-file ".\$($mod.id)\results\ReleaseAudit.txt"
        $notOpenSource += $mod.id
        continue
    }
    if ($files.count -eq 1) {
        ilspycmd -p -o ".\$($mod.id)\decompiled" $files
        $("Ready For Automated Code Review`nFiles:`n$($(get-childitem ".\$($mod.id)\release" -Recurse | select -expandproperty fullname) -join "`n")") | out-file ".\$($mod.id)\results\ReleaseAudit.txt"
        $readyForCodeReview += $mod.id
        continue
    }
    if ($files.count -gt 1) {
        $("MULTIPLE ASSEMBLIES OR EXECUTABLES`nFiles:`n$($files -join "`n")") | out-file ".\$($mod.id)\results\ReleaseAudit.txt"
        $multipleAssemblies+=$mod.id
        continue
    }
}

cd ..

