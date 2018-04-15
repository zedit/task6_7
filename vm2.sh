#!/bin/bash

source vm2.config

conf_net="/etc/network/interfaces"
int_if=${1:-$INTERNAL_IF}

function conf_ext_iface() {
  if ! cat "${conf_net}" | grep "${int_if}" >> /dev/null; then
    echo "auto ${int_if}" >> "${conf_net}"
    echo "iface ${int_if} inet static" >> "${conf_net}"
    if ! cat "${conf_net}" | grep "${INT_IP}" >> /dev/null; then
      echo "address ${INT_IP}" >> "${conf_net}"
      echo "gateway ${GW_IP}" >> "${conf_net}"
      ifup "${int_if}"
    else
      echo "Address ${INT_IP} already taken" 
    fi
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf
  else
    echo "Interface ${int_if} already configured"
  fi
}

function conf_vlan() {
  check_vlan_inst=$(apt-cache policy vlan | grep Installed | awk -F ': ' '{print $2}')
  if [ "${check_vlan_inst}" == "(none)" ]; then
    apt-get update
    apt-get install -y vlan
  fi
  vconfig add "${int_if}" "${VLAN}"
  ip addr add "${APACHE_VLAN_IP}" dev "${int_if}.${VLAN}"
  ip link set up "${int_if}.${VLAN}"
}

function nginx_conf() {
  check_nginx_inst=$(apt-cache policy apache2 | grep Installed | awk -F ': ' '{print $2}')
  if [ "${check_nginx_inst}" == "(none)" ]; then
    apt-get update
    apt-get install -y apache2
  fi
cat << EOF > /tmp/site.conf 

EOF
}


