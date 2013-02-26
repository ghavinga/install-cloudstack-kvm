#!/bin/bash
# Script to prepare a virgin installation of Ubuntu 12.10 server for Cloudstack
# KVM node deployment
#
# Version 0.4, Gerry Havinga, January 2013
# 
# 0.1 - first attempt, not complete
# 0.2 - added extra echo statements to make output more eligible (still a mess)
# 0.3 - Fixed wrong sed match
# 0.4 - added function to edit qemu.conf and enable VNC console access from anywhere
# 0.5 - Ubuntu 12.10LTS of course
#
# Ubuntu installed with defaults, "Basic Ubuntu server" and "OpenSSH server" software installed.

function init_vars ()
{
	# Date
	date=`date +%Y%m%d%H%M%S`
	# Will only run on
	SUPPORTED_UBUNTU=12.10TLS
	# For basic netorking all hosts can be in the same subnet. Networks are isolated
	# by specifying non-overlapping ranges of IP addresses.
	# Set IP addressing:
	# Assuming management to run between IPs 32 and 64
	MANAGER_IP=10.128.0.32
	MANAGER_NAME=cloudstack
	MANAGER_FQDN_NAME=cloudstack.acme.com
	# Assuming nodes to run between IPs 65 and 94
	# Node
	KVM_NODE_IP=10.128.0.48
	KVM_NODE_MASK=255.255.255.0
	KVM_NODE_NW=10.128.0.0
	KVM_NODE_GW=10.128.0.1
	KVM_NODE_BC=10.128.0.255
	KVM_NODE_NAME=node01leusden
	KVM_FQDN_NODE_NAME=node01leusden.acme.com
	# Management network (KVM host must be able to see Cloudstack manager)
	MGMT_NET=10.128.0.0
	MGMT_MASK=255.255.255.0
	MGMT_GW=10.128.0.1
	# Public network - addresses associated with Internet accessible hosts
	# In basic networking the guest and public networks are the same
	# Assuming public network range from IPs 95 till 126
	PUBLIC_NET=10.128.0.95
	PUBLIC_MASK=255.255.255.0
	PUBLIC_GW=10.128.0.1
	# Guest network, tenant network to which instances are attached
	# In basic networking the guest and public networks are the same
	# Assuming guest network range from IPs 95 till 126
	GUEST_NET=10.128.0.95
	GUEST_MASK=255.255.255.0
	GUEST_GW=10.128.0.1
	# Privat (storage) network - must be accessible by system VMs and KVM host
	# Assuming from IPs 65 and 94
	PRIVAT_NET=10.128.0.65
	PRIVAT_MASK=255.255.255.0
	PRIVAT_GW=10.128.0.1
	# Name servers
	DNS_PRIMARY=10.0.0.1
	DNS_SECONDARY=8.8.8.8
	DNS_SEARCH=acme.com
	echo "Script $0 for setting up an $SUPPORTED_UBUNTU KVM host for inclusion in a Cloudstack POD."
	echo "IP settings will be:"
	echo "This host: [$KVM_NODE_IP] [$KVM_NODE_MASK] [$KVM_NODE_GW]"
	echo "Management network: [$MGMT_NET] [$MGMT_MASK] [$MGMT_GW]"
	echo "Public network: [$PUBLIC_NET] [$PUBLIC_MASK] [$PUBLIC_GW]"
	echo "Guest network (for VMs): [$GUEST_NET] [$GUEST_MASK] [$GUEST_GW]"
	echo "Privat (storage) network: [$PRIVAT_NET] [$PRIVAT_MASK] [$PRIVAT_GW]"
	read -p "Do you wish to continue [ynq]?" yn
	case $yn in
		[Yy]* ) return; echo " ";;
		[NnQq]* ) exit;;
		* ) echo "Please answer y or n.";;
	esac
}

function enable_root ()
{
	echo "Enabling root, please specify a new root password."
	sudo passwd root
	echo " "
}

function make_interfaces_bridges ()
{
	echo "Trying to install Cloudstack for KVM once again ...."
	echo "With pre-configured bridges."
	echo "KVM node IP addres and mask: $KVM_NODE_IP $KVM_NODE_MASK"
	echo "Management network, mask and gateway: $MGMT_NET $MGMT_GW"
	echo "Public network, mask and gateway: $PUBLIC_NET $PUBLIC_MASK $PUBLIC_GW"
	echo "Guest network, mask and gateway: $GUEST_NET $GUEST_MASK $GUEST_GW"
	echo "Privat (storage) network, mask and gateway: $PRIVAT_NET $PRIVAT_MASK $PRIVAT_GW"
	echo "Making backup of interfaces... to /etc/network/interfaces.backup.$date"
	cp /etc/network/interfaces /etc/network/interfaces.backup.$date
	cat > /etc/network/interfaces << _EOF_
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet static
	address $KVM_NODE_IP
	netmask $KVM_NODE_MASK
	network $KVM_NODE_NW
	broadcast $KVM_NODE_BC
	gateway $KVM_NODE_GW
	# dns-* options are implemented by the resolvconf package, if installed
	dns-nameservers $DNS_PRIMARY $DNS_SECONDARY
	dns-search $DNS_SEARCH

# Public network
auto cloudbr0
iface cloudbr0 inet manual
    bridge_ports eth0.200
    bridge_fd 5
    bridge_stp off
    bridge_maxwait 1

# Private network
auto cloudbr1
iface cloudbr1 inet manual
    bridge_ports eth0.300
    bridge_fd 5
    bridge_stp off
    bridge_maxwait 1
_EOF_
	echo " "
}

function make_interfaces ()
{
	echo "Trying to install Cloudstack for KVM once again ...."
	echo "Without pre-configured bridges."
	echo "KVM node IP addres and mask: $KVM_NODE_IP $KVM_NODE_MASK"
	echo "Management network, mask and gateway: $MGMT_NET $MGMT_GW"
	echo "Public network, mask and gateway: $PUBLIC_NET $PUBLIC_MASK $PUBLIC_GW"
	echo "Guest network, mask and gateway: $GUEST_NET $GUEST_MASK $GUEST_GW"
	echo "Privat (storage) network, mask and gateway: $PRIVAT_NET $PRIVAT_MASK $PRIVAT_GW"
	echo "Making backup of interfaces... to /etc/network/interfaces.backup.$date"
	cp /etc/network/interfaces /etc/network/interfaces.backup.$date
	cat > /etc/network/interfaces << _EOF_
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet static
	address $KVM_NODE_IP
	netmask $KVM_NODE_MASK
	network $KVM_NODE_NW
	broadcast $KVM_NODE_BC
	gateway $KVM_NODE_GW
	# dns-* options are implemented by the resolvconf package, if installed
	dns-nameservers $DNS_PRIMARY $DNS_SECONDARY
	dns-search $DNS_SEARCH

_EOF_
	echo " "
}

function set_hosts_hostname ()
{
	echo "Setting hostname and hosts file."
	echo "Making backup of hostname file to /etc/hostname.backup.$date."
	cp /etc/hostname /etc/hostname.backup.$date
	cat > /etc/hostname << _EOF_
$KVM_NODE_NAME
_EOF_
	echo "Making backup of hosts file to /etc/hosts.backup.$date."
	cp /etc/hosts /etc/hosts.backup.$date
	cat > /etc/hosts << _EOF_
127.0.0.1	localhost
$KVM_NODE_IP	$KVM_FQDN_NODE_NAME	$KVM_NODE_NAME
$MANAGER_IP	$MANAGER_FQDN_NAME	$MANAGER_NAME

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
_EOF_
	hostname -b -F /etc/hostname
	echo " "
}

function restart_network ()
{
	echo "Restarting network..."
	/etc/init.d/networking restart
	echo " "
}

function set_firewall ()
{
	echo "Setting up Ubuntu's simple firewall..."
	ufw allow proto tcp from any to any port 22
	ufw allow proto tcp from any to any port 1798
	ufw allow proto tcp from any to any port 16509
	ufw allow proto tcp from any to any port 5900:6100
	ufw allow proto tcp from any to any port 49152:49216
	ufw enable
	echo " "
}

function ubuntu_update ()
{
	echo "Prepare the Cloudstack repository."
	cat > /etc/apt/sources.list.d/cloudstack.list << _EOF_
deb http://cloudstack.apt-get.eu/ubuntu precise 4.0
_EOF_
	wget -O - http://cloudstack.apt-get.eu/release.asc|apt-key add -
	echo "Update and upgrade."
	apt-get -y update
	apt-get -y upgrade
	echo "Install openntpd (update/upgrade first because of a bug in 12.10)"
	apt-get -y install openntpd
	echo "In case we need it."
	apt-get -y install tcpdump
	echo " "
}

function pre_install_checks ()
{
	echo "Does hostname resolve fully?"
	hostname --fqdn
	echo "Can we reach the outside world?"
	ping -c 4 www.cloudstack.org
	echo "Can we ping the management?"
	ping -c 4 $MANAGER_IP
	echo "*************************************************************"
	echo "Warning check the above two tests have worked as you expected."
	echo "Only continue if both FQDN and outside world tests succeeded."
	echo "*************************************************************"
	read -p "Do you wish to continue?" yn
	case $yn in
		[Yy]* ) return; echo " ";;
		[Nn]* ) exit;;
		* ) echo "Please answer y or n.";;
	esac
}

function install_cloudstack ()
{
	echo "Installing cloudstack agent and system iso."
	apt-get -y install cloud-agent
	apt-get -y install cloud-system-iso
}

function prepare_libvirt ()
{
	echo "Updating the libvirt configuration (appending)..."
	cp /etc/libvirt/libvirtd.conf /etc/libvirt/libvirtd.conf.backup.$date
	cat >> /etc/libvirt/libvirtd.conf << _EOF_
listen_tls = 0
listen_tcp = 1
tcp_port = 16059
auth_tcp = "none"
mdns_adv = 0
_EOF_
	echo "Adjusting startup parameters for libvirt deamon."
	cp /etc/init/libvirt-bin.conf /etc/init/libvirt-bin.conf.backup.$date
	sed -i 's/libvirtd_opts="-d"/libvirtd_opts="-d -l"/g' /etc/init/libvirt-bin.conf
	echo "Restarting libvirt service..."
	service libvirt-bin restart
	echo " "
}

function prepare_qemu ()
{
	echo "Adjusting vnc_listen = 0.0.0.0 in /etc/libvirt/qemu.conf. "
	cp /etc/libvirt/qemu.conf /etc/libvirt/qemu.conf.backup.$date
	sed -i 's/# vnc_listen = "0.0.0.0"/vnc_listen = "0.0.0.0"/g' /etc/libvirt/qemu.conf
	service libvirt-bin restart
}


function prepare_apparmor ()
{
	dpkg --list 'apparmor'
	echo "Prepare Ubuntu's application armor to be nice to libvirt."
	ln -s /etc/apparmor.d/usr.sbin.libvirtd /etc/apparmor.d/disable/
	ln -s /etc/apparmor.d/usr.lib.libvirt.virt-aa-helper /etc/apparmor.d/disable/
	apparmor_parser -R /etc/apparmor.d/usr.sbin.libvirtd
	apparmor_parser -R /etc/apparmor.d/usr.lib.libvirt.virt-aa-helper
	echo " "
}

function list_addresses ()
{
	echo " "
	echo "IP settings:"
	echo "This host: [$KVM_NODE_IP] [$KVM_NODE_MASK] [$KVM_NODE_GW]"
	echo "Management network: [$MGMT_NET] [$MGMT_MASK] [$MGMT_GW]"
	echo "Public network: [$PUBLIC_NET] [$PUBLIC_MASK] [$PUBLIC_GW]"
	echo "Guest network (for VMs): [$GUEST_NET] [$GUEST_MASK] [$GUEST_GW]"
	echo "Privat (storage) network: [$PRIVAT_NET] [$PRIVAT_MASK] [$PRIVAT_GW]"
	echo " "
}

# Main part
init_vars
enable_root
make_interfaces
# make_interfaces_bridges
set_hosts_hostname 
restart_network
set_firewall
ubuntu_update
pre_install_checks
install_cloudstack
prepare_libvirt
prepare_qemu 
prepare_apparmor
list_addresses
echo "Recommend to re-boot the system."
echo "Now add the KVM host to the Cloud manager."
echo "End of script."

