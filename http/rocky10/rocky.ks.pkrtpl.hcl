#version=RHEL10
text
eula --agreed
reboot

url --url="https://download.rockylinux.org/pub/rocky/10/BaseOS/x86_64/os/"
repo --name="AppStream" --baseurl="https://download.rockylinux.org/pub/rocky/10/AppStream/x86_64/os/"

lang en_US.UTF-8
keyboard --vckeymap=us --xlayouts='us'
timezone Europe/Kyiv --utc

# Переконайтеся, що мережа активується при завантаженні системи
network --bootproto=dhcp --noipv6 --device=link --activate --onboot=yes --hostname=${hostname}

rootpw --lock
user --name=${username} --groups=wheel --password='$6$rounds=4096$VAGRANTuser$FQr.uHVzF/9FGEkMLZrOgogAuidujs4RVzjTIIBemT36T8AFsOgvmp3PhuGOC.iITEmDrK504wThkl7KB2kEC0' --iscrypted

# Явно вмикаємо службу SSH
services --enabled="sshd"

bootloader --timeout=1
zerombr
clearpart --all --initlabel
autopart --type=plain

# Вимикаємо firewall для усунення проблем з підключенням Packer
firewall --disabled
selinux --enforcing
skipx
firstboot --disable

%packages
@^minimal-environment
openssh-server
sudo
%end

%addon com_redhat_kdump --disable
%end

%post --log=/root/ks-post.log --erroronfail
# NOPASSWD для sudo
echo "${username} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${username}
chmod 0440 /etc/sudoers.d/${username}

# Додавання SSH ключа
USER_HOME="/home/${username}"
mkdir -p "$${USER_HOME}/.ssh"
echo "${authorized_key}" > "$${USER_HOME}/.ssh/authorized_keys"

chmod 0700 "$${USER_HOME}/.ssh"
chmod 0600 "$${USER_HOME}/.ssh/authorized_keys"
chown -R ${username}:${username} "$${USER_HOME}/.ssh"

# Генерація host-ключів SSH для гарантії запуску sshd
ssh-keygen -A
%end