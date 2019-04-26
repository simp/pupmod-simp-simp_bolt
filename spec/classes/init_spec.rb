require 'spec_helper'
require 'rspec-puppet-facts'

describe 'simp_bolt' do
  shared_examples_for "a structured module" do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('simp_bolt') }
    it { is_expected.to contain_class('simp_bolt') }
    it { is_expected.to contain_class('simp_bolt::target') }
  end


  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          os_facts.merge({
          :puppet_server => 'puppet',
          :simplib__sshd_config => {'authorizedkeysfile' => '.ssh/authorized_keys'}
          })
        end
        let(:hieradata) { 'password' }

        context "simp_bolt class without any parameters" do
          it_behaves_like "a structured module"
          it { is_expected.not_to contain_class('simp_bolt::controller') }
        end

        context "simp_bolt class with bolt_controller specified" do
          let(:params) {{
            :bolt_controller => true
          }}

          it_behaves_like "a structured module"
          it { is_expected.to contain_class('simp_bolt::controller') }
        end
      end
    end
  end
end
