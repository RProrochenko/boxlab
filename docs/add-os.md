[← README](../README.md)

# Додати нову ОС

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
| `os` | має збігатися з назвою каталогу, `http/<os>/` і `config/machines/<os>.json` |
| `username` | користувач у гостьовій ОС |
| `guest_os_type` | тип VirtualBox; список: `VBoxManage list ostypes` |
| `iso_url`, `iso_checksum` | пряма сума `sha256:...` або `file:https://.../CHECKSUM` |
| `cpus`, `memory`, `disk_size`, `headless` | ресурси збірки |
| `autoinstall_path`, `autoinstall_file` | шлях, за яким Packer віддає файл автоінсталяції, і його ім'я в `http/<os>/` |
| `boot_command` | послідовність клавіш у завантажувачі |
| `provision` | що доставити в образ |

`box_name` і `hostname` вписувати не треба — вони читаються з `config/machines/<os>.json`.

У `_skeleton.pkr.hcl` для `boot_command` і `provision` є закоментовані зразки для двох сімейств: Debian/Ubuntu і RHEL/Rocky.

**4. Зібрати:** `.\build.ps1` → вибрати `debian13`.

**Правило іменування:** значення `os` = назва каталогу `packer/<os>/` = назва каталогу `http/<os>/` = ім'я файлу `config/machines/<os>.json`.

**Порада:** для першої збірки нової ОС лишіть `headless = false` — буде видно вікно VirtualBox, і `boot_command` можна діагностувати наочно. Найтонше місце саме воно.

## Далі

- [Збірка box](build.md)
- [Запуск машин](machines.md)
