packer {
  required_version = "= 1.16.0"
  required_plugins {
    virtualbox = { source = "github.com/hashicorp/virtualbox", version = "1.1.5" }
    vagrant    = { source = "github.com/hashicorp/vagrant", version = "1.1.7" }
  }
}

# ═══════════════════════════════════════════════════════════════
#  НАЛАШТУВАННЯ ОС — єдиний блок, який редагують
# ═══════════════════════════════════════════════════════════════

locals {
  # --- Ідентифікація ---
  os       = "rocky10"  # = назва цього каталогу, каталогу http/<os>/ і файлу config/machines/<os>.json

  # Користувач у гостьовій ОС: під цим іменем Packer створює обліковку й кладе
  # SSH-ключ, а Vagrant під ним підключається.
  #
  # Зручна альтернатива "user" — поставити тут ім'я своєї локальної обліковки на
  # хості. Тоді пряме підключення (звичайним ssh або з IDE, не через `vagrant ssh`)
  # працює без явного вказування користувача: ssh-клієнт сам підставляє поточного
  # користувача хоста.
  #
  # Значення має збігатися зі ssh.username у config/machines/<os>.json — інакше
  # Packer покладе ключ одному користувачу, а Vagrant ходитиме під іншим.
  username = "user"

  # --- Образ ---
  guest_os_type = "RedHat_64"            # тип гостьової ОС у VirtualBox
  iso_url       = "https://download.rockylinux.org/pub/rocky/10/isos/x86_64/Rocky-10.2-x86_64-minimal.iso"
  iso_checksum  = "file:https://download.rockylinux.org/pub/rocky/10/isos/x86_64/Rocky-10.2-x86_64-minimal.iso.CHECKSUM"

  # --- Ресурси збірки ---
  cpus      = 4
  memory    = 8192
  disk_size = 30000
  headless  = false                      # false — показувати вікно VirtualBox

  # --- Автоінсталяція (файл лежить у http/<os>/) ---
  autoinstall_path = "/rocky.ks"
  autoinstall_file = "rocky.ks.pkrtpl.hcl"

  # --- Послідовність клавіш у завантажувачі ---
  boot_command = [
    "e",
    "<down><down><end><wait>",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/rocky.ks inst.text",
    "<f10>"
  ]

  # --- Що доставити в образ ---
  provision = [
    "sudo dnf -y update",

    # Docker
    "sudo dnf -y install dnf-plugins-core",
    "sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo",
    "sudo dnf -y --best install docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-ce-rootless-extras docker-buildx-plugin",
    "sudo systemctl enable docker",
    "sudo usermod -aG docker ${local.username}",

    # Базові пакети
    "sudo dnf -y install tree unzip zip",

    "sudo dnf clean all"
  ]

  # --- Похідне, не чіпати ---
  # box_name і hostname беруться з config/machines/<os>.json —
  # щоб образ і Vagrant гарантовано мали однакові значення.
  root           = abspath("${path.root}/../..")
  cfg            = jsondecode(file("${local.root}/config/machines/${local.os}.json"))
  box_name       = local.cfg.box.name
  hostname       = try(local.cfg.hostname, local.cfg.name)
  authorized_key = trimspace(file("${local.root}/ssh/private-key.pub"))
}

# ═══════════════════════════════════════════════════════════════
#  Нижче нічого міняти не треба — блок ідентичний для всіх ОС
# ═══════════════════════════════════════════════════════════════

source "virtualbox-iso" "vm" {
  vm_name       = local.box_name
  guest_os_type = local.guest_os_type
  iso_url       = local.iso_url
  iso_checksum  = local.iso_checksum

  cpus      = local.cpus
  memory    = local.memory
  disk_size = local.disk_size
  headless  = local.headless

  output_directory     = "${local.root}/builds/packer-${local.os}"
  guest_additions_mode = "disable"

  http_content = {
    "/meta-data" = ""
    (local.autoinstall_path) = templatefile("${local.root}/http/${local.os}/${local.autoinstall_file}", {
      hostname       = local.hostname
      username       = local.username
      authorized_key = local.authorized_key
    })
  }

  ssh_username         = local.username
  ssh_private_key_file = "${local.root}/ssh/private-key"
  ssh_timeout          = "30m"

  boot_wait        = "5s"
  boot_command     = local.boot_command
  shutdown_command = "sudo shutdown -P now"
}

build {
  sources = ["source.virtualbox-iso.vm"]

  provisioner "shell" {
    inline = local.provision
  }

  post-processor "vagrant" {
    output = "${local.root}/builds/${local.box_name}.box"
  }
}
