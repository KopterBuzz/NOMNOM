$manifestPaths = get-childitem .\modManifests\*.json | select -ExpandProperty fullname

foreach ($path in $manifestPaths)
{
    $data = Get-Content $path
    if ($($data -match '"isAiAssisted":'))
    {
        Write-Host "isAiAssisted exists in $($path)" -ForegroundColor Green
    }
    
    else
    {
        Write-Host "isAiAssisted is missing in $($path)" -ForegroundColor Yellow
        Write-Host "adding isAiAssisted to $($path)"
        $Manifest = $data | ConvertFrom-Json
        $Manifest | Add-Member -MemberType NoteProperty -Name "isAiAssisted" -Value "False" -Force
        $JsonOut = $Manifest | ConvertTo-Json -Depth 100
        $JsonOut | Set-Content $path -Encoding utf8NoBOM
    } 
}