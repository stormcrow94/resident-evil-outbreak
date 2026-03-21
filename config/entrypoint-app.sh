#!/bin/bash
set -euo pipefail

EXT_IP="${EXTERNAL_IP:?Must set EXTERNAL_IP}"
DB_PASSWORD="${MYSQL_PASSWORD:?Must set MYSQL_PASSWORD}"
DB_HOST="${DB_HOST:-mariadb}"

apply_runtime_config() {
  for d in bioserv1 bioserv2; do
    sed -i "s/^gs_ip=.*/gs_ip=${EXT_IP}/" "/root/bioserver/${d}/config.properties"
    sed -i "s/^db_password=.*/db_password=${DB_PASSWORD}/" "/root/bioserver/${d}/config.properties"
    sed -i "s/^db_host=.*/db_host=${DB_HOST}/" "/root/bioserver/${d}/config.properties"
    sed -i "s/^db_port=.*/db_port=3306/" "/root/bioserver/${d}/config.properties"
  done
  sed -i "s/xxxxxxxxxxxxxxxx/${DB_PASSWORD}/g" /var/www/bhof1/db_cred.php
  sed -i "s/xxxxxxxxxxxxxxxx/${DB_PASSWORD}/g" /var/www/bhof2/db_cred.php
  sed -i "s/^\$serv = '.*';/\$serv = '${DB_HOST}';/" /var/www/bhof1/db_cred.php
  sed -i "s/^\$serv = '.*';/\$serv = '${DB_HOST}';/" /var/www/bhof2/db_cred.php
  cat >/etc/dnsmasq.d/obcomsrv <<EOF
address=/gate1.jp.dnas.playstation.org/${EXT_IP}
address=/www01.kddi-mmbb.jp/${EXT_IP}
listen-address=0.0.0.0
EOF
}

configure_apache_once() {
  mkdir -p /var/lib/outbreak
  local mark="/var/lib/outbreak/.outbreak-httpd-configured-app"
  if [ -f "${mark}" ]; then
    return 0
  fi
  if ! grep -q 'custom OpenSSL' /opt/apache/bin/envvars 2>/dev/null; then
    sed -i '/^export LD_LIBRARY_PATH/i LD_LIBRARY_PATH="/opt/openssl-1.0.2/lib:$LD_LIBRARY_PATH"' /opt/apache/bin/envvars
  fi
  for pat in 'rewrite_module' 'proxy_module' 'proxy_fcgi_module' 'ssl_module'; do
    sed -i "/LoadModule ${pat}/s/^#//" /opt/apache/conf/httpd.conf
  done
  sed -i 's/User daemon/User www-data/g' /opt/apache/conf/httpd.conf
  sed -i 's/Group daemon/Group www-data/g' /opt/apache/conf/httpd.conf
  cat /root/end_of_httpd.conf >>/opt/apache/conf/httpd.conf
  touch "${mark}"
}

wait_for_remote_mysql() {
  for _ in $(seq 1 90); do
    if (echo >/dev/tcp/${DB_HOST}/3306) &>/dev/null; then
      return 0
    fi
    sleep 1
  done
  echo "Could not reach MariaDB at ${DB_HOST}:3306" >&2
  return 1
}

apply_runtime_config
configure_apache_once

mkdir -p /run/php
chown www-data:www-data /run/php

wait_for_remote_mysql

/usr/sbin/dnsmasq --log-facility=/var/log/dnsmasq.log --log-queries
/opt/apache/bin/apachectl -d /opt/apache/ -f /opt/apache/conf/httpd.conf -k start -e info
php-fpm7.4 -D

cd /root/bioserver/bioserv1/
./run_file1.sh &
cd /root/bioserver/bioserv2/
exec ./run_file2.sh
