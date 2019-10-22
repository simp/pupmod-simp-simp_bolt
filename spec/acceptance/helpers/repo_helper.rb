module Acceptance
  module Helpers
    module RepoHelper

      def install_puppet_repo(host)
        case ENV['BEAKER_puppet_repo']
        when 'true'
           install_repo = true
        when 'false'
           install_repo = false
        else
           install_repo = true
        end

        if install_repo
          puppet_collection = ENV['PUPPET_COLLECTION'] || 'puppet5'

          puts('='*72)
          puts("Using Puppet #{puppet_collection} repo from yum.puppetlabs.com")
          puts('='*72)

          if host.host_hash[:platform] =~ /el-7/
            family = 'el-7'
          elsif host.host_hash[:platform] =~ /el-6/
            family = 'el-6'
          else
            fail("install_puppet_repo(): Cannot determine puppet repo for #{host.name}")
          end
          url = "http://yum.puppetlabs.com/#{puppet_collection}/#{puppet_collection}-release-#{family}.noarch.rpm"
          on(host, "yum install #{url} -y")
        end
      end

      # Install a SIMP packagecloud yum repo
      #
      # - Each repo is modeled after what appears in simp-doc
      # - See https://packagecloud.io/simp-project/ for the reponame key
      #
      # +host+: Host object on which SIMP repo(s) will be installed
      # +reponame+: The base name of the repo, e.g. '6_X'
      # +type+: Which repo to install:
      #   :main for the main repo containing SIMP puppet modules
      #   :deps for the SIMP dependency repo containing OS or application
      #         RPMs not available from standard CentOS repos
      #
      # @fails if the specified repo cannot be installed on host
      def install_internet_simp_repo(host, reponame, type)
        case type
        when :main
          full_reponame = reponame
          # FIXME: Use a gpgkey list appropriate for more than 6_X
          repo = <<~EOM
            [simp-project_#{reponame}]
            name=simp-project_#{reponame}
            baseurl=https://packagecloud.io/simp-project/#{reponame}/el/$releasever/$basearch
            gpgcheck=1
            enabled=1
            gpgkey=https://raw.githubusercontent.com/NationalSecurityAgency/SIMP/master/GPGKEYS/RPM-GPG-KEY-SIMP
                   https://download.simp-project.com/simp/GPGKEYS/RPM-GPG-KEY-SIMP-6
            sslverify=1
            sslcacert=/etc/pki/tls/certs/ca-bundle.crt
            metadata_expire=300
          EOM
        when :deps
          full_reponame = "#{reponame}_Dependencies"
          # FIXME: Use a gpgkey list appropriate for more than 6_X
          repo = <<~EOM
            [simp-project_#{reponame}_dependencies]
            name=simp-project_#{reponame}_dependencies
            baseurl=https://packagecloud.io/simp-project/#{reponame}_Dependencies/el/$releasever/$basearch
            gpgcheck=1
            enabled=1
            gpgkey=https://raw.githubusercontent.com/NationalSecurityAgency/SIMP/master/GPGKEYS/RPM-GPG-KEY-SIMP
                   https://download.simp-project.com/simp/GPGKEYS/RPM-GPG-KEY-SIMP-6
                   https://yum.puppet.com/RPM-GPG-KEY-puppetlabs
                   https://yum.puppet.com/RPM-GPG-KEY-puppet
                   https://apt.postgresql.org/pub/repos/yum/RPM-GPG-KEY-PGDG-96
                   https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-$releasever
            sslverify=1
            sslcacert=/etc/pki/tls/certs/ca-bundle.crt
            metadata_expire=300
          EOM
          full_reponame = "#{reponame}_Dependencies"
        else
          fail("install_internet_simp_repo() Unknown repo type specified '#{type.to_s}'")
        end
        puts('='*72)
        puts("Using SIMP #{full_reponame} Internet repo from packagecloud")
        puts('='*72)

        create_remote_file(host, "/etc/yum.repos.d/simp-project_#{full_reponame.downcase}.repo", repo)
      end
    end
  end
end
