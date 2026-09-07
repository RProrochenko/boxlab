variable "rocky10_build_cpus" {
  type    = number
  default = null
}

variable "rocky10_build_memory" {
  type    = number
  default = null
}

variable "rocky10_box_output_path" {
  type    = string
  default = null
}

variable "rocky10_build_output_directory" {
  type    = string
  default = null
}

variable "rocky10_headless" {
  type    = bool
  default = false
}

variable "rocky10_vm_name" {
  type    = string
  default = null
}

variable "rocky10_iso_url" {
  type    = string
  default = null
}

variable "rocky10_iso_checksum" {
  type    = string
  default = null
}

locals {
  # Цей файл лежить у packer/, а спільні для Vagrant і Packer ресурси (ssh/, http/, builds/)
  # залишаються в корені проекту — тому всі шляхи до них будуються від project_root.
  rocky10_project_root = abspath("${path.root}/..")

  # --- Параметри VM ---
  rocky10_hostname             = "rocky-dev"
  rocky10_ssh_username         = "user"
  rocky10_ssh_private_key_path = "ssh/private-key"
  rocky10_ssh_authorized_key   = trimspace(file("${local.rocky10_project_root}/ssh/private-key.pub"))
  rocky10_box_name             = "rocky-10-rpr-virtualbox"
  rocky10_default_vm_name      = "rocky-10-base"
  rocky10_default_build_cpus   = 4
  rocky10_default_build_memory = 8192
  rocky10_default_output_dir   = "builds/packer-rocky"
  rocky10_install_docker       = true
  rocky10_packages             = ["tree", "unzip", "zip"]

  # --- Параметри ОС-шаблону ---
  rocky10_guest_os_type        = "RedHat_64"
  rocky10_default_iso_url      = "https://download.rockylinux.org/pub/rocky/10/isos/x86_64/Rocky-10.2-x86_64-minimal.iso"
  rocky10_default_iso_checksum = "file:https://download.rockylinux.org/pub/rocky/10/isos/x86_64/Rocky-10.2-x86_64-minimal.iso.CHECKSUM"
  rocky10_disk_size            = 30000

  # --- Похідні значення (можна перевизначити через -var або .pkrvars.hcl) ---
  rocky10_build_cpus       = coalesce(var.rocky10_build_cpus, local.rocky10_default_build_cpus)
  rocky10_build_memory     = coalesce(var.rocky10_build_memory, local.rocky10_default_build_memory)
  rocky10_box_output_path  = coalesce(var.rocky10_box_output_path, "${local.rocky10_project_root}/builds/${local.rocky10_box_name}.box")
  rocky10_output_directory = coalesce(var.rocky10_build_output_directory, "${local.rocky10_project_root}/${local.rocky10_default_output_dir}")
  rocky10_vm_name          = coalesce(var.rocky10_vm_name, local.rocky10_default_vm_name)
  rocky10_iso_url          = coalesce(var.rocky10_iso_url, local.rocky10_default_iso_url)
  rocky10_iso_checksum     = coalesce(var.rocky10_iso_checksum, local.rocky10_default_iso_checksum)

  # --- Kickstart: шаблон лишається в http/rocky10/rocky.ks.pkrtpl.hcl (у корені проекту) ---
  rocky10_http_content = {
    "/rocky.ks" = templatefile("${local.rocky10_project_root}/http/rocky10/rocky.ks.pkrtpl.hcl", {
      hostname       = local.rocky10_hostname
      username       = local.rocky10_ssh_username
      authorized_key = local.rocky10_ssh_authorized_key
    })
  }
}

source "virtualbox-iso" "rocky10" {
  vm_name       = local.rocky10_vm_name
  guest_os_type = local.rocky10_guest_os_type

  iso_url      = local.rocky10_iso_url
  iso_checksum = local.rocky10_iso_checksum

  cpus      = local.rocky10_build_cpus
  memory    = local.rocky10_build_memory
  disk_size = local.rocky10_disk_size

  output_directory = local.rocky10_output_directory
  headless         = var.rocky10_headless

  guest_additions_mode = "disable"
  http_content         = local.rocky10_http_content

  ssh_username         = local.rocky10_ssh_username
  ssh_private_key_file = "${local.rocky10_project_root}/${local.rocky10_ssh_private_key_path}"
  ssh_timeout          = "30m"

  boot_wait = "5s"

  boot_command = [
    "e",
    "<down><down><end><wait>",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/rocky.ks inst.text",
    "<f10>"
  ]
  shutdown_command = "sudo shutdown -P now"
}

build {
  sources = ["source.virtualbox-iso.rocky10"]

  provisioner "shell" {
      inline = concat(
        ["sudo dnf -y update"],
        local.rocky10_install_docker ? [
          "sudo dnf -y install dnf-plugins-core",
          "sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo",
          "sudo dnf -y --best install docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-ce-rootless-extras docker-buildx-plugin",
          "sudo systemctl enable docker",
          "sudo usermod -aG docker ${local.rocky10_ssh_username}"
        ] : [],
        length(local.rocky10_packages) > 0 ? ["sudo dnf -y install ${join(" ", local.rocky10_packages)}"] : [],
        ["sudo dnf clean all"]
      )
    }

  post-processor "vagrant" {
    output = local.rocky10_box_output_path
  }
}
