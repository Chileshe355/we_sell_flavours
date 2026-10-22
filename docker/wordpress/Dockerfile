ARG WORDPRESS_IMAGE=wordpress:7.1.3-php8.3-fpm@sha256:788d6b34cb89997483ff2a08e2e04d1df28ce284ca046cd7990b0be10828c5b9
FROM ${WORDPRESS_IMAGE}

ARG IMAGICK_VERSION=3.8.0

USER root

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        libfcgi-bin \
        mariadb-client; \
    if ! php -m | grep -Fxq imagick; then \
        apt-get install -y --no-install-recommends libmagickwand-dev; \
        pecl install "imagick-${IMAGICK_VERSION}"; \
        docker-php-ext-enable imagick; \
    fi; \
    rm -rf /var/lib/apt/lists/* /tmp/pear; \
    php -r 'exit(PHP_VERSION === "8.3.36" ? 0 : 1);'; \
    php -m | grep -Fx imagick; \
    php -m | grep -Fx mysqli; \
    rm -rf /usr/src/wordpress/wp-content/plugins

COPY conf.d/zz-application.ini /usr/local/etc/php/conf.d/zz-application.ini
COPY fpm/zz-health.conf /usr/local/etc/php-fpm.d/zz-health.conf
COPY healthcheck.sh /usr/local/bin/fpm-healthcheck

RUN chmod 0755 /usr/local/bin/fpm-healthcheck \
    && chown root:root /usr/local/bin/fpm-healthcheck \
    && mkdir -p /var/www/html \
    && chown -R www-data:www-data /var/www/html

WORKDIR /var/www/html
