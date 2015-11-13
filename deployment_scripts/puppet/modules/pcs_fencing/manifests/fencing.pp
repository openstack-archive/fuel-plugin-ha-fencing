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
# == Define: pcs_fencing::fencing
#
# Configure STONITH resources for Pacemaker.
#
# === Parameters:
#
# [*agent_type*]
#   The fence agent name for a STONITH resource
#   Defaults to undef
#
# [*parameters*]
#   The hash of parameters for a STONITH resource
#   Defaults to False
#
# [*operations*]
#   The hash of operations for a STONITH resource
#   Defaults to False
#
# [*meta*]
#   The hash of metadata for a STONITH resource
#   Defaults to False
#
define pcs_fencing::fencing (
  $agent_type,
  $parameters    = false,
  $operations    = false,
  $meta          = false,
){
  $res_name = "stonith__${title}__${::hostname}"

  cs_resource { $res_name:
    ensure              => present,
    # stonith does not support providers
    provided_by         => undef,
    primitive_class     => 'stonith',
    primitive_type      => $agent_type,
    parameters          => $parameters,
    operations          => $operations,
    metadata            => $meta,
  }

  cs_rsc_location {"location__prohibit__${res_name}":
    node_name  => $::pacemaker_hostname,
    node_score => '-INFINITY',
    primitive  => $res_name,
  }

  cs_rsc_location {"location__allow__${res_name}":
    primitive  => $res_name,
    rules     => [
      {
        'score'   => '100',
        'boolean' => '',
        'expressions' => [
          {
            'attribute'=> '#uname',
            'operation'=>'ne',
            'value'=>$::pacemaker_hostname,
          },
        ],
      },
    ],
  }

  Cs_resource[$res_name] ->
  Cs_rsc_location<||>
}
