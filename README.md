# vagrant

![Packer](https://img.shields.io/badge/Packer-1.16.0-02A8EF?logo=packer&logoColor=white)
![Vagrant](https://img.shields.io/badge/Vagrant-2-1868F2?logo=vagrant&logoColor=white)
![VirtualBox](https://img.shields.io/badge/VirtualBox-provider-183A61?logo=virtualbox&logoColor=white)
![Rocky Linux](https://img.shields.io/badge/Rocky_Linux-10-10B981?logo=rockylinux&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-26.04-E95420?logo=ubuntu&logoColor=white)
![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)


## Вимоги

- [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- [Vagrant](https://developer.hashicorp.com/vagrant/downloads) 2.x, перевірено на 2.4.9
- [Packer](https://developer.hashicorp.com/packer/install) рівно 1.16.0 — версія зафіксована в `packer/plugins.pkr.hcl`


## Швидкий старт

```bash
git clone https://github.com/RProrochenko/vagrant.git
cd vagrant
```

```powershell
.\build.ps1
vagrant up ubuntu26
vagrant ssh ubuntu26
```

`build.ps1` збирає бокс і сам реєструє його у Vagrant, тому між збіркою і запуском ручних кроків немає.

## Етап 1: збірка боксу (Packer)

Потрібен перед першим запуском ОС і після зміни `packer/<os>.pkr.hcl` або `http/<os>/*`. Повне встановлення ОС з нуля займає 10-20+ хвилин.

### Через build.ps1

Скрипт читає всі `config/machines/*.json`, показує меню `назва [os] — файл.json`, і після вибору:

1. перевіряє, що конфіг має `os`, `name`, `box`;
2. перевіряє наявність `packer/<os>.pkr.hcl`;
3. перевіряє `box.name` на допустимі символи;
4. вибирає бінарник: локальний `packer.exe` або `packer` з `PATH`;
5. виконує `packer init`, `packer validate -only=*.<os>`, `packer build -force -only=*.<os>`;
6. перевіряє, що `builds/<box.name>.box` з'явився;
7. реєструє бокс: `vagrant box add --name <box.name> <файл> --force`.

`0` або порожній ввід — вихід. Помилка на будь-якому кроці зупиняє скрипт із текстом причини. `-force` в обох командах означає, що і файл боксу, і його запис в індексі Vagrant перезаписуються без запитань. Якщо `vagrant` не знайдено в `PATH`, скрипт повідомить готову команду для ручної реєстрації — зібраний бокс при цьому не втрачається.

### Вручну

```powershell
packer init packer
packer validate -only="*.rocky10" packer
packer build -only="*.rocky10" packer
vagrant box add --name rocky-10-rpr-virtualbox .\builds\rocky-10-rpr-virtualbox.box --force
```

### Змінні Packer

Оголошені з префіксом назви ОС, за замовчуванням `null`, підставляються через `coalesce`. Передаються через `-var` або `.pkrvars.hcl`.

| Змінна | Призначення | За замовчуванням |
| --- | --- | --- |
| `<os>_build_cpus` | CPU на час збірки | 4 |
| `<os>_build_memory` | RAM у МБ на час збірки | 8192 |
| `<os>_vm_name` | назва тимчасової ВМ у VirtualBox | `rocky-10-base`, `ubuntu-26.04-base` |
| `<os>_iso_url` | джерело ISO | офіційне дзеркало ОС |
| `<os>_iso_checksum` | контрольна сума ISO | файл `CHECKSUM` для Rocky, `sha256:` для Ubuntu |
| `<os>_build_output_directory` | тека проміжних файлів VirtualBox | `builds/packer-rocky`, `builds/packer-ubuntu` |
| `<os>_box_output_path` | шлях готового боксу | `builds/<box_name>.box` |
| `<os>_headless` | збірка без вікна | `false` для Rocky, `true` для Ubuntu |

```powershell
packer build -only="*.ubuntu26" -var "ubuntu26_build_memory=4096" -var "ubuntu26_headless=false" packer
```

Решта параметрів — у `locals` того ж файлу: hostname, ім'я користувача, назва боксу, диск на 30 ГБ, `guest_os_type`, прапорець Docker, список пакетів.

### Вміст образу

Автовстановлення описане в `http/<os>/`: kickstart для Rocky, cloud-init autoinstall для Ubuntu. Packer роздає ці файли по HTTP, підставляючи hostname, ім'я користувача і публічний ключ. Ключ читається з `ssh/private-key.pub` функцією `file()`, тому в шаблонах не дублюється.

Спільне для обох ОС:

- локаль `en_US.UTF-8`, розкладка `us`, часовий пояс `Europe/Kyiv`
- користувач `user` із sudo без пароля через `/etc/sudoers.d/user`, права `0440`
- вхід лише по SSH-ключу: root заблокований у Rocky, парольна аутентифікація вимкнена в Ubuntu. Хеш пароля в шаблоні — запасний вхід через консоль VirtualBox
- увімкнений sshd, автоматичне розбиття диска, Guest Additions вимкнені на рівні Packer

Rocky 10: текстовий інсталятор, мінімальне середовище, firewall вимкнений для підключення Packer, SELinux enforcing, kdump і firstboot вимкнені, host-ключі через `ssh-keygen -A`.

Ubuntu 26.04: пряме розбиття диска, sudoers-файл створюється в `late-commands` через `curtin` і перевіряється `visudo -c`.

Shell-provisioner після встановлення:

| ОС | Оновлення | Docker | Пакети |
| --- | --- | --- | --- |
| Rocky 10 | `dnf -y update` | репозиторій `docker-ce` з compose-, buildx- і rootless-плагінами, служба в автозапуску | `tree`, `unzip`, `zip` |
| Ubuntu 26.04 | `apt-get update` | скрипт `get.docker.com` | `tree`, `unzip`, `virtualbox-guest-utils`, `zip` |

Користувача додано в групу `docker`, кеш пакетного менеджера очищено. Прапорець `<os>_install_docker` вимикає встановлення Docker. Post-processor пакує результат у `builds/<box_name>.box`.

## Етап 2: запуск машини (Vagrant)

### Реєстрація боксу

`Vagrantfile` посилається на бокс лише за іменем, без URL, тому Vagrant шукає його у власному індексі, а не в `builds/`. Реєстрацію робить `build.ps1` останнім кроком, і при перезбірці запис перезаписується разом із файлом. Ім'я в індексі завжди дорівнює `box.name` із профілю машини.

Перевірити, що бокс на місці:

```powershell
vagrant box list
```

### Команди

Машина адресується полем `name` зі свого профілю, а не назвою ОС-шаблону:

```bash
vagrant up rocky10        # створити й запустити
vagrant ssh rocky10       # зайти по SSH
vagrant halt rocky10      # вимкнути
vagrant destroy rocky10   # видалити ВМ, бокс лишається
vagrant status            # стан усіх машин
```

У VirtualBox ВМ отримує ім'я, що дорівнює назві машини Vagrant.

### Кілька машин з одного профілю

Один профіль обслуговує скільки завгодно машин. Vagrant не приймає довільний другий аргумент — `vagrant up ubuntu26 name_test` означає «підняти дві машини», — тому `Vagrantfile` сам сканує аргументи команди і на кожен токен виду `<базова-назва>-<суфікс>` оголошує на льоту окрему ізольовану машину на базі профілю `<базова-назва>`:

```bash
vagrant up ubuntu26-DB
vagrant up ubuntu26-DB ubuntu26-app rocky10-ci
```

- суфікс починається з літери або цифри, далі літери, цифри, дефіс, підкреслення
- hostname кастомної машини — це сам суфікс, підкреслення замінюється на дефіс: `ubuntu26-name_test` дає hostname `name-test`
- кастомна машина успадковує бокс, ресурси та SSH-налаштування базового профілю, але ніколи не стає `primary`
- працює однаково для `up`, `ssh`, `halt`, `destroy`, `status`

## Профіль машини

`Vagrantfile` читає всі файли з `config/machines/` за алфавітом. Невідоме поле, невірний тип, дублікат назви чи hostname — аварійне завершення з описом проблеми.

| Поле | Обов'язкове | Опис і правила |
| --- | --- | --- |
| `os` | так | назва ОС-шаблону, тобто файлу `packer/<os>.pkr.hcl` |
| `name` | так | назва машини для команд Vagrant, унікальна; літери, цифри, дефіс, підкреслення |
| `box.name` | так | ім'я боксу в індексі Vagrant |
| `box.resources.cpus`, `box.resources.memory` | ні | ресурси, зашиті в профіль боксу |
| `hostname` | ні | 1-63 символи: літери, цифри, внутрішні дефіси; унікальний; типово дорівнює `name` |
| `guest` | ні | тип гостя: `linux`, `ubuntu`, `windows` |
| `communicator` | ні | `ssh` (типово) або `winrm` |
| `ssh.username` | для ssh | користувач для підключення |
| `ssh.private_key_path` | для ssh | шлях до приватного ключа відносно кореня проекту |
| `ssh.public_key_path` | для ssh | валідується, але не використовується |
| `ssh.insert_key` | ні | `false` — не підміняти ключ на власний згенерований |
| `winrm` | лише для winrm | мапа налаштувань, застосовується тільки `username` |
| `cpus` | ні | ядра для запуску ВМ, типово 2 |
| `memory` | ні | RAM у МБ для запуску ВМ, типово 2048 |
| `autostart` | ні | піднімати при `vagrant up` без аргументів, типово `false` |
| `primary` | ні | машина за замовчуванням для команд без імені, типово `false`, така може бути лише одна |
| `synced_folder` | ні | монтувати корінь проекту в `/vagrant`, типово `true` |

Ресурси збираються в три шари, кожен перекриває попередній: значення за замовчуванням, `box.resources`, поля `cpus` і `memory` верхнього рівня.

Решта перевірок: `cpus` і `memory` — цілі додатні; `autostart`, `primary`, `synced_folder` — тільки `true`/`false`; блок `ssh` і комунікатор `winrm` взаємовиключні; для гостя `windows` hostname обмежений 15 символами.

| Профіль | ОС-шаблон | hostname | CPU / RAM | Бокс |
| --- | --- | --- | --- | --- |
| `config/machines/rocky10.json` | `rocky10` | `rocky-dev` | 2 / 4096 | `rocky-10-rpr-virtualbox` |
| `config/machines/ubuntu26.json` | `ubuntu26` | `ubuntu-dev` | 4 / 8192 | `ubuntu-26.04-rpr-virtualbox` |

## SSH-ключ

`ssh/private-key` і `.pub` — спільна пара: Packer вписує публічну частину в образ, Vagrant заходить приватною в готову ВМ. Ключ уже в репозиторії.

```bash
ssh-keygen -t ed25519 -f ssh/private-key -N ""
```

Packer підхопить новий публічний ключ автоматично. Вже зібрані бокси про заміну не знають — для входу в них потрібен ключ, який був на момент збірки.

## Структура проекту

```
vagrant/
├── Vagrantfile               # запуск ВМ: читає профілі, валідує, оголошує машини
├── build.ps1                 # збірка боксу через Packer і реєстрація у Vagrant
├── packer.exe                # опційний локальний Packer 1.16.0 (git-ignored)
├── packer/
│   ├── plugins.pkr.hcl       #   пін версій Packer core і плагінів
│   ├── rocky10.pkr.hcl       #   повний build Rocky 10
│   └── ubuntu26.pkr.hcl      #   повний build Ubuntu 26.04
├── http/                     # шаблони автовстановлення, роздаються Packer по HTTP
│   ├── rocky10/rocky.ks.pkrtpl.hcl
│   └── ubuntu26/user-data.pkrtpl.hcl
├── config/machines/          # опис машин для Vagrant, один файл на машину
│   ├── rocky10.json
│   └── ubuntu26.json
├── ssh/private-key(.pub)     # спільний ключ для Packer і Vagrant
├── builds/                   # готові бокси і проміжні файли VirtualBox (git-ignored)
└── packer_cache/             # кеш ISO (git-ignored)
```

`.gitattributes` фіксує переводи рядків: LF для `Vagrantfile`, JSON, HCL, YAML і публічного ключа, CRLF для PowerShell, бінарний режим для приватного ключа. Kickstart і cloud-init читає Linux-інсталятор, `build.ps1` — Windows-оболонка.

## Додати нову ОС

1. `http/<os>/*.pkrtpl.hcl` — шаблон автовстановлення. Мінімум: hostname, користувач із sudo без пароля, публічний ключ у `authorized_keys`, увімкнений sshd.
2. `packer/<os>.pkr.hcl` — змінні з префіксом назви ОС, `locals` із коренем проекту, джерело `virtualbox-iso` з `boot_command` під інсталятор цієї ОС, `http_content` через `templatefile`, приватний ключ із `ssh/`, shell-provisioner, post-processor у `builds/<box>.box`.
3. `config/machines/<name>.json` — поле `os` із кроку 2 і `box.name`, що збігається з post-processor.
4. `.\build.ps1` — нова машина сама з'явиться в меню, бокс зареєструється, далі `vagrant up <name>`.

## Відомі обмеження

- **Ручна збірка Packer'ом не реєструє бокс.** `build.ps1` це робить, а прямий `packer build` — ні, тому після нього потрібен `vagrant box add`. Інакше `vagrant up` шукатиме бокс у Vagrant Cloud і впаде.
- **Приватний ключ у git.** Прийнятно для ізольованих локальних машин. Перед публікацією репозиторію ключ варто ротувати і надалі тримати поза git, лишивши тільки публічну частину.
- **`ssh.public_key_path` нічого не робить.** Поле валідується, але `Vagrantfile` його не застосовує: публічний ключ потрібен лише Packer'у.
- **Версія боксу не фіксується.** Профіль не приймає такого поля, тому Vagrant бере єдину зареєстровану версію.
- **WinRM реалізований частково.** Валідація й вибір комунікатора є, застосовується тільки ім'я користувача, Windows-шаблону в проекті немає.
- **hostname задається у двох місцях.** Образ отримує його з Packer-шаблону, запущена ВМ — зі свого профілю, і друге перекриває перше на кожному завантаженні.
- **`primary` і `synced_folder` вимкнені в обох профілях.** `vagrant up` без аргументів не підніме нічого, тека `/vagrant` не змонтована.

## Ліцензія

[MIT](LICENSE)
