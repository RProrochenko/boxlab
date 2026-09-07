packer {
  required_version = "= 1.16.0"
  required_plugins {
    virtualbox = { source = "github.com/hashicorp/virtualbox", version = "1.1.5" }
    vagrant    = { source = "github.com/hashicorp/vagrant", version = "1.1.7" }
  }
}

# ═══════════════════════════════════════════════════════════════
#  НАЛАШТУВАННЯ ОС — заповніть цей блок і більше нічого
#
#  Порядок дій:
#    1. cp -r packer/_skeleton packer/<os>
#    2. Перейменуйте _skeleton.pkr.hcl на <os>.pkr.hcl
#    3. Створіть http/<os>/<файл автоінсталяції>
#    4. Заповніть блок нижче
#    5. Скопіюйте config/machines/*.json → config/machines/<os>.json
#       і узгодьте в ньому os / name / hostname / box.name
#    6. packer validate packer/<os>
# ═══════════════════════════════════════════════════════════════

locals {
  # --- Ідентифікація ---
  # os має збігатися з назвою цього каталогу, каталогу http/<os>/ і файлу
  # config/machines/<os>.json — звідти шаблон сам візьме box.name і hostname.
  os       = "TODO"  # напр. "debian13"

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
  # guest_os_type: подивитися список можна командою `VBoxManage list ostypes`
  guest_os_type = "TODO"  # напр. "Debian_64", "Ubuntu_64", "RedHat_64"
  iso_url       = "TODO"
  # Або пряма сума "sha256:...", або "file:https://.../CHECKSUM"
  iso_checksum  = "TODO"

  # --- Ресурси збірки ---
  cpus      = 4
  memory    = 8192
  disk_size = 30000
  headless  = false  # для першої збірки лишіть false — буде видно вікно VirtualBox

  # --- Автоінсталяція (файл лежить у http/<os>/) ---
  # Debian/Ubuntu: "/user-data" + cloud-init autoinstall
  # RHEL/Rocky:    "/rocky.ks"  + kickstart
  autoinstall_path = "TODO"
  autoinstall_file = "TODO"

  # --- Послідовність клавіш у завантажувачі ---
  # Найтонше місце. Візьміть за основу найближчу ОС:
  #
  #   Ubuntu (GRUB, редагування командного рядка через "c"):
  #     "<esc><wait>", "c<wait>",
  #     "linux /casper/vmlinuz autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<enter><wait>",
  #     "initrd /casper/initrd<enter><wait>", "boot<enter>"
  #
  #   Rocky (GRUB, редагування пункту меню через "e" і запуск через F10):
  #     "e", "<down><down><end><wait>",
  #     " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/rocky.ks inst.text", "<f10>"
  boot_command = [
    "TODO"
  ]

  # --- Що доставити в образ ---
  # Debian/Ubuntu:
  #   "sudo apt-get update",
  #   "curl -fsSL https://get.docker.com -o /tmp/get-docker.sh",
  #   "sudo sh /tmp/get-docker.sh",
  #   "rm -f /tmp/get-docker.sh",
  #   "sudo usermod -aG docker ${local.username}",
  #   "sudo apt-get install -y tree unzip zip",
  #   "sudo apt-get clean"
  #
  # RHEL/Rocky:
  #   "sudo dnf -y update",
  #   "sudo dnf -y install dnf-plugins-core",
  #   "sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo",
  #   "sudo dnf -y --best install docker-ce docker-ce-cli containerd.io docker-compose-plugin",
  #   "sudo systemctl enable docker",
  #   "sudo usermod -aG docker ${local.username}",
  #   "sudo dnf -y install tree unzip zip",
  #   "sudo dnf clean all"
  provision = [
    "TODO"
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
