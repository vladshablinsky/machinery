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

require_relative "spec_helper"

describe WorkloadMapper do
  include GivenFilesystemSpecHelpers
  use_given_filesystem

  before(:each) do
    allow_any_instance_of(Machinery::SystemFile).
      to receive(:content).and_return(File.read(config_file_path))
  end

  let(:system_description) {
    create_test_description(json: <<-EOF)
      {
        "services": {
          "init_system": "systemd",
          "services": [
            {
              "name": "mysql.service",
              "state": "enabled"
            }]
        },
        "config_files": {
          "extracted": true,
          "files": [
            {
              "name": "/etc/my.cnf"
            }
          ]
        }
      }
    EOF
  }
  let(:output_path) { given_directory }
  let(:mapper_path) { given_directory_from_data "mapper" }
  let(:docker_path) { given_directory_from_data "docker" }

  let(:workloads) { YAML::load(File.read(File.join(docker_path, "workloads.yml"))) }
  let(:config_file_path) { File.join(mapper_path, "my.cnf") }

  describe "#write_compose_file" do
    it "writes a docker-compose.yml" do
      subject.write_compose_file(workloads, output_path)
      expect(File.read(File.join(output_path, "docker-compose.yml"))).
        to include(File.read(File.join(docker_path, "docker-compose.yml")))
    end
  end

  describe "#compose_service" do
    let(:expected_node) {
      {
        "db" => {
          "image" => "opensuse/mariadb",
          "environment" => {
            "MYSQL_USER" => "portus",
            "MYSQL_PASS" => "portus"
          }
        }
      }
    }
    let(:workload) { "mariadb" }
    let(:config) {
      {
        "service" => "db",
        "parameters" => {
          "user" => "portus",
          "password" => "portus"
        }
      }
    }

    it "returns a valid compose node" do
      expect(subject.compose_service(workload, config)).to eq(expected_node)
    end
  end

  describe "#identify_workloads" do
    it "returns a list of workloads" do
      expect(subject.identify_workloads(system_description)).
        to have_key("mariadb")
    end
  end
end