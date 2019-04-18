FROM php:7.2-apache
MAINTAINER Rob Wilkes <mail@robbiew.net>

ENV PHPIPAM_SOURCE="https://github.com/phpipam/phpipam/archive" \
    PHPIPAM_VERSION="1.3.2" \
    PHPMAILER_SOURCE="https://github.com/PHPMailer/PHPMailer/archive" \
    PHPMAILER_VERSION="5.2.27" \
    APACHE_DOCUMENT_ROOT="/var/www/html" \
    MYSQL_HOST="mysql" \
    MYSQL_USER="phpipam" \
    MYSQL_PASSWORD="phpipamadmin" \
    MYSQL_DB="phpipam" \
    MYSQL_PORT="3306" \
    MYSQL_SSL="false" \
    MYSQL_SSL_KEY="/path/to/cert.key" \
    MYSQL_SSL_CERT="/path/to/cert.crt" \
    MYSQL_SSL_CA="/path/to/ca.crt" \
    MYSQL_SSL_CAPATH="/path/to/ca_certs" \
    MYSQL_SSL_CIPHER="DHE-RSA-AES256-SHA:AES128-SHA"

# PHPMailer 6.0.X appears to be currently unsupported by phpIPAM

# Install required deb packages
RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y git libgmp-dev libfreetype6-dev libjpeg62-turbo-dev libldb-dev libldap2-dev inetutils-ping cron fping ssl-cert

# Configure apache and required PHP modules
RUN rm -rf /var/lib/apt/lists/* && \
    docker-php-ext-configure mysqli --with-mysqli=mysqlnd && \
    docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ && \
    ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h && \
    docker-php-ext-configure gmp --with-gmp=/usr/include/x86_64-linux-gnu && \
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu && \
    docker-php-ext-install -j$(nproc) pdo_mysql sockets gd gmp ldap gettext pcntl && \
    echo ". /etc/environment" >> /etc/apache2/envvars && \
    a2enmod rewrite

COPY php.ini /usr/local/etc/php/

# Copy phpipam sources to web dir
ADD ${PHPIPAM_SOURCE}/${PHPIPAM_VERSION}.tar.gz /tmp/
RUN tar -xzf /tmp/${PHPIPAM_VERSION}.tar.gz -C ${APACHE_DOCUMENT_ROOT}/ --strip-components=1 && \
    cp ${APACHE_DOCUMENT_ROOT}/config.dist.php ${APACHE_DOCUMENT_ROOT}/config.php && \
    chown www-data ${APACHE_DOCUMENT_ROOT}/app/admin/import-export/upload && \
    chown www-data ${APACHE_DOCUMENT_ROOT}/app/subnets/import-subnet/upload && \
    chown www-data ${APACHE_DOCUMENT_ROOT}/css/images/logo
# Copy referenced submodules into the right directory
ADD ${PHPMAILER_SOURCE}/v${PHPMAILER_VERSION}.tar.gz /tmp/
RUN tar -xzf /tmp/v${PHPMAILER_VERSION}.tar.gz -C ${APACHE_DOCUMENT_ROOT}/functions/PHPMailer/ --strip-components=1

# Set up cron for ping scanning
ADD crontab /etc/cron.d/phpipam-cron
RUN chmod 0644 /etc/cron.d/phpipam-cron && \
    sed -i "s|APACHE_DOC_ROOT|${APACHE_DOCUMENT_ROOT}|g" /etc/cron.d/phpipam-cron && \
    sed -i '/session    required     pam_loginuid.so/c\#session    required   pam_loginuid.so' /etc/pam.d/cron && \
    crontab /etc/cron.d/phpipam-cron

# Use system environment variables into config.php
RUN sed -i \
    -e "s/\['host'\] = 'localhost'/\['host'\] = getenv(\"MYSQL_HOST\")/" \
    -e "s/\['user'\] = 'phpipam'/\['user'\] = getenv(\"MYSQL_USER\")/" \
    -e "s/\['pass'\] = 'phpipamadmin'/\['pass'\] = getenv(\"MYSQL_PASSWORD\")/" \
    -e "s/\['name'\] = 'phpipam'/\['name'\] = getenv(\"MYSQL_DB\")/" \
    -e "s/\['port'\] = 3306/\['port'\] = getenv(\"MYSQL_PORT\")/" \
    -e "s/\['ssl'\] *= false/\['ssl'\] = getenv(\"MYSQL_SSL\")/" \
    -e "s/\['ssl_key'\] *= '\/path\/to\/cert.key'/['ssl_key'\] = getenv(\"MYSQL_SSL_KEY\")/" \
    -e "s/\['ssl_cert'\] *= '\/path\/to\/cert.crt'/['ssl_cert'\] = getenv(\"MYSQL_SSL_CERT\")/" \
    -e "s/\['ssl_ca'\] *= '\/path\/to\/ca.crt'/['ssl_ca'\] = getenv(\"MYSQL_SSL_CA\")/" \
    -e "s/\['ssl_capath'\] *= '\/path\/to\/ca_certs'/['ssl_capath'\] = getenv(\"MYSQL_SSL_CAPATH\")/" \
    -e "s/\['ssl_cipher'\] *= 'DHE-RSA-AES256-SHA:AES128-SHA'/['ssl_cipher'\] = getenv(\"MYSQL_SSL_CIPHER\")/" \
    ${APACHE_DOCUMENT_ROOT}/config.php

RUN a2enmod rewrite
RUN a2ensite default-ssl
RUN a2enmod ssl

EXPOSE 443
VOLUME /etc/ssl

CMD [ "sh", "-c", "cron && apache2-foreground" ]
