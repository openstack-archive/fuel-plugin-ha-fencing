notice('MODULAR: ha_fencing/ha_fencing_hiera_override.pp')

$ha_fencing_hash = hiera('ha_fencing', undef)
$hiera_dir = '/etc/hiera/override'
$plugin_name = 'ha_fencing'
$plugin_yaml = "${plugin_name}.yaml"

if $ha_fencing_hash {
  $yaml_additional_config = pick(
    $ha_fencing_hash['yaml_additional_config'], {})

  file {'/etc/hiera/override':
    ensure  => directory,
  } ->
  file { "${hiera_dir}/${plugin_yaml}":
    ensure  => file,
    source => $yaml_additional_config,
  }

  package {'ruby-deep-merge':
    ensure  => 'installed',
  }

  file_line {"${plugin_name}_hiera_override":
    path  => '/etc/hiera.yaml',
    line  => "  - override/${plugin_name}",
    after => '  - override/module/%{calling_module}',
  }
}
