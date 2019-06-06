<#
.SYNOPSIS
Downloads an HTML file from a Uri, or recursively downloads all HTMl of a site.

.PARAMETER MaxDepth
Maximum level of links to follow. Default 100.

.PARAMETER OutDir
The directory in which to download the files.

.PARAMETER Recurse
Recursively downloads all links discovered on URI, and so forth.

#>

# Parse options
param(
    [Alias("r")] [switch] $Recurse = $false,
    [int] $MaxDepth = 100,
    [string] $OutDir = ".",
    [Parameter(Position = 0)] [string] $MainUri
)

# Keep track of downloaded URIs
[System.Collections.ArrayList] $script:downloadedUris = @()

# Create temp dir if not exists
New-Item -ItemType Directory -Path (Get-Item $OutDir) -ErrorAction Ignore | Out-Null
$tmpDir = Get-Item $OutDir


function Uri2File ([string] $Uri) {
    $cleanUrl = (Split-Path $Uri -NoQualifier).Split('#')[0].Trim('/')
    $uPath, $uQuery = $cleanUrl -Split "\?" -Split "%3F" -Split "%3f"
    $uFile = $null
    if ($uPath.Split("/").Count -gt 1) {
        $uFile = $uPath.Split("/")[-1]
    }
    if ($null -ne $uQuery) {
        $uQuery = "?" + $uQuery
    }
    if ($uFile -Match ".+\.\w+$") {
        $uFileName = $uFile.Substring(0, $uFile.LastIndexOf("."))
        $uFileExt = $uFile.Substring($uFile.LastIndexOf("."))
        $outFile = Join-Path $tmpDir (Split-Path -Parent $uPath) ($uFileName + $uQuery + $uFileExt)
    }
    else {
        $outFile = Join-Path $tmpDir $uPath ("index" + $uQuery + ".html")
    }
    return $outFile
}


function Href2Uri ([string] $Href, [string] $CurrUri) {
    # Format absolute/relative href contents into a full URL for this site.
    # Return null if the href does not belong to this site or if it is traversing upwards.

    # Strip client-side URLs
    $Href = $Href.Trim().Split("#")[0]
    $Uri = $null
    # Empty, null, or beings with dot.
    if (
        $null -eq $Href -or
        $Href -eq "" -or
        $Href.StartsWith(".")
    ) {
        $Uri = $null
    }
    # Starts with the MainUri (e.g. "https://example.com/")
    elseif ($Href.StartsWith($MainUri)) {
        $Uri = $Href
    }
    # Starts with the MainUri regardless of protocol (e.g. "//example.com")
    elseif ( (Split-Path -NoQualifier $Href).StartsWith( (Split-Path -NoQualifier $MainUri) )) {
        $Uri = $Href
    }
    # Starts with a slash (e.g. "/index.html")
    elseif ($Href.StartsWith("/")) {
        $Uri = $MainUri.Trim("/") + $Href
    }
    # Doesn't start with a protocol or double slashes (e.g. "index.html")
    elseif (-not (Split-Path -NoQualifier $Href).StartsWith("//")) {
        $Uri = $CurrUri.Substring(0, $CurrUri.LastIndexOf("/")) + "/" + $Href
    }
    return $Uri
}


function Get-Html ([string] $Uri, [int] $currDepth = 1) {
    if (-not $downloadedUris.Contains($Uri)) {

        # Download HTML
        $downloadedUris.Add($Uri) | Out-Null
        $OutFile = Uri2File($Uri)
        New-Item -Force -Path $OutFile | Out-Null
        Write-Output "Downloading: $Uri"
        $Response = Invoke-WebRequest -PassThru -SkipCertificateCheck -Uri $Uri -OutFile $OutFile

        # Recurse on sub-links
        if ($Recurse -and $currDepth -lt $MaxDepth) {
            $currDepth = $currDepth + 1
            foreach ($Href in ($Response.Links.Href | Select-Object -Unique)) {
                $SubUri = Href2Uri -CurrUri $Uri -Href $Href
                if ($SubUri) {
                    Get-Html -Uri $SubUri -currDepth $currDepth
                }
            }
        }

    }
}

# Begin downloading
Get-Html -Uri $MainUri
