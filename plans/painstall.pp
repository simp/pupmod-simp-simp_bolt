# Checks for puppet-agent and installs or updates if necessary
#
# @param nodes
#   Target nodeset for puppet-agent
# @param agent_version
#   The minimum version of puppet-agent to install or update to
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
  $need_agent = $results.filter |$result| { $result[status] == 'uninstalled' }
  $install_subset = $need_agent.map |$result| { $result.target }
  $ver_inst_results = run_task('facts', $install_subset)

  # Generate set of nodes that require a newer puppet agent
  $have_agent = $results.filter |$result| { $result[status] == 'installed' }
  $need_update = $have_agent.filter |$result| { versioncmp($result[version], "${agent_version}") == -1 }
  $update_subset = $need_update.map |$result| { $result.target }
  $ver_upd_results = run_task('facts', $update_subset)

  $r = ['7']
  $r.each |$r| {
    # For new installs
    $rel_installs = $ver_inst_results.filter |$result| { $result['os']['release']['major'] == "${r}" }
    $install_rel_subset = $rel_installs.map |$result| { $result.target }

    # Check existing repo for adequate version
    $repo_version = run_task('simp_bolt::payum', $install_rel_subset,
      version => "${agent_version}.el${r}")
    # Install agent_version if available from yum
    $yum_tgt_rel_subset = $repo_version.filter |$result| { versioncmp($result[_output], "${agent_version}.el${r}") == 0 }
    $install_target_rel_subset = $yum_tgt_rel_subset.map |$result| { $result.target }
    run_task('package::linux', $install_target_rel_subset,
      name    => 'puppet-agent',
      version => "${agent_version}.el${r}",
      action  => 'install')
    # Install newer agent_version if available from yum
    $yum_newer_rel_subset = $repo_version.filter |$result| { versioncmp($result[_output], "${agent_version}.el${r}") == 1 }
    $install_newer_rel_subset = $yum_newer_rel_subset.map |$result| { $result.target }
    run_task('package::linux', $install_newer_rel_subset,
      name    => 'puppet-agent',
      action  => 'install')
    # Copy rpm file to target and install if yum does not offer a suitable version
    $yum_no_rel_subset = $repo_version.filter |$result| { versioncmp($result[_output], "${agent_version}.el${r}") == -1 }
    $rpm_rel_subset = $yum_no_rel_subset.map |$result| { $result.target }
    # No need to check for rpm if yum is sufficient
    if !empty($rpm_rel_subset) {
      if file::exists("simp_bolt/puppet-agent-${agent_version}.el${r}.x86_64.rpm") {
        upload_file("simp_bolt/puppet-agent-${agent_version}.el${r}.x86_64.rpm", "/var/local/puppet-agent-${agent_version}.el${r}.x86_64.rpm", $rpm_rel_subset)
        run_command("yum localinstall -y /var/local/puppet-agent-${agent_version}.el${r}.x86_64.rpm", $rpm_rel_subset)
      } else {
        out::message("no puppet-agent is available for ${rpm_rel_subset}")
      }
    }

    # For updates
    $rel_updates = $ver_upd_results.filter |$result| { $result['os']['release']['major'] == "${r}" }
    $update_rel_subset = $rel_updates.map |$result| { $result.target }
    if !empty($update_rel_subset) {
      if $update {
        # Check existing repo for adequate version
        $urepo_version = run_task('simp_bolt::payum', $update_rel_subset,
          version => "${agent_version}.el${r}")
        # Install agent_version if available from yum
        $yum_update_subset = $urepo_version.filter |$result| { versioncmp($result[_output], "${agent_version}.el${r}") == 0 }
        $update_target_subset = $yum_update_subset.map |$result| { $result.target }
        run_task('package::linux', $update_target_subset,
          name    => 'puppet-agent',
          version => "${agent_version}.el${r}",
          action  => 'upgrade')
        # Install newer agent_version if available from yum
        $yum_newer_subset = $urepo_version.filter |$result| { versioncmp($result[_output], "${agent_version}.el${r}") == 1 }
        $update_newer_subset = $yum_newer_subset.map |$result| { $result.target }
        run_task('package::linux', $update_newer_subset,
          name    => 'puppet-agent',
          action  => 'upgrade')
        # Copy rpm file to target and install
        $yum_no_subset = $urepo_version.filter |$result| { versioncmp($result[_output], "${agent_version}.el${r}") == -1 }
        $rpm_update_subset = $yum_no_subset.map |$result| { $result.target }
        # No need to check for rpm if yum is sufficient
        if !empty($rpm_update_subset) {
          if file::exists("simp_bolt/puppet-agent-${agent_version}.el${r}.x86_64.rpm") {
            upload_file("simp_bolt/puppet-agent-${agent_version}.el${r}.x86_64.rpm", "/var/local/puppet-agent-${agent_version}.el${r}.x86_64.rpm", $rpm_update_subset)
            run_command("yum localinstall -y /var/local/puppet-agent-${agent_version}.el${r}.x86_64.rpm", $rpm_update_subset)
          } else {
            out::message("no puppet-agent is available for update on ${rpm_update_subset}")
          }
        }
      } else {
        out::message("${update_subset} require updates but the update parameter is false")
      }
    }
  }
}
