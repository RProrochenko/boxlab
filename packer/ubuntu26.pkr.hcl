variable "ubuntu26_build_cpus" {
  type    = number
  default = null
}

variable "ubuntu26_build_memory" {
  type    = number
  default = null
}

variable "ubuntu26_box_output_path" {
  type    = string
  default = null
}

variable "ubuntu26_build_output_directory" {
  type    = string
  default = null
}

variable "ubuntu26_headless" {
  type    = bool
  default = true
}

variable "ubuntu26_vm_name" {
  type    = string
  default = null
}

variable "ubuntu26_iso_url" {
  type    = string
  default = null
}

variable "ubuntu26_iso_checksum" {
  type    = string
  default = null
}

locals {
  # Цей файл лежить у packer/, а спільні для Vagrant і Packer ресурси (ssh/, http/, builds/)
  # залишаються в корені проекту — тому всі шляхи до них будуються від project_root.
  ubuntu26_project_root = abspath("${path.root}/..")

  # --- Параметри VM ---
  ubuntu26_hostname             = "ubuntu-dev"
  ubuntu26_ssh_username         = "user"
  ubuntu26_ssh_private_key_path = "ssh/private-key"
  ubuntu26_ssh_authorized_key   = trimspace(file("${local.ubuntu26_project_root}/ssh/private-key.pub"))
  ubuntu26_box_name             = "ubuntu-26.04-rpr-virtualbox"
  ubuntu26_default_vm_name      = "ubuntu-26.04-base"
  ubuntu26_default_build_cpus   = 4
  ubuntu26_default_build_memory = 8192
  ubuntu26_default_output_dir   = "builds/packer-ubuntu"
  ubuntu26_install_docker       = true
  ubuntu26_packages             = ["tree", "unzip", "virtualbox-guest-utils", "zip"]

  # --- Параметри ОС-шаблону ---
  ubuntu26_guest_os_type        = "Ubuntu_64"
  ubuntu26_default_iso_url      = "https://releases.ubuntu.com/26.04.1/ubuntu-26.04.1-live-server-amd64.iso"
  ubuntu26_default_iso_checksum = "sha256:cc8a95cde20f6ced61a322420de00f10cc3c90ced545daa46cb9c1a117f1d927"
  ubuntu26_disk_size            = 30000

  # --- Похідні значення (можна перевизначити через -var або .pkrvars.hcl) ---
  ubuntu26_build_cpus       = coalesce(var.ubuntu26_build_cpus, local.ubuntu26_default_build_cpus)
  ubuntu26_build_memory     = coalesce(var.ubuntu26_build_memory, local.ubuntu26_default_build_memory)
  ubuntu26_box_output_path  = coalesce(var.ubuntu26_box_output_path, "${local.ubuntu26_project_root}/builds/${local.ubuntu26_box_name}.box")
  ubuntu26_output_directory = coalesce(var.ubuntu26_build_output_directory, "${local.ubuntu26_project_root}/${local.ubuntu26_default_output_dir}")
  ubuntu26_vm_name          = coalesce(var.ubuntu26_vm_name, local.ubuntu26_default_vm_name)
  ubuntu26_iso_url          = coalesce(var.ubuntu26_iso_url, local.ubuntu26_default_iso_url)
  ubuntu26_iso_checksum     = coalesce(var.ubuntu26_iso_checksum, local.ubuntu26_default_iso_checksum)

  # --- cloud-init autoinstall: шаблон лишається в http/ubuntu26/user-data.pkrtpl.hcl (у корені проекту) ---
  ubuntu26_http_content = {
    "/meta-data" = ""
    "/user-data" = templatefile("${local.ubuntu26_project_root}/http/ubuntu26/user-data.pkrtpl.hcl", {
      hostname       = local.ubuntu26_hostname
      username       = local.ubuntu26_ssh_username
      authorized_key = local.ubuntu26_ssh_authorized_key
    })
  }
}

source "virtualbox-iso" "ubuntu26" {
  vm_name       = local.ubuntu26_vm_name
  guest_os_type = local.ubuntu26_guest_os_type

  iso_url      = local.ubuntu26_iso_url
  iso_checksum = local.ubuntu26_iso_checksum

  cpus      = local.ubuntu26_build_cpus
  memory    = local.ubuntu26_build_memory
  disk_size = local.ubuntu26_disk_size

  output_directory = local.ubuntu26_output_directory

  headless             = var.ubuntu26_headless
  guest_additions_mode = "disable"

  http_content = local.ubuntu26_http_content

  ssh_username         = local.ubuntu26_ssh_username
  ssh_private_key_file = "${local.ubuntu26_project_root}/${local.ubuntu26_ssh_private_key_path}"
  ssh_timeout          = "30m"

  boot_wait = "5s"

  boot_command = [
    "<esc><wait>",
    "c<wait>",
    "linux /casper/vmlinuz autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<enter><wait>",
    "initrd /casper/initrd<enter><wait>",
    "boot<enter>"
  ]

  shutdown_command = "sudo shutdown -P now"
}

build {
  sources = ["source.virtualbox-iso.ubuntu26"]

  provisioner "shell" {
    inline = concat(
      ["sudo apt-get update"],
      local.ubuntu26_install_docker ? [
        "curl -fsSL https://get.docker.com -o /tmp/get-docker.sh",
        "sudo sh /tmp/get-docker.sh",
        "rm -f /tmp/get-docker.sh",
        "sudo usermod -aG docker ${local.ubuntu26_ssh_username}"
      ] : [],
      length(local.ubuntu26_packages) > 0 ? ["sudo apt-get install -y ${join(" ", local.ubuntu26_packages)}"] : [],
      ["sudo apt-get clean"]
    )
  }

  post-processor "vagrant" {
    output = local.ubuntu26_box_output_path
  }
}
