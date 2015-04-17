#    Copyright 2013 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
#
# == Class: pcs_fencing::fencing_primitives
#
# Creates Pacemaker fencing primitives and topology for given nodes.
# Assumes all nodes have the same OS installed.
#
# === Parameters:
#
# [*fence_primitives*]
#   The hash of parameters for STONITH resources in Pacemaker
#   Defaults to undef
#
# [*fence_topology*]
#   The hash of parameters for a fencing topology in Pacemaker
#   Defaults to undef
#
# [*node*]
#   The array of node names in Pacemaker cluster
#
class pcs_fencing::fencing_primitives (
  $fence_primitives,
  $fence_topology,
  $nodes,
) {
  case $::osfamily {
    'RedHat': {
      $names = filter_hash($nodes, 'fqdn')
    }
    'Debian': {
      $names = filter_hash($nodes, 'name')
    }
    default: {
      fail("Unsupported osfamily: ${::osfamily} operatingsystem: ${::operatingsystem}, module ${module_name} only support osfamily RedHat and Debian")
    }
  }

  anchor {'Fencing primitives start':}
  anchor {'Fencing primitives end':}

  create_resources('::pcs_fencing::fencing', $fence_primitives)

  cs_fencetopo { 'fencing_topology':
    ensure         => present,
    fence_topology => $fence_topology,
    nodes          => $names,
  }
  cs_property { 'stonith-enabled': value  => 'true' }
  cs_property { 'cluster-recheck-interval':  value  => '3min' }
  package {'fence-agents':}

  Anchor['Fencing primitives start'] ->
  Package['fence-agents'] ->
  Pcs_fencing::Fencing<||> ->
  Cs_fencetopo['fencing_topology'] ->
  Cs_property<||> ->
  Anchor['Fencing primitives end']
}
