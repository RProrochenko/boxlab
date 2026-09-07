[← README](../README.md)

# Збірка box

## Через `build.ps1`

```powershell
.\build.ps1
```

Скрипт послідовно:

1. Обходить `machines/*/machine.json` і показує нумерований список машин. Каталог без `machine.json` (напр. `_skeleton`) пропускається.
2. `packer init machines/<os>` — встановлює закріплені плагіни.
3. `packer validate machines/<os>` — перевіряє шаблон.
4. `packer build -force machines/<os>` — збирає образ.
5. Перевіряє, що з'явився `builds/<box.name>.box`.
6. `vagrant box add --name <box.name> <файл> --force` — реєструє box у Vagrant.

Останній крок критичний: Vagrant шукає box за іменем у власному індексі, а не в каталозі `builds/`. Без реєстрації `vagrant up` пішов би шукати box у Vagrant Cloud і впав би.

Якщо `vagrant` не знайдено в `PATH`, скрипт зупиниться з підказкою — box уже зібрано, залишиться зареєструвати його вручну:

```powershell
vagrant box add --name <box.name> .\builds\<box.name>.box --force
```

## Вручну

```powershell
packer init machines/<os>
packer validate machines/<os>
packer build -force machines/<os>
```

Кожен каталог `machines/<os>/` — самостійна конфігурація Packer із власним блоком `required_plugins`. Каталог `machines/` цілком конфігурацією не є, тому `packer build machines` не спрацює.

## Далі

- [Додати нову ОС](add-os.md)
- [Запуск машин](machines.md)
