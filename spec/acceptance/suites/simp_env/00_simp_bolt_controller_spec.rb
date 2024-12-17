require 'spec_helper_bolt'

test_name 'Install SIMP via Bolt'

describe 'Install SIMP via Bolt' do
  # Enable ssh login with passwords
  hosts.each do |host|
    it 'enables ssh with passwords' do
      on(host, 'sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config')
      os_majver = fact_on(host, 'operatingsystemmajrelease')
      if os_majver.eql?('6')
        on(host, 'service sshd restart')
      else
        on(host, 'systemctl restart sshd')
      end
      # Install puppet-agent 6.13.0 until https://tickets.puppetlabs.com/browse/PUP-10367 is fixed and released.
      on(host, "rpm -Uvh http://yum.puppetlabs.com/puppet/el/#{os_majver}/x86_64/puppet-agent-6.13.0-1.el#{os_majver}.x86_64.rpm")
    end
  end

  let(:run_cmd) { 'runuser vagrant -c ' }
  let(:files_dir) { File.join(File.dirname(__FILE__), 'files') }
  let(:skeleton_dir) { '/usr/share/simp/environment-skeleton' }

  context 'on Bolt controller' do
    # Install SIMP and Bolt
    it 'installs SIMP and Bolt rpms' do
      bolt_controller = only_host_with_role(hosts, 'boltserver')

      if bolt_controller.host_hash['platform'].include?('el-8')
        # dont' have rolling setup for el-8 at this time
        install_simp_download_repo(bolt_controller, 'unstable', 'simp')
        install_simp_download_repo(bolt_controller, 'unstable', 'epel')
      else
        install_simp_download_repo(bolt_controller, 'rolling', 'simp')
        install_simp_download_repo(bolt_controller, 'rolling', 'epel')
      end
      install_puppet_repo(bolt_controller)
      # Install puppet-bolt that uses  6.13.0 until https://tickets.puppetlabs.com/browse/PUP-10367 is fixed and released.
      on(bolt_controller, 'rpm -Uvh http://yum.puppetlabs.com/puppet/el/7/x86_64/puppet-bolt-2.3.1-1.el7.x86_64.rpm')
      on(bolt_controller, 'yum install -y simp')
      # uncomment the following line and delete the above 2 lines  once Puppet release a new version that is working.
      # on(bolt_controller, 'yum install -y simp puppet-bolt')
      # This next step is only required until permisions on SIMP modules are changed
      on(bolt_controller, 'chmod -R o+rX /usr/share/simp/modules')
      # This next step is only required until simp-enviroment-skeleton-7.1.1 is released
      on(bolt_controller, "chmod -R o+rX #{skeleton_dir}")
    end

    # Set up the Bolt and SIMP environments from the commandline with a few variable helpers
    let(:bolt_dir) { '/home/vagrant/.puppetlabs/bolt' }
    let(:bolt_command) { 'bolt apply manifests/' }
    let(:initial_bolt_options) { '-u vagrant -p vagrant --run-as root --sudo-password vagrant --no-host-key-check --tmpdir /home/vagrant' }
    let(:simp_config_settings) { 'cli::network::interface=eth1 cli::is_simp_ldap_server=false cli::network::dhcp=static cli::set_grub_password=false svckill::mode=enforcing' }
    let(:bolt_options) { '-p password --no-host-key-check' }
    let(:sec_dir) { '/home/vagrant/secondary' }
    let(:ca_dir) { "#{sec_dir}/bolt/FakeCA" }
    let(:source_module) { 'spec/fixtures/modules/simp_bolt/' }
    let(:bolt_module) { "#{bolt_dir}/modules/simp_bolt" }
    let(:hiera_dir) { "#{bolt_dir}/data" }
    let(:hosts_dir) { "#{hiera_dir}/hosts" }
    let(:prune_command) { "grep ^mod #{bolt_dir}/Puppetfile| while read mod; do sed -i \"/$mod/,+3d\" #{bolt_dir}/Puppetfile.simp; done" }

    it 'sets up the SIMP and Bolt environments' do
      bolt_controller = only_host_with_role(hosts, 'boltserver')
      # Create Boltdir by executing a Bolt command
      # Allowing exit code 1 because of Bolt analytics warning
      on(bolt_controller, "#{run_cmd} 'bolt puppetfile show-modules 2>&1'", acceptable_exit_codes: [1])
      # Create the secondary environment directory
      on(bolt_controller, "#{run_cmd} \"mkdir #{sec_dir}\"")
      # Copy the SIMP omni-environment directories from the skeleton
      on(bolt_controller, "#{run_cmd} \"rsync -a #{skeleton_dir}/puppet/ #{bolt_dir}/\"")
      on(bolt_controller, "#{run_cmd} \"rsync -a #{skeleton_dir}/secondary/ #{sec_dir}/bolt\"")
      # Populate the togen file in the FakeCA dir and generate certs
      togen = []
      hosts.each do |host|
        fqdn = on(host, 'facter fqdn', accept_all_exit_codes: true).stdout.strip
        togen << fqdn
      end
      create_remote_file(bolt_controller, "#{ca_dir}/togen", togen.join("\n"))
      # Allowing exit code 1 because gencerts_nopass.sh tries to chown files, which vagrant user cannot perform
      on(bolt_controller, "#{run_cmd} \"cd #{ca_dir} && ./gencerts_nopass.sh auto\"", acceptable_exit_codes: [1])
      # Copy simp_bolt module to bolt_controller
      on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && mkdir modules\"")
      rsync_to(bolt_controller, source_module.to_s, bolt_module)
      on(bolt_controller, "chown -R vagrant #{bolt_module}")
      # Create Puppetfiles and install modules
      on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && simp puppetfile generate -s > Puppetfile\"")
      on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && simp puppetfile generate > Puppetfile.simp\"")
      # In the following commands, touching the files before scp ensures correct file permissions
      on(bolt_controller, "#{run_cmd} \"touch #{bolt_dir}/updated_modules\"")
      scp_to(bolt_controller, File.join(files_dir, 'updated_modules.example'), "#{bolt_dir}/updated_modules")
      # Add updated modules to the Puppetfile
      on(bolt_controller, "sed -i \"/# Add your own Puppet modules here/r #{bolt_dir}/updated_modules\" #{bolt_dir}/Puppetfile")
      # Remove updated modules from Puppetfile.simp so there are no duplicates
      on(bolt_controller, prune_command.to_s)
      # Install modules
      on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && bolt puppetfile install\"")
      # Copy bolt manifest and Hiera files
      on(bolt_controller, "#{run_cmd} \"touch #{bolt_dir}/manifests/bolt.pp #{hiera_dir}/default.yaml\"")
      on(bolt_controller, "#{run_cmd} \"touch #{hosts_dir}/bolt-controller.yaml\"")
      scp_to(bolt_controller, File.join(files_dir, 'bolt.pp.example'), "#{bolt_dir}/manifests/bolt.pp")
      scp_to(bolt_controller, File.join(files_dir, 'default.yaml.example'), "#{hiera_dir}/default.yaml")
      scp_to(bolt_controller, File.join(files_dir, 'bolt-controller.yaml.example'), "#{hosts_dir}/bolt-controller.yaml")
      ipaddr = on(bolt_controller, "hostname -I|sed -e 's/\s/,/g'").stdout.strip
      hosts_with_role(hosts, 'target').each do |host|
        on(bolt_controller, "#{run_cmd} \"touch #{hosts_dir}/#{host.name}.yaml\"")
        scp_to(bolt_controller, File.join(files_dir, 'target.yaml.example'), "#{hosts_dir}/#{host.name}.yaml")
        # Adding IP addresses because DNS is not configured
        on(bolt_controller, "sed -i \"s/user_allowed_from: [[]/user_allowed_from: [#{ipaddr}/\" #{hosts_dir}/#{host.name}.yaml")
      end
    end

    it 'applies SIMP settings to the bolt-controller' do
      bolt_controller = only_host_with_role(hosts, 'boltserver')
      fqdn = on(bolt_controller, 'facter fqdn', accept_all_exit_codes: true).stdout.strip
      # Apply simp_bolt module on the bolt-controller
      on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && #{bolt_command}bolt.pp #{initial_bolt_options} -t #{fqdn} --transport ssh\"")
      # Set basic SIMP configuration
      # Need to determine how to run simp config as non-root user but in the meantime this provides a few basic settings
      on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && simp config --dry-run -f -D -s #{simp_config_settings}\"")
      on(bolt_controller, "rsync -a /home/vagrant/.simp/simp_conf.yaml #{hiera_dir}/simp_config_settings.yaml")
      # Apply SIMP on the bolt-controller, done twice, permitting failures on first run
      on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && #{bolt_command}site.pp  #{initial_bolt_options} -t #{fqdn}\"", acceptable_exit_codes: [0, 1])
      on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && #{bolt_command}site.pp  #{initial_bolt_options} -t  #{fqdn}\"")
    end

    it 'applies SIMP settings to the targets' do
      bolt_controller = only_host_with_role(hosts, 'boltserver')
      hosts_with_role(hosts, 'target').each do |host|
        fqdn = on(host, 'facter fqdn', accept_all_exit_codes: true).stdout.strip
        os = fact_on(host, 'operatingsystemmajrelease')
        if os.eql?('6')
          # Add hmac-sha1 to the allow ciphers to accomodate el6
          # This could be done via Bolt on the controller but the ssh module appended Host target-el6 to the end of ssh_config, meaning Host * matched first
          on(bolt_controller, "sed -i \"/^Host [\*]/i Host #{fqdn}\" /etc/ssh/ssh_config")
          on(bolt_controller, "sed -i \"/^Host [\*]/i MACs hmac-sha1\" /etc/ssh/ssh_config")
        end
        if os.eql?('8')
          # Still not stable yet so let it fail.
          # Using initial_bolt_options for first run because the simp_bolt user has not been created yet, permitting failures on first run
          on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && #{bolt_command}site.pp  #{initial_bolt_options} -t #{fqdn}\"", accept_all_exit_codes: true)
          # Using bolt_options to specify simp_bolt user password and no-host-key-check for ssh
          on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && #{bolt_command}site.pp  #{bolt_options} -t #{fqdn}\"", accept_all_exit_codes: true)
        else

          # Using initial_bolt_options for first run because the simp_bolt user has not been created yet, permitting failures on first run
          on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && #{bolt_command}site.pp  #{initial_bolt_options} -t #{fqdn}\"", acceptable_exit_codes: [0, 1])
          # Using bolt_options to specify simp_bolt user password and no-host-key-check for ssh
          on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && #{bolt_command}site.pp  #{bolt_options} -t #{fqdn}\"")
        end
      end
    end
  end
end
