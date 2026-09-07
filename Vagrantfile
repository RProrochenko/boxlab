require "json"
require "fileutils"

# --- Паралельний up для VirtualBox ---
# Vagrant умів це завжди: у команди `up` --parallel навіть типово увімкнений.
# Але batch_action відкочується на послідовний режим, якщо провайдер сам не
# оголосив підтримку паралелізму — з вбудованих це робить тільки docker,
# VirtualBox ні. Прапорець лежить в options-хеші, який провайдер зареєстрував
# у плагін-менеджері, тож перевизначаємо його тут, до Vagrant.configure.
#
# Типово увімкнено. Вимкнути:
#   vagrant up --no-parallel ...   на одну команду (штатний прапорець Vagrant)
#   VB_PARALLEL=0                  для всіх команд у сесії
#
# `vagrant destroy` лишається послідовним: у нього власний типовий режим
# без паралелізму, і вмикається він лише явним --parallel.
unless ENV["VB_PARALLEL"].to_s.match?(/\A(0|false|no|off)\z/i)
  Vagrant.plugin("2").manager.providers[:virtualbox][1][:parallel] = true
end

# --- Експорт ssh-config для IDE (VS Code Remote-SSH, JetBrains тощо) ---
# Після up/reload/resume кожна машина записує власний файл
# ~/.ssh/config.d/vagrant-<ім'я-машини>, а після destroy — видаляє його.
# Головний ~/.ssh/config має підхоплювати їх рядком "Include config.d/*".
SSH_CONFIG_HOME   = File.expand_path(File.join("~", ".ssh"))
SSH_CONFIG_DIR    = File.join(SSH_CONFIG_HOME, "config.d")
SSH_CONFIG_PREFIX = "vagrant-".freeze

def ssh_config_entry_path(machine_name)
  File.join(SSH_CONFIG_DIR, "#{SSH_CONFIG_PREFIX}#{machine_name}")
end

# Windows-збірка OpenSSH не розуміє "/dev/null".
def ssh_null_device
  Vagrant::Util::Platform.windows? ? "NUL" : "/dev/null"
end

# У ssh_config шлях завжди через "/", інакше Windows-бекслеші читаються як escape.
def ssh_config_quote(path)
  %("#{path.to_s.gsub(File::ALT_SEPARATOR || File::SEPARATOR, '/')}")
end

def warn_missing_ssh_include(ui)
  main_config = File.join(SSH_CONFIG_HOME, "config")
  return if File.exist?(main_config) && File.read(main_config).match?(/^\s*Include\s+.*config\.d/i)

  ui.warn("ssh-config: додайте рядок \"Include config.d/*\" на початок #{main_config}, " \
          "інакше IDE не побачить згенеровані записи")
end

def write_ssh_config_entry(machine)
  info = machine.ssh_info
  if info.nil?
    machine.ui.warn("ssh-config: дані SSH ще недоступні — запис пропущено")
    return
  end

  keys = Array(info[:private_key_path])
  lines = ["# Згенеровано Vagrant-тригером. Правки будуть перезаписані.",
           "Host #{machine.name}",
           "  HostName #{info[:host]}",
           "  Port #{info[:port]}",
           "  User #{info[:username]}"]
  keys.each { |key| lines << "  IdentityFile #{ssh_config_quote(key)}" }
  lines << "  IdentitiesOnly yes" unless keys.empty?
  lines << "  ForwardAgent #{info[:forward_agent] ? 'yes' : 'no'}"
  # VM перестворюються на тих самих портах, тому known_hosts тільки шкодить.
  lines << "  StrictHostKeyChecking no"
  lines << "  UserKnownHostsFile #{ssh_null_device}"
  lines << "  LogLevel ERROR"

  path = ssh_config_entry_path(machine.name)
  FileUtils.mkdir_p(SSH_CONFIG_DIR)
  File.write(path, lines.join("\n") + "\n")
  machine.ui.info("ssh-config: #{path} → ssh #{machine.name}")
  warn_missing_ssh_include(machine.ui)
rescue SystemCallError => error
  machine.ui.warn("ssh-config: не вдалося записати запис: #{error.message}")
end

def remove_ssh_config_entry(machine)
  path = ssh_config_entry_path(machine.name)
  return unless File.exist?(path)

  File.delete(path)
  machine.ui.info("ssh-config: видалено #{path}")
rescue SystemCallError => error
  machine.ui.warn("ssh-config: не вдалося видалити #{path}: #{error.message}")
end

def read_json(path, label)
  config = JSON.parse(File.read(path))
  abort "#{label}: expected a non-empty JSON mapping" unless config.is_a?(Hash) && !config.empty?
  config
rescue JSON::ParserError, SystemCallError => error
  abort "#{label}: #{error.message}"
end

# --- Динамічне налаштування розгортання: власна назва інстансу ---
# Приклад:
#   vagrant up ubuntu26-name_test
#
# Жодних змінних середовища задавати не треба: Vagrantfile сам шукає серед
# аргументів поточної команди (ARGV) токен виду "<базова-назва>-<суфікс>"
# і на льоту реєструє окрему, повністю ізольовану машину з таким іменем на
# базі профілю "<базова-назва>". Працює однаково для up/ssh/halt/destroy/status.
def custom_suffixes_for(base_name)
  pattern = /\A#{Regexp.escape(base_name)}-([a-zA-Z0-9][a-zA-Z0-9_-]*)\z/
  ARGV.each_with_object([]) do |arg, found|
    match = pattern.match(arg)
    found << match[1] if match && !found.include?(match[1])
  end
end

machine_paths = Dir.glob(File.join(__dir__, "machines", "*", "machine.json")).sort
abort "machines: no VM configuration files found" if machine_paths.empty?

resolved = {}
hostnames = []

machine_paths.each do |path|
  label = "machines/#{File.basename(File.dirname(path))}/machine.json"
  settings = read_json(path, label)
  unknown = settings.keys - %w[os name hostname guest communicator winrm cpus memory autostart primary synced_folder ssh_config_export ssh box]
  abort "#{label}: unknown settings: #{unknown.join(', ')}" unless unknown.empty?

  os_name = settings["os"]
  unless os_name.is_a?(String) && os_name.match?(/\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/)
    abort "#{label}: os must be a valid OS-template name"
  end

  base_name = settings["name"]
  unless base_name.is_a?(String) && base_name.match?(/\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/)
    abort "#{label}: name must contain only letters, digits, hyphens and underscores"
  end
  abort "Duplicate machine name: #{base_name}" if resolved.key?(base_name)

  box = settings["box"]
  abort "#{label}: box must be a non-empty mapping" unless box.is_a?(Hash) && !box.empty?
  unknown = box.keys - %w[name resources]
  abort "#{base_name}: unknown box settings: #{unknown.join(', ')}" unless unknown.empty?
  abort "#{base_name}: box must specify name" unless box["name"].is_a?(String) && !box["name"].strip.empty?

  hostname = settings.fetch("hostname", base_name)
  unless hostname.is_a?(String) && hostname.match?(/\A[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\z/)
    abort "#{base_name}: hostname must be 1-63 letters, digits or internal hyphens"
  end
  abort "Duplicate hostname: #{hostname}" if hostnames.include?(hostname.downcase)
  hostnames << hostname.downcase

  box_resources = box.fetch("resources", {})
  unless box_resources.is_a?(Hash) && (box_resources.keys - %w[cpus memory]).empty?
    abort "#{base_name}: resources may contain only cpus and memory"
  end
  options = { "cpus" => 2, "memory" => 2048, "autostart" => false, "ssh_config_export" => true,
              "primary" => false, "synced_folder" => true }
            .merge(box_resources).merge(settings.slice("cpus", "memory", "autostart", "primary", "synced_folder", "ssh_config_export"))
  %w[cpus memory].each do |key|
    abort "#{base_name}: #{key} must be a positive integer" unless options[key].is_a?(Integer) && options[key].positive?
  end
  %w[autostart primary synced_folder ssh_config_export].each do |key|
    abort "#{base_name}: #{key} must be true or false" unless [true, false].include?(options[key])
  end

  communicator = settings.fetch("communicator", "ssh")
  abort "#{base_name}: communicator must be ssh or winrm" unless %w[ssh winrm].include?(communicator)
  ssh = settings.fetch("ssh", {})
  if communicator == "ssh"
    abort "#{base_name}: ssh must be a non-empty mapping" unless ssh.is_a?(Hash) && !ssh.empty?
    allowed = %w[username private_key_path public_key_path insert_key]
    abort "#{base_name}: unsupported ssh settings" unless (ssh.keys - allowed).empty?
    abort "#{base_name}: ssh.username must be a non-empty string" unless ssh["username"].is_a?(String) && !ssh["username"].strip.empty?
    %w[private_key_path public_key_path].each do |key|
      abort "#{base_name}: ssh.#{key} must be a non-empty string" unless ssh[key].is_a?(String) && !ssh[key].strip.empty?
    end
    if ssh.key?("insert_key") && ![true, false].include?(ssh["insert_key"])
      abort "#{base_name}: ssh.insert_key must be true or false"
    end
  elsif settings.key?("ssh")
    abort "#{base_name}: ssh settings conflict with #{communicator} communicator"
  end
  winrm = settings["winrm"]
  if winrm
    abort "#{base_name}: winrm must be a mapping" unless winrm.is_a?(Hash)
    abort "#{base_name}: winrm settings conflict with #{communicator}" unless communicator == "winrm"
  end
  guest = settings["guest"]
  if guest == "windows" && hostname.length > 15
    abort "#{base_name}: Windows hostname must be at most 15 characters"
  end

  vagrant_profile = { "box" => box["name"], "ssh" => ssh }
  vagrant_profile["guest"] = guest if guest
  vagrant_profile["winrm"] = winrm if winrm
  resolved[base_name] = [vagrant_profile, options, hostname, communicator]

  # --- Кастомні інстанси "<base_name>-<суфікс>", якщо такий токен є серед ARGV ---
  custom_suffixes_for(base_name).each do |suffix|
    custom_name = "#{base_name}-#{suffix}"
    abort "Duplicate machine name: #{custom_name}" if resolved.key?(custom_name)

    # Hostname кастомного інстансу — це сам суфікс (а не базовий hostname + суфікс).
    # "_" у ньому не дозволений за DNS-правилами, тому замінюється на "-".
    custom_hostname = suffix.tr('_', '-')
    unless custom_hostname.match?(/\A[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\z/)
      abort "#{custom_name}: hostname must be 1-63 letters, digits or internal hyphens"
    end
    abort "Duplicate hostname: #{custom_hostname}" if hostnames.include?(custom_hostname.downcase)
    hostnames << custom_hostname.downcase
    if guest == "windows" && custom_hostname.length > 15
      abort "#{custom_name}: Windows hostname must be at most 15 characters"
    end

    # Кастомний інстанс ніколи не претендує на primary — primary лишається за базовою машиною.
    custom_options = options.merge("primary" => false)
    resolved[custom_name] = [vagrant_profile, custom_options, custom_hostname, communicator]
  end
end

abort "Only one machine may be primary" if resolved.values.count { |_, options, _, _| options["primary"] } > 1

Vagrant.configure("2") do |config|
  resolved.each do |name, (profile, options, hostname, communicator)|
    config.vm.define name, primary: options["primary"], autostart: options["autostart"] do |vm|
      vm.vm.box = profile["box"]
      vm.vm.box_version = profile["box_version"] if profile.key?("box_version")
      vm.vm.hostname = hostname
      vm.vm.guest = profile["guest"].to_sym if profile.key?("guest")
      vm.vm.communicator = communicator
      vm.vm.synced_folder ".", "/vagrant", disabled: true unless options["synced_folder"]

      if communicator == "ssh"
        ssh = profile.fetch("ssh", {})
        vm.ssh.username = ssh["username"] if ssh.key?("username")
        vm.ssh.insert_key = ssh["insert_key"] if ssh.key?("insert_key")
        vm.ssh.private_key_path = File.expand_path(ssh["private_key_path"], __dir__) if ssh.key?("private_key_path")
      elsif profile.fetch("winrm", {}).key?("username")
        vm.winrm.username = profile["winrm"]["username"]
      end

      # --- Тригери: тримати ~/.ssh/config.d/vagrant-<name> в актуальному стані ---
      if communicator == "ssh" && options["ssh_config_export"]
        vm.trigger.after [:up, :reload, :resume] do |t|
          t.name = "Update SSH config for VS Code"
          t.ruby { |_env, machine| write_ssh_config_entry(machine) }
        end

        vm.trigger.after :destroy do |t|
          t.name = "Remove SSH config for VS Code"
          # destroy без підтвердження скасовується — тоді машина ще жива, запис лишаємо.
          t.ruby { |_env, machine| remove_ssh_config_entry(machine) if machine.state.id == :not_created }
        end
      end

      vm.vm.provider "virtualbox" do |vb|
        vb.name = name
        vb.memory = options["memory"]
        vb.cpus = options["cpus"]
      end
    end
  end
end
