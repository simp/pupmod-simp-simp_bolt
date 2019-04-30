# @summary Installs and configures Puppet Bolt for use within the SIMP enviroment
#
# @param bolt_controller
#   If true, will install and configure the Puppet Bolt package
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

  # Target class must be included to determine the name of specified user
  # account on the target systems for configuring the controller class
  if $bolt_target or $bolt_controller {
    include 'simp_bolt::target'
  }

  if $bolt_controller {
    include 'simp_bolt::controller'

    Class[ 'simp_bolt::target' ]
      -> Class[ 'simp_bolt::controller' ]
  }
}
