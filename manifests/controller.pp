# Installs and configures Puppet Bolt for use within the SIMP enviroment
#
# @param local_user_name
#   The username of the local user account to launch bolt commands
#
# @param local_group_name
#   The default group name of the local user account
#
# @param local_user_home
#   The full path to the local user's home directory
#
# @author SIMP Team <https://simp-project.com/>
#
class simp_bolt::controller (
  Optional[String]           $local_user_name  = undef,
  Optional[String]           $local_group_name = undef,
  Optional[Stdlib::Unixpath] $local_user_home  = undef,
) {
  assert_private()

  include '::simp_bolt::controller::install'
  include '::simp_bolt::controller::config'

  Class[ '::simp_bolt::controller::install' ]
    -> Class[ '::simp_bolt::controller::config' ]

}

