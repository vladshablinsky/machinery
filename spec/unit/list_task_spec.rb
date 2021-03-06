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

require_relative "spec_helper"

describe ListTask do
  capture_machinery_output
  include FakeFS::SpecHelpers
  let(:list_task) { ListTask.new }
  let(:store) { SystemDescriptionStore.new }
  let(:name) { "foo" }
  let(:name2) { "bar" }
  let(:name3) { "description" }
  let(:date) { "2014-02-07T14:04:45Z" }
  let(:hostname) { "example.com" }
  let(:date_human) { DateTime.parse(date).to_time.localtime.strftime("%Y-%m-%d %H:%M:%S") }
  let(:system_description) {
    create_test_description(
      scopes: ["packages", "repositories"], modified: date, hostname: hostname,
      name: name, store: store
    )
  }
  let(:system_description2) {
    create_test_description(
      scopes: ["packages", "repositories"], modified: date, hostname: hostname,
      name: name2, store: store
    )
  }
  let(:system_description3) {
    create_test_description(
      scopes: ["packages", "repositories"], modified: date, hostname: hostname,
      name: name3, store: store
    )
  }
  let(:system_description_without_scope_meta) {
    create_test_description(scopes: ["packages"], add_scope_meta: false, name: name, store: store)
  }
  let(:system_description_with_extracted_files) {
    create_test_description(
      scopes: ["changed_managed_files"],
      extracted_scopes: ["config_files", "unmanaged_files"],
      name: name, store: store)
  }
  let(:system_description_with_newer_data_format) {
    create_test_description(json: <<-EOF, name: name, store: store)
      { "meta": { "format_version": #{SystemDescription::CURRENT_FORMAT_VERSION + 1} } }
    EOF
  }
  let(:system_description_with_old_data_format) {
    create_test_description(json: <<-EOF, name: name, store: store)
      { "meta": { "format_version": 1 } }
    EOF
  }
  let(:system_description_with_incompatible_data_format) {
    create_test_description(json: <<-EOF, name: name, store: store)
      {}
    EOF
  }

  describe "#list" do
    before(:each) do
      allow(JsonValidator).to receive(:new).and_return(double(validate: []))
    end

    context "when a system_description is specified" do
      it "lists only this system description with scopes" do
        system_description.save
        expected_output = <<-EOF
 foo:
   * packages
   * repositories

        EOF
        list_task.list(store, ["foo"])
        expect(captured_machinery_output).to eq(expected_output)
      end
    end

    context "when multiple system_descriptions are specified" do
      it "lists only these system descriptions with scopes, sorted by name" do
        system_description.save
        system_description2.save
        expected_output = <<-EOF
 bar:
   * packages
   * repositories

 foo:
   * packages
   * repositories

        EOF
        list_task.list(store, ["foo", "bar"])
        expect(captured_machinery_output).to eq(expected_output)
      end

      it "lists only the existing system descriptions with scopes" do
        system_description.save
        expected_output = <<-EOF
 bar: Couldn't find a system description with the name 'bar'.

 foo:
   * packages
   * repositories

        EOF
        list_task.list(store, ["foo", "bar"])
        expect(captured_machinery_output).to eq(expected_output)
      end
    end

    context "when no system_description is specified" do
      it "lists all system descriptions with scopes" do
        system_description.save
        system_description2.save
        system_description3.save
        expected_output = <<-EOF
 bar:
   * packages
   * repositories

 description:
   * packages
   * repositories

 foo:
   * packages
   * repositories

        EOF
        list_task.list(store, [])
        expect(captured_machinery_output).to eq(expected_output)
      end

      context "if short is true" do
        let(:attributes) { { short: true } }
        it "lists only the description names" do
          system_description.save
          system_description2.save
          system_description3.save
          expected_output = <<-EOF.chomp
bar
description
foo

          EOF
          list_task.list(store, [], attributes)
          expect(captured_machinery_output).to eq(expected_output)
        end

        it "also shows errors in one line only" do
          system_description.save
          create_test_description(
            scopes: ["packages"], modified: date, hostname: hostname, name: "description_old",
              format_version: 1, store: store
          ).save
          system_description2.save
          expected_output = <<-EOF.chomp
bar
description_old: format version 1, needs to be upgraded. Try '.+ upgrade-format description_old' to upgrade it to the current version.
foo

        EOF
          list_task.list(store, [], attributes)
          expect(captured_machinery_output).to match(expected_output)
        end
      end

      it "shows also the date and hostname of the descriptions if verbose is true" do
        system_description.save
        system_description2.save
        system_description3.save
        expected_output = <<-EOF
 bar:
   * packages
      Host: [#{hostname}]
      Date: (#{date_human})
   * repositories
      Host: [#{hostname}]
      Date: (#{date_human})

 description:
   * packages
      Host: [#{hostname}]
      Date: (#{date_human})
   * repositories
      Host: [#{hostname}]
      Date: (#{date_human})

 foo:
   * packages
      Host: [#{hostname}]
      Date: (#{date_human})
   * repositories
      Host: [#{hostname}]
      Date: (#{date_human})
        EOF
        list_task.list(store, [], verbose: true)
        expect(captured_machinery_output).to include(expected_output)
      end

      it "verbose shows the date/hostname as unknown if there is no meta data for it" do
        system_description_without_scope_meta.save
        expected_output = <<-EOF
 foo:
   * packages
      Host: [Unknown hostname]
      Date: (unknown)
        EOF
        list_task.list(store, [], verbose: true)
        expect(captured_machinery_output).to include(expected_output)
      end

      it "show the extracted state of extractable scopes" do
        allow_any_instance_of(SystemDescription).to receive(:validate_file_data)

        system_description_with_extracted_files.save
        expected_output = <<-EOF
 foo:
   * config-files (extracted)
   * changed-managed-files (not extracted)
   * unmanaged-files (extracted)
        EOF
        list_task.list(store, [])
        expect(captured_machinery_output).to include(expected_output)
      end

      context "with old data format" do
        context "using the long option" do
          it "marks descriptions" do
            system_description_with_old_data_format.save
            list_task.list(store, [])
            expect(captured_machinery_output).to include("needs to be upgraded")
          end
        end

        context "using the short option" do
          it "marks descriptions" do
            system_description_with_old_data_format.save
            list_task.list(store, [], short: true)
            expect(captured_machinery_output).to include("needs to be upgraded")
          end
        end
      end

      it "marks descriptions with incompatible data format" do
        system_description_with_incompatible_data_format.save
        list_task.list(store, [])
        expect(captured_machinery_output).to include("Can not be upgraded.")
      end

      it "marks descriptions with newer data format" do
        system_description_with_newer_data_format.save
        list_task.list(store, [])
        expect(captured_machinery_output).to include("upgrade Machinery")
      end
    end
  end
end
