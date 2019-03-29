require 'spec_helper'

describe 'simp_bolt' do
  shared_examples_for "a structured module" do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('simp_bolt') }
    it { is_expected.to contain_class('simp_bolt') }
    it { is_expected.to contain_class('simp_bolt::install').that_comes_before('Class[simp_bolt::config]') }
    it { is_expected.to contain_class('simp_bolt::config') }
    it { is_expected.to contain_class('simp_bolt::service').that_subscribes_to('Class[simp_bolt::config]') }

    it { is_expected.to contain_service('simp_bolt') }
    it { is_expected.to contain_package('simp_bolt').with_ensure('present') }
  end

  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          os_facts
        end

        context "simp_bolt class without any parameters" do
          let(:params) {{ }}
          it_behaves_like "a structured module"
          it { is_expected.to contain_class('simp_bolt').with_trusted_nets(['127.0.0.1/32']) }
        end

        context "simp_bolt class with firewall enabled" do
          let(:params) {{
            :enable_firewall => true
          }}

          ###it_behaves_like "a structured module"
          it { is_expected.to contain_class('simp_bolt::config::firewall') }

          it { is_expected.to contain_class('simp_bolt::config::firewall').that_comes_before('Class[simp_bolt::service]') }
          it { is_expected.to create_iptables__listen__tcp_stateful('allow_simp_bolt_tcp_connections').with_dports(9999)
          }
        end

        context "simp_bolt class with auditing enabled" do
          let(:params) {{
            :enable_auditing => true
          }}

          ###it_behaves_like "a structured module"
          it { is_expected.to contain_class('simp_bolt::config::auditing') }
          it { is_expected.to contain_class('simp_bolt::config::auditing').that_comes_before('Class[simp_bolt::service]') }
          it { is_expected.to create_notify('FIXME: auditing') }
        end

        context "simp_bolt class with logging enabled" do
          let(:params) {{
            :enable_logging => true
          }}

          ###it_behaves_like "a structured module"
          it { is_expected.to contain_class('simp_bolt::config::logging') }
          it { is_expected.to contain_class('simp_bolt::config::logging').that_comes_before('Class[simp_bolt::service]') }
          it { is_expected.to create_notify('FIXME: logging') }
        end
      end
    end
  end

  context 'unsupported operating system' do
    describe 'simp_bolt class without any parameters on Solaris/Nexenta' do
      let(:facts) {{
        :os => {
          :family => 'Solaris',
          :name   => 'Nexenta'
        }
      }}

      it { expect { is_expected.to contain_package('simp_bolt').to raise_error(/OS 'Nexenta' is not supported/) } }
    end
  end
end
