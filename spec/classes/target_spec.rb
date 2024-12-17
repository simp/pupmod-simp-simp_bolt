require 'spec_helper'
require 'rspec-puppet-facts'

describe 'simp_bolt::target' do
  shared_examples_for 'a structured module' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('simp_bolt::target') }
    it { is_expected.to contain_class('simp_bolt::target::user') }
  end

  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          os_facts
        end
        # Target class invokes user.pp, which references variable set in init.pp, so including here
        let(:pre_condition) { 'include simp_bolt' }

        before(:each) do
          # Mask 'assert_private' for testing
          Puppet::Parser::Functions.newfunction(:assert_private, type: :rvalue) { |args| }
        end

        context 'with a disallowed user specified' do
          let(:params) do
            {
              user_name: 'root',
           user_home: '/var/local/${user_name}',
            }
          end

          it 'is expected to fail' do
            expect { catalogue }.to raise_error Puppet::PreformattedError, %r{Due to security ramifications,}
          end
        end

        context 'with no password or ssh authorized keys' do
          let(:params) do
            {
              create_user: true,
           user_name: 'simp_bolt',
           user_home: '/var/local/${user_name}',
            }
          end

          it 'is expected to fail' do
            expect { catalogue }.to raise_error Puppet::PreformattedError, %r{You must specify either 'simp_bolt::target::user_password' or 'simp_bolt::target::user_ssh_authorized_keys'}
          end
        end

        context 'with a password specified' do
          let(:params) do
            {
              create_user: true,
           user_name: 'simp_bolt',
           user_home: '/var/local/${user_name}',
           user_password: 'password_hash',
            }
          end

          it_behaves_like 'a structured module'
        end

        context 'with a ssh authorized keys specified' do
          let(:facts) do
            os_facts.merge({
                             'simplib__sshd_config' => {
                               'AuthorizedKeysFile' => '.ssh/authorized_keys'
                             }
                           })
          end

          let(:params) do
            {
              create_user: true,
           user_name: 'simp_bolt',
           user_home: '/var/local/${user_name}',
           user_sudo_user: 'root',
           user_ssh_authorized_keys: ['ssh', 'authorized', 'keys']
            }
          end

          it_behaves_like 'a structured module'
        end
      end
    end
  end
end
