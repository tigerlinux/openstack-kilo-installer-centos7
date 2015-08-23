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
	echo "Can't access my config file. Aborting !"
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
	echo "This module was already completed. Exiting !"
	echo ""
	exit 0
fi

#
# If we are not going to install Keystone, we proceed to create the environment
# file, declare success of the installation script, and exit this module
#

if [ $keystoneinstall == "no" ]
then
	SERVICE_ENDPOINT="http://$keystonehost:35357/v2.0"
	OS_USERNAME=$keystoneadminuser
	OS_TENANT_NAME=$keystoneadminuser
	OS_PASSWORD=$keystoneadminpass
	OS_AUTH_URL="http://$keystonehost:5000/v2.0"

	echo "# export SERVICE_ENDPOINT=$SERVICE_ENDPOINT" > $keystone_admin_rc_file
	echo "# export SERVICE_TOKEN=$SERVICE_TOKEN" >> $keystone_admin_rc_file
	echo "# export OS_SERVICE_TOKEN=$SERVICE_TOKEN" >> $keystone_admin_rc_file
	echo "export OS_USERNAME=$OS_USERNAME" >> $keystone_admin_rc_file
	echo "export OS_PASSWORD=$OS_PASSWORD" >> $keystone_admin_rc_file
	echo "export OS_TENANT_NAME=$OS_TENANT_NAME" >> $keystone_admin_rc_file
	echo "export OS_AUTH_URL=$OS_AUTH_URL" >> $keystone_admin_rc_file
	echo "export OS_VOLUME_API_VERSION=2" >> $keystone_admin_rc_file
	echo "PS1='[\u@\h \W(keystone_admin)]\$ '" >> $keystone_admin_rc_file

        OS_AUTH_URL_FULLADMIN="http://$keystonehost:35357/v2.0"

        echo "# export SERVICE_ENDPOINT=$SERVICE_ENDPOINT" > $keystone_fulladmin_rc_file
        echo "# export SERVICE_TOKEN=$SERVICE_TOKEN" >> $keystone_fulladmin_rc_file
        echo "# export OS_SERVICE_TOKEN=$SERVICE_TOKEN" >> $keystone_fulladmin_rc_file
        echo "export OS_USERNAME=$OS_USERNAME" >> $keystone_fulladmin_rc_file
        echo "export OS_PASSWORD=$OS_PASSWORD" >> $keystone_fulladmin_rc_file
        echo "export OS_TENANT_NAME=$OS_TENANT_NAME" >> $keystone_fulladmin_rc_file
        echo "export OS_AUTH_URL=$OS_AUTH_URL_FULLADMIN" >> $keystone_fulladmin_rc_file
        echo "export OS_VOLUME_API_VERSION=2" >> $keystone_fulladmin_rc_file
        echo "PS1='[\u@\h \W(keystone_fulladmin)]\$ '" >> $keystone_fulladmin_rc_file

	mkdir -p /etc/openstack-control-script-config
	date > /etc/openstack-control-script-config/keystone-installed
	date > /etc/openstack-control-script-config/keystone-extra-idents

	exit 0
fi

echo "Installing Keystone Packages"

#
# We proceed to install keystone packages and it's dependencies
#
# IMPORTANT NOTE: From KILO, Keystone make use of mod_wsgi and apache for it's
# services in ports 5000 and 35357
# but, for some reason, this is not working properlly yet in Centos
# We'll prepare everything for a future use of wsgi
#

yum -y install openstack-keystone openstack-utils openstack-selinux python-psycopg2
yum -y install mod_wsgi memcached python-memcached httpd
yum -y install python-openstackclient

#
# We also start/enable memcached service
#

systemctl enable memcached.service
systemctl start memcached.service

echo "Done"

#
# We export Keystone "admin service token", defined in our main configutation file at ./configs directory
#

echo $SERVICE_TOKEN > /root/ks_admin_token
export OS_TOKEN=$SERVICE_TOKEN


echo ""
echo "Configuring Keystone"

sync
sleep 5
sync

#
# Using pyhton based "ini" configuration tools, we begin Keystone configuration
#

crudini --set /etc/keystone/keystone.conf DEFAULT admin_token $SERVICE_TOKEN
crudini --set /etc/keystone/keystone.conf DEFAULT compute_port 8774
crudini --set /etc/keystone/keystone.conf DEFAULT debug False
crudini --set /etc/keystone/keystone.conf DEFAULT verbose False
crudini --set /etc/keystone/keystone.conf DEFAULT log_file /var/log/keystone/keystone.log
crudini --set /etc/keystone/keystone.conf DEFAULT use_syslog False
crudini --set /etc/keystone/keystone.conf memcache servers localhost:11211


case $dbflavor in
"mysql")
	crudini --set /etc/keystone/keystone.conf database connection mysql://$keystonedbuser:$keystonedbpass@$dbbackendhost:$mysqldbport/$keystonedbname
	;;
"postgres")
	crudini --set /etc/keystone/keystone.conf database connection postgresql://$keystonedbuser:$keystonedbpass@$dbbackendhost:$psqldbport/$keystonedbname
	;;
esac

crudini --set /etc/keystone/keystone.conf database retry_interval 10
crudini --set /etc/keystone/keystone.conf database idle_timeout 3600
crudini --set /etc/keystone/keystone.conf database min_pool_size 1
crudini --set /etc/keystone/keystone.conf database max_pool_size 10
crudini --set /etc/keystone/keystone.conf database max_retries 100
crudini --set /etc/keystone/keystone.conf database pool_timeout 10

crudini --set /etc/keystone/keystone.conf catalog driver keystone.catalog.backends.sql.Catalog
crudini --set /etc/keystone/keystone.conf token expiration 86400
# Since KILO, we use memcache as persistence token cache. That is included on KILO documentation
crudini --set /etc/keystone/keystone.conf token driver keystone.token.persistence.backends.memcache.Token
crudini --set /etc/keystone/keystone.conf revoke driver keystone.contrib.revoke.backends.sql.Revoke

case $keystonetokenflavor in
"pki")
	keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
	chown -R keystone:keystone /var/log/keystone /etc/keystone/ssl
	crudini --set /etc/keystone/keystone.conf token provider keystone.token.providers.pki.Provider
	;;
"uuid")
	crudini --set /etc/keystone/keystone.conf token provider keystone.token.providers.uuid.Provider
	;;
esac

#
# We provision/update Keystone database
#

su keystone -s /bin/sh -c "keystone-manage db_sync"

echo "Done"
echo ""

#
# With the basic configuration done, and the "admin service token" exported to our environment,
# we proceed to start Keystone in order to create all needed credentials
#

echo "Starting Keystone"

# Keystone nows uses apache and wsgi instead of it's own services

systemctl stop openstack-keystone.service
systemctl disable openstack-keystone.service

systemctl start memcached.service
systemctl enable memcached.service

mkdir -p /var/www/cgi-bin/keystone/
rm -f /var/www/cgi-bin/keystone/*
cp -v /usr/share/keystone/keystone.wsgi /var/www/cgi-bin/keystone/admin
cp -v /usr/share/keystone/keystone.wsgi /var/www/cgi-bin/keystone/main
cp -v ./libs/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
# 
chown -R keystone:keystone /var/www/cgi-bin/keystone
chmod 755 /var/www/cgi-bin/keystone/*
#
# PATCH !!.. Without this, Keystone on wsgi does not work...
crudini --set /etc/keystone/keystone.conf paste_deploy config_file "/usr/share/keystone/keystone-dist-paste.ini"
cat /etc/keystone/keystone.conf > /usr/share/keystone/keystone-dist.conf
cat /etc/keystone/policy.json > /usr/share/keystone/policy.json
chown root.keystone /usr/share/keystone/policy.json
# END OF PATCH !!
#
keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
chown -R keystone:keystone /var/log/keystone
chown -R keystone:keystone /etc/keystone/ssl
chmod -R o-rwx /etc/keystone/ssl
#
restorecon /var/www/cgi-bin
#
usermod -a -G keystone apache
#
#
systemctl start httpd.service
systemctl restart httpd.service
systemctl enable httpd.service
#

echo "Done"

sync
sleep 5
sync

echo ""

#
# Here is where the most important part of OpenStack Cloud deployment starts. If there is no identity service
# with properlly configured users, services, roles, endpoints, etc., then no OpenStack service will be able
# to function.
#
# First, we'll create Keystone identities, then the entities for all OpenStack services we are required to
# install
#

echo "Creating Keystone Service Endpoint"
export OS_URL="http://$keystonehost:35357/v2.0"
openstack service create \
	--name $keystoneservicename \
	--description="Keystone Identity Service" \
	identity

sync
sleep 5
sync

echo "Creating endpoint V 2.0"

openstack endpoint create \
	--publicurl "http://$keystonehost:5000/v2.0" \
	--internalurl "http://$keystonehost:5000/v2.0" \
	--adminurl "http://$keystonehost:35357/v2.0" \
	--region $endpointsregion \
	identity

sync
sleep 5
sync

echo "Creating Admin Project: $keystoneadminuser"
openstack project create --description "Admin Project" $keystoneadminuser

echo "Creating Admin User: $keystoneadminuser"
openstack user create --password $keystoneadminpass --email $keystoneadminuseremail $keystoneadminuser

echo "Creating Admin Role: $keystoneadminuser"
openstack role create $keystoneadminuser

echo "Adding Admin role to $keystoneadminuser User in $keystoneadminuser Project"
openstack role add --project $keystoneadminuser --user $keystoneadminuser $keystoneadminuser

echo "Creating Services Project: $keystoneservicestenant"
openstack project create --description "Service Project" $keystoneservicestenant

# Dashboard/Reseller
echo "Creating Member Role: $keystonememberrole"
openstack role create $keystonememberrole

echo "Adding Member Role $keystonememberrole to Admin User: $keystoneadminuser"
openstack role add --project $keystoneadminuser --user $keystoneadminuser $keystonememberrole

sync
sleep 5
sync

#
# Keystone Service endpoints ready, then we provision our environment file
#

SERVICE_ENDPOINT="http://$keystonehost:35357/v2.0"
OS_USERNAME=$keystoneadminuser
OS_TENANT_NAME=$keystoneadminuser
OS_PASSWORD=$keystoneadminpass
OS_AUTH_URL="http://$keystonehost:5000/v2.0"

echo "# export SERVICE_ENDPOINT=$SERVICE_ENDPOINT" > $keystone_admin_rc_file
echo "# export SERVICE_TOKEN=$SERVICE_TOKEN" >> $keystone_admin_rc_file
echo "# export OS_SERVICE_TOKEN=$SERVICE_TOKEN" >> $keystone_admin_rc_file
echo "export OS_USERNAME=$OS_USERNAME" >> $keystone_admin_rc_file
echo "export OS_PASSWORD=$OS_PASSWORD" >> $keystone_admin_rc_file
echo "export OS_TENANT_NAME=$OS_TENANT_NAME" >> $keystone_admin_rc_file
echo "export OS_AUTH_URL=$OS_AUTH_URL" >> $keystone_admin_rc_file
echo "export OS_VOLUME_API_VERSION=2" >> $keystone_admin_rc_file
echo "PS1='[\u@\h \W(keystone_admin)]\$ '" >> $keystone_admin_rc_file

OS_AUTH_URL_FULLADMIN="http://$keystonehost:35357/v2.0"

echo "# export SERVICE_ENDPOINT=$SERVICE_ENDPOINT" > $keystone_fulladmin_rc_file
echo "# export SERVICE_TOKEN=$SERVICE_TOKEN" >> $keystone_fulladmin_rc_file
echo "# export OS_SERVICE_TOKEN=$SERVICE_TOKEN" >> $keystone_fulladmin_rc_file
echo "export OS_USERNAME=$OS_USERNAME" >> $keystone_fulladmin_rc_file
echo "export OS_PASSWORD=$OS_PASSWORD" >> $keystone_fulladmin_rc_file
echo "export OS_TENANT_NAME=$OS_TENANT_NAME" >> $keystone_fulladmin_rc_file
echo "export OS_AUTH_URL=$OS_AUTH_URL_FULLADMIN" >> $keystone_fulladmin_rc_file
echo "export OS_VOLUME_API_VERSION=2" >> $keystone_fulladmin_rc_file
echo "PS1='[\u@\h \W(keystone_fulladmin)]\$ '" >> $keystone_fulladmin_rc_file

#
# Then we source the file, as we are goint to use it from now on
#

# source $keystone_admin_rc_file
source $keystone_fulladmin_rc_file

echo "Keystone Main Identities Configured:"

openstack project list
openstack user list
openstack service list
openstack endpoint list
openstack role list


#
# We apply IPTABLES rules and verify if the service was properlly installed. If not, we fail
# and stop further processing.
#

echo ""
echo "Applying IPTABLES rules"

iptables -A INPUT -p tcp -m multiport --dports 5000,11211,35357 -j ACCEPT
service iptables save

keystonetest=`rpm -qi openstack-keystone|grep -ci "is not installed"`
if [ $keystonetest == "1" ]
then
	echo ""
	echo "Keystone Installation FAILED. Aborting !"
	echo ""
	exit 0
else
	date > /etc/openstack-control-script-config/keystone-installed
	date > /etc/openstack-control-script-config/keystone
fi

checkadmincreate=`openstack user list|awk '{print $4}'|grep -ci ^$keystoneadminuser$`

if [ $checkadmincreate == "0" ]
then
	echo ""
	echo "Admin User Creation FAILED - Aborting !"
	echo ""
	rm -f /etc/openstack-control-script-config/keystone-installed
	rm -f /etc/openstack-control-script-config/keystone
	exit 0
fi

#
# Now, depending if the choose to install specific OpenStack components, we proceed
# to call the keystone sub-script that will create the specific service identities,
# meaning: user, roles, services, and endpoints.
#
# OpenStack Components make use of REST interface trough their Endpoints in order to
# communicate to each other. Without those endpoints, OpenStack will not work at all.
#
# In all and every sub-script the proccess is the same: First we create the user, then
# we assign a role to the user, second: we create the service (or services) identity,
# and finally we create the endpoint (or endpoints) identity.
#

echo ""
echo "Creating OpenStack Services Identities"
echo ""


if [ $swiftinstall == "yes" ]
then
	./modules/keystone-swift.sh
fi

if [ $glanceinstall == "yes" ]
then
	./modules/keystone-glance.sh
fi

if [ $cinderinstall == "yes" ]
then
	./modules/keystone-cinder.sh
fi

if [ $neutroninstall == "yes" ]
then
	./modules/keystone-neutron.sh
fi

if [ $novainstall == "yes" ]
then
	./modules/keystone-nova.sh
fi

if [ $ceilometerinstall == "yes" ]
then
	./modules/keystone-ceilometer.sh
fi

if [ $heatinstall == "yes" ]
then
	./modules/keystone-heat.sh
fi

case $dbflavor in
"mysql")
        if [ $troveinstall == "yes" ]
        then
                ./modules/keystone-trove.sh
        fi
        ;;
"postgres")
        if [ $troveinstall == "yes" ]
        then
		./modules/keystone-trove.sh
        fi
        ;;
esac


if [ $saharainstall == "yes" ]
then
	./modules/keystone-sahara.sh
fi

#
# If we define extra tenants in the installer config file, here we proceed to create them
#

./modules/keystone-extratenants.sh

date > /etc/openstack-control-script-config/keystone-extra-idents

#
# Everything done, we proceed to list all identities created by this module
#

echo ""
echo "Ready"

echo ""
echo "Keystone Proccess DONE"
echo ""

echo "Complete list following bellow:"
echo ""
echo "Projects:"
openstack project list
sleep 5
echo "Users:"
openstack user list
sleep 5
echo "Services:"
openstack service list
sleep 5
echo "Roles:"
openstack role list
sleep 5
echo "Endpoints:"
openstack endpoint list
sleep 5

echo ""
echo "Identities Proccess completed"
echo ""


