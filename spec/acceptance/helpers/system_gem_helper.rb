module Acceptance::Helpers::SystemGemHelper
  def install_system_factor_gem(host)
    host.install_package('rubygems')
    on(host, %(/usr/bin/gem install facter --version '< 4.0.0'))

    # beaker-helper fact_on() now uses '--json' on facter calls, so
    # we need to make sure the json gem is installed
    result = on(host, 'facter --json fqdn', accept_all_exit_codes: true)
    return unless result.exit_code != 0
    # We have old system Ruby (1.8.7) which does not include json.  So,
    # install the pure-Ruby version of json.
    on(host, "gem install json_pure --version '<2.0.0'")
  end
end
