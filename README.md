# vagrant

![Packer](https://img.shields.io/badge/Packer-1.16.0-02A8EF?logo=packer&logoColor=white)
![Vagrant](https://img.shields.io/badge/Vagrant-2-1868F2?logo=vagrant&logoColor=white)
![VirtualBox](https://img.shields.io/badge/VirtualBox-provider-183A61?logo=virtualbox&logoColor=white)
![Rocky Linux](https://img.shields.io/badge/Rocky_Linux-10-10B981?logo=rockylinux&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-26.04-E95420?logo=ubuntu&logoColor=white)
![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)

Збірка базових Vagrant/VirtualBox боксів через Packer (Rocky Linux 10, Ubuntu 26.04) та їх подальший запуск як dev-машин через Vagrant.

Два незалежні етапи:

1. **Packer** — збирає ISO в готовий `.box`-файл (`packer/` + `http/`).
2. **Vagrant** — піднімає VM з уже готового боксу (`Vagrantfile` + `config/`).

Пов'язані вони лише іменами (назва боксу, ssh-ключ, hostname), не спільним кодом.

## Зміст

- [Вимоги](#вимоги)
- [1. Клонування репозиторію](#1-клонування-репозиторію)
- [2. SSH-ключ](#2-ssh-ключ)
- [3. Збірка боксу (Packer)](#3-збірка-боксу-packer)
- [4. Запуск VM (Vagrant)](#4-запуск-vm-vagrant)
  - [Кастомна назва інстансу](#кастомна-назва-інстансу)
- [Структура проекту](#структура-проекту)
- [Створення нового образу з нуля](#створення-нового-образу-з-нуля)
- [Відомі обмеження та рекомендації](#відомі-обмеження-та-рекомендації)

## Вимоги

- [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- [Vagrant](https://developer.hashicorp.com/vagrant/downloads)
- [Packer](https://developer.hashicorp.com/packer/install)
  

## 1. Клонування репозиторію

```bash
git clone https://github.com/RProrochenko/vagrant.git
cd vagrant
```

Нічого встановлювати чи ініціалізувати додатково не треба — весь потрібний код і шаблони вже в репозиторії.

## 2. SSH-ключ

У `ssh/private-key` (+ `.pub`) лежить спільний ключ, яким Packer вписує `authorized_keys` в образ під час зборки, а Vagrant потім заходить по SSH у вже готову VM. Він уже є в репозиторії — окремо нічого генерувати не треба, якщо влаштовує ключ за замовчуванням.

Щоб замінити його на власний:

```bash
ssh-keygen -t ed25519 -f ssh/private-key -N ""
```

Це перезапише і `ssh/private-key`, і `ssh/private-key.pub` — новий публічний ключ підхопиться Packer-шаблонами автоматично (він читається з файлу, а не хардкодиться в `.hcl`). Якщо бокс уже зібраний зі старим ключем — перезбирати не обов'язково, доки Vagrant використовує саме `ssh/private-key`, що відповідає ключу, вписаному в конкретний бокс.

## 3. Збірка боксу (Packer)

Цей крок перетворює ISO-образ ОС на готовий `.box`-файл. Потрібен лише перед першим запуском конкретної ОС або коли хочеться пересобрати бокс (наприклад, після зміни списку пакетів у `packer/<os>.pkr.hcl`).

Інтерактивно:

```powershell
.\build.ps1
```

Скрипт покаже список машин із `config/machines/*.json`, дасть обрати одну і сам виконає `packer init/validate/build -only=*.<os>` над текою `packer/`. Зборка триває довго (unattended-install ОС з нуля через kickstart/cloud-init) — очікуйте 10–20+ хвилин залежно від диска й мережі.

Вручну (той самий процес крок за кроком):

```powershell
packer init packer
packer validate -only="*.rocky10" packer
packer build -only="*.rocky10" packer
```

Готовий `.box` з'явиться в `builds/` (назва береться з поля `box.name` відповідного `config/machines/<name>.json`).

## 4. Запуск VM (Vagrant)

Коли бокс зібрано (лежить у `builds/`), піднімаємо VM по назві з `config/machines/*.json` (поле `name`, не назва ОС-шаблону):

```bash
vagrant up rocky10
vagrant up ubuntu26
```

Інші корисні команди:

```bash
vagrant ssh rocky10       # зайти в машину по SSH
vagrant halt rocky10      # вимкнути
vagrant destroy rocky10   # видалити VM (бокс у builds/ лишається)
vagrant status            # стан усіх машин
```

### Кастомна назва інстансу

Vagrant не приймає довільний другий аргумент після назви машини — `vagrant up ubuntu26 name_test` означає підняти ДВІ окремі машини "ubuntu26" і "name_test", а не "ubuntu26 з іменем name_test".

Замість цього `Vagrantfile` сам шукає серед аргументів поточної команди (`ARGV`) токен виду `<базова-назва>-<суфікс>` і на льоту реєструє окрему, повністю ізольовану машину з таким іменем на базі профілю `<базова-назва>`. Змінних середовища задавати не треба — достатньо вказати ім'я прямо в команді:

```bash
vagrant up ubuntu26-name_test
```

Працює однаково для `up`/`ssh`/`halt`/`destroy`/`status`. Кастомний інстанс ніколи не стає `primary` — цей статус лишається за базовою машиною.

## Структура проекту

```
vagrant/
├── Vagrantfile              # запуск VM: читає config/machines
├── build.ps1                # інтерактивна збірка боксу через Packer
├── packer.exe                # Packer 1.16.0 (Windows), опційно, git-ignored
├── packer/                   # усі Packer-файли в одному місці
│   ├── plugins.pkr.hcl       #   версії Packer core + плагінів
│   ├── rocky10.pkr.hcl       #   повний build Rocky 10 (vars, source, provision)
│   └── ubuntu26.pkr.hcl      #   повний build Ubuntu 26.04
├── http/                      # kickstart / cloud-init для unattended-install
│   ├── rocky10/rocky.ks.pkrtpl.hcl
│   └── ubuntu26/user-data.pkrtpl.hcl
├── config/
│   └── machines/               # усе, що читає Vagrantfile — один файл на машину
│       ├── rocky10.json        #   guest, communicator, hostname, ресурси, ssh, box...
│       └── ubuntu26.json
├── ssh/private-key(.pub)      # спільний ssh-ключ для Packer і Vagrant
├── builds/                    # готові .box-файли (git-ignored)
└── packer_cache/              # кеш ISO (git-ignored)
```

`config/machines/<name>.json` описує все, що потрібно `Vagrantfile` для одного інстансу: і незмінні для ОС параметри (`guest`, `communicator`), і параметри конкретного розгортання (hostname, ресурси, ssh, назва боксу, `primary`, `synced_folder`...). Поле `os` вказує на однойменний Packer-шаблон у `packer/<os>.pkr.hcl`, за яким `build.ps1` збирає бокс — це єдиний зв'язок між двома етапами.

## Створення нового образу з нуля

Повний шлях для нової ОС, якої ще немає в проєкті:

1. **Kickstart / cloud-init шаблон.** Додати `http/<os>/*.pkrtpl.hcl` — файл автоматичного встановлення ОС (аналогічно `http/rocky10/rocky.ks.pkrtpl.hcl` для kickstart або `http/ubuntu26/user-data.pkrtpl.hcl` для cloud-init). Мінімум: hostname, користувач (`${username}`) з sudo без пароля, встановлення `${authorized_key}` в `authorized_keys`, увімкнений sshd.
2. **Packer-шаблон.** Додати `packer/<os>.pkr.hcl` за зразком наявних: джерело `virtualbox-iso`, `iso_url`/`iso_checksum` (з можливістю перевизначити через `-var`), `http_content` з підстановкою kickstart/cloud-init шаблону, `ssh_private_key_file` на `ssh/private-key`, `provisioner "shell"` для встановлення пакетів, `post-processor "vagrant"` з виводом у `builds/<box-name>.box`.
3. **Зборка боксу.** `packer init packer && packer validate -only="*.<os>" packer && packer build -only="*.<os>" packer` (або через `.\build.ps1`, коли з'явиться відповідний `config/machines/<name>.json`).
4. **Машина для Vagrant.** Додати `config/machines/<name>.json` з полями `os` (= назва Packer-шаблону з кроку 2), `name`, `hostname`, `guest`, `communicator`, `box.name` (той самий, що в `post-processor "vagrant"` кроку 2) + опційно `winrm`/`cpus`/`memory`/`autostart`/`primary`/`synced_folder`/`ssh`/`box.resources`.
5. **Запуск.** `Vagrantfile` підхопить новий файл автоматично — правок коду не потрібно. `vagrant up <name>`.

## Відомі обмеження та рекомендації

- **Приватний SSH-ключ у git.** `ssh/private-key` закомічений у репозиторій — це спільний ключ для Packer (вписується в образ) і Vagrant (яким піднімається VM). Прийнятно для ізольованих локальних dev-боксів, але перед тим як робити репозиторій публічним або використовувати ключ десь ще — варто його ротувати (див. [крок 2](#2-ssh-ключ)) і надалі тримати поза git (лишити в репо тільки `.pub`).
- **`ssh.public_key_path` нічого не робить.** Поле валідується (`config/machines/*.json`), але `Vagrantfile` ніде не застосовує його значення — публічний ключ реально потрібен лише Packer'у при зборці образу, а не Vagrant'у при запуску вже готового бокса.
- **Фіксований пароль користувача.** Kickstart і cloud-init шаблони використовують той самий захардкоджений хеш пароля для `user` — вхід передбачений лише по SSH-ключу (`allow-pw: false` / `rootpw --lock`), пароль потрібен тільки як fallback для консолі VirtualBox.
- **`primary` / `synced_folder` наразі вимкнені в обох машинах** (`config/machines/*.json`) — жодна VM не є Vagrant'івською "primary" за замовчуванням, і синхронізація поточної теки в `/vagrant` вимкнена для обох. Якщо потрібна робоча тека всередині VM або команди без явної назви машини (`vagrant up` без аргументів) — увімкніть відповідні поля в потрібному `config/machines/<name>.json`.
