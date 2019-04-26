# Configure a system to be managed by Puppet Bolt
#
# @param user_name
#   The username to use for remote access
#
# @param manage_user
#   Create and manage the local user account
#
# @param user_password
#   The password for the user in passwd-compatible salted hash form
#
# @param user_home
#   The full path to the user's home directory
#
# @param user_uid
#   The UID of the user
#
# @param user_gid
#   The GID of the user
#
# @param user_ssh_authorized_keys
#   The SSH public key for authorized Bolt users
#
#   * See the native ``ssh_authorized_key`` resource definition for details
#
# @param user_ssh_authorized_key_type
#   The SSH public key type
#
#   * See the native ``ssh_authorized_key`` resource definition for details
#
# @param user_sudo_user
#   The user that the ``username`` user may escalate to
#
# @param user_sudo_password_required
#   Require password for user to sudo
#
# @param user_sudo_commands
#   The commands that the ``username`` user is allowed to execute via sudo as one
#   of the allowed users
#
# @param user_allowed_from
#   The ``pam_access`` compatible locations that the user will be logging in
#   from
#
#   * Set to ``['ALL']`` to allow from any location
#
# @param user_max_logins
#   The ``pam_limits`` restricting the number of concurrent sessions permitted for
#   ``username``
#
class simp_bolt::target (
  Boolean                    $enable_user                  = false,
  String                     $user_name                    = 'simp_bolt',
  Boolean                    $manage_user_security         = false,
  Optional[String[8]]        $user_password                = undef,
  Pattern['^/']              $user_home                    = "/var/local/${user_name}",
  Integer                    $user_uid                     = 1779,
  Integer                    $user_gid                     = $user_uid,
  Optional[Array[String[1]]] $user_ssh_authorized_keys     = undef,
  String[1]                  $user_ssh_authorized_key_type = 'ssh-rsa',
  String                     $user_sudo_user               = 'root',
  Boolean                    $user_sudo_password_required  = false,
  Array[String]              $user_sudo_commands           = ['ALL'],
  Array[String]              $user_allowed_from            = [ $facts['puppet_server'] ],
  Integer                    $user_max_logins              = 1
) {
  assert_private()

  if $enable_user{
    unless ($user_password or $user_ssh_authorized_keys) {
      fail("You must specify either 'simp_bolt::target::user_password' or 'simp_bolt::target::user_ssh_authorized_keys'")
    }
  }

  if $manage_user_security{
    if $user_name == 'root' {
      fail('Due to restrictions on the Bolt user, you must use a different account than root')
    }
  }

  if $simp_bolt::bolt_target{
    include '::simp_bolt::target::user'
  }
}
