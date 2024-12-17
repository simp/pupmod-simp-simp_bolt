require 'spec_helper'
require 'rspec-puppet-facts'

describe 'simp_bolt::target::user' do
  shared_examples_for 'a structured module' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('simp_bolt::target::user') }
  end

  shared_examples_for 'a simp_bolt user' do
    it { is_expected.to create_user('simp_bolt') }
    it { is_expected.to create_group('simp_bolt') }
    it { is_expected.to create_file('/var/local/simp_bolt') }
    it { is_expected.to create_pam__access__rule('allow_simp_bolt') }
  end

  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        before(:each) do
          # Mask 'assert_private' for testing
          Puppet::Parser::Functions.newfunction(:assert_private, type: :rvalue) { |args| }
        end

        let(:facts) do
          os_facts
        end

        # Requires variable set in init.pp, so including here
        let(:pre_condition) { 'include simp_bolt' }

        # Set parameters inherited from variables in parent classes to default values
        let(:params) do
          {
            create: false,
         username: 'simp_bolt',
         password: :undef,
         home: '/var/local/simp_bolt',
         uid: 1779,
         gid: 1779,
         ssh_authorized_keys: :undef,
         ssh_authorized_key_type: 'ssh-rsa',
         sudo_user: 'root',
         sudo_password_required: false,
         sudo_commands: ['ALL'],
         allowed_from: ['puppet_server'],
         max_logins: 2
          }
        end

        let(:facts) do
          os_facts.merge({
                           'simplib__sshd_config' => {
                             'AuthorizedKeysFile' => '.ssh/authorized_keys'
                           }
                         })
        end

        context 'with create false' do
          context 'and default parameters' do
            it_behaves_like 'a structured module'
            it { is_expected.not_to create_user('simp_bolt') }
            it { is_expected.not_to create_group('simp_bolt') }
            it { is_expected.not_to create_file('/var/local/simp_bolt') }
            it { is_expected.not_to create_pam__access__rule('allow_simp_bolt') }
            it { is_expected.to contain_exec('Create /var/local/simp_bolt').with_command('mkdir -p /var/local/simp_bolt') }
            it { is_expected.to create_pam__limits__rule('limit_simp_bolt') }
            it { is_expected.to create_sudo__user_specification('simp_bolt') }
          end

          context 'and a password' do
            let(:params) { super().merge(password: 'password_hash') }

            it_behaves_like 'a structured module'
            it { is_expected.not_to create_user('simp_bolt') }
            it { is_expected.not_to create_group('simp_bolt') }
            it { is_expected.not_to create_file('/var/local/simp_bolt') }
            it { is_expected.not_to create_pam__access__rule('allow_simp_bolt') }
            it { is_expected.to contain_exec('Create /var/local/simp_bolt').with_command('mkdir -p /var/local/simp_bolt') }
          end

          context 'with a ssh_authorized_key' do
            let(:params) { super().merge(ssh_authorized_keys: ['ssh_authorized_key']) }

            it_behaves_like 'a structured module'
            it { is_expected.not_to create_user('simp_bolt') }
            it { is_expected.not_to create_group('simp_bolt') }
            it { is_expected.not_to create_file('/var/local/simp_bolt') }
            it { is_expected.not_to create_pam__access__rule('allow_simp_bolt') }
            it { is_expected.to contain_exec('Create /var/local/simp_bolt').with_command('mkdir -p /var/local/simp_bolt') }
            it { is_expected.to create_ssh_authorized_key('simp_bolt0').with_key('ssh_authorized_key') }
          end

          context 'with no sudo user' do
            let(:params) { super().merge(sudo_user: :undef) }

            it_behaves_like 'a structured module'
            it { is_expected.not_to create_sudo__user_specification('simp_bolt') }
          end
        end

        context 'with create set to true' do
          context 'and a password' do
            let(:params) do
              super().merge(
              create: true,
              password: 'password_hash',
            )
            end

            it_behaves_like 'a structured module'
            it_behaves_like 'a simp_bolt user'
          end

          context 'and a ssh_authorized_key' do
            let(:params) do
              super().merge(
              create: true,
              ssh_authorized_keys: ['ssh_authorized_key'],
            )
            end

            it_behaves_like 'a structured module'
            it_behaves_like 'a simp_bolt user'
            it { is_expected.to create_ssh_authorized_key('simp_bolt0').with_key('ssh_authorized_key') }
          end

          context 'and multiple ssh_authorized_keys' do
            let(:params) do
              super().merge(
              create: true,
              ssh_authorized_keys: ['ssh', 'authorized', 'key'],
            )
            end

            it_behaves_like 'a structured module'
            it_behaves_like 'a simp_bolt user'
            it { is_expected.to create_ssh_authorized_key('simp_bolt0').with_key('ssh') }
            it { is_expected.to create_ssh_authorized_key('simp_bolt1').with_key('authorized') }
            it { is_expected.to create_ssh_authorized_key('simp_bolt2').with_key('key') }
          end

          context 'and a password and a ssh_authorized_keys' do
            let(:params) do
              super().merge(
              create: true,
              password: 'password_hash',
              ssh_authorized_keys: ['ssh_authorized_key'],
            )
            end

            it_behaves_like 'a structured module'
            it_behaves_like 'a simp_bolt user'
            it { is_expected.to create_ssh_authorized_key('simp_bolt0').with_key('ssh_authorized_key') }
          end

          context 'with allowed from multiple systems' do
            let(:params) do
              super().merge(
              create: true,
              allowed_from: ['system1', 'system2'],
            )
            end

            it_behaves_like 'a structured module'
            it_behaves_like 'a simp_bolt user'
          end
        end
      end
    end
  end
end
