# Локальна лабораторія віртуальних машин: Packer + Vagrant + VirtualBox

Лабораторія для збірки й запуску віртуальних машин на власному Windows-хості: усе відтворюється з коду, тому машину можна вільно ламати, зносити й піднімати заново.

Робота лабораторії складається з двох етапів:

1. **Packer** з ISO-образу встановлює ОС без участі людини, ставить Docker і базові пакети та пакує результат у Vagrant box.
2. **Vagrant** піднімає машини з цього box за описами в `config/machines/*.json` — без правок `Vagrantfile`.

Готові стенди: **Ubuntu 26.04** (`ubuntu26`) і **Rocky Linux 10** (`rocky10`).

---

## Зміст

- [Вимоги](#вимоги)
- [Швидкий старт](#швидкий-старт)
- [Збірка box](#збірка-box)
- [Динамічні інстанси](#динамічні-інстанси)
- [Додати нову ОС](#додати-нову-ос)
- [Типові операції](#типові-операції)
- [Структура репозиторію](#структура-репозиторію)
- [Ліцензія](#ліцензія)

---

## Вимоги

- **VirtualBox**
- **Vagrant**
- **Packer**

`packer.exe` можна покласти в корінь проекту — `build.ps1` віддає перевагу саме йому, а якщо файлу немає, шукає `packer` у `PATH`.

---

## Швидкий старт

```powershell
# 1. Зібрати box (інтерактивний вибір ОС зі списку)
.\build.ps1

# 2. Підняти машину
vagrant up ubuntu26

# 3. Зайти по SSH
vagrant ssh ubuntu26

# 4. Прибрати за собою
vagrant destroy -f ubuntu26
```

Перша збірка однієї ОС триває приблизно 20–40 хвилин: завантаження ISO, автоматична інсталяція, встановлення пакетів, пакування box. Повторний `vagrant up` з уже зареєстрованого box — близько хвилини.

---

## Збірка box

### Через `build.ps1` (рекомендовано)

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
vagrant box add --name ubuntu-26.04-rpr-virtualbox .\builds\ubuntu-26.04-rpr-virtualbox.box --force
```

### Вручну

```powershell
packer init packer/ubuntu26
packer validate packer/ubuntu26
packer build -force packer/ubuntu26
```

Кожен каталог `packer/<os>/` — самостійна конфігурація Packer із власним блоком `required_plugins`. Каталог `packer/` цілком конфігурацією не є, тому `packer build packer` не спрацює.

---

## Динамічні інстанси

Щоб підняти кілька незалежних копій однієї машини, не створюючи нових JSON-файлів, додайте суфікс до імені:

```powershell
vagrant up  ubuntu26-test1
vagrant ssh ubuntu26-test1
```

`Vagrantfile` бачить в аргументах команди токен виду `<name>-<суфікс>` і на льоту реєструє окрему, повністю ізольовану машину на базі профілю `<name>`. Змінні середовища задавати не потрібно.

### Кілька машин одночасно

Імена перелічуються через пробіл — усі вони піднімуться однією командою:

```powershell
vagrant up ubuntu26-test1 ubuntu26-test2 ubuntu26-test3
```

Так само можна змішувати різні ОС і базові машини в одній команді:

```powershell
vagrant up ubuntu26 ubuntu26-test1 rocky10-test1
```

Кожен інстанс отримує власну VM у VirtualBox, власний диск і власний hostname — вони нічого не поділяють між собою.

Далі всі команди приймають той самий список імен:

```powershell
vagrant status  ubuntu26-test1 ubuntu26-test2
vagrant halt    ubuntu26-test1 ubuntu26-test2
vagrant destroy -f ubuntu26-test1 ubuntu26-test2 ubuntu26-test3
```

### Що важливо знати

- Суфікс починається з літери або цифри; далі можна літери, цифри, `-`, `_`.
- `hostname` інстансу — **це сам суфікс**, а не `<базовий hostname>-<суфікс>`. Символ `_` у ньому замінюється на `-` за правилами DNS.
- Кастомний інстанс ніколи не стає `primary` — цей статус залишається за базовою машиною.
- Інстанс існує лише в тих командах, де його ім'я вказано явно. `vagrant status` без аргументів його не покаже — вказуйте ім'я: `vagrant status ubuntu26-test1`.
- Щоб побачити всі підняті інстанси незалежно від імен, скористайтеся `vagrant global-status --prune`.
- Працює однаково для `up`, `ssh`, `halt`, `destroy`, `status`.

---

## Додати нову ОС

На прикладі `debian13`.

**1. Опис машини** — скопіюйте найближчий `config/machines/*.json` у `config/machines/debian13.json` і замініть `os`, `name`, `hostname` та `box.name`. Робіть це першим: шаблон Packer читає цей файл, і без нього не пройде навіть `packer validate`.

**2. Файл автоінсталяції** — `http/debian13/preseed.pkrtpl.hcl` (або `user-data` / `.ks` залежно від сімейства). Шаблон отримує три параметри: `hostname`, `username`, `authorized_key`. Він обов'язково має налаштувати вхід по SSH-ключу і `NOPASSWD` для sudo — інакше Packer не під'єднається і збірка впаде на таймауті.

**3. Шаблон Packer:**

```powershell
cp -r packer/_skeleton packer/debian13
mv packer/debian13/_skeleton.pkr.hcl packer/debian13/debian13.pkr.hcl
```

Далі заповніть верхній блок `locals` — усе, що треба міняти, зібрано там, нижче роздільника чіпати нічого не потрібно:

| Поле | Що вписати |
|---|---|
| `os` | `debian13` — має збігатися з назвою каталогу, `http/<os>/` і `config/machines/<os>.json` |
| `username` | користувач у гостьовій ОС |
| `guest_os_type` | тип VirtualBox, напр. `Debian_64`. Список: `VBoxManage list ostypes` |
| `iso_url`, `iso_checksum` | пряма сума `sha256:...` або `file:https://.../CHECKSUM` |
| `cpus`, `memory`, `disk_size`, `headless` | ресурси збірки |
| `autoinstall_path`, `autoinstall_file` | шлях, за яким Packer віддає файл автоінсталяції, і його ім'я в `http/<os>/` |
| `boot_command` | послідовність клавіш у завантажувачі |
| `provision` | що доставити в образ |

`box_name` і `hostname` вписувати не треба — вони читаються з `config/machines/<os>.json`.

У `_skeleton.pkr.hcl` для `boot_command` і `provision` є закоментовані готові зразки для двох сімейств: Debian/Ubuntu і RHEL/Rocky.

**4. Зібрати:** `.\build.ps1` → вибрати `debian13`.

**Правило іменування:** значення `os` = назва каталогу `packer/<os>/` = назва каталогу `http/<os>/` = ім'я файлу `config/machines/<os>.json`.

**Порада:** для першої збірки нової ОС лишіть `headless = false` — буде видно вікно VirtualBox, і `boot_command` можна діагностувати наочно. Найтонше місце саме воно.

---

## Типові операції

```powershell
# Стан машин
vagrant status
vagrant status ubuntu26-test1        # для динамічного інстансу ім'я обов'язкове
vagrant global-status --prune        # усі машини на хості

# Життєвий цикл
vagrant up ubuntu26
vagrant halt ubuntu26                # коректне вимкнення
vagrant reload ubuntu26              # перезапуск із застосуванням змін конфігурації
vagrant destroy -f ubuntu26          # повне видалення VM

# SSH
vagrant ssh ubuntu26
vagrant ssh-config ubuntu26          # параметри для сторонніх SSH-клієнтів та IDE

# Box
vagrant box list
vagrant box remove ubuntu-26.04-rpr-virtualbox
vagrant box prune                    # прибрати старі версії
```

**Після зміни `config/machines/*.json`** (hostname, cpus, memory, synced_folder):

```powershell
vagrant reload ubuntu26
```

**Після зміни `packer/<os>/*` або `http/<os>/*`** потрібна повна перезбірка:

```powershell
vagrant destroy -f ubuntu26
.\build.ps1                          # вибрати ubuntu26
vagrant up ubuntu26
```

---

## Структура репозиторію

```
.
├── build.ps1                     # Інтерактивна збірка box: init → validate → build → box add
├── Vagrantfile                   # Читає config/machines/*.json і реєструє машини
│
├── config/machines/              # Описи VM — головне місце для щоденних правок
│   ├── ubuntu26.json
│   └── rocky10.json
│
├── packer/                       # Шаблони збірки образів — каталог на кожну ОС
│   ├── _skeleton/                # Заготовка для нової ОС
│   ├── ubuntu26/ubuntu26.pkr.hcl
│   └── rocky10/rocky10.pkr.hcl
│
├── http/                         # Файли автоінсталяції (Packer роздає їх по HTTP)
│   ├── ubuntu26/user-data.pkrtpl.hcl    # cloud-init autoinstall
│   └── rocky10/rocky.ks.pkrtpl.hcl      # kickstart
│
├── ssh/                          # Ключова пара для доступу в гостьові ОС
│   ├── private-key
│   └── private-key.pub
│
├── builds/                       # Готові .box і робочі каталоги Packer (не в git)
├── packer_cache/                 # Кеш завантажених ISO (не в git)
└── .vagrant/                     # Стан машин Vagrant (не в git)
```

Логіка поділу проста:

| Що змінюєте | Де | Чи потрібна перезбірка box |
|---|---|---|
| Ресурси, hostname, автостарт | `config/machines/*.json` | Ні — досить `vagrant reload` |
| Склад ПО, розмір диска, ISO | `packer/<os>/<os>.pkr.hcl` | Так |
| Сценарій першої інсталяції ОС | `http/<os>/*` | Так |

Кожен шаблон `packer/<os>/<os>.pkr.hcl` поділений роздільником навпіл: угорі блок `locals` з усім, що відрізняється між ОС, унизу — механіка, однакова в усіх шаблонах. `box_name` і `hostname` шаблон бере з `config/machines/<os>.json`, тож ці значення не дублюються.

---

## Ліцензія

MIT — див. [LICENSE](LICENSE).
