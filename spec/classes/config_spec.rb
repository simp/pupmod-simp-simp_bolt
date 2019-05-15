require 'spec_helper'
require 'rspec-puppet-facts'

describe 'simp_bolt::controller::config' do
  shared_examples_for "a structured module" do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('simp_bolt::controller::config') }

  end

  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do

        let(:facts) do
          os_facts
        end

        before(:each) do
          # Mask 'assert_private' for testing
          Puppet::Parser::Functions.newfunction(:assert_private, :type => :rvalue) { |args| }
        end

        # Requires variable set in init.pp, so including here
        let(:pre_condition) { 'include simp_bolt' }

#        context 'with no transport options or config hash' do
#          let(:params) {{
#            :transport_options => :undef
#          }}
#          it "is expected to fail" do
#            expect { catalogue }.to raise_error Puppet::PreformattedError, /You must specify transport options/
#          end
#        end

        context 'with default parameters' do
          it_behaves_like "a structured module"
          it { is_expected.to contain_exec('Create Local Bolt Home').with_command('mkdir -p /var/local/simp_bolt') }
          it { is_expected.to create_file('/var/local/simp_bolt/puppetlabs') }
          it { is_expected.to create_file('/var/local/simp_bolt/puppetlabs/bolt') }
          it { is_expected.to create_file('/var/local/simp_bolt/puppetlabs/bolt/bolt.yaml') }
          it { is_expected.to create_file('/var/local/simp_bolt/puppetlabs/bolt/analytics.yaml') }
          it { is_expected.to create_file_line('analytics_yaml') }
          it { is_expected.to contain_exec('Create Bolt Log Dir').with_command('mkdir -p /var/log/puppetlabs/bolt') }
          it { is_expected.not_to create_file('/var/log/puppetlabs/bolt') }
        end

        context 'with a local user specified' do
          let(:params) {{
            :local_user  => 'user',
            :local_group => 'user',
            :local_home  => '/home/user'
          }}
          it_behaves_like "a structured module"
          it { is_expected.to contain_exec('Create Local Bolt Home').with_command('mkdir -p /home/user') }
          it { is_expected.to create_file('/home/user/.puppetlabs') }
          it { is_expected.to create_file('/home/user/.puppetlabs/bolt') }
          it { is_expected.to create_file('/home/user/.puppetlabs/bolt/bolt.yaml') }
          it { is_expected.to create_file('/home/user/.puppetlabs/bolt/analytics.yaml') }
          it { is_expected.to create_file_line('analytics_yaml') }
          it { is_expected.to contain_exec('Create Bolt Log Dir').with_command('mkdir -p /var/log/puppetlabs/bolt') }
          it { is_expected.to create_file('/var/log/puppetlabs/bolt') }
        end

      end
    end
  end
end
