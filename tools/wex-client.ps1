# Shared validation for Wex Client release assets (PowerShell 5.1).
function Get-WexClientRelease {
    param([string]$MetadataPath, [string]$ReleaseDir = "")
    $release = Get-Content -LiteralPath $MetadataPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($release.version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?$') {
        throw "Invalid Wex Client release version"
    }
    $artifacts = @($release.artifacts)
    if ($artifacts.Count -ne 2) { throw "Wex Client requires exactly two release artifacts" }
    foreach ($mc in @('1.20.1', '1.21.1')) {
        $items = @($artifacts | Where-Object minecraft -eq $mc)
        if ($items.Count -ne 1) { throw "Missing or duplicate Wex Client artifact for $mc" }
        $a = $items[0]
        $fileName = "wex-client-$($release.version)+mc$mc.jar"
        if ($a.fileName -cne $fileName -or $a.path -cne "mods/$fileName" -or
                $a.mode -cne 'sync' -or $a.sha256 -cnotmatch '^[0-9a-f]{64}$' -or
                $a.size -isnot [ValueType] -or $a.size -le 0 -or $a.size -ne [long]$a.size) {
            throw "Invalid Wex Client release asset for $mc"
        }
        if ($ReleaseDir) {
            $jar = Join-Path $ReleaseDir $fileName
            if ((Get-Item -LiteralPath $jar).Length -ne $a.size -or
                    (Get-FileHash -LiteralPath $jar -Algorithm SHA256).Hash.ToLowerInvariant() -cne $a.sha256) {
                throw "Wex Client local asset hash/size mismatch: $fileName"
            }
        }
    }
    return $release
}

# ConvertTo-Json on Windows PowerShell uses excessive array indentation.
function Format-WexJson {
    param([string]$Json)
    $depth = 0
    $lines = foreach ($line in ($Json -split "`r?`n")) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^[}\]]') { $depth-- }
        (' ' * (2 * $depth)) + ($trimmed -replace '^("[^"]+":)  ', '$1 ')
        if ($trimmed -match '[{\[]$') { $depth++ }
    }
    return ($lines -join "`n").TrimEnd("`n") + "`n"
}
