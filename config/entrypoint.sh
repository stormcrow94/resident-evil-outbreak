#!/bin/bash
set -euo pipefail

EXT_IP="${EXTERNAL_IP:?Must set EXTERNAL_IP (LAN IP of this Docker host as seen by clients)}"
DB_PASSWORD="${MYSQL_PASSWORD:-xxxxxxxxxxxxxxxx}"
MARK_DIR="/var/lib/mysql"
MARK_DB="${MARK_DIR}/.outbreak-db-init"
MARK_HTTPD="${MARK_DIR}/.outbreak-httpd-configured"

apply_runtime_config() {
  for d in bioserv1 bioserv2; do
    sed -i "s/^gs_ip=.*/gs_ip=${EXT_IP}/" "/root/bioserver/${d}/config.properties"
    sed -i "s/^db_password=.*/db_password=${DB_PASSWORD}/" "/root/bioserver/${d}/config.properties"
    sed -i "s/^db_host=.*/db_host=localhost/" "/root/bioserver/${d}/config.properties"
    sed -i "s/^db_port=.*/db_port=3306/" "/root/bioserver/${d}/config.properties"
  done
  sed -i "s/xxxxxxxxxxxxxxxx/${DB_PASSWORD}/g" /var/www/bhof1/db_cred.php
  sed -i "s/xxxxxxxxxxxxxxxx/${DB_PASSWORD}/g" /var/www/bhof2/db_cred.php
  cat >/etc/dnsmasq.d/obcomsrv <<EOF
address=/gate1.jp.dnas.playstation.org/${EXT_IP}
address=/www01.kddi-mmbb.jp/${EXT_IP}
listen-address=0.0.0.0
EOF
}

configure_apache_once() {
  if [ -f "${MARK_HTTPD}" ]; then
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
  touch "${MARK_HTTPD}"
}

init_mysql_data() {
  if [ -f "${MARK_DB}" ]; then
    return 0
  fi
  TMP1="/tmp/bioserver1-$$.sql"
  TMP2="/tmp/bioserver2-$$.sql"
  sed "s/xxxxxxxxxxxxxxxx/${DB_PASSWORD}/g" /root/bioserver/bioserv1/database/bioserver.sql >"${TMP1}"
  sed "s/xxxxxxxxxxxxxxxx/${DB_PASSWORD}/g" /root/bioserver/bioserv2/database/bioserver.sql >"${TMP2}"
  mysql -u root -S /run/mysqld/mysqld.sock <"${TMP1}"
  mysql -u root -S /run/mysqld/mysqld.sock <"${TMP2}"
  rm -f "${TMP1}" "${TMP2}"
  touch "${MARK_DB}"
}

wait_for_mysql() {
  export MYSQL_UNIX_PORT=/run/mysqld/mysqld.sock
  for _ in $(seq 1 90); do
    if mysql -u root -S /run/mysqld/mysqld.sock -e "SELECT 1" &>/dev/null; then
      return 0
    fi
    sleep 1
  done
  echo "MariaDB did not become ready in time." >&2
  return 1
}

apply_runtime_config
configure_apache_once

mkdir -p /run/mysqld /run/php
chown mysql:mysql /run/mysqld 2>/dev/null || true
chown www-data:www-data /run/php

mysqld_safe --user=mysql --pid-file=/run/mysqld/mysqld.pid --socket=/run/mysqld/mysqld.sock --datadir="${MARK_DIR}" --log-error=/var/log/mysql-error.log &
wait_for_mysql
init_mysql_data

/usr/sbin/dnsmasq --log-facility=/var/log/dnsmasq.log --log-queries
/opt/apache/bin/apachectl -d /opt/apache/ -f /opt/apache/conf/httpd.conf -k start -e info
php-fpm7.4 -D

cd /root/bioserver/bioserv1/
./run_file1.sh &
cd /root/bioserver/bioserv2/
exec ./run_file2.sh
