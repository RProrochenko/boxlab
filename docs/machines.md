[← README](../README.md)

# Запуск машин

## Динамічні інстанси

Щоб підняти кілька незалежних копій однієї машини, не створюючи нових JSON-файлів, додайте суфікс до імені:

```powershell
vagrant up  ubuntu26-test1
vagrant ssh ubuntu26-test1
# user@test1:~$
```

`Vagrantfile` бачить в аргументах команди токен виду `<name>-<суфікс>` і на льоту реєструє окрему, повністю ізольовану машину на базі профілю `<name>`. Змінні середовища задавати не потрібно.

Суфікс виконує подвійну роль: для Vagrant це частина імені машини (`ubuntu26-test1`), а всередині гостьової ОС — її `hostname` (`test1`). Базовий `hostname` з `config/machines/<os>.json` дістається лише машині без суфікса.

### Кілька машин одночасно

Імена перелічуються через пробіл, ОС можна змішувати:

```powershell
vagrant up ubuntu26 ubuntu26-test1 rocky10-test1
```

Кожен інстанс отримує власну VM, власний диск і власний hostname — вони нічого не поділяють між собою. Далі всі команди приймають той самий список імен:

```powershell
vagrant status  ubuntu26-test1 ubuntu26-test2
vagrant halt    ubuntu26-test1 ubuntu26-test2
vagrant destroy -f ubuntu26-test1 ubuntu26-test2
```

### Що важливо знати

- Суфікс починається з літери або цифри; далі літери, цифри, `-`, `_`. Оскільки він же стає hostname, `_` замінюється на `-` за правилами DNS: `ubuntu26-name_test` дасть hostname `name-test`.
- Hostname має бути унікальним серед усіх машин, тому суфікс не може збігатися з чужим hostname — інакше `Duplicate hostname`.
- Кастомний інстанс ніколи не стає `primary` — цей статус залишається за базовою машиною.
- Інстанс існує лише в тих командах, де його ім'я вказано явно. `vagrant status` без аргументів його не покаже; усі підняті інстанси видно через `vagrant global-status --prune`.
- Працює однаково для `up`, `ssh`, `halt`, `destroy`, `status`.

## Паралельний запуск

`vagrant up ubuntu26 rocky10-test1` піднімає машини одночасно: VirtualBox-провайдер сам паралелізм не оголошує, тому `Vagrantfile` вмикає його на старті.

Вимкнути:

```powershell
vagrant up --no-parallel ubuntu26 rocky10-test1   # на одну команду
$env:VB_PARALLEL = 0                              # на всю сесію
```

`vagrant destroy` лишається послідовним, вмикається явно (активує `--force`):

```powershell
vagrant destroy --parallel ubuntu26-test1 ubuntu26-test2
```

Паралельне створення машин інколи падає на гонці у `VBoxManage` (`E_ACCESSDENIED`): машина лишається створеною, але недовантаженою — повторіть для неї `vagrant up`. Перший `up` набору надійніше робити з `--no-parallel`.

RAM потрібна одночасно на всі машини набору.

## Далі

- [SSH-конфіг для IDE](ssh.md)
- [Типові операції](operations.md)
