$ErrorActionPreference = 'Stop'
Push-Location -LiteralPath $PSScriptRoot

try {
    $machineFiles = @(Get-ChildItem -LiteralPath 'config/machines' -File -Filter '*.json' | Sort-Object Name)
    if ($machineFiles.Count -eq 0) { throw 'Файли config/machines/*.json не знайдено.' }

    $machines = foreach ($file in $machineFiles) {
        $config = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $config.os -or -not $config.name -or -not $config.box -or -not $config.build) {
            throw "$($file.Name) має містити os, name, box і build."
        }
        [pscustomobject]@{ File = $file; Config = $config }
    }

    for ($i = 0; $i -lt $machines.Count; $i++) {
        $machine = $machines[$i]
        Write-Host "$($i + 1). $($machine.Config.name) [$($machine.Config.os)] — $($machine.File.Name)"
    }
    Write-Host '0. Вийти'
    do {
        $answer = Read-Host 'Оберіть VM для побудови box'
        if ([string]::IsNullOrWhiteSpace($answer)) { return }
        $choice = 0
        $valid = [int]::TryParse($answer, [ref]$choice) -and $choice -ge 0 -and $choice -le $machines.Count
        if (-not $valid) { Write-Host 'Введіть номер зі списку.' }
    } until ($valid)
    if ($choice -eq 0) { return }

    $machine = $machines[$choice - 1]
    $machineConfig = $machine.Config
    $templatePath = "$($machineConfig.os).pkr.hcl"
    if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
        throw "Для OS-шаблону $($machineConfig.os) не знайдено $templatePath."
    }
    $box = $machineConfig.box.name
    if (-not $box -or $box -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]*$') {
        throw "Некоректне поле box.name у $($machine.File.Name)."
    }

    $boxFile = ".\builds\$box.box"
    $packer = if (Test-Path .\packer.exe) { Join-Path $PSScriptRoot 'packer.exe' } else { 'packer' }
    $source = "*.$($machineConfig.os)"

    & $packer init $PSScriptRoot
    if ($LASTEXITCODE -ne 0) { throw 'Packer init failed' }

    & $packer validate "-only=$source" $PSScriptRoot
    if ($LASTEXITCODE -ne 0) { throw 'Packer validate failed' }

    & $packer build -force "-only=$source" $PSScriptRoot
    if ($LASTEXITCODE -ne 0) { throw 'Packer build failed' }
    if (-not (Test-Path -LiteralPath $boxFile -PathType Leaf)) { throw "Box not found: $boxFile" }

}
finally {
    Pop-Location
}
