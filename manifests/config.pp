# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#

# == Class simp_bolt::config
#
# Setup Bolt configuration
#   - Set the global configuration and transport options for Bolt.  Addtional details on the
#     options can be found at https://puppet.com/docs/bolt/latest/bolt_configuration_options.html.
#
# @param modulepath
#    The module path for loading tasks and plan code, formatted as a string containing a list
#    directories.  The first directory listed will be the default for downloaded modules.  The
#    default is "/etc/puppetlabs/bolt-code/modules:~/.puppetlabs/bolt-code/site-modules:
#    /etc/puppetlabs/code/environments/simp/modules"
#
# @param color
#    Wheter to use colored output when printing messages to the console.  By default this is true.
#
# @param concurrency
#    The number of threads to use when executing on remote nodes.  By default this is 100.
#
# @param format
#   The format to use when printing results; either human or json.  By default this is human.
#
# @param hiera-config
#   The path to the Hiera config file.  The default is set to /etc/puppetlabs/code/environments/simp/
#   hiera.yaml.
#
# @param inventoryfile
#   Path to  a structured data inventory file used to refer to groups of nodes on the command
#   line and from plans.  By default this is to /etc/puppetlabs/bolt/inventory.yaml
#
# @param transport
#   The default transport to use when not specified in the URL or inventory.  Valid options
#   for transport are docker, local, pcp, ssh, and winrm.  By default this is ssh.
#
# @param ssh_host-key-check
#   Whether to perform host key validation when connecting over SSH.  By default this is true.
#
# @param ssh_password
#   Login password for the remote system.
#
# @param ssh_port
#   Connection port.  By default this is 22.
#
# @param ssh_private-key
#   The path to the private key file to use for SSH authentication.
#
# @param ssh_proxyjump
#   A jump host to proxy SSH connections through.
#
# @param ssh_tmpdir
#   The directory to upload and execute temporarty files on the target system.  The default
#   is /var/local.
#
# @param ssh_user
#   Login user.  The default is root.
#
# @param ssh_run-as
#   A different user to run commands as afterlogin.
#
# @log_console_level
#   The type of information to display on the console.  Valid options are debug, info, notice,
#   warn, and error.  The default is info.
#
# @log_file
#   The path and name of the log file.
#
# @log_file_level
#   The type of information to record in the log file.  Valid options are debug, info, notice,
#   warn, and error.  By default this is info.
#
# @log_file_append
#   Add output to an existing log file. By default this is true (default).
#
# @param disable_analytics
#   A different user to run commands as afterlogin.
#
class simp_bolt::config (
  String                                                     $modulepath         = '/etc/puppetlabs/bolt-code/modules:~/.puppetlabs/bolt-code/site-modules:/etc/puppetlabs/code/environments/simp/modules',
  Optional[Boolean]                                          $color              = undef,
  Optional[Integer[0]]                                       $concurrency        = undef,
  Optional[Enum['human','json']]                             $format             = undef,
  Optional[String]                                           $hiera_config       = undef,
  Optional[String]                                           $inventoryfile      = undef,
  Optional[Enum['docker','local','pcp','ssh','winrm']]       $transport          = undef,
  Optional[Boolean]                                          $ssh_host_key_check = undef,
  Optional[String]                                           $ssh_password       = undef,
  Optional[Integer[0]]                                       $ssh_port           = undef,
  Optional[String]                                           $ssh_private_key    = undef,
  Optional[String]                                           $ssh_proxyjump      = undef,
  String                                                     $ssh_tmpdir         = '/var/local',
  String                                                     $ssh_user           = 'root',
  Optional[String]                                           $ssh_run_as         = undef,
  Enum['debug', 'info', 'notice', 'warn', 'error']           $log_console_level  = 'info',
  String                                                     $log_file           = '/var/log/puppetlabs/bolt/bolt.log',
  Optional[Enum['debug', 'info', 'notice', 'warn', 'error']] $log_file_level     = undef,
  Optional[Boolean]                                          $log_file_append    = undef
  Boolean                                                    $disable_analytics  = true,
){
  assert_private()

# Create the Boltdir
  file { '/etc/puppetlabs/bolt':
    ensure => 'directory',
    owner  => 'root',
    group  => 'root',
    mode   => '0750'
  }

# Create the config file for bolt
  file { '/etc/puppetlabs/bolt/bolt.yaml':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0750',
    content => template("${module_name}/bolt_yaml.erb")
  }

# Ensure the directory for the log file exists
  $log_dir = dirname($log_file)
  exec { "mkdir -p ${log_dir}":
    path => ['/bin','/usr/bin'],
    onlyif => "test ! -d $log_dir"
  }

# Create the config file for analytics
  file { '/etc/puppetlabs/bolt/analytics.yaml':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0750'
  } 

# Ensure analytics are correctly enabled or disabled
  if $disable_analytics {
    file_line { 'analytics_yaml':
      ensure => present,
      path   => '/etc/puppetlabs/bolt/analytics.yaml',
      line   => "^disabled: ${disable_analytics}"
    }
  } else {
    file_line { 'analytics_yaml':
      ensure => absent,
      path   => '/etc/puppetlabs/bolt/analytics.yaml',
      match  => "^disabled:*"
    }
  }
}

