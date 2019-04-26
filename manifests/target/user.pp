# NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# Configure a 'simp_bolt' system user
#
# @param username
#   The username to use for remote access
#
# @param password
#   The password for the user in passwd-compatible salted hash form
#
# @param home
#   The full path to the user's home directory
#
# @param uid
#   The UID of the user
#
# @param gid
#   The GID of the user
#
# @param ssh_authorized_key
#   The SSH public key for the user
#
#   * See the native ``ssh_authorized_key`` resource definition for details
#
# @param ssh_authorized_key_type
#   The SSH public key type
#
#   * See the native ``ssh_authorized_key`` resource definition for details
#
# @param sudo_users
#   The users that the ``username`` user may escalate to
#
# @param sudo_password_required
#   Require password for user to sudo
#
# @param sudo_commands
#   The commands that the ``username`` user is allowed to execute via sudo as one
#   of the allowed users
#
# @param allowed_from
#   The ``pam_access`` compatible locations that the user will be logging in
#   from
#
#   * Set to ``['ALL']`` to allow from any location
#
# @param max_logins
#   The ``pam_limits`` restricting the number of concurrent sessions permitted for
#   ``username``
#
class simp_bolt::target::user (
  Boolean                    $enable                  = $simp_bolt::target::enable_user,
  String                     $username                = $simp_bolt::target::user_name,
  Boolean                    $manage                  = $simp_bolt::target::manage_user_security,
  Optional[String[8]]        $password                = $simp_bolt::target::user_password,
  Pattern['^/']              $home                    = $simp_bolt::target::user_home,
  Integer                    $uid                     = $simp_bolt::target::user_uid,
  Integer                    $gid                     = $simp_bolt::target::user_gid,
  Optional[Array[String[1]]] $ssh_authorized_keys     = $simp_bolt::target::user_ssh_authorized_keys,
  String[1]                  $ssh_authorized_key_type = $simp_bolt::target::user_ssh_authorized_key_type,
  String                     $sudo_user               = $simp_bolt::target::user_sudo_user,
  Boolean                    $sudo_password_required  = $simp_bolt::target::user_sudo_password_required,
  Array[String]              $sudo_commands           = $simp_bolt::target::user_sudo_commands,
  Array[String]              $allowed_from            = $simp_bolt::target::user_allowed_from,
  Integer                    $max_logins              = $simp_bolt::target::user_max_logins
) {
  assert_private()

  $_ensure = $enable ? {
    true    => 'present',
    default => 'absent'
  }

  if $enable{

    file { $home:
      owner   => $username,
      group   => $username,
      mode    => '0640',
      seltype => 'user_home_dir_t'
    }

    group { $username:
      ensure => $_ensure,
      gid    => $gid
    }

    user { $username:
      ensure         => $_ensure,
      password       => $password,
      comment        => 'SIMP Bolt User',
      uid            => $uid,
      gid            => $gid,
      home           => $home,
      managehome     => true,
      purge_ssh_keys => true
    }

    $ssh_authorized_keys.each |String $key| {
      ssh_authorized_key { $key[-20,20]:
        ensure => $_ensure,
        key    => $key,
        type   => $ssh_authorized_key_type,
        user   => $username
      }
    }

# Set selinux context of ssh authorized_key file
    if $ssh_authorized_keys {
      if $facts['simplib__sshd_config']['AuthorizedKeysFile'] !~ '^/' {
        $_ssh_authorizedkeysfile = "${home}/${facts['simplib__sshd_config']['AuthorizedKeysFile']}"
      } else {
        $_ssh_authorizedkeysfile = regsubst($facts['simplib__sshd_config']['AuthorizedKeysFile'], '%u', $username, 'G')
      }
      file { $_ssh_authorizedkeysfile:
        seltype => 'sshd_key_t'
      }
    }
  }

  if $manage{

    simplib::assert_optional_dependency($module_name, 'simp/pam')

# Restrict login for user ssh to only specified Bolt servers 
# If system is also a Bolt server, allow login from localhost 
    if $::simp_bolt::bolt_controller {
      $_allowed_from = ['LOCAL'] + $allowed_from
    } else {
      $_allowed_from = $allowed_from
    }
    pam::access::rule { "allow_${username}":
      users   => [$username],
      origins => $_allowed_from,
      comment => 'SIMP BOLT user, restricted to remote access from specified BOLT systems'
    }

# Include an extra login session on the server to allow for running Bolt on itself
    if $::simp_bolt::bolt_controller {
      $_max_logins = $max_logins + 1
    } else {
      $_max_logins = $max_logins
    }
    pam::limits::rule { "limit_${username}":
      domains => [$username],
      type    => 'hard',
      item    => 'maxlogins',
      value   => $_max_logins
    }

    simplib::assert_optional_dependency($module_name, 'simp/sudo')

    sudo::user_specification { $username:
      user_list => [$username],
      runas     => $sudo_user,
      cmnd      => $sudo_commands,
      passwd    => $sudo_password_required
    }
  }
}
