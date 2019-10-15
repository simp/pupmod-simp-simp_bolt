require 'spec_helper_bolt'

test_name 'Install SIMP via Bolt'

describe 'Install SIMP via Bolt' do

  # Enable ssh login with passwords
  hosts.each do |host|
    it 'should enable ssh with passwords' do
      on(host, 'sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config')
      os = fact_on(host,'operatingsystemmajrelease')
      if os.eql?('7')
        on(host, 'systemctl restart sshd')
      else os.eql?('6')
        on(host, 'service sshd restart')
      end
    end
  end

  let(:run_cmd) {'runuser vagrant -c '}
  let(:files_dir) { File.join(File.dirname(__FILE__), 'files') }
  let(:skeleton_dir) { '/usr/share/simp/environment-skeleton' }

  context 'on Bolt controller' do
    # Install SIMP and Bolt
    it 'should install SIMP and Bolt rpms' do
      bolt_controller = only_host_with_role(hosts, 'boltserver')
      on(bolt_controller, 'curl -s https://packagecloud.io/install/repositories/simp-project/6_X/script.rpm.sh | sudo bash')
      on(bolt_controller, 'curl -s https://packagecloud.io/install/repositories/simp-project/6_X_Dependencies/script.rpm.sh | sudo bash')
      on(bolt_controller, 'rpm -Uvh https://yum.puppet.com/puppet-tools-release-el-7.noarch.rpm')
      on(bolt_controller, 'yum install -y simp puppet-bolt')
      # This next step is only required until permisions on SIMP modules are changed
      on(bolt_controller, 'chmod -R o+rX /usr/share/simp/modules')
      # This next step is only required until simp-enviroment-skeleton-7.1.1 is released
      on(bolt_controller, "chmod -R o+rX #{skeleton_dir}")
    end

    # Set up the Bolt and SIMP environments from the commandline with a few variable helpers
    let(:bolt_dir) { '/home/vagrant/.puppetlabs/bolt' }
    let(:sec_dir) { '/home/vagrant/secondary' }
    let(:ca_dir) { "#{sec_dir}/bolt/FakeCA" }
    let(:hiera_dir) { "#{bolt_dir}/data" }
    let(:hosts_dir) { "#{hiera_dir}/hosts" }
    let(:prune_command) { "grep ^mod #{bolt_dir}/Puppetfile| while read mod; do sed -i \"/$mod/,+3d\" #{bolt_dir}/Puppetfile.simp; done" }

    it 'should set up the SIMP and Bolt environments' do
      bolt_controller = only_host_with_role(hosts, 'boltserver')
      # Create Boltdir
      # Allowing exit code 1 because of Bolt analytics warning 
      on(bolt_controller, "#{run_cmd} 'bolt puppetfile show-modules 2>&1'", :acceptable_exit_codes => [1])
      # Create the secondary environment directory
      on(bolt_controller, "#{run_cmd} \"mkdir #{sec_dir}\"")
      # Copy the SIMP omni-environment directories from the skeleton 
      on(bolt_controller, "#{run_cmd} \"rsync -a #{skeleton_dir}/puppet/ #{bolt_dir}/\"")
      on(bolt_controller, "#{run_cmd} \"rsync -a #{skeleton_dir}/secondary/ #{sec_dir}/bolt\"")
      # Populate the togen file in the FakeCA dir and generate certs
      togen = []
      hosts.each do |host|
        fqdn = on(host, 'facter fqdn', :accept_all_exit_codes => true).stdout.strip
        togen << fqdn
      end
      create_remote_file(bolt_controller, "#{ca_dir}/togen", togen.join("\n"))
      # Allowing exit code 1 because gencerts_nopass.sh tries to chown files, which vagrant user cannot perform
      on(bolt_controller, "#{run_cmd} \"cd #{ca_dir} && ./gencerts_nopass.sh auto\"", :acceptable_exit_codes => [1])
      # Create Puppetfiles and install modules
      on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && simp puppetfile generate -s > Puppetfile\"")
      on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && simp puppetfile generate > Puppetfile.simp\"")
      # In the following commands, touching the files before scp ensures correct file permissions
      on(bolt_controller, "#{run_cmd} \"touch #{bolt_dir}/updated_modules\"")
      scp_to(bolt_controller, File.join(files_dir, 'updated_modules.example'), "#{bolt_dir}/updated_modules")
      # Add updated modules to the Puppetfile
      on(bolt_controller, "sed -i \"/# Add your own Puppet modules here/r #{bolt_dir}/updated_modules\" #{bolt_dir}/Puppetfile")
      # Remove updated modules from Puppetfile.simp so there are no duplicates
      on(bolt_controller, "#{prune_command}")
      # Install modules
      on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && bolt puppetfile install\"")
      # Copy bolt manifest and Hiera files 
      on(bolt_controller, "#{run_cmd} \"touch #{bolt_dir}/manifests/bolt.pp #{hiera_dir}/default.yaml\"")
      on(bolt_controller, "#{run_cmd} \"touch #{hosts_dir}/bolt-controller.yaml\"")
      scp_to(bolt_controller, File.join(files_dir, 'bolt.pp.example'), "#{bolt_dir}/manifests/bolt.pp")
      scp_to(bolt_controller, File.join(files_dir, 'default.yaml.example'), "#{hiera_dir}/default.yaml")
      scp_to(bolt_controller, File.join(files_dir, 'bolt-controller.yaml.example'), "#{hosts_dir}/bolt-controller.yaml")
      ipaddr = on(bolt_controller, "hostname -I|hostname -I|sed -e 's/\s/,/g'").stdout.strip
      hosts_with_role( hosts, 'target' ).each do |host|
        on(bolt_controller, "#{run_cmd} \"touch #{hosts_dir}/#{host.name}.yaml\"")
        scp_to(bolt_controller, File.join(files_dir, 'target.yaml.example'), "#{hosts_dir}/#{host.name}.yaml")
        # Adding IP addresses because DNS is not configured
        on(bolt_controller, "sed -i \"s/user_allowed_from: [[]/user_allowed_from: [#{ipaddr}/\" #{hosts_dir}/#{host.name}.yaml")
      end
    end

    let (:bolt_command) { 'bolt apply manifests/' }
    let (:initial_bolt_options) { '-u vagrant -p vagrant --run-as root --sudo-password vagrant --no-host-key-check --tmpdir /home/vagrant' }
    let (:simp_config_settings) { 'cli::network::interface=eth1 cli::is_simp_ldap_server=false cli::network::dhcp=static cli::set_grub_password=false svckill::mode=enforcing' }

    it 'should apply SIMP settings to the bolt-controller' do
      bolt_controller = only_host_with_role(hosts, 'boltserver')
      fqdn = on(bolt_controller, 'facter fqdn', :accept_all_exit_codes => true).stdout.strip
      # Apply simp_bolt module on the bolt-controller
      on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && #{bolt_command}bolt.pp #{initial_bolt_options} -n #{fqdn} --transport ssh\"")
      # Set basic SIMP configuration
      # Need to determine how to run simp config as non-root user but in the meantime this provides a few basic settings
      on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && simp config --dry-run -f -D -s #{simp_config_settings}\"")
      on(bolt_controller, "rsync -a /home/vagrant/.simp/simp_conf.yaml #{hiera_dir}/simp_config_settings.yaml")
      # Apply SIMP on the bolt-controller, done twice, permitting failures on first run
      on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && #{bolt_command}site.pp  #{initial_bolt_options} -n #{fqdn}\"", :acceptable_exit_codes => [1])
      on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && #{bolt_command}site.pp  #{initial_bolt_options} -n  #{fqdn}\"")
    end

    let (:bolt_options) { '-p password --no-host-key-check' }

    it 'should apply SIMP settings to the targets' do
      bolt_controller = only_host_with_role(hosts, 'boltserver')
      hosts_with_role( hosts, 'target' ).each do |host|
        fqdn = on(host, 'facter fqdn', :accept_all_exit_codes => true).stdout.strip
        os = fact_on(host,'operatingsystemmajrelease')
        if os.eql?('6')
          # Add hmac-sha1 to the allow ciphers to accomodate el6
          # This could be done via Bolt on the controller but the ssh module appended Host target-el6 to the end of ssh_config, meaning Host * matched first
          on(bolt_controller, "sed -i \"/^Host [\*]/i Host #{fqdn}\" /etc/ssh/ssh_config")
          on(bolt_controller, "sed -i \"/^Host [\*]/i MACs hmac-sha1\" /etc/ssh/ssh_config")
        end
        # Using initial_bolt_options for first run because the simp_bolt user has not been created yet, permitting failures on first run
        on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && #{bolt_command}site.pp  #{initial_bolt_options} -n #{fqdn}\"", :acceptable_exit_codes => [1])
        # Using bolt_options to specify simp_bolt user password and no-host-key-check for ssh
        on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && #{bolt_command}site.pp  #{bolt_options} -n #{fqdn}\"")
      end
    end
  end
end
