# Installs and configures Puppet Bolt for use within the SIMP enviroment
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
