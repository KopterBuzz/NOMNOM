function Get-ModReleaseArtifact {
    [CmdletBinding()]
    param($Mod, $Release)

    if ($Release.IsDraft) { return }

    $versionText = $Release.TagName
    if ($Mod.releaseTagPrefix) {
        if (!$versionText.StartsWith($Mod.releaseTagPrefix, [StringComparison]::Ordinal)) {
            return
        }
        $versionText = $versionText.Substring($Mod.releaseTagPrefix.Length)
    } else {
        # Preserve the tag cleanup used by existing manifests.
        $versionText = $versionText -replace "v|\-pre|_IL2CPP", ""
    }

    [version]$version = $null
    if (![version]::TryParse($versionText, [ref]$version)) {
        Write-Warning "Skipping release '$($Release.TagName)' for '$($Mod.id)': invalid version '$versionText'."
        return
    }

    if (!$Release.Assets) {
        Write-Warning "Skipping release '$($Release.TagName)' for '$($Mod.id)': no release assets available."
        return
    }

    if ($Mod.releaseAssetName) {
        $asset = $Release.Assets | Where-Object {
            [string]::Equals($_.FileName, $Mod.releaseAssetName, [StringComparison]::Ordinal)
        } | Select-Object -First 1
    } else {
        $asset = $Release.Assets[0]
    }

    if (!$asset) {
        Write-Warning "Skipping release '$($Release.TagName)' for '$($Mod.id)': release asset '$($Mod.releaseAssetName)' unavailable."
        return
    }

    [PSCustomObject]@{
        Version = $versionText
        Asset = $asset
    }
}
