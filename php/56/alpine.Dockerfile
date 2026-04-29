ARG DOCKER_REGISTRY=docker.io
FROM ${DOCKER_REGISTRY}/mlocati/php-extension-installer AS php-extension-installer

FROM ${DOCKER_REGISTRY}/php:5.6.40-fpm-alpine3.8
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# 替换alpine镜像源
ARG DOCKER_APK_MIRROR=dl-cdn.alpinelinux.org
RUN sed -i "s@dl-cdn.alpinelinux.org@${DOCKER_APK_MIRROR}@g" /etc/apk/repositories

RUN apk add --no-cache \
    ca-certificates

# 安装php依赖
COPY --from=php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

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