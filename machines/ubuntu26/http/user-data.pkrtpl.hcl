#cloud-config
autoinstall:
  version: 1

  locale: en_US.UTF-8

  keyboard:
    layout: us

  timezone: Europe/Kyiv

  identity:
    hostname: ${hostname}
    username: ${username}
    password: '$6$rounds=4096$VAGRANTuser$FQr.uHVzF/9FGEkMLZrOkogAuidujs4RVzjTIIBemT36T8AFsOgvmp3PhuGOC.iITEmDrK504wThkl7KB2kEC0'

  ssh:
    install-server: true
    authorized-keys:
      - ${authorized_key}
    allow-pw: false

  storage:
    layout:
      name: direct

  late-commands:
    - curtin in-target --target=/target -- bash -c "printf '%s\\n' '${username} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/${username}"
    - curtin in-target --target=/target -- chmod 440 /etc/sudoers.d/${username}
    - curtin in-target --target=/target -- visudo -cf /etc/sudoers.d/${username}
