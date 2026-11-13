function Get-GitHubReleases {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Owner,
        
        [Parameter(Mandatory = $true)]
        [string]$Repository ,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeDraft = $false,
        
        [Parameter(Mandatory = $false)]
        [string]$Token
    )
    
    $uri = [uri]"https://api.github.com/repos/$Owner/$Repository/releases"
    
    $params = @{
        Uri = $uri
        Method = 'Get'
        Headers = @{
            'Accept' = 'application/vnd.github+json'
            'User-Agent' = 'PowerShell-GitHubReleaseParser'
        }
    }
    
    if ($Token) {
        $params.Headers['Authorization'] = "Bearer $Token"
        $params['PreserveAuthorizationOnRedirect'] = $true
    }
    
    try {
        $allReleases = @()
        $page = 1
        
        do {
            $pageUri = [uri]"$($uri.AbsoluteUri)?per_page=100&page=$page"
            $params.Uri = $pageUri
            
            $response = Invoke-RestMethod @params
            if ($response) {
                $allReleases += @($response)
                $page++
            }
        } while ($response.Count -eq 100)
        
        $filtered = $allReleases | Where-Object {
            if ($_.draft -and -not $IncludeDraft) { return $false }
            return $true
        }
        
        foreach ($release in $filtered) {
            $assets = foreach ($asset in $release.assets) {
                [PSCustomObject]@{
                    FileName = $asset.name
                    DownloadUrl = $asset.browser_download_url
                    Size = $asset.size
                    ContentType = $asset.content_type
                    DownloadCount = $asset.download_count
                    digest = $asset.digest
                }
            }
            
            [PSCustomObject]@{
                TagName = $release.tag_name
                ReleaseName = $release.name
                ReleaseUrl = $release.html_url
                PublishedAt = if ($release.published_at) { [DateTime]$release.published_at } else { $null }
                IsPrerelease = [bool]$release.prerelease
                IsDraft = [bool]$release.draft
                Body = $release.body
                Author = $release.author.login
                Assets = $assets
                AssetCount = $assets.Count
            }
        }
    }
    catch {
        Write-Error "Failed: $_"
        throw
    }
}
