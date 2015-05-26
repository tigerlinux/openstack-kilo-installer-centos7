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
	echo "Can't access my config file"
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
	echo "This module was already completed. Exiting"
	echo ""
	exit 0
fi

source $keystone_admin_rc_file

echo ""
echo "Creating CEILOMETER identities"
echo ""

echo "Ceilometer User:"
openstack user create --password $ceilometerpass --email $ceilometeremail $ceilometeruser

echo "Ceilometer Role:"
openstack role add --project $keystoneservicestenant --user $ceilometeruser $keystoneadminuser

echo "Ceilometer Service:"
openstack service create \
	--name $ceilometersvce \
	--description "Telemetry" \
	metering

echo "Ceilometer Endpoint:"
openstack endpoint create \
	--publicurl "http://$ceilometerhost:8777" \
	--internalurl "http://$ceilometerhost:8777" \
	--adminurl "http://$ceilometerhost:8777" \
	--region $endpointsregion \
	metering

echo "Creating Role: $keystonereselleradminrole"
openstack role create $keystonereselleradminrole
openstack role add --project $keystoneservicestenant --user $ceilometeruser $keystonereselleradminrole

echo "Done"

echo ""
echo "Ceilometer Identities Ready"
echo ""
