$ErrorActionPreference = 'Stop'
Push-Location -LiteralPath $PSScriptRoot

try {
    # Каталог машини самодостатній: machine.json і шаблон Packer лежать поруч.
    # Каталог без machine.json машиною не є (напр. _skeleton) — пропускаємо.
    $machines = @(foreach ($dir in Get-ChildItem -LiteralPath 'machines' -Directory | Sort-Object Name) {
        $jsonPath = Join-Path $dir.FullName 'machine.json'
        if (-not (Test-Path -LiteralPath $jsonPath -PathType Leaf)) { continue }
        $config = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $config.os -or -not $config.name -or -not $config.box) {
            throw "$($dir.Name)/machine.json має містити os, name і box."
        }
        [pscustomobject]@{ Dir = $dir; Config = $config }
    })
    if ($machines.Count -eq 0) { throw 'Файли machines/*/machine.json не знайдено.' }

    for ($i = 0; $i -lt $machines.Count; $i++) {
        $machine = $machines[$i]
        Write-Host "$($i + 1). $($machine.Config.name) [$($machine.Config.os)] — machines/$($machine.Dir.Name)"
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

    $templateDir = $machine.Dir.FullName

    $box = $machineConfig.box.name
    if (-not $box -or $box -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]*$') {
        throw "Некоректне поле box.name у machines/$($machine.Dir.Name)/machine.json."
    }

    $boxFile = ".\builds\$box.box"
    $packerExe = Join-Path $PSScriptRoot 'packer.exe'
    $packer = if (Test-Path $packerExe) { $packerExe } else { 'packer' }

    & $packer init $templateDir
    if ($LASTEXITCODE -ne 0) { throw 'Packer init failed' }

    & $packer validate $templateDir
    if ($LASTEXITCODE -ne 0) { throw 'Packer validate failed' }

    & $packer build -force $templateDir
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
