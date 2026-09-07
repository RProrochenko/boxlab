[← README](../README.md)

# SSH-конфіг для IDE

Кожна SSH-машина після `up`, `reload` і `resume` записує свій запис у `~/.ssh/config.d/vagrant-<ім'я-машини>`, а після `destroy` видаляє його. Порт, ключ і користувача Vagrant бере з живої машини, тому запис не старіє після перестворення VM на іншому порту.

Один раз додайте на початок `~/.ssh/config`:

```
Include config.d/*
```

Далі ім'я машини — звичайний SSH-хост, який бачать VS Code (**Remote Explorer → SSH**), JetBrains Gateway, `scp`, `rsync`:

```powershell
ssh ubuntu26-test1
code --remote ssh-remote+ubuntu26-test1 /home/<username>
```

Звертайтеся повним іменем машини, а не суфіксом: суфікс — це hostname всередині гостя, тому в промпті буде `user@test1`, а SSH-хост зветься `ubuntu26-test1`.

## Згенерований запис

```
Host ubuntu26-test1
  HostName 127.0.0.1
  Port 2222
  User <username>
  IdentityFile "<шлях-до-проєкту>/ssh/private-key"
  IdentitiesOnly yes
  ForwardAgent no
  StrictHostKeyChecking no
  UserKnownHostsFile NUL
  LogLevel ERROR
```

`StrictHostKeyChecking no` навмисно: VM перестворюються на тих самих локальних портах, і без цього кожен `destroy` + `up` ламав би `known_hosts`.

## Вимкнути

Для окремої машини — у `machines/<os>/machine.json`:

```json
"ssh_config_export": false
```

Типово `true`. Для `communicator: "winrm"` тригери не реєструються.

## Далі

- [Запуск машин](machines.md)
- [Типові операції](operations.md)
