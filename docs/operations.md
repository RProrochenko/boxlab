[← README](../README.md)

# Типові операції

```powershell
# Стан машин
vagrant status
vagrant status ubuntu26-test1        # для динамічного інстансу ім'я обов'язкове
vagrant global-status --prune        # усі машини на хості

# Життєвий цикл
vagrant up ubuntu26
vagrant up ubuntu26 rocky10          # кілька машин — піднімаються паралельно
vagrant up --no-parallel ubuntu26 rocky10
vagrant halt ubuntu26
vagrant reload ubuntu26              # застосувати зміни конфігурації
vagrant destroy -f ubuntu26

# SSH
vagrant ssh ubuntu26
ssh ubuntu26                         # через ~/.ssh/config.d/
vagrant ssh-config ubuntu26

# Box
vagrant box list
vagrant box remove <box.name>
vagrant box prune
```

**Після зміни `machines/<os>/machine.json`** (hostname, cpus, memory, synced_folder, ssh_config_export) досить `vagrant reload <name>`.

**Після зміни `machines/<os>/<os>.pkr.hcl` або `machines/<os>/http/*`** потрібна повна перезбірка:

```powershell
vagrant destroy -f <name>
.\build.ps1
vagrant up <name>
```

## Далі

- [Запуск машин](machines.md)
- [SSH-конфіг для IDE](ssh.md)
