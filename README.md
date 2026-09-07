![Packer](https://img.shields.io/badge/Packer-1.16.0-02A8EF?logo=packer&logoColor=white)
![Vagrant](https://img.shields.io/badge/Vagrant-2-1868F2?logo=vagrant&logoColor=white)
![VirtualBox](https://img.shields.io/badge/VirtualBox-provider-183A61?logo=virtualbox&logoColor=white)
![Rocky Linux](https://img.shields.io/badge/Rocky_Linux-10-10B981?logo=rockylinux&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-26.04-E95420?logo=ubuntu&logoColor=white)
![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)

---

# Локальна лабораторія віртуальних машин: Packer + Vagrant + VirtualBox

Лабораторія для збірки й запуску віртуальних машин на локальному хості: усе відтворюється з коду, тому машину можна вільно ламати, зносити й піднімати заново.

Два етапи:

1. **Packer** з ISO-образу встановлює ОС без участі людини, ставить базові пакети та пакує результат у Vagrant box.
2. **Vagrant** піднімає машини з цього box за описами в `machines/<os>/machine.json` — без правок `Vagrantfile`.

Готові стенди: **Ubuntu 26.04** (`ubuntu26`) і **Rocky Linux 10** (`rocky10`).

---

## Вимоги

- [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- [Vagrant](https://developer.hashicorp.com/vagrant/downloads)
- [Packer](https://developer.hashicorp.com/packer/install)

Виконуваний файл Packer можна покласти в корінь проєкту — `build.ps1` віддає перевагу саме йому, інакше шукає `packer` у `PATH`.

---

## Швидкий старт

```powershell
.\build.ps1                          # зібрати box (інтерактивний вибір ОС)
vagrant up ubuntu26
vagrant ssh ubuntu26
vagrant destroy -f ubuntu26
```

Перша збірка ОС довга: завантаження ISO, автоматична інсталяція, встановлення пакетів, пакування box. Повторний `vagrant up` з уже зареєстрованого box — швидкий.

---

## Документація

| Документ | Про що |
|---|---|
| [Збірка box](docs/build.md) | `build.ps1`, ручний `packer init/validate/build`, реєстрація box |
| [Запуск машин](docs/machines.md) | Динамічні інстанси за суфіксом, паралельний запуск |
| [SSH-конфіг для IDE](docs/ssh.md) | Автоекспорт у `~/.ssh/config.d/` для VS Code та інших клієнтів |
| [Додати нову ОС](docs/add-os.md) | Покроково: JSON, автоінсталяція, шаблон Packer |
| [Типові операції](docs/operations.md) | Шпаргалка команд і що робити після змін конфігурації |

---

## Структура репозиторію

```
.
├── build.ps1                     # Інтерактивна збірка box: init → validate → build → box add
├── Vagrantfile                   # Читає machines/*/machine.json, реєструє машини й ssh-config тригери
│
├── machines/                     # Каталог на кожну ОС — усе про неї лежить разом
│   ├── _skeleton/                # Заготовка для нової ОС
│   └── <os>/
│       ├── machine.json          # Опис VM — головне місце для щоденних правок
│       ├── <os>.pkr.hcl          # Шаблон збірки образу
│       └── http/                 # Файли автоінсталяції (Packer роздає їх по HTTP):
│                                 # cloud-init autoinstall, kickstart, preseed
│
├── ssh/                          # Ключова пара для доступу в гостьові ОС
│   ├── private-key
│   └── private-key.pub
│
├── docs/                         # Документація
│
├── builds/                       # Готові .box і робочі каталоги Packer (не в git)
├── packer_cache/                 # Кеш завантажених ISO (не в git)
└── .vagrant/                     # Стан машин Vagrant (не в git)
```

| Що змінюєте | Де | Чи потрібна перезбірка box |
|---|---|---|
| Ресурси, hostname, автостарт, експорт ssh-config | `machines/<os>/machine.json` | Ні — досить `vagrant reload` |
| Склад ПО, розмір диска, ISO | `machines/<os>/<os>.pkr.hcl` | Так |
| Сценарій першої інсталяції ОС | `machines/<os>/http/*` | Так |

Кожен шаблон `machines/<os>/<os>.pkr.hcl` поділений роздільником навпіл: угорі блок `locals` з усім, що відрізняється між ОС, унизу — механіка, однакова в усіх шаблонах. `box_name` і `hostname` шаблон бере з сусіднього `machine.json`, тож ці значення не дублюються.

---

## Ліцензія

MIT — див. [LICENSE](LICENSE).
