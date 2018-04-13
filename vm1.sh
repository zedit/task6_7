#!/bin/bash

source vm1.config

ext_if=${1:-$EXTERNAL_IF}
int_if=${2:-$INTERNAL_IF}
man_if=${3:-$MANAGEMENT_IF}
conf_net="/etc/network/interfaces"

function conf_int_iface() {
  if ! cat "${conf_net}" | grep "${int_if}" >> /dev/null; then
    echo "auto ${int_if}" >> "${conf_net}"
    echo "iface ${int_if} inet static" >> "${conf_net}"
    if ! cat "${conf_net}" | grep "${INT_IP}" >> /dev/null; then
      echo "address ${INT_IP}" >> "${conf_net}"
      ifup "${int_if}"
    else
      echo "Address ${INT_IP} already taken" 
    fi
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf
    iptables -t nat -A POSTROUTING -s ${INT_IP} ! -d ${INT_IP} -j MASQUERADE
    sysctl -w net.ipv4.ip_forward=1
  else
    echo "Interface ${int_if} already configured"
  fi
}

conf_int_iface

