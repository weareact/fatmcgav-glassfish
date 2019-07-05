# == Define: glassfish::create_service
#
# Create a glassfish service.
#
# === Parameters
#
# [*domain_name*] - Name of Glassfish domain.
#  Defaults to undef
#
# [*cluster_name*] - Name of Glassfish cluster.
#  Defaults to undef
#
# [*instance_name*] - Name of Glassfish instance.
#  Defaults to undef
#
# [*node_name*] - Name of Glassfish node.
#  Defaults to undef
#
# [*runuser*] - User to run process as.
#  Defaults to $glassfish::user
#
# [*running*] - Is the domain already running?
#  Defaults to false
#
# [*mode*] - Glassfish service mode required.
#  Can be: domain, cluster or instance.
#
# [*das_port*] - Glassfish Domain Adminsitration Service port to connect to
#
# [*status_cmd*] - Custom status command to use when checking service state.
#
# [*service_name*] - Service name to create service as.
#
# === Examples
#
#
# === Authors
#
# Gavin Williams <fatmcgav@gmail.com>
#
# === Copyright
#
# Copyright 2014 Gavin Williams, unless otherwise noted.
#
define glassfish::create_service (
  $ensure                = present,
  $domain_name           = undef,
  $cluster_name          = undef,
  $instance_name         = undef,
  $node_name             = undef,
  $runuser               = $glassfish::user,
  $running               = false,
  $mode                  = 'domain',
  $das_port              = undef,
  $status_cmd            = undef,
  $service_enable        = true,
  $service_name          = undef,
  $service_provider      = $glassfish::service_provider,
  $systemd_start_timeout = undef,
  $systemd_file_limit    = undef
) {
  # Check that we've got a domain name if domain mode.
  if $mode == 'domain' and !$domain_name {
    fail('Domain name must be specified to install service for domain mode.')
  }

  # Check that we've got a cluster name if cluster mode.
  if $mode == 'cluster' and !$cluster_name {
    fail('Cluster name must be specified to install service for cluster mode.')
  }

  # Check that we have a das_port if required
  if $mode == 'cluster' and !$das_port {
    fail('DAS Port must be specified to install service for cluster mode.')
  }

  # Check that we've got a instance name if instance mode.
  if $mode == 'instance' and !$instance_name {
    fail('Instance name must be specified to install service for instance mode.')
  }

  # Check that we've got a node name if instance mode.
  if $mode == 'instance' and !$node_name {
    fail('Node name must be specified to install service for instance mode.')
  }

  # Work out the correct service_name
  if ($service_name == undef) {
    $svc_name = "glassfish_${title}"
  } else {
    $svc_name = $service_name
  }

  case $service_provider {
    'init': {
      glassfish::service::init { $svc_name:
        ensure => $ensure,
        enable => $service_enable,
        mode   => $mode,
        user   => $runuser
      }
    }
    'systemd': {
      glassfish::service::systemd { $svc_name:
        ensure        => $ensure,
        enable        => $service_enable,
        mode          => $mode,
        start_timeout => $systemd_start_timeout,
        file_limit    => $systemd_file_limit,
        user          => $runuser
      }
    }
    default: {
      fail("Unknown service provider ${service_provider}")
    }
  }

  # # SystemD module provides a useful fact for identifying use of systemd
  # include ::systemd

  # # What template do we want to use?
  # case $::systemd {
  #   true: { $service_type = 'systemd' }
  #   default: { $service_type = 'init' }
  # }

  # # What service_file should we be using, based on osfamily.
  # case $::osfamily {
  #   'RedHat' : {
  #     case $mode {
  #       'domain'   : { $service_file = template("glassfish/${service_type}/domain-el.service.erb") }
  #       'cluster'  : { $service_file = template("glassfish/${service_type}/cluster-el.service.erb") }
  #       'instance' : { $service_file = template("glassfish/${service_type}/instance-el.service.erb") }
  #       default    : { fail("Mode ${mode} not supported.") }
  #     }
  #   }
  #   'Debian' : {
  #     $service_file = template("glassfish/${service_type}/domain-debian.service.erb")
  #   }
  #   default  : {
  #     fail("OSFamily ${::osfamily} not supported.")
  #   }
  # }

  # # SystemD uses a different path to init
  # $service_config_path = $::systemd ? {
  #   true    => $::osfamily ? {
  #     'Debian' => "/etc/systemd/system/${svc_name}.service",
  #     'RedHat' => "/usr/lib/systemd/system/${svc_name}.service"
  #   },
  #   default => "/etc/init.d/${svc_name}",
  # }

  # # If using systemd, need to notify reload-systemd after creating service script
  # $service_config_notify = $::systemd ? {
  #   true  => [
  #     Service[$svc_name],
  #     Exec['systemctl-daemon-reload'],
  #   ],
  #   false => Service[$svc_name],
  # }

  # # Create the init file
  # file { "${title}_servicefile":
  #   ensure  => present,
  #   path    => $service_config_path,
  #   mode    => '0755',
  #   content => $service_file,
  #   notify  => $service_config_notify,
  # }

  # Need to stop the domain if it was auto-started
  if $running {
    # Setup a puppet flag in the domain being managed
    $_puppet_indicator = "${glassfish::glassfish_dir}/glassfish/domains/${domain_name}/.puppet_managed"

    exec { "stop_${domain_name}":
      command => "su - ${runuser} -c \"${glassfish::glassfish_asadmin_path} stop-domain ${domain_name}\
 && touch ${_puppet_indicator}\"",
      creates => $_puppet_indicator,
      path    => ['/sbin', '/usr/sbin', '/bin', '/usr/bin'],
      before  => Service[$svc_name]
    }
  }

  # # Handle different service status options
  # if $status_cmd {
  #   $has_status = false
  # } else {
  #   $has_status = true
  # }

  # # Make sure the service is running and enabled.
  # service { $svc_name:
  #   ensure     => 'running',
  #   enable     => $service_enable,
  #   hasstatus  => $has_status,
  #   hasrestart => true,
  #   status     => $status_cmd
  # }

  # # Make sure systemd reloads before service if required
  # if $::systemd {
  #   Exec['systemctl-daemon-reload'] ~> Service[$svc_name]
  # }

}
