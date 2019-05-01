# @summary Installs and configures Puppet Bolt for use within the SIMP enviroment
#
# This class will not do anything on the target system by default. You must
# opt-in to adding either the controller or the target configuration.
#
# @param bolt_controller
#   Install and configure Puppet Bolt.
#
#   * Configuration specifics should be managed via the
#     ``simp_bolt::controller`` parameters.
#
# @param bolt_target
#   Configure the system as a target for Bolt management
#
#   * Configuration specifics should be managed via the
#     ``simp_bolt::target`` parameters.
#
# @param package_name
#   The name of the Puppet Bolt rpm package
#
# @author SIMP Team <https://simp-project.com/>
#
class simp_bolt (
  Boolean  $bolt_controller = false,
  Boolean  $bolt_target     = false,
  String   $package_name    = 'puppet-bolt'
) {

  simplib::assert_metadata($module_name)

  if $bolt_target {
    include 'simp_bolt::target'
  }

  if $bolt_controller {
    include 'simp_bolt::controller'
  }
}
