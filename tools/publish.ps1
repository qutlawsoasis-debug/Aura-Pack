# tools\publish.ps1 (PowerShell 5.1 compatible, ASCII safe)
param(
    [switch]$Yes,
    [switch]$Full
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$packDir = (Resolve-Path (Join-Path $scriptDir "..")).Path

# 1. Run make-manifest.ps1
$makeManifestScript = Join-Path $scriptDir "make-manifest.ps1"
if (-not (Test-Path $makeManifestScript)) {
    throw "make-manifest.ps1 script not found: $makeManifestScript"
}

Write-Host "=== Generating Manifest ==="
$manifestOutput = & powershell.exe -ExecutionPolicy Bypass -File $makeManifestScript
$manifestOutput | ForEach-Object { Write-Host $_ }

if ($manifestOutput -contains "No changes" -or $manifestOutput -contains "Нет изменений") {
    Write-Host "make-manifest reported: No changes. Publication not needed."
    return
}

$manifestPath = Join-Path $packDir "manifest.json"
if (-not (Test-Path $manifestPath)) {
    throw "Manifest was not created: $manifestPath"
}

$manifest = (Get-Content $manifestPath -Raw) | ConvertFrom-Json
$packVersion = $manifest.packVersion

# 2. Git status summary
Push-Location $packDir
try {
    Write-Host "`n=== Git Status Summary ==="
    $statusLines = git status --short
    if (-not $statusLines) {
        Write-Host "No changes to commit."
        return
    }
    
    $added = 0
    $modified = 0
    $deleted = 0
    $untracked = 0
    
    foreach ($line in $statusLines) {
        $st = $line.Substring(0, 2)
        if ($st.Contains("A")) { $added++ }
        elseif ($st.Contains("M")) { $modified++ }
        elseif ($st.Contains("D")) { $deleted++ }
        elseif ($st.Contains("?")) { $untracked++ }
    }
    
    Write-Host "Added: $added, Modified: $modified, Deleted: $deleted, Untracked: $untracked"
    
    $totalSizeBytes = 0
    foreach ($f in $manifest.files) {
        $totalSizeBytes += $f.size
    }
    $totalMb = [math]::Round($totalSizeBytes / 1MB, 2)
    Write-Host "Total pack size: $totalMb MB ($($manifest.files.Count) files)`n"

    Write-Host "=== Files to be committed ==="
    foreach ($line in $statusLines) {
        Write-Host "  $line"
    }

    # User confirmation
    if (-not $Yes) {
        Write-Host ""
        $confirm = Read-Host "Confirm publication of pack $packVersion? (y/n)"
        if ($confirm -ne "y" -and $confirm -ne "Y") {
            Write-Host "Publication cancelled by user."
            return
        }
    } else {
        Write-Host "`nFlag -Yes is active: confirmation skipped."
    }

    # 3. git add, commit, push
    Write-Host "`n=== Executing git add, commit, push ==="
    git add -A
    git commit -m "pack $packVersion"
    git push origin main
    if ($LASTEXITCODE -ne 0) {
        throw "git push failed."
    }

    Write-Host "Successfully pushed to GitHub."
}
finally {
    Pop-Location
}

# 4. Verify from raw.githubusercontent.com
Write-Host "`n=== Verification from raw.githubusercontent.com ==="
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$rawBase = "https://raw.githubusercontent.com/qutlawsoasis-debug/Aura-Pack/main"
$sha256 = [System.Security.Cryptography.SHA256]::Create()

function Download-And-Hash {
    param(
        [string]$url,
        [ref]$statusCode
    )
    $req = [System.Net.HttpWebRequest]::Create($url)
    $req.Method = "GET"
    $req.UserAgent = "AuraPackPublisher"
    $req.Timeout = 20000

    try {
        $resp = $req.GetResponse()
        $statusCode.Value = [int]$resp.StatusCode
        $stream = $resp.GetResponseStream()
        $ms = New-Object System.IO.MemoryStream
        $stream.CopyTo($ms)
        $stream.Close()
        $resp.Close()

        $bytes = $ms.ToArray()
        $ms.Dispose()

        $hashBytes = $sha256.ComputeHash($bytes)
        $sb = New-Object System.Text.StringBuilder
        foreach ($b in $hashBytes) {
            [void]$sb.Append($b.ToString("x2"))
        }
        return $sb.ToString()
    }
    catch [System.Net.WebException] {
        if ($_.Response) {
            $statusCode.Value = [int]$_.Response.StatusCode
            $_.Response.Close()
        } else {
            $statusCode.Value = 0
        }
        return $null
    }
}

# 4.1. Check manifest.json
$manifestUrl = "$rawBase/manifest.json?t=" + [DateTime]::UtcNow.Ticks
$mStatus = 0
$mHash = Download-And-Hash -url $manifestUrl -statusCode ([ref]$mStatus)
if ($mStatus -ne 200) {
    throw "Failed to download manifest.json from GitHub (HTTP $mStatus)"
}
Write-Host "manifest.json verified: HTTP 200, SHA-256: $mHash"

# Check packVersion in remote manifest
$remoteManifest = (Invoke-RestMethod -Uri $manifestUrl -Headers @{"User-Agent"="AuraPackPublisher"})
if ($remoteManifest.packVersion -ne $packVersion) {
    throw "Remote packVersion mismatch! Local: $packVersion, Remote: $($remoteManifest.packVersion)"
}
Write-Host "packVersion on GitHub matches: $packVersion"

# 4.2. Check 2 files with '+' in path: %2B vs literal '+'
$plusFiles = @($manifest.files | Where-Object { $_.path -match "\+" })
if ($plusFiles.Count -ge 2) {
    Write-Host "`n=== Special check for files with '+' in name ==="
    for ($pIdx = 0; $pIdx -lt 2; $pIdx++) {
        $pf = $plusFiles[$pIdx]
        Write-Host "File: $($pf.path)"
        
        # Variant 1: %2B
        $segEnc = $pf.path.Split('/') | ForEach-Object { [Uri]::EscapeDataString($_) }
        $pathEnc = $segEnc -join '/'
        $urlEnc = "$rawBase/$pathEnc?t=" + [DateTime]::UtcNow.Ticks
        $stEnc = 0
        $hashEnc = Download-And-Hash -url $urlEnc -statusCode ([ref]$stEnc)
        $matchEnc = ($hashEnc -eq $pf.sha256)
        Write-Host "  Variant %2B: HTTP $stEnc, SHA-256 match = $matchEnc"

        # Variant 2: literal '+'
        $segLit = $pf.path.Split('/') | ForEach-Object { [Uri]::EscapeDataString($_).Replace("%2B", "+") }
        $pathLit = $segLit -join '/'
        $urlLit = "$rawBase/$pathLit?t=" + [DateTime]::UtcNow.Ticks
        $stLit = 0
        $hashLit = Download-And-Hash -url $urlLit -statusCode ([ref]$stLit)
        $matchLit = ($hashLit -eq $pf.sha256)
        Write-Host "  Variant '+':  HTTP $stLit, SHA-256 match = $matchLit"
    }
}

# 4.3. Check pack files
$filesToCheck = @()
if ($Full) {
    Write-Host "`n=== Full verification of all manifest files (-Full) ==="
    $filesToCheck = $manifest.files
} else {
    Write-Host "`n=== Sample check of 3 files ==="
    $configFiles = @($manifest.files | Where-Object { $_.path.StartsWith("config/") })
    $modFiles = @($manifest.files | Where-Object { $_.path.StartsWith("mods/") })
    $optFile = $manifest.files | Where-Object { $_.path -eq "options.txt" }
    if ($configFiles.Count -gt 0) { $filesToCheck += $configFiles[(Get-Random -Maximum $configFiles.Count)] }
    if ($modFiles.Count -gt 0) { $filesToCheck += $modFiles[(Get-Random -Maximum $modFiles.Count)] }
    if ($optFile) { $filesToCheck += $optFile }
}

$checkedCount = 0
$matchedCount = 0
$totalToCheck = $filesToCheck.Count

foreach ($f in $filesToCheck) {
    $segments = $f.path.Split('/')
    $escapedSegments = New-Object System.Collections.Generic.List[string]
    foreach ($seg in $segments) {
        $escapedSegments.Add([Uri]::EscapeDataString($seg))
    }
    $escapedPath = [string]::Join('/', $escapedSegments)
    $fileUrl = "$rawBase/$escapedPath?t=" + [DateTime]::UtcNow.Ticks

    $fStatus = 0
    $actualHash = Download-And-Hash -url $fileUrl -statusCode ([ref]$fStatus)

    if ($fStatus -ne 200) {
        throw "Failed to download $($f.path) from GitHub (HTTP $fStatus)"
    }
    if ($actualHash -ne $f.sha256) {
        throw "SHA-256 mismatch for $($f.path)! Expected: $($f.sha256), Got: $actualHash"
    }

    $checkedCount++
    $matchedCount++

    if ($checkedCount % 10 -eq 0 -or $checkedCount -eq $totalToCheck) {
        Write-Host "Verified: $checkedCount / $totalToCheck files (100% SHA-256 OK)"
    }
}

$sha256.Dispose()
Write-Host "`nSUCCESS: All verification checks passed! Checked $checkedCount files, all matched manifest."