# == Define: l23network::l3::ifconfig
#
# Specify IP address for network interface and put interface to the UP state.
#
# === Parameters
#
# [*interface*]
#   Specify interface.
#
# [*ipaddr*]
#   IP address for interface. Can contains IP address, 'dhcp', or 'none'
#   for up empty unaddressed interface.
#
# [*netmask*]
#   Specify network mask. Default is '255.255.255.0'.
#
# [*ifname_order_prefix*]
#   Centos and Ubuntu at boot time Up and configure network interfaces in
#   alphabetical order of interface configuration file names.
#   This option helps You change this order at system startup.
#
# [*gateway*]
#   Specify default gateway if need.
#
# [*dns_nameservers*]
#   Specify pair of nameservers if need. Must be array, for example:
#   nameservers => ['8.8.8.8', '8.8.4.4']
# TODO: realize dns_domain derecive
#
# [*dhcp_hostname*]
#   Specify hostname for DHCP if need.
#
# [*dhcp_nowait*]
#   If you put 'true' to this option dhcp agent will be started in background.
#   Puppet will not wait for obtain IP address and route.
#
# [*check_by_ping*]
#   You can put here IP address, that will be pinged after interface UP. We will
#   be wait that this IP will pinged. 
#   Can be IP address, 'none', or 'gateway' for check awailability default gateway
#   if it exists for this interface.
#   
# [*check_by_ping_timeout*]
#   Timeout for check_by_ping
#
define l23network::l3::ifconfig (
    $ipaddr,
    $interface       = $name,
    $netmask         = '255.255.255.0',
    $gateway         = undef,
    $dns_nameservers = undef,
    $dns_search      = undef,
    $dns_domain      = undef,
    $dhcp_hostname   = undef,
    $dhcp_nowait     = false,
    $ifname_order_prefix = false,
    $check_by_ping   = 'gateway',
    $check_by_ping_timeout = 120,
){
  case $ipaddr {
    'dhcp':  { $method = 'dhcp' }
    'none':  { $method = 'manual' }
    default: { $method = 'static' }
  }
  case $::osfamily {
    /(?i)debian/: {
      $if_files_dir = '/etc/network/interfaces.d'
      $interfaces = '/etc/network/interfaces'
      if $dns_nameservers {
        $dns_nameservers_join = join($dns_nameservers, ' ')
      }
    }
    /(?i)redhat/: {
      $if_files_dir = '/etc/sysconfig/network-scripts'
      $interfaces = false
      if $dns_nameservers {
        $dns_nameservers_1 = $dns_nameservers[0]
        $dns_nameservers_2 = $dns_nameservers[1]
      }
    }
    default: {
      fail("Unsupported OS: ${::osfamily}/${::operatingsystem}")
    }
  }

  if $ifname_order_prefix {
    $interface_file= "${if_files_dir}/ifcfg-${ifname_order_prefix}-${interface}"
  } else {
    $interface_file= "${if_files_dir}/ifcfg-${interface}"
  }

  if $method == 'static' {
    if $gateway {
      $def_gateway = $gateway
    } else {
      if $::l3_default_route and $::l3_default_route_interface == $interface {
        $def_gateway = $::l3_default_route
      } else {
        $def_gateway = undef
      }
    }
  } else {
    $def_gateway = undef
  }

  if $interfaces {
    if ! defined(File[$interfaces]) {
      file {$interfaces:
        ensure  => present,
        content => template('l23network/interfaces.erb'),
      }
    }
    File[$interfaces] -> File[$if_files_dir]
  }

  if ! defined(File[$if_files_dir]) {
    file {$if_files_dir:
      ensure  => directory,
      owner   => 'root',
      mode    => '0755',
      recurse => true,
    }
  }

  file {$interface_file:
    ensure  => present,
    owner   => 'root',
    mode    => '0644',
    content => template("l23network/ipconfig_${::osfamily}_${method}.erb"),
    require => File[$if_files_dir],
  }

  notify {"ifconfig_${interface}": message=>"Interface:${interface} IP:${ipaddr}/${netmask}", withpath=>false} ->
  l3_if_downup {$interface:
    check_by_ping => $check_by_ping,
    check_by_ping_timeout => $check_by_ping_timeout,
    subscribe     => File[$interface_file],
    refreshonly   => true,
  }
}
