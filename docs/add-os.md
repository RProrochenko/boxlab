[← README](../README.md)

# Додати нову ОС

На прикладі `debian13`.

**1. Каталог машини** — скопіюйте заготовку і перейменуйте два файли:

```powershell
cp -r machines/_skeleton machines/debian13
mv machines/debian13/_skeleton.pkr.hcl machines/debian13/debian13.pkr.hcl
mv machines/debian13/machine.example.json machines/debian13/machine.json
```

**2. Опис машини** — у `machines/debian13/machine.json` замініть `os`, `name`, `hostname` та `box.name`. Робіть це першим: шаблон Packer читає цей файл, і без нього не пройде навіть `packer validate`.

**3. Файл автоінсталяції** — `machines/debian13/http/preseed.pkrtpl.hcl` (або `user-data` / `.ks` залежно від сімейства). Шаблон отримує три параметри: `hostname`, `username`, `authorized_key`. Він обов'язково має налаштувати вхід по SSH-ключу і `NOPASSWD` для sudo — інакше Packer не під'єднається і збірка впаде на таймауті.

**4. Шаблон Packer**

Далі заповніть верхній блок `locals` — усе, що треба міняти, зібрано там, нижче роздільника чіпати нічого не потрібно:

| Поле | Що вписати |
|---|---|
| `os` | має збігатися з назвою каталогу `machines/<os>/` |
| `username` | користувач у гостьовій ОС |
| `guest_os_type` | тип VirtualBox; список: `VBoxManage list ostypes` |
| `iso_url`, `iso_checksum` | пряма сума `sha256:...` або `file:https://.../CHECKSUM` |
| `cpus`, `memory`, `disk_size`, `headless` | ресурси збірки |
| `autoinstall_path`, `autoinstall_file` | шлях, за яким Packer віддає файл автоінсталяції, і його ім'я в `machines/<os>/http/` |
| `boot_command` | послідовність клавіш у завантажувачі |
| `provision` | що доставити в образ |

`box_name` і `hostname` вписувати не треба — вони читаються з сусіднього `machine.json`.

У `_skeleton.pkr.hcl` для `boot_command` і `provision` є закоментовані зразки для двох сімейств: Debian/Ubuntu і RHEL/Rocky.

**5. Зібрати:** `.\build.ps1` → вибрати `debian13`.

**Правило іменування:** значення `os` = назва каталогу `machines/<os>/`. Решта шляхів усередині каталогу фіксовані: `machine.json`, `<os>.pkr.hcl`, `http/`.

**Порада:** для першої збірки нової ОС лишіть `headless = false` — буде видно вікно VirtualBox, і `boot_command` можна діагностувати наочно. Найтонше місце саме воно.

## Далі

- [Збірка box](build.md)
- [Запуск машин](machines.md)
