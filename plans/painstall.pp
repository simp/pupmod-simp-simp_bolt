# Checks for puppet-agent and installs or updates if necessary
#
# @param nodes
#   Target nodeset for puppet-agent
# @param agent_version
#   The version of puppet-agent to install or update to
# @param update
#   Update existing puppet-agent versions

plan simp_bolt::painstall (
  TargetSpec $nodes,
  String     $agent_version = '5.5.14-1',
  Boolean    $update        = false
) {
  # Query nodes for puppet-agent
  $results = run_task('package::linux', $nodes, name => 'puppet-agent', action => 'status')

  # Generate set of nodes with no puppet-agent
  $need_agent = $results.filter |$result| { $result[status] == "uninstalled" }
  $install_subset = $need_agent.map |$result| { $result.target }

  # Generate set of nodes the need newer puppet agent
  $have_agent = $results.filter |$result| { $result[status] == "installed" }
  $need_update = $have_agent.filter |$result| { versioncmp($result[version], "$agent_version") == -1 }
  $update_subset = $need_update.map |$result| { $result.target }

  #Determine OS Release and Install
  $ver_results = run_task('facts', $install_subset)
  $el6 = $ver_results.filter |$result| { $result['os']['release']['major'] == 6 }
  $install_el6_subset = $el6.map |$result| { $result.target }
  run_task('package::linux', $install_el6_subset,
           name    => 'puppet-agent',
           version => "${agent_version}.el6",
           action  => 'install')

  $el7 = $ver_results.filter |$result| { $result['os']['release']['major'] == "7" }
  out::message("                 el7  $el7")
  $install_el7_subset = $el7.map |$result| { $result.target }
  run_task('package::linux', $install_el7_subset,
           name    => 'puppet-agent',
           version => "${agent_version}.el7",
           action  => 'install')

  if !empty($update_subset) {
    if $update {
      run_task('package::linux', $update_subset,
               name    => 'puppet-agent',
               version => "$agent_version",
               action  => 'install')
    } else {
      out::message("$update_subset require updates but the update parameter is false")
    }
  }
}

