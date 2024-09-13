# @summary Configure a system to be managed by Puppet Bolt
#
# @param create_user
#   Create the user on the target system
#
# @param user_name
#   The username to use for remote access
#
#   * Has no effect if ``$create_user`` is ``false``
#
# @param disallowed_users
#   Users that may not be used for the remote ``bolt`` login user
#
# @param user_password
#   The password for the user in passwd-compatible salted hash form
#
#   * Has no effect if ``$create_user`` is ``false``
#
# @param user_home
#   The full path to the user's home directory
#
#   * Has no effect if ``$create_user`` is ``false``
#
# @param user_uid
#   The UID of the user
#
#   * Has no effect if ``$create_user`` is ``false``
#
# @param user_gid
#   The GID of the user
#
#   * Has no effect if ``$create_user`` is ``false``
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
#   If set to ``undef``, will not manage sudo settings on the target system for
#   this user.
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
#   * If empty, will disable the use of pam_access for this user
#
# @param user_max_logins
#   The ``pam_limits`` restricting the number of concurrent sessions permitted for
#   ``username``
#
#   If set to ``undef``, will not restrict the maximum number of logins for the
#   user
#
class simp_bolt::target (
  Boolean                    $create_user                  = false,
  String[1]                  $user_name                    = $simp_bolt::target_user_name,
  Array[String[1]]           $disallowed_users             = ['root'],
  Optional[String[8]]        $user_password                = undef,
  Stdlib::Unixpath           $user_home                    = $simp_bolt::target_user_home,
  Integer[500]               $user_uid                     = 1779,
  Integer[500]               $user_gid                     = $user_uid,
  Optional[Array[String[1]]] $user_ssh_authorized_keys     = undef,
  String[1]                  $user_ssh_authorized_key_type = 'ssh-rsa',
  Optional[String[1]]        $user_sudo_user               = getvar(simp_bolt::target_sudo_user),
  Boolean                    $user_sudo_password_required  = false,
  Array[String[1],1]         $user_sudo_commands           = ['ALL'],
  Array[String[1]]           $user_allowed_from            = [pick(fact('puppet_server'), 'LOCAL')],
  Integer[1]                 $user_max_logins              = 2
) {
  assert_private()

  if $user_name in $disallowed_users {
    $_err_str = join($disallowed_users, "', '")
    fail("Due to security ramifications, '\$user_name' cannot be one of '${_err_str}'")
  }

  if $create_user{
    unless ($user_password or $user_ssh_authorized_keys) {
      fail("You must specify either 'simp_bolt::target::user_password' or 'simp_bolt::target::user_ssh_authorized_keys'")
    }
  }

  include 'simp_bolt::target::user'
}
