#!/bin/sh
set -e

mkdir -p /etc/nginx/ssl

if [ ! -f /etc/nginx/ssl/cert.pem ]; then
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout /etc/nginx/ssl/key.pem \
		-out /etc/nginx/ssl/cert.pem \
		-subj "/C=BR/ST=RJ/L=RJ/O=42/CN=mviana-v.42.fr"
fi

exec nginx -g "daemon off;"
