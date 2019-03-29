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
# @param package_name
#   The name of the simp_bolt package
#
# @param trusted_nets
#   A whitelist of subnets (in CIDR notation) permitted access
#
# @param enable_auditing
#   If true, manage auditing for simp_bolt
#
# @param enable_firewall
#   If true, manage firewall rules to acommodate simp_bolt
#
# @param enable_logging
#   If true, manage logging configuration for simp_bolt
#
# @author SIMP Team
#
class simp_bolt (
  String                        $package_name       = 'puppet-bolt',
) {

  simplib::assert_metadata($module_name)

  include '::simp_bolt::install'
  include '::simp_bolt::config'

  Class[ '::simp_bolt::install' ]
  -> Class[ '::simp_bolt::config' ]

}
