#!/bin/bash

# Проверяем, что скрипт запущен от root
if [ "$EUID" -ne 0 ]
  then echo "Пожалуйста, запустите скрипт от root"
  exit
fi

# Проверяем наличие аргументов
if [ $# -ne 3 ]; then
    echo "Использование: $0 <домен> <внутренний адрес сервера (например, localhost:3000)> <email>"
    exit 1
fi

DOMAIN=$1
INTERNAL_ADDRESS=$2
EMAIL=$3

# Устанавливаем необходимые пакеты
echo "Установка Nginx и Certbot..."
apt update
apt install -y nginx certbot python3-certbot-nginx

# Создаем конфигурацию Nginx
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
echo "Создаем конфигурацию Nginx для домена $DOMAIN..."

cat > $NGINX_CONF <<EOL
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://$INTERNAL_ADDRESS;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}
EOL

# Включаем сайт в Nginx
ln -s $NGINX_CONF /etc/nginx/sites-enabled/

# Проверяем конфигурацию Nginx
echo "Проверка конфигурации Nginx..."
nginx -t

# Перезапуск Nginx
echo "Перезапуск Nginx..."
systemctl reload nginx

echo "Добавляем Nginx в автозапуск..."
systemctl enable nginx

# Устанавливаем SSL сертификат с помощью Certbot
echo "Запуск Certbot для получения SSL сертификата..."
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

# Проверяем статус обновления сертификатов
echo "Проверка Certbot..."
certbot renew --dry-run

echo "Настройка завершена! Ваш домен $DOMAIN настроен для проксирования на $INTERNAL_ADDRESS с поддержкой SSL."
