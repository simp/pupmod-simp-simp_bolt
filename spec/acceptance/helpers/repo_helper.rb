module Acceptance::Helpers::RepoHelper
  def install_puppet_repo(host)
    install_repo = case ENV['BEAKER_puppet_repo']
                   when 'true'
                     true
                   when 'false'
                     false
                   else
                     true
                   end

    return unless install_repo
    puppet_collection = ENV['PUPPET_COLLECTION'] || 'puppet5'

    puts('=' * 72)
    puts("Using Puppet #{puppet_collection} repo from yum.puppetlabs.com")
    puts('=' * 72)

    if host.host_hash[:platform].include?('el-7')
      family = 'el-7'
    elsif host.host_hash[:platform].include?('el-8')
      family = 'el-8'
    else
      raise("install_puppet_repo(): Cannot determine puppet repo for #{host.name}")
    end
    url = "http://yum.puppetlabs.com/#{puppet_collection}/#{puppet_collection}-release-#{family}.noarch.rpm"
    on(host, "yum install #{url} -y")
  end

  # Install a SIMP Project Repo
  #
  def install_simp_download_repo(host, reponame, type, version = '6')
    unless ['rolling', 'releases', 'unstable'].include?(reponame)
      raise("install_internet_simp_repo() Unknown reponame specified #{reponame}.  Must be one of: ['rolling','releases','unstable'] ")
    end
    unless ['simp', 'epel', 'puppet', 'postgresql'].include?(type)
      raise("install_internet_simp_repo() Unknown type specified #{type}.  Must be one of ['simp','epel','puppet','postgresql']")
    end

    repo = <<~EOM
[#{type}]
name=#{type}
baseurl=https://download.simp-project.com/simp/yum/#{reponame}/#{version}/el/$releasever/x86_64/#{type}
gpgcheck=1
enabled=1
gpgkey=https://raw.githubusercontent.com/NationalSecurityAgency/SIMP/master/GPGKEYS/RPM-GPG-KEY-SIMP
     https://download.simp-project.com/simp/GPGKEYS/RPM-GPG-KEY-SIMP-6
     https://download.simp-project.com/simp/GPGKEYS/RPM-GPG-KEY-SIMP
     https://download.simp-project.com/simp/GPGKEYS/RPM-GPG-KEY-SIMP-UNSTABLE
     https://raw.githubusercontent.com/NationalSecurityAgency/SIMP/master/GPGKEYS/RPM-GPG-KEY-SIMP
     https://download.simp-project.com/simp/GPGKEYS/RPM-GPG-KEY-SIMP-6
     https://yum.puppet.com/RPM-GPG-KEY-puppetlabs
     https://yum.puppet.com/RPM-GPG-KEY-puppet
     https://apt.postgresql.org/pub/repos/yum/RPM-GPG-KEY-PGDG-96
     https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-$releasever
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
        EOM
    puts('=' * 72)
    puts("Using repo #{type} from download.simp-project.com directory: #{reponame} version: #{version}")
    puts('=' * 72)

    create_remote_file(host, "/etc/yum.repos.d/simp-project_#{type.downcase}.repo", repo)
  end
end
