[← README](../README.md)

# Збірка box

## Через `build.ps1`

```powershell
.\build.ps1
```

Скрипт послідовно:

1. Читає всі `config/machines/*.json` і показує нумерований список машин.
2. За полем `os` знаходить каталог `packer/<os>/`.
3. `packer init packer/<os>` — встановлює закріплені плагіни.
4. `packer validate packer/<os>` — перевіряє шаблон.
5. `packer build -force packer/<os>` — збирає образ.
6. Перевіряє, що з'явився `builds/<box.name>.box`.
7. `vagrant box add --name <box.name> <файл> --force` — реєструє box у Vagrant.

Останній крок критичний: Vagrant шукає box за іменем у власному індексі, а не в каталозі `builds/`. Без реєстрації `vagrant up` пішов би шукати box у Vagrant Cloud і впав би.

Якщо `vagrant` не знайдено в `PATH`, скрипт зупиниться з підказкою — box уже зібрано, залишиться зареєструвати його вручну:

```powershell
vagrant box add --name <box.name> .\builds\<box.name>.box --force
```

## Вручну

```powershell
packer init packer/<os>
packer validate packer/<os>
packer build -force packer/<os>
```

Кожен каталог `packer/<os>/` — самостійна конфігурація Packer із власним блоком `required_plugins`. Каталог `packer/` цілком конфігурацією не є, тому `packer build packer` не спрацює.

## Далі

- [Додати нову ОС](add-os.md)
- [Запуск машин](machines.md)
