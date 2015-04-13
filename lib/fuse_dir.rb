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

require 'rfusefs'

class FuseDir
  def initialize(description)
    @description = description
    @config_files = configFiles
    @changed_managed_files = changedManagedFiles
    @unmanaged_files = unmanagedFiles
    @tree = @config_files + @changed_managed_files + @unmanaged_files
    @tar_list_cache = {}
  end

  def contents(path)
    Machinery.logger.info "fuse: contents for #{path}"
    content = []

    (tar_list(path) + @tree).each do |entry|
      if entry.start_with?(path)
        start_slash = entry.index("/", path.length - 1)
        end_slash = entry.index("/", start_slash + 1)
        end_slash = 0 if !end_slash
        content << entry[start_slash+1 .. end_slash-1]
      end
    end

    content.delete_if{|a| a == ""}.uniq
  end

  def tar_read(path, last_path)
    Machinery.logger.info "fuse: tar_read"
    return [] if last_path == "/"

    tar_file = File.join(@description.description_path, "unmanaged_files", "trees", last_path) + ".tgz"
    Machinery.logger.info "trying tar_file #{tar_file}"
    if File.exist?(tar_file)
      Machinery.logger.info "reading tar_file #{tar_file}"
      return Cheetah.run("tar", "xfO", tar_file, path[1..-1], :stdout => :capture)
    else
      # Recursively go through parent directories
      # File.dirname removes the last sub directory from the path
      return tar_read(path, File.dirname(last_path))
    end

  end

  def tar_list(path)
    Machinery.logger.info "fuse: tar_list #{path}"

    return [] if path == "/"

    if @tar_list_cache[path]
      Machinery.logger.info "returning cache"
      return @tar_list_cache[path]
    end

    contents = []
    dir = File.join(@description.description_path, "unmanaged_files", "trees", path)

    if File.directory?(dir)
      Dir.entries(dir).each do |entry|
        if File.directory?( File.join(@description.description_path, "unmanaged_files", "trees", path, entry))
          contents << File.join(path, entry)
        end

        if entry.end_with?(".tgz")
          tar_file = File.join(@description.description_path, "unmanaged_files", "trees", path, entry)
          tar_content = Cheetah.run("tar", "tf", tar_file, :stdout => :capture).gsub(/^/,'/').split(/\r?\n/)
          contents += tar_content
        end
      end
    else
      # Recursively go through parent directories
      # File.dirname removes the last sub directory from the path
      contents = contents + tar_list(File.dirname(path))
    end

    @tar_list_cache[path] = contents
    contents
  end

  def directory?(path)
    Machinery.logger.info "fuse: directory? for #{path}"
    !@tree.include?(path) && !tar_list(path).include?(path)
  end

  def file?(path)
    Machinery.logger.info "fuse: file? for #{path}"
    @tree.include?(path) || tar_list(path).include?(path)
  end

  def configFiles
    list=[]
    files = @description["config_files"].files
    if files && @description["config_files"].extracted
      files.each do |p|
        list << p.name
      end
    end
    list
  end

  def changedManagedFiles
    list=[]
    files = @description["changed_managed_files"].files
    if files && @description["changed_managed_files"].extracted
      files.each do |p|
        list << p.name
      end
    end
    list
  end

  def unmanagedFiles
    tar_file = File.join(@description.description_path, "unmanaged_files", "files.tgz")
    if File.exist?(tar_file)
      Cheetah.run("tar", "tf", tar_file, :stdout => :capture).gsub(/^/,'/').split(/\r?\n/)
    else
      []
    end
  end

  def read_file(path)
    Machinery.logger.info "fuse: read_file for #{path}"
    if @config_files.include?(path)
      read_config_file(path)
    elsif @changed_managed_files.include?(path)
      read_changed_managed_file(path)
    elsif @unmanaged_files.include?(path)
      read_unmanaged_file(path)
    else
      tar_read(path, path)
    end
  end

  def read_config_file(path)
    Machinery.logger.info "fuse: read_config_file for #{path}"
    abs_path = File.join(@description.description_path, "config_files", path)
    file = File.new(abs_path, "r")
    file.read
  end

  def read_changed_managed_file(path)
    Machinery.logger.info "fuse: read_changed_managed_file for #{path}"
    abs_path = File.join(@description.description_path, "changed_managed_files", path)
    file = File.new(abs_path, "r")
    file.read
  end

  def read_unmanaged_file(path)
    Machinery.logger.info "fuse: read_unmanaged_file for #{path}"
    tar_file = File.join(@description.description_path, "unmanaged_files", "files.tgz")
    path[0] = '' if path[0] = "/"
    Cheetah.run("tar", "xfO", tar_file, path, :stdout => :capture)
  end
end
