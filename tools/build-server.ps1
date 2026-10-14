# tools\build-server.ps1
[CmdletBinding()]
param(
    [string]$OutputDir = (Join-Path $env:TEMP "aura-server-test"),
    [switch]$Zip,
    [string]$ZipPath = ""
)

$ErrorActionPreference = "Stop"

$OutputDir = $OutputDir.TrimEnd('\', '/')

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$packDir = (Resolve-Path (Join-Path $scriptDir "..")).Path

Write-Host "=== Aura Dedicated Server Builder ==="
Write-Host "Source pack: $packDir"
Write-Host "Target dir:  $OutputDir"

# 1. Clean / create OutputDir
if (Test-Path $OutputDir) {
    Write-Host "Cleaning output directory (preserving launcher if exists)..."
    Get-ChildItem -Path $OutputDir | Where-Object { $_.Name -ne "fabric-server-launch.jar" } | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# 2. Copy config and tlm_custom_pack
$srcConfig = Join-Path $packDir "config"
if (Test-Path $srcConfig) {
    Write-Host "Copying config..."
    Copy-Item -Path $srcConfig -Destination $OutputDir -Recurse -Force
}

$srcTlm = Join-Path $packDir "tlm_custom_pack"
if (Test-Path $srcTlm) {
    Write-Host "Copying tlm_custom_pack..."
    Copy-Item -Path $srcTlm -Destination $OutputDir -Recurse -Force
}

# 3. Copy mods
$modsDir = Join-Path $OutputDir "mods"
if (-not (Test-Path $modsDir)) {
    New-Item -ItemType Directory -Path $modsDir -Force | Out-Null
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$nameExclusions = @(
    'entityculling*',
    'notenoughanimations*',
    'short-grass*',
    'skinlayers3d*',
    'waveycapes*',
    'lanserverproperties*',
    'sound-physics-remastered*',
    'aura-defaults*',
    'litematica*',
    'malilib*'
)

$allJars = Get-ChildItem -Path (Join-Path $packDir "mods\*.jar")
$copiedCount = 0

foreach ($jar in $allJars) {
    $exclude = $false
    foreach ($pat in $nameExclusions) {
        if ($jar.Name -like $pat) {
            $exclude = $true
            break
        }
    }
    if (-not $exclude) {
        $z = [System.IO.Compression.ZipFile]::OpenRead($jar.FullName)
        $e = $z.GetEntry("fabric.mod.json")
        if ($e) {
            $s = $e.Open()
            $r = New-Object System.IO.StreamReader($s)
            $t = $r.ReadToEnd()
            $r.Close()
            try {
                $j = $t | ConvertFrom-Json
                if ($j.environment -and [string]$j.environment -eq "client") {
                    $exclude = $true
                }
            } catch {}
        }
        $z.Dispose()
    }
    
    if (-not $exclude) {
        Copy-Item -Path $jar.FullName -Destination $modsDir -Force
        $copiedCount++
    }
}

Write-Host "Copied $copiedCount server mods to $modsDir"

# 4. Download Fabric server launcher
$serverJarPath = Join-Path $OutputDir "fabric-server-launch.jar"
if (-not (Test-Path $serverJarPath)) {
    Write-Host "Downloading Fabric server launcher..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $fabricUrl = "https://meta.fabricmc.net/v2/versions/loader/1.20.1/0.19.5/1.0.1/server/jar"
    Invoke-WebRequest -Uri $fabricUrl -OutFile $serverJarPath -UseBasicParsing
    Write-Host "Downloaded: $serverJarPath"
} else {
    Write-Host "Fabric server launcher already present: $serverJarPath"
}

# 5. Write eula.txt, server.properties and start.sh
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$eulaPath = Join-Path $OutputDir "eula.txt"
[System.IO.File]::WriteAllText($eulaPath, "eula=true`n", $utf8NoBom)

$serverPropsPath = Join-Path $OutputDir "server.properties"
$serverPropsContent = @"
online-mode=false
motd=Aura Server
max-players=10
view-distance=10
simulation-distance=8
server-port=25565
"@
[System.IO.File]::WriteAllText($serverPropsPath, $serverPropsContent + "`n", $utf8NoBom)

$startShPath = Join-Path $OutputDir "start.sh"
$startShContent = "#!/bin/sh`njava -Xms8G -Xmx16G -XX:+UseG1GC -Djava.net.preferIPv4Stack=true -jar fabric-server-launch.jar nogui`n"
[System.IO.File]::WriteAllText($startShPath, $startShContent, $utf8NoBom)

# 6. Optional ZIP archive
if ($Zip) {
    if (-not $ZipPath) {
        $parentDir = Split-Path -Parent (Resolve-Path $OutputDir).Path
        $ZipPath = Join-Path $parentDir "aura-server.zip"
    }

    if (Test-Path $ZipPath) {
        Remove-Item -Path $ZipPath -Force
    }

    Write-Host "Creating server zip archive: $ZipPath"

    $zipStream = [System.IO.File]::Open($ZipPath, [System.IO.FileMode]::Create)
    $zipArchive = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)

    # Allowed root files
    $includeFiles = @('fabric-server-launch.jar', 'eula.txt', 'server.properties', 'start.sh')
    foreach ($fn in $includeFiles) {
        $filePath = Join-Path $OutputDir $fn
        if (Test-Path $filePath) {
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $filePath, $fn, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    }

    # Allowed directories
    $includeDirs = @('config', 'mods', 'tlm_custom_pack')
    foreach ($dn in $includeDirs) {
        $dirPath = Join-Path $OutputDir $dn
        if (Test-Path $dirPath) {
            $files = Get-ChildItem -Path $dirPath -Recurse -File
            foreach ($file in $files) {
                $relPath = $file.FullName.Substring($OutputDir.Length).TrimStart('\', '/')
                $entryName = $relPath.Replace('\', '/')
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $file.FullName, $entryName, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
            }
        }
    }

    $zipArchive.Dispose()
    $zipStream.Dispose()

    $zipItem = Get-Item $ZipPath
    $zipMb = [math]::Round($zipItem.Length / 1MB, 2)
    Write-Host "Server zip created successfully: $ZipPath ($zipMb MB)"
}

Write-Host "=== Build Complete ==="
Write-Host "Server directory ready at: $OutputDir"
