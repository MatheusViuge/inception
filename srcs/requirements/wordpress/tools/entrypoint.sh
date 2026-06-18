#!/bin/sh
set -e

mkdir -p /run/php

PHP_VERSION=$(find /etc/php -mindepth 1 -maxdepth 1 -type d | head -n 1 | xargs basename)

sed -i "s|listen = /run/php/php${PHP_VERSION}-fpm.sock|listen = 9000|" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf

i=0
while [ "$i" -lt 30 ]; do
	if mariadb -h mariadb -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; then
		break
	fi
	i=$((i + 1))
	sleep 1
done

mkdir -p /var/www/html
cd /var/www/html

if [ ! -f wp-config.php ]; then
	wp core download --allow-root

	wp config create --allow-root \
		--dbname="${MYSQL_DATABASE}" \
		--dbuser="${MYSQL_USER}" \
		--dbpass="${MYSQL_PASSWORD}" \
		--dbhost="mariadb:3306"

	wp core install --allow-root \
		--url="https://${DOMAIN_NAME}" \
		--title="${WP_TITLE}" \
		--admin_user="${WP_ADMIN_USER}" \
		--admin_password="${WP_ADMIN_PASSWORD}" \
		--admin_email="${WP_ADMIN_EMAIL}"

	wp user create --allow-root \
		"${WP_USER_USER}" "${WP_USER_EMAIL}" \
		--user_pass="${WP_USER_PASSWORD}"
fi

exec php-fpm${PHP_VERSION} -F
