#!/bin/bash

source vm2.config

conf_net="/etc/network/interfaces"
int_if=${1:-$INTERNAL_IF}

function conf_ext_iface() {
  echo "auto ${int_if}" >> "${conf_net}"
  echo "iface ${int_if} inet static" >> "${conf_net}"
  echo "address ${INT_IP}" >> "${conf_net}"
  echo "gateway ${GW_IP}" >> "${conf_net}"
  ifup "${int_if}"
  echo "nameserver 8.8.8.8" >> /etc/resolv.conf
  systemctl restart networking.service
}

function conf_vlan() {
  check_vlan_inst=$(apt-cache policy vlan | grep Installed | awk -F ': ' '{print $2}')
  if [ "${check_vlan_inst}" == "(none)" ]; then
    apt-get update
    apt-get install -y vlan
  fi
  modprobe 8021q
  vconfig add "${int_if}" "${VLAN}"
  ip addr add "${APACHE_VLAN_IP}" dev "${int_if}.${VLAN}"
  ip link set up "${int_if}.${VLAN}"
}

function conf_apache() {
  check_apache_inst=$(apt-cache policy apache2 | grep Installed | awk -F ': ' '{print $2}')
  if [ "${check_apache_inst}" == "(none)" ]; then
    apt-get update
    apt-get install -y apache2
  fi
  service apache2 start
  apache_vlan=$(echo ${APACHE_VLAN_IP} | awk -F'/' '{print $1}')
  sed -i "s/80/${apache_vlan}:80/" /etc/apache2/ports.conf
  service apache2 restart
}

conf_ext_iface
conf_vlan
conf_apache
