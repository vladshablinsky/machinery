# Copyright (c) 2013-2015 SUSE LLC
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 3 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact SUSE LLC.
#
# To contact SUSE about this file by physical or electronic mail,
# you may find current contact information at www.suse.com

# SystemDescriptionFactory provides factory methods to easily create test
# system descriptions in a temporary environment
module SystemDescriptionFactory
  def self.included(klass)
    klass.extend(self)
  end

  def initialize_system_description_factory_store
    include GivenFilesystemSpecHelpers
    use_given_filesystem
  end

  def system_description_factory_store
    if !(self.class < GivenFilesystemSpecHelpers)
      raise RuntimeError.new("Call 'initialize_system_description_factory_store'" \
        " before trying to access the factory store.")
    end

    @store ||= SystemDescriptionStore.new(given_directory)
  end

  # Generates a system description in the temporary description store from raw
  # JSON. It does not try to parse the JSON into a SystemDescription object, so
  # this can be used to store descriptions with an old format version, for
  # example.
  def store_raw_description(name, json)
    Dir.mkdir(File.join(system_description_factory_store.base_path, name))
    File.write(File.join(system_description_factory_store.base_path, name, "manifest.json"), json)
  end

  # Creates a SystemDescription object. The description and how it is stored can
  # be configured via the options hash.
  #
  # Available options:
  # +name+: The name of the system description. Default: 'description'.
  # +store+: The SystemDescriptionStore where the description should be stored.
  #   Default: The temporary factory description store.
  # +store_on_disk+: If true, the description will be stored in the temporary
  #   description store. If false, the description is only created in-memory.
  # +json+: If this option is given, the system description will be generated
  #   from it. Otherwise an empty description is created.
  # +scopes+: The list of scopes to include in the generated system description
  # +extracted_scopes+: The list of extractable scopes that should be extracted.
  # +modified+: Modified date of the system description scopes.
  # +hostname+: Hostname of the inspected host.
  # +add_scope_meta+: Add meta data for each scope if true.
  def create_test_description(options = {})
    options = {
        name: "description",
        store_on_disk: false,
        scopes: [],
        extracted_scopes: [],
        modified: DateTime.now,
        hostname: "example.com",
        add_scope_meta: true
    }.merge(options)

    name  = options[:name] || "description"

    if options[:store_on_disk] && !options[:store]
      store = system_description_factory_store
    else
      store = options[:store] || SystemDescriptionMemoryStore.new
    end

    if options[:json]
      manifest = Manifest.new(name, options[:json])
      manifest.validate!
      description = SystemDescription.from_hash(name, store, manifest.to_hash)
    else
      description = build_description(name, store, options)
    end

    description.save if options[:store_on_disk]

    description
  end

  def create_test_description_json(options = {})
    options = {
      scopes: [],
      extracted_scopes: [],
      modified: DateTime.now,
      hostname: "example.com",
      add_scope_meta: true
    }.merge(options)

    json_objects = []
    meta = {
      format_version: 3
    }

    (options[:scopes] + options[:extracted_scopes]).uniq.each do |scope|
      json_objects << EXAMPLE_SCOPES[scope]
      if options[:add_scope_meta]
        meta[scope] = {
          modified: options[:modified],
          hostname: options[:hostname]
        }
      end
    end

    json_objects << "\"meta\": #{JSON.pretty_generate(meta)}"
    "{\n" + json_objects.join(",\n") + "\n}"
  end

  private

  def build_description(name, store, options)
    json = create_test_description_json(options)
    manifest = Manifest.new(name, json)
    manifest.validate!
    description = SystemDescription.from_hash(name, store, manifest.to_hash)

    options[:extracted_scopes].each do |extracted_scope|
      description[extracted_scope].extracted = true
      if options[:store_on_disk]
        file_store = description.scope_file_store(extracted_scope)
        file_store.create
        if extracted_scope == "unmanaged_files"
          FileUtils.touch(File.join(file_store.path, "files.tgz"))
          FileUtils.mkdir_p(File.join(file_store.path, "etc"))
          FileUtils.touch(
            File.join(file_store.path, "etc", "tarball with spaces.tgz")
          )
        else
          description[extracted_scope].files.each do |file|
            file_name = File.join(file_store.path, file.name)
            FileUtils.mkdir_p(File.dirname(file_name))
            File.write(file_name, "Stub data for #{file.name}.")
          end
        end
      end
    end

    description
  end

  EXAMPLE_SCOPES = {}

  EXAMPLE_SCOPES["changed_managed_files"] = <<-EOF.chomp
    "changed_managed_files": {
      "extracted": false,
      "files": [
        {
          "name": "/etc/cron.daily/md adm",
          "package_name": "mdadm",
          "package_version": "3.3",
          "status": "changed",
          "changes": [
            "deleted"
          ],
          "user": "root",
          "group": "root",
          "mode": "644"
        }
      ]
    }
  EOF
  EXAMPLE_SCOPES["config_files"] = <<-EOF.chomp
    "config_files": {
      "extracted": false,
      "files": [
        {
          "name": "/etc/cron tab",
          "package_name": "cron",
          "package_version": "4.1",
          "status": "changed",
          "changes": ["md5"],
          "user": "root",
          "group": "root",
          "mode": "644"
        }
      ]
    }
  EOF
  EXAMPLE_SCOPES["groups"] = <<-EOF.chomp
    "groups": [
      {
        "name": "audio",
        "password": "x",
        "users": [
          "tux",
          "foo"
        ],
        "gid": 17
      }
    ]
  EOF
  EXAMPLE_SCOPES["os"] = <<-EOF.chomp
    "os": {
      "name": "openSUSE 13.1 (Bottle)",
      "version": "13.1 (Bottle)",
      "architecture": "x86_64"
    }
  EOF
  EXAMPLE_SCOPES["packages"] = <<-EOF.chomp
    "packages": [
      {
        "name": "bash",
        "version": "4.2",
        "release": "68.1.5",
        "arch": "x86_64",
        "vendor": "openSUSE",
        "checksum": "533e40ba8a5551204b528c047e45c169"
      }
    ]
  EOF
  EXAMPLE_SCOPES["patterns"] = <<-EOF.chomp
    "patterns": [
      {
        "name": "base",
        "version": "13.1",
        "release": "13.6.1"
      }
    ]
  EOF
  EXAMPLE_SCOPES["repositories"] = <<-EOF.chomp
    "repositories": [
      {
        "alias": "openSUSE_13.1_OSS",
        "name": "openSUSE_13.1_OSS",
        "type": "yast2",
        "url": "http://download.opensuse.org/distribution/13.1/repo/oss/",
        "enabled": true,
        "autorefresh": true,
        "gpgcheck": true,
        "priority": 99,
        "package_manager": "zypper"
      },
      {
        "alias": "openSUSE_13.1_NON_OSS_ALIAS",
        "name": "openSUSE_13.1_NON_OSS",
        "type": "yast2",
        "url": "http://download.opensuse.org/distribution/13.1/repo/non-oss/",
        "enabled": false,
        "autorefresh": false,
        "gpgcheck": true,
        "priority": 99,
        "package_manager": "zypper"
      },
      {
        "alias": "SLES12-12-0",
        "name": "SLES12-12-0",
        "type": "yast2",
        "url": "cd:///?devices=/dev/disk/by-id/ata-QEMU_DVD-ROM_QM00001",
        "enabled": true,
        "autorefresh": false,
        "gpgcheck": true,
        "priority": 99,
        "package_manager": "zypper"
      }
    ]
  EOF
  EXAMPLE_SCOPES["users"] = <<-EOF.chomp
    "users": [
      {
        "name": "bin",
        "password": "x",
        "uid": 1,
        "gid": 1,
        "comment": "bin",
        "home": "/bin",
        "shell": "/bin/bash",
        "encrypted_password": "*",
        "last_changed_date": 16125
      }
    ]
  EOF

  EXAMPLE_SCOPES["users_with_passwords"] = <<-EOF.chomp
    "users": [
      {
        "name": "root",
        "password": "x",
        "uid": 0,
        "gid": 0,
        "comment": "root",
        "home": "/root",
        "shell": "/bin/bash",
        "encrypted_password": "$6$E4YLEez0s3MP$YkWtqN9J8uxEsYgv4WKDLRKxM2aNCSJajXlffV4XGlALrHzfHg1XRVxMht9XBQURDMY8J7dNVEpMaogqXIkL0.",
        "last_changed_date": 16357
      },
      {
        "name": "vagrant",
        "password": "x",
        "uid": 1000,
        "gid": 100,
        "comment": "",
        "home": "/home/vagrant",
        "shell": "/bin/bash",
        "encrypted_password": "$6$6V/YKqrsHpkC$nSAsvrbcVE8kTI9D3Z7ubc1L/dBHXj47BlL5usy0JNINzXFDl3YXqF5QYjZLTo99BopLC5bdHYUvkUSBRC3a3/",
        "last_changed_date": 16373,
        "min_days": 0,
        "max_days": 99999,
        "warn_days": 7,
        "disable_days": 30,
        "disabled_date": 1234
      }
    ]
  EOF
  EXAMPLE_SCOPES["services"] = <<-EOF.chomp
    "services": {
      "init_system": "systemd",
      "services": [
        {
          "name": "sshd.service",
          "state": "enabled"
        },
        {
          "name": "rsyncd.service",
          "state": "disabled"
        },
        {
          "name": "lvm2-lvmetad.socket",
          "state": "disabled"
        },
        {
          "name": "console-shell.service",
          "state": "static"
        },
        {
          "name": "crypto.service",
          "state": "masked"
        }
      ]
    }
  EOF
  EXAMPLE_SCOPES["services_sysvinit"] = <<-EOF.chomp
    "services": {
      "init_system": "sysvinit",
      "services": [
        {
          "name": "sshd",
          "state": "on"
        },
        {
          "name": "rsyncd",
          "state": "off"
        }
      ]
    }
  EOF
  EXAMPLE_SCOPES["unmanaged_files"] = <<-EOF.chomp
    "unmanaged_files": {
      "extracted": true,
      "files": [
        {
          "name": "/etc/unmanaged-file",
          "type": "file",
          "user": "root",
          "group": "root",
          "size": 8,
          "mode": "644"
        }
      ]
    }
  EOF
end
