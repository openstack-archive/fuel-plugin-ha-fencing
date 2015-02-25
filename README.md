Fuel Fencing Plugin
===================

#### Table of Contents

1. [Overview - What is the Fuel fencing plugin?](#overview)
2. [Plugin Description - What does the plugin do?](#plugin-description)
3. [Setup - The basics of getting started with Fuel fencing plugin](#setup)
4. [Implementation - An under-the-hood peek at what the plugin is doing](#implementation)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the plugin](#development)
7. [Contributors - Those with commits](#contributors)
8. [Versioning - Fuel and plugin versions](#versioning)
9. [Known Issues - Issues and workarounds](#known-issues)
10. [Release Notes - Notes on the most recent updates to the plugin](#release-notes)

Overview
--------

The Fuel fencing plugin is a Puppet configuration module being executed as an
additional post deployment step in order to provide HA fencing (STONITH based)
of a failed cluster nodes.
The plugin itself is used to describe a datacenter's hardware power management
configuration - such as PDU outlets, IPMI and other agents - and represent
it as a fencing topology for Corosync & Pacemaker cluster.

[About Fuel plugins](https://software.mirantis.com/mirantis-openstack-fuel-plug-in-development/)

Plugin Description
------------------

The Fuel fencing plugin is intended to provide STONITHing of the failed nodes
in Corosync & Pacemaker cluster.
Fencing plugin operates the YAML data structures and extends the Fuel YAML
configuration file.

It suggests the manual definition of the YAML data structures with all required
parameters for existing power management (PM) devices for every controller node.
It is up to the user to collect and verify all the needed IP adresses, credentials,
power outlets layouts, BM hosts to PM devices mappings and other parameters.

This plugin also installs fence-agents package and assumes
there is the one avaiable in the OS repositories.

Requirements
------------

| Plugin version | Mirantis OpenStack release  |
| -------------- |:---------------------------:|
| 6.0.0          | 6.0                         |


Setup
-----

### Installing Fencing plugin

To install HA fencing plugin, follow these steps:     
          
1. Download the plug-­in from Plugins Catalog.
2. Copy the plug-­in on already installed Fuel Master node;
   If you do not have the Fuel Master node yet, see the [Quick Start Guide](https://software.mirantis.com/quick-start/):

```
scp ha_fencing-6.0.0.fp root@:<the_Fuel_Master_node_IP>:/tmp
cd /tmp
fuel plugins --install ha_fencing-6.0.0.fp
```

3. Using Fuel UI wizard, create an HA environment.
4. Select the plugin checkbox on the Settings tab of the Fuel web UI.
5. Select the fencing policy (reboot, power off or disabled) on the Settings tab of the Fuel web UI.
6. Assign roles to the nodes as usually. Use Fuel CLI instead of Deploy button to provision all nodes in the environment.


Note that in order to build this plugin the following tools must present:
* rsync
* wget

### Beginning with Fencing plugin

* Create an HA environment and select the fencing policy (reboot, poweroff or
  disabled) at the Settings tab of the Fuel web UI.

* Assign roles to the nodes as always, but use Fuel CLI instead of Deploy button
  to provision all nodes in the environment. Please note, that the power management
  devices should be reachable from the management network via TCP protocol.

* Define YAML configuration files for controller nodes and existing power management
  (PM aka STONITH) devices. See an example in
  ``deployment_scripts/puppet/modules/pcs_fencing/examples/pcs_fencing.yaml``.

  In the given example we assume 'reboot' policy, which is a hard resetting of
  the failed nodes in Pacemaker cluster. We define IPMI reset action and PSU OFF/ON
  actions for ``fence_ipmilan`` and ``fence_apc_snmp`` agent types.
  These agents will be contacted by Pacemaker stonith-ng daemon to STONITH controller
  nodes (there are 3 of them according to the given fence topology) in the following
  order:

  * If IPMI device reported OK on reset action requested, STONITH is completed.
  * if IPMI device cannot succeed on reset action for some reason, PSU OFF action
    will be requested.
  * In the case of PSU OFF action success, PSU ON action will be requested as well.
  * In the case of both OFF and ON actions success, STONITH is completed OK.
  * If either of them failed, repeat from the step 1, untill timeout exceeded.
    (if timeout exceeded, STONITH is failed)

  For other controllers, the same configuration stanza should be manually populated.
  IP addresses, credentials, delay and indexes of the power outlets (in case of PDU/PSU)
  of STONISH devices being connected by these agents should be updated as well as
  node names.

  Please note, that each controller node should have configured all of its fence agent
  types ``delay`` parameters with an increased values. That is required in order to
  resolve a mutual fencing situations then the nodes are triyng to STONITH each other.
  For example, if you have 3 controllers, set all delay values as 0 for 1st controller,
  10 - for 2nd one and 20 seconds - for the last one. The other timeouts should be
  as well adjusted as the following:
  ```
  delay + shell_timeout + login_timeout < power_wait < power_timeout
  ```

  Fencing topology could vary for controller nodes but usually it is the same.
  It provides an ordering of STONITH agents to call in case of the fencing actions.
  It is recommended to configure several types of the fencing devices and put
  them to the dedicated admin network. This network should be either directly connected
  or reached from the management interfaces of controller nodes in order to provide a
  connectivity to the fencing devices.

  In the given example, we define the same topology for node-10 and node-11 and slightly
  different one for node-12 - just to illustrate that each node could have a different
  fence agent types configured, hence, the different topology as well. So, we configure
  nodes 10 and 11 to rely on IPMI and PSU devices, while the node 12 is a virtual node
  and relies on virsh agent.

  Please also note, that the names of nodes in fence topology stanza and ``pcmk_*``
  parameters should be specified as FQDN names in case of RedHat operating systems family and as a
  short names in case of Debian operating systems family. That is related to the node naming rules in
  Pacemaker cluster in different operating system types.
 
* Put created fencing configuration YAML files as ``/etc/pcs_fencing.yaml``
  for the corresponding controller nodes.

* Deploy HA environment either by CLI command or Deploy button

TODO(bogdando) finish the guide, add agents and devices verification commands

Please also note that the recommended value for the ``no-quorum-policy`` cluster property
should be changed manually (after deployment is done) from ignore/stopped to suicide.
For more information on no-quorum policy, see the [Cluster Options](http://clusterlabs.org/doc/en-US/Pacemaker/1.0/html/Pacemaker_Explained/s-cluster-options.html)
section in the official Pacemaker documentation. You can set this property by the command
```
pcs property set no-quorum-policy=suicide
```

Implementation
--------------

### Fuel Fencing plugin

This plugin is a combination of Puppet module and metadata required to
describe and configure the fencing topology for Corosync & Pacemaker
cluster. The plugin includes custom puppet module pcs_fencing and as a dependencies,
custom corosync module and puppetlabs/stdlib module v4.5.0.

It changes global cluster properties as follows:

* cluster-recheck-interval = 3 minutes
* stonith-enabled = True

It creates a set of STONITH primitives in Pacemaker cluster and runs them in a way,
that ensures the node will never try to shoot itself (-inf location constraint).
It configures a fencing topology singleton primitive in Pacemaker cluster.
It uses crm command line tool which is deprecated and will be replaced to pcs later.

Limitations
-----------

* It is not recommended to use this plugin, if controller nodes contain any additional
  roles (such as storage, monitoring, compute) in Openstack environment, because
  STONITH'ed node in Pacemaker cluster will bring these additional roles residing at
  this node down as well.
* Can be used only with the Debian and RedHat OS families with crm command line tool
  available.

Development
-----------

All documentation related to plugins can be found here:

* https://wiki.openstack.org/wiki/Fuel/Plugins

Contributors
------------

Primary contributor:
    Bogdan Dobrelya - <bdobrelya@mirantis.com>

Versioning
----------

This module has been given version 6 to track the Fuel releases. The
versioning for plugin releases are as follows:

```
Plugin :: Fuel version
6.0.0  -> 6.0
```

Known Issues
------------

[LP1411603](https://bugs.launchpad.net/fuel/+bug/1411603)

After the deployment is finished, please make sure all of the controller nodes have
corresponding ``stonith__*`` primitives and the stonith verification command gives
no errors.

You can list the STONITH primitives and check their health by the commands:
```
pcs stonith
pcs stonith level verify
```

And the location constraints could be shown by the commands:
```
pcs constraint list
pcs constraint ref <stonith_resource_name>
```

It is expected that every ``stonith_*`` primitive should have one "prohibit" and
one "allow" location shown by the ref command.

If some of the controller nodes does not have corresponding stonith primitives
or locations for them, please follow the workaround provided at the LP bug.

Release Notes
-------------

*** 6.0.0 *** 

* This is the initial release of this plugin.
