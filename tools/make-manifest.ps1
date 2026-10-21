# tools\make-manifest.ps1 (PowerShell 5.1 compatible, UTF-8 no BOM)
param(
    [string]$TargetVersion = "1.20.1"
)
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$packDir = (Resolve-Path (Join-Path $scriptDir "..")).Path

# 1. Чтение pack.settings.json
$settingsPath = Join-Path $packDir "pack.settings.json"
if (-not (Test-Path $settingsPath)) {
    throw "pack.settings.json not found in pack root: $settingsPath"
}
$settingsJson = Get-Content $settingsPath -Raw
$settings = $settingsJson | ConvertFrom-Json

$name = $settings.name
if (-not $name) { $name = "Aura" }

if ($TargetVersion -eq "1.21.1") {
    $minecraft = "1.21.1"
    $fabricLoader = "0.19.5"
    $manifestFileName = "manifest-1.21.1.json"
    $optionsPath = Join-Path $packDir "versions\1.21.1\options.txt"
    $rpBasePath = Join-Path $packDir "versions\1.21.1\resourcepacks"
} else {
    $minecraft = if ($settings.minecraft) { $settings.minecraft } else { "1.20.1" }
    $fabricLoader = if ($settings.fabricLoader) { $settings.fabricLoader } else { "0.19.5" }
    $manifestFileName = "manifest.json"
    $optionsPath = Join-Path $packDir "options.txt"
    $rpBasePath = Join-Path $packDir "resourcepacks"
}

$forceConfigs = @()
if ($settings.forceConfigs) {
    foreach ($fc in $settings.forceConfigs) {
        $cleanFc = $fc.Replace("\", "/").TrimStart("/")
        $forceConfigs += $cleanFc
    }
}

# 2. Проверка options.txt и ресурспаков
if (Test-Path $optionsPath) {
    $optLines = Get-Content $optionsPath
    foreach ($line in $optLines) {
        if ($line.StartsWith("resourcePacks:")) {
            $rawList = $line.Substring("resourcePacks:".Length)
            $prefix = '"file/'
            $idx = 0
            while (($idx = $rawList.IndexOf($prefix, $idx)) -ge 0) {
                $start = $idx + $prefix.Length
                $end = $rawList.IndexOf('"', $start)
                if ($end -gt $start) {
                    $rpFile = $rawList.Substring($start, $end - $start)
                    $rpFullPath = Join-Path $rpBasePath $rpFile
                    if (-not (Test-Path $rpFullPath)) {
                        Write-Warning "ResourcePack '$rpFile' in options.txt not found at $rpFullPath"
                    }
                    $idx = $end + 1
                } else {
                    break
                }
            }
        }
    }
}

# 3. Получение списка файлов через git ls-files с кодировкой UTF-8
Push-Location $packDir
try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $gitFiles = git -c core.quotepath=false ls-files --cached --others --exclude-standard
}
finally {
    Pop-Location
}

if (-not $gitFiles) {
    throw "git ls-files returned an empty file list."
}

# 4. Фильтрация, проверки и расчет SHA-256
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$maxFileSize = 90 * 1024 * 1024 # 90 MB

$fileEntries = New-Object System.Collections.Generic.List[PSObject]
$seenPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

foreach ($relPathRaw in $gitFiles) {
    $relPath = $relPathRaw.Trim()
    if ([string]::IsNullOrWhiteSpace($relPath)) { continue }

    # Проверка на кавычки и недопустимые символы
    if ($relPath.StartsWith('"') -or $relPath.EndsWith('"')) {
        throw "Path starts or ends with quote: $relPath"
    }
    if ($relPath.Contains([string][char]0xFFFD)) {
        throw "Path contains replacement char U+FFFD (encoding error): $relPath"
    }

    # Проверка ведущих и замыкающих пробелов
    if ($relPath -ne $relPath.Trim()) {
        throw "Path has leading or trailing spaces: '$relPath'"
    }
    $segments = $relPath.Split('/')
    foreach ($seg in $segments) {
        if ($seg -ne $seg.Trim()) {
            throw "Path segment has leading or trailing spaces: '$seg' in '$relPath'"
        }
    }

    # Валидация пути
    if ($relPath.Contains("..")) {
        throw "Invalid path (contains '..'): $relPath"
    }
    if ($relPath.Contains("\")) {
        throw "Invalid path (contains backslash): $relPath"
    }
    if ($relPath.StartsWith("/") -or $relPath.Contains(":")) {
        throw "Invalid path (absolute path): $relPath"
    }

    # Исключения
    if ($relPath -eq "manifest.json" -or $relPath -eq "manifest-1.21.1.json" -or $relPath -eq "pack.settings.json" -or $relPath -eq "server-mods.json" -or $relPath -eq "servers.json" -or $relPath.EndsWith(".example") -or $relPath.StartsWith(".git") -or $relPath.StartsWith("tools/") -or $relPath.StartsWith(".github/") -or $relPath.StartsWith("assets/") -or $relPath.StartsWith(".agents/") -or $relPath.StartsWith("shaderpacks_pool/") -or $relPath -like "README*" -or $relPath -like "LICENSE*" -or $relPath -like "CONTRIBUTING*" -or $relPath -like "AGENTS*") {
        continue
    }

    # Разделение по версиям
    if ($TargetVersion -eq "1.21.1") {
        if (-not $relPath.StartsWith("versions/1.21.1/")) {
            continue
        }
        else {
            $relPathInManifest = $relPath.Substring("versions/1.21.1/".Length)
        }
    } else {
        if ($relPath.StartsWith("versions/")) {
            continue
        }
        $relPathInManifest = $relPath
    }

    # Проверка на дубликаты (без учета регистра)
    if (-not $seenPaths.Add($relPathInManifest)) {
        throw "Duplicate path detected in manifest: $relPathInManifest"
    }

    $fullPath = Join-Path $packDir ($relPath.Replace("/", "\"))
    if (-not (Test-Path $fullPath -PathType Leaf)) {
        continue # Пропускаем директории
    }

    $fileInfo = New-Object System.IO.FileInfo($fullPath)
    if ($fileInfo.Length -gt $maxFileSize) {
        $mb = [math]::Round($fileInfo.Length / 1MB, 2)
        throw "File exceeds 90 MB limit: $relPath ($mb MB)"
    }

    # Определение режима: sync vs default
    $mode = "sync"
    if ($relPathInManifest.StartsWith("config/") -or $relPathInManifest -eq "options.txt") {
        $mode = "default"
        foreach ($fc in $forceConfigs) {
            if ($relPathInManifest -eq $fc -or $relPathInManifest -eq ("config/" + $fc)) {
                $mode = "sync"
                break
            }
        }
    }
    elseif ($relPathInManifest.StartsWith("mods/") -or $relPathInManifest.StartsWith("shaderpacks/") -or $relPathInManifest.StartsWith("shaderpacks_pool/") -or $relPathInManifest.StartsWith("resourcepacks/") -or $relPathInManifest.StartsWith("tlm_custom_pack/")) {
        $mode = "sync"
    }
    else {
        $mode = "default"
    }

    # Расчет SHA-256
    $bytes = [System.IO.File]::ReadAllBytes($fullPath)
    $hashBytes = $sha256.ComputeHash($bytes)
    $sb = New-Object System.Text.StringBuilder
    foreach ($b in $hashBytes) {
        [void]$sb.Append($b.ToString("x2"))
    }
    $hashStr = $sb.ToString()

    $entry = [PSCustomObject]@{
        path   = $relPathInManifest
        sha256 = $hashStr
        size   = $fileInfo.Length
        mode   = $mode
    }
    $fileEntries.Add($entry)
}

$sha256.Dispose()

# 5. Ординальная сортировка ([System.StringComparer]::Ordinal)
$fileEntries.Sort([System.Comparison[PSObject]]{ param($x, $y) [System.StringComparer]::Ordinal.Compare($x.path, $y.path) })
$finalFilesList = @($fileEntries)

# 6. Чтение servers.json (необязательное поле)
$serversPath = Join-Path $packDir "servers.json"
$serversList = $null
if (Test-Path $serversPath) {
    try {
        $serversRaw = Get-Content $serversPath -Raw
        $serversData = $serversRaw | ConvertFrom-Json
        if ($serversData) {
            $serversList = @($serversData)
        }
    } catch {
        Write-Warning "Ошибка чтения servers.json: $_"
    }
}

# 7. Проверка идентичности с существующим манифестом
$manifestPath = Join-Path $packDir $manifestFileName
$isIdentical = $false
$existingPackVersion = $null

if (Test-Path $manifestPath) {
    try {
        $oldManifest = (Get-Content $manifestPath -Raw) | ConvertFrom-Json
        if ($oldManifest.files -and $oldManifest.files.Count -eq $finalFilesList.Count) {
            $isIdentical = $true
            for ($k = 0; $k -lt $finalFilesList.Count; $k++) {
                $n = $finalFilesList[$k]
                $o = $oldManifest.files[$k]
                if ($n.path -ne $o.path -or $n.sha256 -ne $o.sha256 -or $n.size -ne $o.size -or $n.mode -ne $o.mode) {
                    $isIdentical = $false
                    break
                }
            }
            if ($isIdentical) {
                # Сравнение servers
                $oldServersJson = if ($oldManifest.PSObject.Properties['servers'] -and $oldManifest.servers) { ($oldManifest.servers | ConvertTo-Json -Compress) } else { "" }
                $newServersJson = if ($serversList) { ($serversList | ConvertTo-Json -Compress) } else { "" }
                if ($oldServersJson -ne $newServersJson) {
                    $isIdentical = $false
                }
            }
            if ($isIdentical) {
                $existingPackVersion = $oldManifest.packVersion
            }
        }
    } catch {
        $isIdentical = $false
    }
}

if ($isIdentical) {
    Write-Host "[$TargetVersion] Нет изменений в $manifestFileName"
    return
}

# 8. Формирование packVersion (UTC yyyyMMdd.HHmm)
$packVersion = (Get-Date).ToUniversalTime().ToString("yyyyMMdd.HHmm")

$manifest = [ordered]@{
    name         = $name
    packVersion  = $packVersion
    minecraft    = $minecraft
    fabricLoader = $fabricLoader
}
if ($serversList -ne $null) {
    $manifest["servers"] = $serversList
}
$manifest["files"] = $finalFilesList

# Сериализация JSON
$json = $manifest | ConvertTo-Json -Depth 10

# LF line endings
$json = $json.Replace("`r`n", "`n").TrimEnd("`n") + "`n"

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($manifestPath, $json, $utf8NoBom)

Write-Host "Manifest сгенерирован: $manifestPath"
Write-Host "packVersion: $packVersion"
Write-Host "Всего файлов в манифесте: $($finalFilesList.Count)"