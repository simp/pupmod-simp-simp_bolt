# Installs and configures Puppet Bolt for use within the SIMP enviroment
#
# === Welcome to SIMP!
#
# This module is a component of the System Integrity Management Platform, a
# managed security compliance framework built on Puppet.
#
# This module is optimally designed for use within a larger SIMP ecosystem, but
# it can be used independently:
#
# * When included within the SIMP ecosystem, security compliance settings will
#   be managed from the Puppet server.
#
# * If used independently, all SIMP-managed security subsystems are disabled by
#   default, and must be explicitly opted into by administrators.  Please
#   review the +trusted_nets+ and +$enable_*+ parameters for details.
#
# @param bolt_server
#   If true, will install and configure the Puppet Bolt package
#
# @param package_name
#   The name of the Puppet Bolt rpm package
#
# @author SIMP Team <https://simp-project.com/>
# 
class simp_bolt (
  Boolean  $bolt_server  = false,
  String   $package_name = 'puppet-bolt'
) {

  simplib::assert_metadata($module_name)

  include '::simp_bolt::user'

  if $bolt_server {
    include '::simp_bolt::install'
    include '::simp_bolt::config'

    Class[ '::simp_bolt::user' ]
    -> Class[ '::simp_bolt::install' ]
      -> Class[ '::simp_bolt::config' ]
  }

}
