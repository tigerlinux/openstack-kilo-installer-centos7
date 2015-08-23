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
	echo "Can't Access my config file. Aborting !"
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
echo "Creating HEAT Identities"
echo ""

echo "Heat User:"
openstack user create --password $heatpass --email $heatemail $heatuser

echo "Heat Role:"
openstack role add --project $keystoneservicestenant --user $heatuser $keystoneadminuser

echo "Heat User Role:"
openstack role create $heat_stack_user_role

echo "Heat Stack Owner"
openstack role create $heat_stack_owner

echo "Adding Admin User in Admin Project to Heat Stack Owner role"
openstack role add --project $keystoneadmintenant --user $keystoneadminuser $heat_stack_owner

echo "Heat and Heat-CloudFormation Services:"

openstack service create \
	--name $heatsvce \
	--description "Orchestration" \
	orchestration
openstack service create \
	--name $heatcfnsvce \
	--description "Orchestration" \
	cloudformation

echo "Heat and Heat-CloudFormation Endpoints:"

openstack endpoint create \
	--publicurl "http://$heathost:8004/v1/\$(tenant_id)s" \
	--internalurl "http://$heathost:8004/v1/\$(tenant_id)s" \
	--adminurl "http://$heathost:8004/v1/\$(tenant_id)s" \
	--region $endpointsregion \
	orchestration

openstack endpoint create \
	--publicurl "http://$heathost:8000/v1" \
	--internalurl "http://$heathost:8000/v1" \
	--adminurl "http://$heathost:8000/v1" \
	--region $endpointsregion \
	cloudformation

echo "Ready"

echo ""
echo "Heat Identities Ready"
echo ""
