param([ValidateSet('OpenKey64.exe', 'OpenKey32.exe')] [string] $MainExe)
$ErrorActionPreference = 'Stop'
try {
    Expand-Archive -LiteralPath './_OpenKeyUpdate.zip' -DestinationPath './_OpenKeyUpdate' -Force
    if (!(Test-Path -LiteralPath './_OpenKeyUpdate/Rime/build/pinyin_simp.table.bin')) { throw 'Missing Pinyin dictionary' }
    $sourceExe = Join-Path './_OpenKeyUpdate' $MainExe
    if (!(Test-Path -LiteralPath $sourceExe)) { throw 'Missing application' }
    $copied = $false
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        try {
            Copy-Item -LiteralPath './_OpenKeyUpdate/Rime' -Destination './' -Recurse -Force
            Copy-Item -LiteralPath $sourceExe -Destination (Join-Path './' $MainExe) -Force
            $copied = $true
            break
        } catch { Start-Sleep -Milliseconds 250 }
    }
    if (!$copied) { throw 'Could not replace application files' }
    exit 0
} catch { exit 1 }
