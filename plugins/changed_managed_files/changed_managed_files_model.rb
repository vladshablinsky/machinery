# Copyright (c) 2013-2016 SUSE LLC
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

class ChangedManagedFile < Machinery::SystemFile
end

class ChangedManagedFileList < Machinery::Array
  has_elements class: ChangedManagedFile

  def compare_with(other)
    only_self = self - other
    only_other = other - self
    common = self & other
    changed = Machinery::Scope.extract_changed_elements(only_self, only_other, :name)

    [
      only_self,
      only_other,
      changed,
      common
    ].map { |e| (e && !e.empty?) ? e : nil }
  end
end

class ChangedManagedFilesScope < FileScope
  include Machinery::Scope
  include ScopeFileAccessFlat

  has_attributes :extracted
  has_elements class: ChangedManagedFile
end
