#!/bin/sh
set -e

echo "[mariadb] Iniciando entrypoint..."

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld
chown -R mysql:mysql /var/lib/mysql

if [ ! -d /var/lib/mysql/mysql ]; then
	echo "[mariadb] Inicializando data directory..."
	mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db > /dev/null 2>&1

	echo "[mariadb] Rodando SQL de setup via bootstrap..."
	mysqld --user=mysql --bootstrap --verbose=0 <<EOFSQL
USE mysql;
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOFSQL

	echo "[mariadb] Setup concluido!"
else
	echo "[mariadb] Data directory ja existe, pulando init."
fi

echo "[mariadb] Subindo MariaDB..."
exec mysqld --user=mysql --bind-address=0.0.0.0 --console
