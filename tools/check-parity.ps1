param(
    [string]$Root120 = (Resolve-Path "$PSScriptRoot\..").Path,
    [string]$Root121 = (Resolve-Path "$PSScriptRoot\..\versions\1.21.1").Path,
    [string]$ExceptionsFile = (Join-Path $PSScriptRoot "parity-exceptions.json"),
    [string]$ClientReleaseDir = ""
)

$ErrorActionPreference = "Stop"

$Root120 = (Resolve-Path $Root120).Path
$Root121 = (Resolve-Path $Root121).Path
if (Test-Path $ExceptionsFile) {
    $ExceptionsFile = (Resolve-Path $ExceptionsFile).Path
}

Write-Host "=== Wex Pack Parity Check (1.20.1 vs 1.21.1) ===" -ForegroundColor Cyan

$exceptions = $null
if (Test-Path $ExceptionsFile) {
    $exceptions = Get-Content $ExceptionsFile -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-ModMap([string]$modsFolder) {
    $map = @{}
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $jars = Get-ChildItem -Path $modsFolder -Filter "*.jar"
    foreach ($jar in $jars) {
        try {
            $zip = [System.IO.Compression.ZipFile]::OpenRead($jar.FullName)
            $entry = $zip.GetEntry("fabric.mod.json")
            if ($entry) {
                $stream = $entry.Open()
                $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
                $jsonText = $reader.ReadToEnd()
                $reader.Close()
                $stream.Close()
                $modJson = $jsonText | ConvertFrom-Json
                $map[$modJson.id] = @{
                    FileName = $jar.Name
                    Version = $modJson.version
                    Name = $modJson.name
                }
            } else {
                $map[$jar.Name] = @{
                    FileName = $jar.Name
                    Version = "unknown"
                    Name = $jar.BaseName
                }
            }
            $zip.Dispose()
        } catch {
            Write-Warning "Failed reading $($jar.Name): $_"
        }
    }
    return $map
}

$m120 = Get-ModMap (Join-Path $Root120 "mods")
$m121 = Get-ModMap (Join-Path $Root121 "mods")

$hasErrors = $false

# Verify the raw-GitHub jars as well as future release metadata.
. (Join-Path $PSScriptRoot "wex-client.ps1")
$clientRelease = Get-WexClientRelease -MetadataPath (Join-Path $PSScriptRoot "wex-client-release.json") -ReleaseDir $ClientReleaseDir
foreach ($mc in @('1.20.1', '1.21.1')) {
    $root = if ($mc -eq '1.20.1') { $Root120 } else { $Root121 }
    $manifestPath = if ($mc -eq '1.20.1') { Join-Path $Root120 'manifest.json' } else { Join-Path $Root120 'manifest-1.21.1.json' }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $expected = @($clientRelease.artifacts | Where-Object minecraft -eq $mc)[0]
    $entries = @($manifest.files | Where-Object path -Like 'mods/wex-client-*.jar')
    if ($entries.Count -ne 1) { throw "Expected one Wex Client entry in $manifestPath" }
    foreach ($key in @('path', 'url', 'sha256', 'size', 'mode')) {
        if ($entries[0].$key -cne $expected.$key) { throw "Wex Client $key mismatch for $mc" }
    }
    $jars = @(Get-ChildItem -LiteralPath (Join-Path $root 'mods') -Filter '*.jar' | Where-Object Name -Match '^(?:aura|wex)-client-')
    if ($jars.Count -ne 1 -or $jars[0].Name -cne $expected.fileName) {
        throw "Expected one matching local Wex Client jar for $mc"
    }
    if ($jars[0].Length -ne $expected.size -or
            (Get-FileHash -LiteralPath $jars[0].FullName -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expected.sha256) {
        throw "Local Wex Client jar hash/size mismatch for $mc"
    }
}
Write-Host "[OK] Wex Client release metadata and both manifest entries verified"


# 1. Compare Mods
Write-Host "`n1. Checking Mods..." -ForegroundColor Yellow
$missingIn121 = @()
foreach ($k in $m120.Keys) {
    if (-not $m121.ContainsKey($k)) {
        $isException = $false
        if ($exceptions) {
            if ($exceptions.droppedIn121.$k) { $isException = $true }
            if ($exceptions.modIdReplacements.$k) { $isException = $true }
        }
        if (-not $isException) {
            $missingIn121 += "$k ($($m120[$k].FileName))"
        }
    }
}

$extraIn121 = @()
foreach ($k in $m121.Keys) {
    if (-not $m120.ContainsKey($k)) {
        $isException = $false
        if ($exceptions) {
            if ($exceptions.extraIn121.$k) { $isException = $true }
            if ($exceptions.modIdReplacements) {
                foreach ($prop in $exceptions.modIdReplacements.PSObject.Properties) {
                    foreach ($rep in $prop.Value) {
                        if ($rep.target -eq $k) { $isException = $true }
                    }
                }
            }
        }
        if (-not $isException) {
            $extraIn121 += "$k ($($m121[$k].FileName))"
        }
    }
}

if ($missingIn121.Count -gt 0) {
    Write-Host "[-] Missing in 1.21.1: $($missingIn121 -join ', ')" -ForegroundColor Red
    $hasErrors = $true
}
if ($extraIn121.Count -gt 0) {
    Write-Host "[+] Extra in 1.21.1: $($extraIn121 -join ', ')" -ForegroundColor Red
    $hasErrors = $true
}
if ($missingIn121.Count -eq 0 -and $extraIn121.Count -eq 0) {
    Write-Host "[OK] Mods parity OK: 1.20 count=$($m120.Count), 1.21 count=$($m121.Count)" -ForegroundColor Green
}

# 2. Compare Configs
Write-Host "`n2. Checking Config Files..." -ForegroundColor Yellow
$cfg120 = Get-ChildItem -Path (Join-Path $Root120 "config") -Recurse -File | ForEach-Object {
    $_.FullName.Substring((Join-Path $Root120 "config").Length + 1)
}
$cfg121 = Get-ChildItem -Path (Join-Path $Root121 "config") -Recurse -File | ForEach-Object {
    $_.FullName.Substring((Join-Path $Root121 "config").Length + 1)
}

$missingCfg = $cfg120 | Where-Object { $cfg121 -notcontains $_ }
$extraCfg = $cfg121 | Where-Object { $cfg120 -notcontains $_ }

if ($missingCfg.Count -gt 0) {
    Write-Host "[-] Missing configs in 1.21.1: $($missingCfg -join ', ')" -ForegroundColor Red
    $hasErrors = $true
}
if ($extraCfg.Count -gt 0) {
    $badExtras = $extraCfg | Where-Object { $_ -match "\.bak$" -or $_ -match "cache" }
    if ($badExtras.Count -gt 0) {
        Write-Host "[-] Unwanted backup/cache files in 1.21.1: $($badExtras -join ', ')" -ForegroundColor Red
        $hasErrors = $true
    } else {
        Write-Host "[i] 1.21-specific extra configs: $($extraCfg -join ', ')" -ForegroundColor Gray
    }
}
if ($missingCfg.Count -eq 0) {
    Write-Host "[OK] All 1.20 configs are present in 1.21.1" -ForegroundColor Green
}

# 3. Compare Resourcepacks
Write-Host "`n3. Checking Resourcepacks..." -ForegroundColor Yellow
$rp120 = Get-ChildItem -Path (Join-Path $Root120 "resourcepacks") -Filter "*.zip" | Select-Object -ExpandProperty Name
$rp121 = Get-ChildItem -Path (Join-Path $Root121 "resourcepacks") -Filter "*.zip" | Select-Object -ExpandProperty Name

$missingRp = $rp120 | Where-Object { $rp121 -notcontains $_ }
if ($missingRp.Count -gt 0) {
    Write-Host "[-] Missing resourcepacks in 1.21.1: $($missingRp -join ', ')" -ForegroundColor Red
    $hasErrors = $true
} else {
    Write-Host "[OK] All resourcepacks are present in 1.21.1" -ForegroundColor Green
}

# 4. Compare options.txt resourcePacks
Write-Host "`n4. Checking options.txt resourcePacks order..." -ForegroundColor Yellow
$opt120 = Get-Content (Join-Path $Root120 "options.txt") | Where-Object { $_ -match "^resourcePacks:" }
$opt121 = Get-Content (Join-Path $Root121 "options.txt") | Where-Object { $_ -match "^resourcePacks:" }

if ($opt120 -ne $opt121) {
    Write-Host "[-] resourcePacks order mismatch!" -ForegroundColor Red
    Write-Host "1.20: $opt120"
    Write-Host "1.21: $opt121"
    $hasErrors = $true
} else {
    Write-Host "[OK] resourcePacks order matches 1:1" -ForegroundColor Green
}

if ($hasErrors) {
    Write-Host "`n[FAIL] Parity check failed!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n[SUCCESS] Parity 1.20.1 vs 1.21.1 verified: 0 violations!" -ForegroundColor Green
    exit 0
}
