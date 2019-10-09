require 'spec_helper_acceptance'

test_name 'Install Bolt and SIMP modules'

describe 'Install Bolt and SIMP modules' do

  let(:run_cmd) {'runuser vagrant -c '}
  let(:files_dir) { File.join(File.dirname(__FILE__), 'files') }
  let(:skeleton_dir) { '/usr/share/simp/environment-skeleton' }

  context 'on Bolt controller' do
    # Install SIMP and Bolt
    it 'should install SIMP and Bolt' do
      bolt_controller = only_host_with_role(hosts, 'boltserver')
      on(bolt_controller, 'rpm -Uvh https://yum.puppet.com/puppet-tools-release-el-7.noarch.rpm')
      on(bolt_controller, 'yum install -y simp puppet-bolt')
      # This next step is only required until permisions on SIMP modules are changed
      on(bolt_controller, 'chmod -R o+rX /usr/share/simp/modules')
      # This next step is only required until simp-enviroment-skeleton-7.1.1 is released
      on(bolt_controller, "chmod -R o+rX #{skeleton_dir}")
    end

    # We'll set up the Bolt and SIMP environments from the commandline
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
      # Copy togen file to the FakeCA dir and generate certs
      scp_to(bolt_controller, File.join(files_dir, 'togen.example'), "#{ca_dir}/togen")
      # Allowing exit code 1 because gencerts_nopass.sh tries to chown files, which vagrant user cannot perform
      on(bolt_controller, "#{run_cmd} \"cd #{ca_dir} && ./gencerts_nopass.sh auto\"", :acceptable_exit_codes => [1])

      # Create Puppetfiles and install modules
      # In the following sections, touching the files before scp ensures file permissions
      on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && simp puppetfile generate -s > Puppetfile\"")
      on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && simp puppetfile generate > Puppetfile.simp\"")
      on(bolt_controller, "#{run_cmd} \"touch #{bolt_dir}/updated_modules\"")
      scp_to(bolt_controller, File.join(files_dir, 'updated_modules.example'), "#{bolt_dir}/updated_modules")
      on(bolt_controller, "sed -i \"/# Add your own Puppet modules here/r #{bolt_dir}/updated_modules\" #{bolt_dir}/Puppetfile")
      on(bolt_controller, "#{prune_command}")
      on(bolt_controller, "#{run_cmd} \"cd #{bolt_dir} && bolt puppetfile install\"")

      # Copy bolt manifest and Hiera files 
      on(bolt_controller, "#{run_cmd} \"touch #{bolt_dir}/manifests/bolt.pp #{hiera_dir}/default.yaml\"")
      on(bolt_controller, "#{run_cmd} \"touch #{hosts_dir}/bolt-controller.yaml #{hosts_dir}/target-el7.yaml\"")
      scp_to(bolt_controller, File.join(files_dir, 'bolt.pp.example'), "#{bolt_dir}/manifests/bolt.pp")
      scp_to(bolt_controller, File.join(files_dir, 'default.yaml.example'), "#{hiera_dir}/default.yaml")
      scp_to(bolt_controller, File.join(files_dir, 'bolt-controller.yaml.example'), "#{hosts_dir}/bolt-controller.yaml")
      scp_to(bolt_controller, File.join(files_dir, 'target-el7.yaml.example'), "#{hiera_dir}/target-el7.yaml")
    end

  end
end
