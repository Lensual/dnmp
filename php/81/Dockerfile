FROM php:8.1.27-fpm-alpine3.19
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

#安装php依赖
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
ARG DOCKER_APK_MIRROR=dl-cdn.alpinelinux.org
#替换alpine镜像源
RUN sed -i "s@dl-cdn.alpinelinux.org@${DOCKER_APK_MIRROR}@g" /etc/apk/repositories
RUN apk update
RUN install-php-extensions gd
RUN install-php-extensions pdo_mysql
RUN install-php-extensions mysqli
RUN install-php-extensions sockets
RUN install-php-extensions zip
RUN install-php-extensions exif
RUN install-php-extensions imagick-stable
RUN install-php-extensions bcmath
RUN install-php-extensions intl
RUN install-php-extensions mcrypt
RUN install-php-extensions opcache
RUN install-php-extensions redis-stable
RUN install-php-extensions @composer
RUN install-php-extensions pcntl
