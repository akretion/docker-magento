#! /bin/bash

echo "Waiting for mysql"
until mysql -h "db" -P "$DB_PORT_3306_TCP_PORT" -u "$DB_ENV_USER" -p"$DB_ENV_PASS" &> /dev/null
do
  printf "."
  sleep 1
done

echo -e "\nmysql ready"

# ugly quickfix (it's for dev anyway)
chmod 777 /tmp

mkdir -p /firstrun
if [[ -e /firstrun/ok ]]; then

  echo "not first run so skipping initialization"

else

  cp -r /var_www_backup/* /var/www

  echo "setting the default installer info for magento"
  sed -i "s/<host>localhost/<host>db/g" /var/www/app/etc/config.xml
  sed -i "s/<username\/>/<username>user<\/username>/" /var/www/app/etc/config.xml
  sed -i "s/<password\/>/<password>password<\/password>/g" /var/www/app/etc/config.xml

  echo "Creating the magento database..."

  echo "create database magento" | mysql -u "$DB_ENV_USER" --password="$DB_ENV_PASS" -h db -P "$DB_PORT_3306_TCP_PORT"

  while [ $? -ne 0 ]; do
    sleep 5
    echo "create database magento" | mysql -u "$DB_ENV_USER" --password="$DB_ENV_PASS" -h db -P "$DB_PORT_3306_TCP_PORT"
    echo "show tables" | mysql -u "$DB_ENV_USER" --password="$DB_ENV_PASS" -h db -P "$DB_PORT_3306_TCP_PORT" magento
  done

  echo "Loading sample data"
  mysql -u "$DB_ENV_USER" --password="$DB_ENV_PASS" -h db -P "$DB_PORT_3306_TCP_PORT" magento < /tmp/magento-sample-data-*/magento_sample_data*.sql

  echo "Moving sample media"
  cp -R /tmp/magento-sample-data-1.9.1.0/media/* /var/www/media/
  cp -R /tmp/magento-sample-data-1.9.1.0/skin/* /var/www/skin/

  echo "Moving Magento Connector module"
  cp /tmp/module-magento-trunk/Openlabs_OpenERPConnector-1.1.0/app/etc/modules/Openlabs_OpenERPConnector.xml /var/www/app/etc/modules/
  cp -R /tmp/module-magento-trunk/Openlabs_OpenERPConnector-1.1.0/Openlabs /var/www/app/code/community/
  rm -rf /tmp/module-magento-trunk


  echo "Adding Magento Caching"

  sed -i -e  '/<\/config>/{ r /var/www/app/etc/mage-cache.xml' -e 'd}' /var/www/app/etc/local.xml.template


  echo "Installing"
  php -f /var/www/install.php -- \
  --license_agreement_accepted yes \
  --locale "fr_FR" \
  --timezone "Europe/Berlin" \
  --default_currency "EUR" \
  --db_host "db" \
  --db_name "magento" \
  --db_user "$DB_ENV_USER" \
  --db_pass "$DB_ENV_PASS" \
  --url "$VIRTUAL_HOST" \
  --skip_url_validation \
  --use_rewrites no \
  --use_secure no \
  --secure_base_url "" \
  --use_secure_admin no \
  --admin_firstname "Admin" \
  --admin_lastname "Admin" \
  --admin_email "admin@admin.com" \
  --admin_username "admin" \
  --admin_password "admin25"

  touch /firstrun/ok

fi

chown -R apache:apache /var/www/var
chown -R apache:apache /var/www/media
chown -R apache:apache /var/www/app/etc

if [[ -n "$VIRTUAL_HOST" ]]; then
  php /var/www/seturl.php
fi

service php-fpm start

nginx
