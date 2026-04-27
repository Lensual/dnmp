ARG VERSION=stable-trixie
FROM nginx:${VERSION} AS build

# 添加nginx编译依赖
ARG DOCKER_APT_MIRROR=deb.debian.org
RUN sed -i "s@deb.debian.org@${DOCKER_APT_MIRROR}@g" /etc/apt/sources.list.d/debian.sources
RUN apt-get update
RUN apt-get install -y --no-install-recommends \
    wget \
    git \
    gcc \
    make \
    libc-dev \
    libpcre2-dev \
    zlib1g-dev \
    cmake

# 一步一个缓存，避免下载失败全部重新下载
RUN wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
RUN git clone --depth 1  -b v0.2.5 https://github.com/vozlt/nginx-module-vts.git
RUN git clone --depth 1  -b master https://github.com/google/ngx_brotli.git \
&& cd ngx_brotli && git checkout a71f9312c2deb28875acc7bacfdd5695a111aa53
RUN cd ngx_brotli && git submodule update --init
RUN git clone --depth 1  -b v0.39 https://github.com/openresty/headers-more-nginx-module

# 编译brotli
RUN cd ngx_brotli/deps/brotli \
  && mkdir out && cd out \
  && cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_C_FLAGS="-Ofast -march=native -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" \
    -DCMAKE_CXX_FLAGS="-Ofast -march=native -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" \
    -DCMAKE_INSTALL_PREFIX=./installed .. \
  && cmake --build . --config Release --target brotlienc

# 编译nginx自定义模块
RUN tar xf nginx-${NGINX_VERSION}.tar.gz \
  && cd nginx-${NGINX_VERSION} \
  && ./configure \
    --with-compat \
    --with-cc-opt='-Ofast -fomit-frame-pointer -Werror=implicit-function-declaration -fstack-protector-strong -fstack-clash-protection -Wformat -Werror=format-security -fcf-protection -Wp,-D_FORTIFY_SOURCE=2 -fPIC' \
    --with-ld-opt='-Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie' \
    --add-dynamic-module=/nginx-module-vts \
    --add-dynamic-module=/ngx_brotli \
    --add-dynamic-module=/headers-more-nginx-module \
  && make modules -j$(getconf _NPROCESSORS_ONLN) \
  && rm -rf /nginx-module-vts \
  && rm -rf /ngx_brotli

# 添加自定义模块
FROM nginx:${VERSION}

ARG DOCKER_APT_MIRROR=deb.debian.org
RUN sed -i "s@deb.debian.org@${DOCKER_APT_MIRROR}@g" /etc/apt/sources.list.d/debian.sources
RUN apt-get update && apt-get install -y --no-install-recommends \
  logrotate \
  busybox \
  acme.sh \
  && rm -rf /var/lib/apt/lists/*

COPY --from=build /nginx-${NGINX_VERSION}/objs/ngx_http_vhost_traffic_status_module.so /usr/lib/nginx/modules/
COPY --from=build /nginx-${NGINX_VERSION}/objs/ngx_http_brotli_filter_module.so /usr/lib/nginx/modules/
COPY --from=build /nginx-${NGINX_VERSION}/objs/ngx_http_brotli_static_module.so /usr/lib/nginx/modules/
COPY --from=build /nginx-${NGINX_VERSION}/objs/ngx_http_headers_more_filter_module.so /usr/lib/nginx/modules/

# 添加crond配置文件
COPY --chown=root:root --chmod=775 ./docker-entrypoint.d/* /docker-entrypoint.d/

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*
