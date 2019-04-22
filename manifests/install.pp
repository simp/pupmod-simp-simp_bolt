# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# == Class simp_bolt::install
#
# This class is called from simp_bolt for install.
#
class simp_bolt::install {
  assert_private()

  package { $::simp_bolt::package_name:
    ensure => present
  }
}
