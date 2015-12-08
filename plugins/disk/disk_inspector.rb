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
require 'storage'
require 'open3'

class DiskInspector < Inspector
  has_priority 50

  def initialize(system, description)
    @system = system
    @description = description
  end

  def inspect(_filter, _options = {})
    disks = []
    libstorage(@system).to_s.each_line do |line|
      disk = Disk.new
      disk.content = line
      disks << disk
    end
    @description.disk = DiskScope.new(disks)
  end

  def summary
    "Found storage information."
  end
end

class MyRemoteCallbacks < Storage::RemoteCallbacks
  def initialize(system)
    @system = system
    super()
  end

  def command(name)
    ret = Storage::RemoteCommand.new
    ret.exit_code = 0
    begin

      # Ugly hack in Hackweek 13:
      # Unquote command line because Cheetah will quote it again
      command = name.gsub(/ '/, ' ').
                     gsub(/' /, ' ').
                     gsub(/'$/, '').split(" ")

      stdout, stderr = @system.run_command(command, stdout: :capture, stderr: :capture)
      stdout.each_line { |line| ret.stdout << line.rstrip }
      stderr.each_line { |line| ret.stderr << line.rstrip }
    rescue Cheetah::ExecutionFailed => e
      e.stdout.each_line { |line| ret.stdout << line.rstrip }
      e.stderr.each_line { |line| ret.stderr << line.rstrip }
      ret.exit_code = e.status.exitstatus
    end

    ret
  end

  def file(name)
    file_content = @system.read_file(name)
    return Storage::RemoteFile.new unless file_content
    Storage::RemoteFile.new(Storage::VectorString.new(file_content.split("\n")))
  end
end

def libstorage(system)
  my_remote_callbacks = MyRemoteCallbacks.new(system)
  Storage.remote_callbacks = my_remote_callbacks
  environment = Storage::Environment.new(true)
  storage = Storage::Storage.new(environment)
  probed = storage.probed()
end


