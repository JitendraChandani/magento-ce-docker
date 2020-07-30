# image
FROM php:7.1-apache
MAINTAINER Jitendra Chandani <jeetu.chandani@gmail.com>
# envs
ENV INSTALL_DIR /var/www/html
ENV APACHE_DOCUMENT_ROOT /var/www/html/magento2

RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf


# install composer
RUN curl -sS https://getcomposer.org/installer | php \
&& mv composer.phar /usr/local/bin/composer

ENV COMPOSER_HOME /root/.config/composer
COPY auth.json /root/.config/composer/


# install libraries
RUN requirements="cron libzip-dev libpng-dev libmcrypt-dev libmcrypt4 libcurl3-dev libfreetype6 libjpeg62-turbo libjpeg62-turbo-dev libfreetype6-dev libicu-dev libxslt1-dev" \
 && apt-get update \
 && apt-get install -y $requirements \
 && rm -rf /var/lib/apt/lists/* \
 && docker-php-ext-install pdo_mysql \
 && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
 && docker-php-ext-install gd \
 && docker-php-ext-install sockets \
 && docker-php-ext-install mcrypt \
 && docker-php-ext-install mbstring \
 && docker-php-ext-install zip \
 && docker-php-ext-install intl \
 && docker-php-ext-install xsl \
 && docker-php-ext-install soap \
 && docker-php-ext-install bcmath

# add magento cron job
COPY ./crontab /etc/cron.d/magento2-cron
RUN chmod 0644 /etc/cron.d/magento2-cron
RUN crontab -u www-data /etc/cron.d/magento2-cron

# turn on mod_rewrite
RUN a2enmod rewrite

# set memory limits
RUN echo "memory_limit=2048M" > /usr/local/etc/php/conf.d/memory-limit.ini

# clean apt-get
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN composer create-project --repository=https://repo.magento.com/ --no-dev magento/project-community-edition=2.3.4 magento2

# www-data should own /var/www
RUN chown -R www-data:www-data /var/www

# switch user to www-data
USER www-data

# copy sources with proper user
COPY --chown=www-data . $INSTALL_DIR

# set working dir
WORKDIR $INSTALL_DIR

#RUN composer create-project --repository=https://repo.magento.com/ magento/project-community-edition magento2
WORKDIR $INSTALL_DIR/magento2

# composer install
RUN composer install
RUN composer config repositories.magento composer https://repo.magento.com/

RUN find . -type d -exec chmod 770 {} \; \
    && find . -type f -exec chmod 660 {} \; \
    && chmod u+x bin/magento

# chmod directories
RUN chmod u+x bin/magento

# switch back
USER root

# run cron alongside apache
CMD [ "sh", "-c", "cron && apache2-foreground" ]
