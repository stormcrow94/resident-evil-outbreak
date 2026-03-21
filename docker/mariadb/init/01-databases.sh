#!/bin/bash
set -euo pipefail
# MariaDB official image runs scripts in /docker-entrypoint-initdb.d on first data volume init only.
# Creates remote-capable user for the Java bioservers (split compose).

mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<-EOSQL
CREATE DATABASE IF NOT EXISTS bioserver;
CREATE DATABASE IF NOT EXISTS bioserver2;
CREATE USER IF NOT EXISTS 'bioserver'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON bioserver.* TO 'bioserver'@'%';
GRANT ALL PRIVILEGES ON bioserver2.* TO 'bioserver'@'%';
FLUSH PRIVILEGES;
EOSQL

# Schemas are mounted outside initdb.d (see docker-compose.split.yml) to avoid double-execution.
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" bioserver < /tmp/schema-bioserver.sql
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" bioserver2 < /tmp/schema-bioserver2.sql
