require 'spec_helper'
require 'rspec-puppet-facts'

describe 'simp_bolt::target::user' do
  shared_examples_for "a structured module" do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('simp_bolt::target::user') }
  end

  shared_examples_for "a simp_bolt user" do
    it { is_expected.to create_user('simp_bolt') }
    it { is_expected.to create_group('simp_bolt') }
    it { is_expected.to create_file('/var/local/simp_bolt') }
    it { is_expected.to create_sudo__user_specification('simp_bolt') }
  end


  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do

        before(:each) do
          # Mask 'assert_private' for testing
          Puppet::Parser::Functions.newfunction(:assert_private, :type => :rvalue) { |args| }
        end

        let(:facts) do
          os_facts
        end

#        let(:hieradata) { 'password' }

        # Set variables inherited from parent classes
        let(:pre_condition) { [
          "class{'simp_bolt':
            bolt_controller => false
          }",
          "class{'simp_bolt::target':
            create_user                  => false,
#            user_name                    => 'simp_bolt',
#            user_password                => undef,
#            user_home                    => '/var/local/simp_bolt',
#            user_uid                     => 1779,
#            user_gid                     => 1779,
#            user_ssh_authorized_keys     => undef,
#            user_ssh_authorized_key_type => 'ssh-rsa',
#            user_sudo_user               => 'root',
#            user_sudo_password_required  => false,
#            user_sudo_commands           => ['ALL'],
#            user_allowed_from            => ['puppet_server'],
#            user_max_logins              => 2
          }"
        ] }

        context 'with defaults' do
          let(:facts) do
            os_facts.merge({
              'simplib__sshd_config' => {
                'AuthorizedKeysFile' => '.ssh/authorized_keys'
              }
            })
          end
          context 'and a password' do
            let(:params) {{
              :create   => true,
              :password => 'password_hash',
            }}
            it_behaves_like "a structured module"
            it_behaves_like "a simp_bolt user"
          end
          context 'and a ssh_authorized_key' do
            let(:params) {{
              :create              => true,
              :ssh_authorized_keys => ['ssh_authorized_key'],
            }}
            it_behaves_like "a structured module"
            it_behaves_like "a simp_bolt user"
            it { is_expected.to create_ssh_authorized_key} #(params[:username]).with_key(params[:user_ssh_authorized_keys]) }
          end
          context 'and multiple ssh_authorized_keys' do
            let(:params) {{
              :create              => true,
              :ssh_authorized_keys => ['ssh','authorized','key']
            }}
            it_behaves_like "a structured module"
            it_behaves_like "a simp_bolt user"
          end
          context 'and a password and a ssh_authorized_keys' do
            let(:params) {{
              :create              => true,
              :password            => 'password_hash',
              :ssh_authorized_keys => ['ssh_authorized_key']
            }}
            it_behaves_like "a structured module"
            it_behaves_like "a simp_bolt user"
          end

        end
      end
    end
  end
end
