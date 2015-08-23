#!/bin/bash
#
# Unattended/SemiAutomatted OpenStack Installer
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
# OpenStack KILO for Centos 7
#
#

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

if [ -f ./configs/main-config.rc ]
then
	source ./configs/main-config.rc
	mkdir -p /etc/openstack-control-script-config
else
	echo "Can't access my config file. Aborting"
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

if [ -f /etc/openstack-control-script-config/keystone-extra-idents ]
then
	echo ""
	echo "This module was already completed. Exiting !"
	echo ""
	exit 0
fi


source $keystone_fulladmin_rc_file

echo ""
echo "Creating CINDER Identities"
echo ""

echo "Cinder User:"
openstack user create --password $cinderpass --email $cinderemail $cinderuser

echo "Cinder Role"
openstack role add --project $keystoneservicestenant --user $cinderuser $keystoneadminuser

echo "Cinder Services (V1 and V2)"
openstack service create \
	--name $cindersvce \
	--description "OpenStack Block Storage" \
	volume
openstack service create \
	--name $cindersvcev2 \
	--description "OpenStack Block Storage" \
	volumev2

echo "Endpoint for Cinder V1"
openstack endpoint create \
	--publicurl "http://$cinderhost:8776/v2/\$(tenant_id)s" \
	--internalurl "http://$cinderhost:8776/v2/\$(tenant_id)s" \
	--adminurl "http://$cinderhost:8776/v2/\$(tenant_id)s" \
	--region $endpointsregion \
	volume

echo "Endpoint for Cinder V2"
openstack endpoint create \
        --publicurl "http://$cinderhost:8776/v2/\$(tenant_id)s" \
        --internalurl "http://$cinderhost:8776/v2/\$(tenant_id)s" \
        --adminurl "http://$cinderhost:8776/v2/\$(tenant_id)s" \
        --region $endpointsregion \
        volumev2

echo "Ready"

echo ""
echo "CINDER V1/V2 Identities ready"
echo ""
