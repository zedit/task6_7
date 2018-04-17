#!/bin/bash

source vm1.config

ext_if=${1:-$EXTERNAL_IF}
int_if=${2:-$INTERNAL_IF}
conf_net="/etc/network/interfaces"
ssl_cert="/etc/ssl/certs/web.crt"
ssl_cert_key="/etc/ssl/certs/web.key"
root_cert="/etc/ssl/certs/root-ca.crt"
root_cert_key="/etc/ssl/certs/root-ca.key"

function conf_ext_iface() {
  if [ "${EXT_IP}" == "dhcp" ]; then  
    echo "auto ${ext_if}" >> "${conf_net}"
    echo "iface ${ext_if} inet "${EXT_IP}"" >> "${conf_net}"
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf
    systemctl restart networking.service
  else
    echo "auto ${ext_if}" >> "${conf_net}"
    echo "iface ${ext_if} inet static" >> "${conf_net}"
    echo "address ${EXT_IP}" >> "${conf_net}"
    echo "gateway ${EXT_GW}" >> "${conf_net}"
    ifup "${ext_if}"
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf
    systemctl restart networking.service
  fi
}

function conf_int_iface() {
  echo "auto ${int_if}" >> "${conf_net}"
  echo "iface ${int_if} inet static" >> "${conf_net}"
  echo "address ${INT_IP}" >> "${conf_net}"
  ifup "${int_if}"
  echo "nameserver 8.8.8.8" >> /etc/resolv.conf
  iptables -t nat -A POSTROUTING -s ${INT_IP} ! -d ${INT_IP} -j MASQUERADE
  sysctl -w net.ipv4.ip_forward=1
  systemctl restart networking.service
}

function conf_vlan() {
  check_vlan_inst=$(apt-cache policy vlan | grep Installed | awk -F ': ' '{print $2}')
  if [ "${check_vlan_inst}" == "(none)" ]; then
    apt-get update
    apt-get install -y vlan
  fi 
  apt-get install -y vlan
  modprobe 8021q
  vconfig add "${int_if}" "${VLAN}"
  ip addr add "${VLAN_IP}" dev "${int_if}.${VLAN}"
  ip link set up "${int_if}.${VLAN}"
}

function get_ssl_certs() {
  openssl genrsa -out "${root_cert_key}" 4096
  openssl req -x509 -new -nodes -key "${root_cert_key}" -sha256 -days 10000 -out "${root_cert}" -subj "/C=UA/ST=Kharkov/L=Kharkov/O=homework/OU=task6_7/CN=root_cert"
  openssl genrsa -out "${ssl_cert_key}" 2048
  openssl req -new -out /etc/ssl/certs/web.csr -key "${ssl_cert_key}" -subj "/C=UA/ST=Kharkov/L=Kharkov/O=homework/OU=task6_7/CN=$(hostname)/"
  openssl x509 -req -in /etc/ssl/certs/web.csr -CA "${root_cert}" -CAkey "${root_cert_key}" -CAcreateserial -out "${ssl_cert}"
  cat "${ssl_cert}" "${root_cert}" > /etc/ssl/certs/web-ca-chain.pem
}

function conf_nginx() {
  check_nginx_inst=$(apt-cache policy nginx | grep Installed | awk -F ': ' '{print $2}')
  if [ "${check_nginx_inst}" == "(none)" ]; then
    apt-get update 
    apt-get install -y nginx
  fi
cat << EOF > /etc/nginx/sites-available/example.com 
server {
    listen ${NGINX_PORT} ssl;
    server_name vm2;

    ssl on;
    ssl_certificate         ${ssl_cert};
    ssl_certificate_key     ${ssl_cert_key};
    ssl_trusted_certificate ${root_cert};

    location / {
        proxy_pass http://${APACHE_VLAN}/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
  ln -s /etc/nginx/sites-available/vm1 /etc/nginx/sites-enabled/vm1
}

conf_ext_iface
conf_int_iface
conf_vlan
get_ssl_certs
conf_nginx
