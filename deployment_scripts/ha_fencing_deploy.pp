notice('MODULAR: ha_fencing/ha_fencing_deploy.pp')

$role = hiera('role', '')
$primary_controller = $role ? {
  'primary-controller'=>true, default=>false }
$is_controller      = $role ? {
  'controller'=>true, default=>false }

if ($is_controller or $primary_controller) {
  # Fetch fencing policy and settings
  $ha_fencing_hash = hiera_hash('ha_fencing', {})
  $fence_policy = $ha_fencing_hash['fence_policy']
  $fencing_enabled  = $fence_policy ? {
    'disabled'=>false, 'reboot'=>true,
    'poweroff'=>true, default=>false }

  if $fencing_enabled {
    $fence_primitives = hiera_hash('fence_primitives', {})
    $fence_topology   = hiera_hash('fence_topology', {})

    $nodes_hash = hiera_hash('nodes', {})
    $controllers = concat(
      filter_nodes($nodes_hash,'role','primary-controller'),
      filter_nodes($nodes_hash,'role','controller'))

    include stdlib
    class { '::pcs_fencing::fencing_primitives':
      fence_primitives   => $fence_primitives,
      fence_topology     => $fence_topology,
      nodes              => $controllers,
      primary_controller => $primary_controller,
    }
  }
}
