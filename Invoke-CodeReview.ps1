param (
    [string]$ModId,
    [string]$PromptFilePath = ".\prompt.md"
)

$repoDir = ".\$ModId\repo"
$decompiledDir = ".\$ModId\decompiled"
$resultsFile = ".\$ModId\results\AI_Review.md"

# 1. Load the system prompt
$systemPrompt = Get-Content $PromptFilePath -Raw

# 2. Gather all code into a single string to send as context
$codeContext = "=== REPO SOURCE CODE ===`n"
Get-ChildItem -Path $repoDir -Recurse -Filter *.cs | ForEach-Object {
    $codeContext += "`n--- FILE: $($_.FullName.Replace($PWD.Path, '')) ---`n"
    $codeContext += Get-Content $_.FullName -Raw
}

$codeContext += "`n`n=== DECOMPILED SOURCE CODE ===`n"
Get-ChildItem -Path $decompiledDir -Recurse -Filter *.cs | ForEach-Object {
    $codeContext += "`n--- FILE: $($_.FullName.Replace($PWD.Path, '')) ---`n"
    $codeContext += Get-Content $_.FullName -Raw
}

# 3. Construct the full prompt string
$fullPrompt = "$systemPrompt`n`nHere is the code to review:`n`n$codeContext"

# 4. Save the prompt to a temp file to avoid Windows CMD character limits
$tempPromptFile = New-TemporaryFile
$fullPrompt | Out-File -FilePath $tempPromptFile.FullName -Encoding UTF8

Write-Host "Sending $ModId to Antigravity CLI for review (Context length: $($codeContext.Length) chars)..."

try {
    # 5. Pipe the file contents into the Antigravity CLI (agy)
    # If `agy` expects a file argument (e.g., agy --file), adjust this line. Otherwise, standard STDIN piping works:
    Get-Content -Path $tempPromptFile.FullName -Raw | agy | Out-File -FilePath $resultsFile -Encoding UTF8
    
    Write-Host "AI Review completed for $ModId!" -ForegroundColor Green
}
catch {
    Write-Error "Failed to run Antigravity CLI (agy): $_"
}
finally {
    # 6. Cleanup
    Remove-Item -Path $tempPromptFile.FullName -Force
}
