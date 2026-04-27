FROM php:5.6.40-fpm-stretch
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# 替换debian镜像源
ARG DOCKER_APT_MIRROR=deb.debian.org
RUN sed -i "s@deb.debian.org@${DOCKER_APT_MIRROR}@g" /etc/apt/sources.list

RUN apt-get update && apt-get install -y --no-install-recommends \
    busybox \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 安装php依赖
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions gd
RUN install-php-extensions pdo_mysql
RUN install-php-extensions mysqli
RUN install-php-extensions sockets
RUN install-php-extensions zip
RUN install-php-extensions exif
RUN install-php-extensions imagick-stable
RUN install-php-extensions bcmath
RUN install-php-extensions intl
RUN install-php-extensions opcache
RUN install-php-extensions redis-stable
RUN install-php-extensions @composer
RUN install-php-extensions pcntl