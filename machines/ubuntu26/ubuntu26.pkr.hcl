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
  os       = "ubuntu26"  # = назва цього каталогу; machine.json і http/ лежать поруч

  # Користувач у гостьовій ОС: під цим іменем Packer створює обліковку й кладе
  # SSH-ключ, а Vagrant під ним підключається.
  #
  # Зручна альтернатива "user" — поставити тут ім'я своєї локальної обліковки на
  # хості. Тоді пряме підключення (звичайним ssh або з IDE, не через `vagrant ssh`)
  # працює без явного вказування користувача: ssh-клієнт сам підставляє поточного
  # користувача хоста.
  #
  # Значення має збігатися зі ssh.username у machine.json поруч — інакше
  # Packer покладе ключ одному користувачу, а Vagrant ходитиме під іншим.
  username = "user"

  # --- Образ ---
  guest_os_type = "Ubuntu_64"               # тип гостьової ОС у VirtualBox
  iso_url       = "https://releases.ubuntu.com/26.04.1/ubuntu-26.04.1-live-server-amd64.iso"
  iso_checksum  = "sha256:cc8a95cde20f6ced61a322420de00f10cc3c90ced545daa46cb9c1a117f1d927"

  # --- Ресурси збірки ---
  cpus      = 4
  memory    = 8192
  disk_size = 30000
  headless  = true                          # false — показувати вікно VirtualBox

  # --- Автоінсталяція (файл лежить у http/ поруч) ---
  autoinstall_path = "/user-data"
  autoinstall_file = "user-data.pkrtpl.hcl"

  # --- Послідовність клавіш у завантажувачі ---
  boot_command = [
    "<esc><wait>",
    "c<wait>",
    "linux /casper/vmlinuz autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>"
  ]

  # --- Що доставити в образ ---
  provision = [
    "sudo apt-get update",

    # Docker
    "curl -fsSL https://get.docker.com -o /tmp/get-docker.sh",
    "sudo sh /tmp/get-docker.sh",
    "rm -f /tmp/get-docker.sh",
    "sudo usermod -aG docker ${local.username}",

    # Базові пакети
    "sudo apt-get install -y tree unzip virtualbox-guest-utils zip",

    "sudo apt-get clean"
  ]

  # --- Похідне, не чіпати ---
  # box_name і hostname беруться з machine.json поруч —
  # щоб образ і Vagrant гарантовано мали однакові значення.
  dir            = abspath(path.root)
  root           = abspath("${path.root}/../..")
  cfg            = jsondecode(file("${local.dir}/machine.json"))
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
    (local.autoinstall_path) = templatefile("${local.dir}/http/${local.autoinstall_file}", {
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
