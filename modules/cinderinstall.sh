#!/bin/bash
#
# Unattended/SemiAutomatted OpenStack Installer
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
# OpenStack KILO for Centos 7
#
#

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

#
# First, we source our config file and verify that some important proccess are 
# already completed.
#

if [ -f ./configs/main-config.rc ]
then
	source ./configs/main-config.rc
	mkdir -p /etc/openstack-control-script-config
else
	echo "Can't access my config file. Aborting !."
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/db-installed ]
then
	echo ""
	echo "DB Proccess OK. Let's continue"
	echo ""
else
	echo ""
	echo "DB Proccess not completed. Aborting !"
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/keystone-installed ]
then
	echo ""
	echo "Keystone Proccess OK. Let's continue"
	echo ""
else
	echo ""
	echo "Keystone Proccess not completed. Aborting !"
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/cinder-installed ]
then
	echo ""
	echo "This module was already completed. Exiting"
	echo ""
	exit 0
fi


echo "Installing Cinder Packages"

#
# We proceed to install the cinder packages and dependencies
#

yum -y install openstack-cinder openstack-utils openstack-selinux python-oslo-db
yum -y install lvm2
yum -y install openstack-cinder targetcli python-oslo-db python-oslo-log MySQL-python

systemctl enable lvm2-lvmetad.service
systemctl start lvm2-lvmetad.service

cat ./libs/openstack-config > /usr/bin/openstack-config

source $keystone_admin_rc_file

echo "Done"

echo ""
echo "Configuring Cinder"

sync
sleep 5
sync

#
# Using python based tools, we proceed to configure Cinder Services
#

crudini --set /etc/cinder/api-paste.ini filter:authtoken paste.filter_factory  "keystonemiddleware.auth_token:filter_factory"
crudini --set /etc/cinder/api-paste.ini filter:authtoken service_protocol http
crudini --set /etc/cinder/api-paste.ini filter:authtoken service_host $keystonehost
crudini --set /etc/cinder/api-paste.ini filter:authtoken service_port 5000
crudini --set /etc/cinder/api-paste.ini filter:authtoken auth_protocol http
crudini --set /etc/cinder/api-paste.ini filter:authtoken auth_host $keystonehost
crudini --set /etc/cinder/api-paste.ini filter:authtoken admin_tenant_name $keystoneservicestenant
crudini --set /etc/cinder/api-paste.ini filter:authtoken admin_user $cinderuser
crudini --set /etc/cinder/api-paste.ini filter:authtoken admin_password $cinderpass
crudini --set /etc/cinder/api-paste.ini filter:authtoken auth_port 35357
crudini --set /etc/cinder/api-paste.ini filter:authtoken auth_uri http://$keystonehost:5000/v2.0/
crudini --set /etc/cinder/api-paste.ini filter:authtoken identity_uri http://$keystonehost:35357

crudini --set /etc/cinder/cinder.conf DEFAULT osapi_volume_listen 0.0.0.0
crudini --set /etc/cinder/cinder.conf DEFAULT api_paste_config /etc/cinder/api-paste.ini
crudini --set /etc/cinder/cinder.conf DEFAULT glance_host $glancehost
crudini --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
crudini --set /etc/cinder/cinder.conf DEFAULT debug False
crudini --set /etc/cinder/cinder.conf DEFAULT verbose False
crudini --set /etc/cinder/cinder.conf DEFAULT use_syslog False

crudini --set /etc/cinder/cinder.conf DEFAULT enable_v1_api false
crudini --set /etc/cinder/cinder.conf DEFAULT enable_v2_api true

case $brokerflavor in
"qpid")
	# crudini --set /etc/cinder/cinder.conf DEFAULT rpc_backend cinder.openstack.common.rpc.impl_qpid
	crudini --set /etc/cinder/cinder.conf DEFAULT rpc_backend qpid
	crudini --set /etc/cinder/cinder.conf DEFAULT qpid_hostname $messagebrokerhost
	crudini --set /etc/cinder/cinder.conf DEFAULT qpid_username $brokeruser
	crudini --set /etc/cinder/cinder.conf DEFAULT qpid_password $brokerpass
	crudini --set /etc/cinder/cinder.conf DEFAULT qpid_reconnect_limit 0
	crudini --set /etc/cinder/cinder.conf DEFAULT qpid_reconnect true
	crudini --set /etc/cinder/cinder.conf DEFAULT qpid_reconnect_interval_min 0
	crudini --set /etc/cinder/cinder.conf DEFAULT qpid_reconnect_interval_max 0
	crudini --set /etc/cinder/cinder.conf DEFAULT qpid_heartbeat 60
	crudini --set /etc/cinder/cinder.conf DEFAULT qpid_protocol tcp
	crudini --set /etc/cinder/cinder.conf DEFAULT qpid_tcp_nodelay True
	crudini --set /etc/cinder/cinder.conf oslo_messaging_qpid qpid_hostname $messagebrokerhost
	crudini --set /etc/cinder/cinder.conf oslo_messaging_qpid qpid_port 5672
	crudini --set /etc/cinder/cinder.conf oslo_messaging_qpid qpid_username $brokeruser
	crudini --set /etc/cinder/cinder.conf oslo_messaging_qpid qpid_password $brokerpass
	crudini --set /etc/cinder/cinder.conf oslo_messaging_qpid qpid_heartbeat 60
	crudini --set /etc/cinder/cinder.conf oslo_messaging_qpid qpid_protocol tcp
	crudini --set /etc/cinder/cinder.conf oslo_messaging_qpid qpid_tcp_nodelay True
	;;

"rabbitmq")
	# crudini --set /etc/cinder/cinder.conf DEFAULT rpc_backend cinder.openstack.common.rpc.impl_kombu
	crudini --set /etc/cinder/cinder.conf DEFAULT rpc_backend rabbit
	crudini --set /etc/cinder/cinder.conf DEFAULT rabbit_host $messagebrokerhost
	crudini --set /etc/cinder/cinder.conf DEFAULT rabbit_port 5672
	crudini --set /etc/cinder/cinder.conf DEFAULT rabbit_use_ssl false
	crudini --set /etc/cinder/cinder.conf DEFAULT rabbit_userid $brokeruser
	crudini --set /etc/cinder/cinder.conf DEFAULT rabbit_password $brokerpass
	crudini --set /etc/cinder/cinder.conf DEFAULT rabbit_virtual_host $brokervhost
	crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_host $messagebrokerhost
	crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_password $brokerpass
	crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_userid $brokeruser
	crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_port 5672
	crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_use_ssl false
	crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_virtual_host $brokervhost
	crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_max_retries 0
	crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_retry_interval 1
	crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_ha_queues false
	;;
esac

# crudini --set /etc/cinder/cinder.conf DEFAULT iscsi_helper tgtadm
# crudini --set /etc/cinder/cinder.conf DEFAULT volume_group cinder-volumes
# crudini --set /etc/cinder/cinder.conf DEFAULT volume_driver cinder.volume.drivers.lvm.LVMISCSIDriver
crudini --set /etc/cinder/cinder.conf DEFAULT logdir /var/log/cinder
crudini --set /etc/cinder/cinder.conf DEFAULT state_path /var/lib/cinder
# crudini --set /etc/cinder/cinder.conf DEFAULT lock_path /var/lib/cinder/tmp
# crudini --set /etc/cinder/cinder.conf DEFAULT volumes_dir /etc/cinder/volumes
crudini --set /etc/cinder/cinder.conf DEFAULT volumes_dir /var/lib/cinder/volumes/
crudini --set /etc/cinder/cinder.conf DEFAULT rootwrap_config /etc/cinder/rootwrap.conf
# crudini --set /etc/cinder/cinder.conf DEFAULT iscsi_ip_address $cinder_iscsi_ip_address

crudini --set /etc/cinder/cinder.conf DEFAULT enabled_backends lvm
crudini --set /etc/cinder/cinder.conf lvm volume_group cinder-volumes
crudini --set /etc/cinder/cinder.conf lvm volume_driver cinder.volume.drivers.lvm.LVMVolumeDriver
crudini --set /etc/cinder/cinder.conf lvm iscsi_protocol iscsi
# crudini --set /etc/cinder/cinder.conf lvm iscsi_helper lioadm
crudini --set /etc/cinder/cinder.conf lvm iscsi_helper tgtadm
crudini --set /etc/cinder/cinder.conf lvm iscsi_ip_address $cinder_iscsi_ip_address
crudini --set /etc/cinder/cinder.conf lvm volume_backend_name LVM_iSCSI

case $dbflavor in
"mysql")
	crudini --set /etc/cinder/cinder.conf database connection mysql://$cinderdbuser:$cinderdbpass@$dbbackendhost:$mysqldbport/$cinderdbname
	;;
"postgres")
	crudini --set /etc/cinder/cinder.conf database connection postgresql://$cinderdbuser:$cinderdbpass@$dbbackendhost:$psqldbport/$cinderdbname
	;;
esac

crudini --set /etc/cinder/cinder.conf database retry_interval 10
crudini --set /etc/cinder/cinder.conf database idle_timeout 3600
crudini --set /etc/cinder/cinder.conf database min_pool_size 1
crudini --set /etc/cinder/cinder.conf database max_pool_size 10
crudini --set /etc/cinder/cinder.conf database max_retries 100
crudini --set /etc/cinder/cinder.conf database pool_timeout 10

# crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_host $keystonehost
# crudini --set /etc/cinder/cinder.conf keystone_authtoken admin_tenant_name $keystoneservicestenant
# crudini --set /etc/cinder/cinder.conf keystone_authtoken admin_user $cinderuser
# crudini --set /etc/cinder/cinder.conf keystone_authtoken admin_password $cinderpass
# crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_port 35357
# crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_protocol http
# crudini --set /etc/cinder/cinder.conf keystone_authtoken signing_dirname /tmp/keystone-signing-cinder
# crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_uri http://$keystonehost:5000/v2.0/
# crudini --set /etc/cinder/cinder.conf keystone_authtoken identity_uri http://$keystonehost:35357
crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_uri http://$keystonehost:5000
crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_url http://$keystonehost:35357
crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_plugin password
crudini --set /etc/cinder/cinder.conf keystone_authtoken project_domain_id default
crudini --set /etc/cinder/cinder.conf keystone_authtoken user_domain_id default
crudini --set /etc/cinder/cinder.conf keystone_authtoken project_name $keystoneservicestenant
crudini --set /etc/cinder/cinder.conf keystone_authtoken username $cinderuser
crudini --set /etc/cinder/cinder.conf keystone_authtoken password $cinderpass
crudini --set /etc/cinder/cinder.conf oslo_concurrency lock_path "/var/oslock/cinder"

# crudini --set /etc/cinder/cinder.conf DEFAULT notification_driver cinder.openstack.common.notifier.rpc_notifier
# crudini --set /etc/cinder/cinder.conf DEFAULT control_exchange cinder

if [ $ceilometerinstall == "yes" ]
then
	crudini --set /etc/cinder/cinder.conf DEFAULT notification_driver messagingv2
	crudini --set /etc/cinder/cinder.conf DEFAULT control_exchange cinder
fi

sync
sleep 2

mkdir -p /var/oslock/cinder
chown -R cinder.cinder /var/oslock/cinder
mkdir -p /var/lib/cinder/volumes
chown -R cinder.cinder /var/lib/cinder/volumes

echo "default-driver iscsi" > /etc/tgt/targets.conf
echo "include /etc/tgt/conf.d/cinder_tgt.conf" >> /etc/tgt/targets.conf
echo "include /var/lib/cinder/volumes/*" > /etc/tgt/conf.d/cinder_tgt.conf

#
# We proceed to provision/update Cinder Database
#

su cinder -s /bin/sh -c "cinder-manage db sync"

#
# Some iscsi configuration
#

echo "include /etc/cinder/volumes/*" >> /etc/tgt/targets.conf

echo ""
echo "Starting Cinder"

#
# Then we proceed to start and enable Cinder Services and apply IPTABLES rules.
#

systemctl stop tgtd
systemctl start tgtd
systemctl enable tgtd
systemctl start target
systemctl enable target
systemctl start iscsid.service
systemctl enable iscsid.service

service openstack-cinder-api start
chkconfig openstack-cinder-api on
service openstack-cinder-scheduler start
chkconfig openstack-cinder-scheduler on
service openstack-cinder-volume start
chkconfig openstack-cinder-volume on

yum -y install python-cinderclient

echo "Ready"

echo ""
echo "Applying IPTABLES rules"

iptables -A INPUT -p tcp -m multiport --dports 3260,8776 -j ACCEPT
service iptables save

#
# Finally, we proceed to verify if Cinder was installed and if not we set a fail so the
# main installer stop further processing.
#
#
# But beforce that, we setup our backend
source $keystone_admin_rc_file
cinder type-create lvm
cinder type-key lvm set volume_backend_name=LVM_iSCSI

testcinder=`rpm -qi openstack-cinder|grep -ci "is not installed"`
if [ $testcinder == "1" ]
then
	echo ""
	echo "Cinder installation failed. Aborting !"
	echo ""
	exit 0
else
	date > /etc/openstack-control-script-config/cinder-installed
	date > /etc/openstack-control-script-config/cinder
fi

echo "Ready"

echo ""
echo "Cinder Installed and Configured"
echo ""

