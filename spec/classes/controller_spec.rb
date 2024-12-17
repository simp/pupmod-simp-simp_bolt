require 'spec_helper'
require 'rspec-puppet-facts'

describe 'simp_bolt::controller' do
  shared_examples_for 'a structured module' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('simp_bolt::controller') }
    it { is_expected.to contain_class('simp_bolt::controller::install').that_comes_before('Class[simp_bolt::controller::config]') }
    it { is_expected.to contain_package('puppet-bolt').with_ensure('present') }
    it { is_expected.to contain_class('simp_bolt::controller::config') }
  end

  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          os_facts
        end
        # Target class invokes user.pp, which references variable set in init.pp, so including here
        let(:pre_condition) { "class{'simp_bolt': bolt_controller => false}" }

        before(:each) do
          # Mask 'assert_private' for testing
          Puppet::Parser::Functions.newfunction(:assert_private, type: :rvalue) { |args| }
        end

        context 'with default parameter' do
          it_behaves_like 'a structured module'
        end
      end
    end
  end
end
