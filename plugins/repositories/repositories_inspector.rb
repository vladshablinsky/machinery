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

class RepositoriesInspector < Inspector
  has_priority 40
  def initialize(system, description)
    @system = system
    @description = description
  end

  def inspect(_filter, _options = {})
    if system.has_command?("zypper")
      @description.repositories = inspect_zypp_repositories
    elsif system.has_command?("yum")
      @description.repositories = inspect_yum_repositories
    elsif system.has_command?("dpkg")
      @description.repositories = inspect_apt_repositories
    else
      raise Machinery::Errors::MissingRequirement.new(
        "Need either the binary 'zypper', 'yum' or 'apt' to be available on the inspected system."
      )
    end
  end

  def summary
    "Found " \
      "#{Machinery.pluralize(@description.repositories.size, "%d repository", "%d repositories")}."
  end

  private

  def inspect_zypp_repositories
    begin
      xml = system.run_command(
        "zypper", "--non-interactive", "--xmlout", "repos", "--details",
        stdout: :capture
      )
      details = system.run_command(
        "zypper", "--non-interactive", "repos", "--details", stdout: :capture
      ).split("\n").select { |l| l =~ /\A# +\| |\A *\d+ \| / }.
        map { |l| l.split("|").map(&:strip) }
    rescue Cheetah::ExecutionFailed => e
      if e.status.exitstatus == 6 # ZYPPER_EXIT_NO_REPOS
        details = []
      else
        raise e
      end
    end

    if details.empty?
      result = []
    else
      priorities = parse_priorities_from_details(details)
      credentials = get_credentials_from_system
      result = parse_repositories_from_xml(xml, priorities, credentials)
    end

    RepositoriesScope.new(result, repository_system: "zypp")
  end

  def inspect_yum_repositories
    script = File.read(File.join(Machinery::ROOT, "inspect_helpers", "yum_repositories.py"))
    begin
      repositories = JSON.parse(system.run_command(
        "bash", "-c", "python", stdin: script, stdout: :capture
      ).split("\n").last).map { |element| YumRepository.new(element) }
    rescue JSON::ParserError
      raise Machinery::Errors::InspectionFailed.new("Extraction of YUM repositories failed.")
    rescue Cheetah::ExecutionFailed => e
      raise Machinery::Errors::InspectionFailed.new(
        "Extraction of YUM repositories failed:\n#{e.stderr}"
      )
    end

    RepositoriesScope.new(repositories, repository_system: "yum")
  end

  def inspect_apt_repositories
    content = system.read_file("/etc/apt/sources.list")
    begin
      content += "\n" + system.run_command(
        "bash", "-c", "cat /etc/apt/sources.list.d/*.list", stdout: :capture
      )
    rescue Cheetah::ExecutionFailed
    end

    RepositoriesScope.new(
      parse_apt_repositories(content), repository_system: "apt"
    )
  end

  def parse_apt_repositories(content)
    repositories = []
    content.each_line do |line|
      if line =~ /^\s*(deb|deb-src)\s+(cdrom:\[.+\]\/|\S+)\s+(\S+)(\s+\S[^#]*\S)?(\s*|\s*#.*)$/
        repositories << AptRepository.new(
          type: $1,
          url: $2,
          distribution: $3,
          components: $4 ? $4.strip.split(" ") : []
        )
      elsif line =~ /Types: deb/
        Machinery::Ui.warn(
          "Warning: An unsupported rfc822 style repository was found, which will be ignored."
        )
      end
    end
    repositories.uniq
  end

  def parse_priorities_from_details(details)
    # parse and remove header
    idx_prio = details.first.index("Priority")
    idx_alias = details.first.index("Alias")
    details.shift

    prio = {}
    details.each do |entry|
      prio[entry[idx_alias]] = entry[idx_prio].to_i
    end

    prio
  end

  def get_credentials_from_system
    credentials = {}
    credential_dir = "/etc/zypp/credentials.d/"
    credential_files = @system.run_command(
      "bash", "-c",
      "test -d '#{credential_dir}' && ls -1 '#{credential_dir}' || echo ''",
      stdout: :capture
    )
    credential_files.split("\n").each do |f|
      content = @system.run_command(
        "cat", "/etc/zypp/credentials.d/#{f}", stdout: :capture, privileged: true
      )
      content.match(/username=(\w*)\npassword=(\w*)/)
      credentials[f] = {
        username: $1,
        password: $2
      }
    end
    credentials
  end

  def parse_repositories_from_xml(xml, priorities, credentials)
    reps = REXML::Document.new(xml).get_elements("/stream/repo-list/repo")
    result = reps.map do |rep|
      if rep.attributes["priority"]
        pri_value = rep.attributes["priority"].to_i
      else
        pri_value = priorities[rep.attributes["alias"]]
      end

      # NCC
      rep.elements["url"].first.to_s.match(/\?credentials=(\w*)/)
      cred_value = $1
      if cred_value && credentials[cred_value]
        username = credentials[cred_value][:username]
        password = credentials[cred_value][:password]
      end

      # SCC
      rep.elements["url"].first.to_s.match(/(https:\/\/updates.suse.com\/SUSE\/)/)
      scc_url = $1
      cred_value = "SCCcredentials"
      if scc_url && credentials[cred_value]
        username = credentials[cred_value][:username]
        password = credentials[cred_value][:password]
      end

      repository = ZyppRepository.new(
        alias:       rep.attributes["alias"],
        name:        rep.attributes["name"],
        type:        rep.attributes["type"],
        url:         rep.elements["url"].first.to_s,
        enabled:     rep.attributes["enabled"] == "1",
        autorefresh: rep.attributes["autorefresh"] == "1",
        gpgcheck:    rep.attributes["gpgcheck"] == "1",
        priority:    pri_value
      )
      if username && password
        repository[:username] = username
        repository[:password] = password
      end
      repository
    end.sort_by(&:name)
    result
  end
end
