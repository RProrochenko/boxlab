require "json"

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

machine_paths = Dir.glob(File.join(__dir__, "config", "machines", "*.json")).sort
abort "config/machines: no VM configuration files found" if machine_paths.empty?

resolved = {}
hostnames = []

machine_paths.each do |path|
  label = "config/machines/#{File.basename(path)}"
  settings = read_json(path, label)
  unknown = settings.keys - %w[os name hostname guest communicator winrm cpus memory autostart primary synced_folder ssh box]
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
  options = { "cpus" => 2, "memory" => 2048, "autostart" => false,
              "primary" => false, "synced_folder" => true }
            .merge(box_resources).merge(settings.slice("cpus", "memory", "autostart", "primary", "synced_folder"))
  %w[cpus memory].each do |key|
    abort "#{base_name}: #{key} must be a positive integer" unless options[key].is_a?(Integer) && options[key].positive?
  end
  %w[autostart primary synced_folder].each do |key|
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

      vm.vm.provider "virtualbox" do |vb|
        vb.name = name
        vb.memory = options["memory"]
        vb.cpus = options["cpus"]
      end
    end
  end
end
