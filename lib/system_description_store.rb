# Copyright (c) 2013-2014 SUSE LLC
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

# The responsibility of the SystemDescriptionStore class is to handle the
# directory where the system description is stored. It provides methods to
# create, delete, and copy descriptions within the top-level directory.
#
# System descriptions are represented by sub directories of this top-level
# directory. They are handled by the SystemDescription class.
class SystemDescriptionStore
  attr_reader :base_path

  def default_path
    Machinery::DEFAULT_CONFIG_DIR
  end

  def persistent?
    true
  end

  def initialize(base_path = default_path)
    @base_path = base_path
    create_dir(@base_path)
  end

  def description_path(name)
    File.join(@base_path, name)
  end

  def manifest_path(name)
    File.join(description_path(name), "manifest.json")
  end

  def html_path(name)
    File.join(description_path(name), "index.html")
  end

  def load_json(name)
    SystemDescription.validate_name(name)
    file_name = manifest_path(name)
    unless File.exists?(file_name)
      raise Machinery::Errors::SystemDescriptionNotFound.new(
        "A system description with the name #{name} was not found."
      )
    end
    File.read(file_name)
  end

  def list
    Dir["#{@base_path}/*"].
      select { |item| File.exists?(manifest_path(File.basename(item)))}.
      map { |item| File.basename(item) }
  end

  def remove(name)
    unless name.empty?
      SystemDescription.validate_name(name)
      FileUtils.rm_rf(description_path(name))
    else
      raise "The system description has no name specified and thus can't be deleted."
    end
  end

  def copy(from, to)
    SystemDescription.validate_name(from)
    SystemDescription.validate_name(to)
    if !list.include?(from)
      raise Machinery::Errors::SystemDescriptionNotFound.new(
        "System description \"#{from}\" does not exist."
      )
    end

    if list.include?(to)
      raise Machinery::Errors::SystemDescriptionError.new(
        "A System description with the name \"#{to}\" does already exist."
      )
    end

    FileUtils.cp_r(description_path(from), description_path(to))
  end

  def initialize_file_store(description_name, store_name)
    file_store = ScopeFileStore.new(description_path(description_name),
      store_name)
    file_store.create
  end

  def file_store(description_name, store_name)
    file_store = ScopeFileStore.new(description_path(description_name),
      store_name)
    file_store.path
  end

  def remove_file_store(description_name, store_name)
    file_store = ScopeFileStore.new(description_path(description_name),
      store_name)
    file_store.remove
  end

  def rename_file_store(description_name, store_old, store_new)
    file_store = ScopeFileStore.new(description_path(description_name),
      store_old)
    file_store.rename(store_new)
  end

  def create_file_store_sub_dir(description_name, store_name, sub_dir)
    file_store = ScopeFileStore.new(description_path(description_name),
      store_name)
    file_store.create_sub_directory(sub_dir)
  end

  def list_file_store_content(description_name, store_name)
    file_store = ScopeFileStore.new(description_path(description_name),
      store_name)
    file_store.list_content
  end

  def directory_for(name)
    dir = description_path(name)
    create_dir(dir)
    dir
  end

  private

  def create_dir(dir, mode = 0700)
    unless Dir.exists?(dir)
      FileUtils.mkdir_p(dir, :mode => mode)
    end
  end
end
