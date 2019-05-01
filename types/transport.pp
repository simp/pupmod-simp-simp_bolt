# @summary Bolt Transports
#
type Simp_bolt::Transport = Enum[
  'docker',
  'local',
  'pcp',
  'ssh',
  'winrm'
]
