# @summary Installs and configures Puppet Bolt for use within the SIMP environment
#
# This class will not do anything on the target system by default. You must
# opt-in to adding either the controller or the target configuration.
#
# @param target_user_name
#   The username of the account to use on target systems
#
# @param target_user_home
#   The full path to the user's home directory on target systems
#
# @param target_sudo_user
#   The user that the ``username`` user may escalate to on target systems
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
  String[1]           $target_user_name      = 'simp_bolt',
  Stdlib::Unixpath    $target_user_home      = "/var/local/${target_user_name}",
  Optional[String[1]] $target_sudo_user      = 'root',
  Boolean             $bolt_controller       = false,
  Boolean             $bolt_target           = false,
  String              $package_name          = 'puppet-bolt'
) {

  simplib::assert_metadata($module_name)

  if $bolt_target {
    include 'simp_bolt::target'
  }

  if $bolt_controller {
    include 'simp_bolt::controller'
  }
}
