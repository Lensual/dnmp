ARG VERSION=stable-alpine
ARG DOCKER_REGISTRY=docker.io
FROM ${DOCKER_REGISTRY}/nginx:${VERSION} AS build

# 添加nginx编译依赖
ARG DOCKER_APK_MIRROR=dl-cdn.alpinelinux.org
RUN sed -i "s@dl-cdn.alpinelinux.org@${DOCKER_APK_MIRROR}@g" /etc/apk/repositories
RUN apk add --no-cache --virtual .build-deps \
    wget \
    git \
    gcc \
    make \
    libc-dev \
    pcre-dev \
    zlib-dev \
    cmake

# 一步一个缓存，避免下载失败全部重新下载
RUN wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
RUN git clone --depth 1 -b v0.2.5 https://github.com/vozlt/nginx-module-vts.git
RUN git clone --depth 1 -b master https://github.com/google/ngx_brotli.git \
  && cd ngx_brotli && git checkout a71f9312c2deb28875acc7bacfdd5695a111aa53
RUN cd ngx_brotli && git submodule update --init
RUN git clone -b v0.39 https://github.com/openresty/headers-more-nginx-module

# 编译brotli
RUN cd ngx_brotli/deps/brotli \
  && mkdir out && cd out \
  && cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_C_FLAGS="-Ofast -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" \
    -DCMAKE_CXX_FLAGS="-Ofast -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" \
    -DCMAKE_INSTALL_PREFIX=./installed .. \
  && cmake --build . --config Release --target brotlienc

# 编译nginx自定义模块
RUN tar xf nginx-${NGINX_VERSION}.tar.gz \
  && cd nginx-${NGINX_VERSION} \
  && ./configure \
    --with-compat \
    --with-cc-opt='-Ofast -fomit-frame-pointer' \
    --with-ld-opt=-'Wl,--as-needed,-Ofast,--sort-common' \
    --add-dynamic-module=/nginx-module-vts \
    --add-dynamic-module=/ngx_brotli \
    --add-dynamic-module=/headers-more-nginx-module \
  && make modules -j$(getconf _NPROCESSORS_ONLN) \
  && rm -rf /nginx-module-vts \
  && rm -rf /ngx_brotli \
  && apk del .build-deps

# 添加自定义模块
FROM ${DOCKER_REGISTRY}/nginx:${VERSION}

ARG DOCKER_APK_MIRROR=dl-cdn.alpinelinux.org
RUN sed -i "s@dl-cdn.alpinelinux.org@${DOCKER_APK_MIRROR}@g" /etc/apk/repositories
RUN apk add --no-cache \
  logrotate

COPY --from=build /nginx-${NGINX_VERSION}/objs/ngx_http_vhost_traffic_status_module.so /usr/lib/nginx/modules/
COPY --from=build /nginx-${NGINX_VERSION}/objs/ngx_http_brotli_filter_module.so /usr/lib/nginx/modules/
COPY --from=build /nginx-${NGINX_VERSION}/objs/ngx_http_brotli_static_module.so /usr/lib/nginx/modules/
COPY --from=build /nginx-${NGINX_VERSION}/objs/ngx_http_headers_more_filter_module.so /usr/lib/nginx/modules/

# 添加crond配置文件
COPY --chown=root:root --chmod=775 ./docker-entrypoint.d/* /docker-entrypoint.d/

RUN apk add --no-cache ca-certificates
