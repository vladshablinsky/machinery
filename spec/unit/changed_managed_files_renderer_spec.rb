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

require_relative "spec_helper"

describe ChangedManagedFilesRenderer do
  let(:system_description) {
    json = <<-EOF
    {
      "changed-managed-files": [
        {
          "name": "/deleted/file",
          "package_name": "glibc",
          "package_version": "2.11.3",
          "changes": [
            "deleted"
          ],
          "package_file_flag": "d"
        },
        {
          "name": "/changed/file",
          "package_name": "login",
          "package_version": "3.41",
          "changes": [
            "md5",
            "mode"
          ],
          "package_file_flag": "c",
          "mode": "644",
          "uid": 0,
          "gid": 0,
          "user": "root",
          "group": "root",
          "md5_hash": "a571ffd6f0f9ab955f274d72c767d06b"
        },
        {
          "name": "/usr/sbin/vlock-main",
          "package_name": "vlock",
          "package_version": "2.2.3",
          "error": "cannot verify root:root 0755 - not listed in /etc/permissions"
        }
      ]
    }
    EOF
    SystemDescription.from_json("name", json)
  }

  describe "#render" do
    before(:each) do
      @output = ChangedManagedFilesRenderer.new.render(system_description)
    end

    it "prints a list of managed files" do
      expect(@output).to match(/\/deleted\/file.*deleted/)
      expect(@output).to match(/\/changed\/file.*md5, mode/)
    end

    it "prints errored files as a separate list" do
      expect(@output).to match(/Errors:\n.*\/usr\/sbin\/vlock-main/)
    end
  end
end