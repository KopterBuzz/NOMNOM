param($modPath="C:\code\NOModManifestTesting\modManifests\NO_Tactitools.json",$allModsHashTable=$(((Get-ChildItem ".\test\" -Filter "*.json").FullName | foreach {Get-Content $_ | ConvertFrom-Json -Depth 100}) | group id -AsHashTable),$test=$true)

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

$newDeps = @()
if ($mod.artifacts[0].dependencies)
{   
    foreach ($dependency in $mod.artifacts[0].dependencies)
    {       
        $dep = [PSCustomObject]@{
            id = $($allModsHashTable[$dependency.id]).id
            version = @($allModsHashTable[$dependency.id]).artifacts[0].version
        }
        $newDeps+=$dep
        Remove-Variable dep
        
    }
    $mod.artifacts[0].dependencies = @($newDeps)
}


SaveAndClose -mod_ $mod -test_ $test