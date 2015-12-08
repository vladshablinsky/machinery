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


class Disk < Machinery::Object
  IGNORED_ATTRIBUTES_IN_COMPARISON = []

  def eql?(other)
    relevant_attributes = (attributes.keys & other.attributes.keys) -
      IGNORED_ATTRIBUTES_IN_COMPARISON

    relevant_attributes.all? do |attribute|
      self[attribute] == other[attribute]
    end
  end

  def hash
    @attributes.reject { |k, _v| IGNORED_ATTRIBUTES_IN_COMPARISON.include?(k) }.hash
  end
end

class DiskScope < Machinery::Array
  include Machinery::Scope

  has_elements class: Disk

  def compare_with(other)
    only_self = self - other
    only_other = other - self
    common = self & other
    changed = Machinery::Scope.extract_changed_elements(only_self, only_other, :content)

    [
      only_self,
      only_other,
      changed,
      common
    ].map { |e| (e && !e.empty?) ? e : nil }
  end
end
