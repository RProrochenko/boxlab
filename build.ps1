$ErrorActionPreference = 'Stop'
Push-Location -LiteralPath $PSScriptRoot

try {
    $packerDir = Join-Path $PSScriptRoot 'packer'

    $machineFiles = @(Get-ChildItem -LiteralPath 'config/machines' -File -Filter '*.json' | Sort-Object Name)
    if ($machineFiles.Count -eq 0) { throw 'Файли config/machines/*.json не знайдено.' }

    $machines = foreach ($file in $machineFiles) {
        $config = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $config.os -or -not $config.name -or -not $config.box) {
            throw "$($file.Name) має містити os, name і box."
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
    $templatePath = Join-Path $packerDir "$($machineConfig.os).pkr.hcl"
    if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
        throw "Для OS-шаблону $($machineConfig.os) не знайдено $templatePath."
    }
    $box = $machineConfig.box.name
    if (-not $box -or $box -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]*$') {
        throw "Некоректне поле box.name у $($machine.File.Name)."
    }

    $boxFile = ".\builds\$box.box"
    $packerExe = Join-Path $PSScriptRoot 'packer.exe'
    $packer = if (Test-Path $packerExe) { $packerExe } else { 'packer' }
    $source = "*.$($machineConfig.os)"

    & $packer init $packerDir
    if ($LASTEXITCODE -ne 0) { throw 'Packer init failed' }

    & $packer validate "-only=$source" $packerDir
    if ($LASTEXITCODE -ne 0) { throw 'Packer validate failed' }

    & $packer build -force "-only=$source" $packerDir
    if ($LASTEXITCODE -ne 0) { throw 'Packer build failed' }
    if (-not (Test-Path -LiteralPath $boxFile -PathType Leaf)) { throw "Box not found: $boxFile" }

    # Vagrant шукає бокс за іменем у власному індексі, а не в builds/ —
    # без цієї реєстрації `vagrant up` пішов би шукати бокс у Vagrant Cloud.
    $vagrant = Get-Command vagrant -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $vagrant) {
        throw "Бокс зібрано ($boxFile), але vagrant не знайдено в PATH — зареєструйте вручну: vagrant box add --name $box $boxFile --force"
    }

    & $vagrant.Source box add --name $box $boxFile --force
    if ($LASTEXITCODE -ne 0) { throw 'Vagrant box add failed' }

    Write-Host "Бокс $box зареєстровано. Запуск: vagrant up $($machineConfig.name)"
}
finally {
    Pop-Location
}
