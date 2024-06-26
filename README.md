# DNMP

Docker Nginx ~~Mysql~~ Php

这个编排脚本是本人工作日常积累得来，经过删减和整理后用于自建服务器。

仅面向单机部署Nginx或PHP网站使用。

**不适用于分布式和生产环境部署。**

**本人不对使用此脚本产生的任何问题负责。**

`network_mode`使用`host`模式，减少网络转发消耗。

数据库因为在实践中很可能是独立的，这里不包含，自己部署就行了。

## 目录

- [DNMP](#dnmp)
  - [目录](#目录)
  - [特性](#特性)
  - [部署 Nginx](#部署-nginx)
  - [添加网站](#添加网站)
  - [可选部署项](#可选部署项)
    - [使用 acme.sh 申请 ssl 证书](#使用-acmesh-申请-ssl-证书)
    - [开启 PHP](#开启-php)
    - [使用 php composer](#使用-php-composer)
  - [cron TODO](#cron-todo)
  - [中国大陆境内部署](#中国大陆境内部署)
  - [Licence](#licence)

---------------------------------


## 特性

- 内置模块
  - ngx_http_vhost_traffic_status
  - ngx_http_brotli_filter
  - ngx_http_brotli_static
  - ngx_http_headers_more_filter
- 可选择Nginx版本，默认使用stable-alpine-otel
- nginx.conf
  - [优化] 默认开启http2
  - [安全] 默认移除nginx(`Server`)和php(`X-Powered-By`)头部标识
  - [安全] 默认开启X-XSS-Protection
  - [优化] 默认开启`gzip`和`brotli`
  - [优化] 常规IO优化 `aio threads` `directio` `sendfile` `nopush` `nodelay` `open_file_cache` `keepalive`
  - 给予了默认自签名SSL证书snakeoil
- 内置配置模板，可直接include
  - ssl.conf
    - [安全] TLS 1.2-1.3
    - [优化] 减少ssl buffer大小，加快ssl握手时间
    - [优化] 启用 ssl 会话复用
    - [安全] 启用 ocsp stapling
    - [安全] 启用 dhparam
    - [安全] 启用 ssl_prefer_server_ciphers
    - [优化] 启用KTLS卸载
  - wordpress.conf
    - [安全] 禁止访问 upload 目录的`.php`文件
    - [安全] 禁止访问 URL 存在 `/.` 的路径
    - [优化] 不记录静态资源访问的日志 `access_log off;`
    - [安全] 防盗链
    - [优化] 静态资源设置为最大过期时间 `expires max;`
    - [优化] 使用 unix socket 与 php8.1 容器通信
  - proxy.conf
    - [优化] 添加代理header `HOST` `X-Real-IP` `X-Forwarded-For` `X-Forwarded-Proto` `Upgrade` `Connection`
    - [优化] 关闭代理缓存防止docker overlay写炸
    - [优化] 开启代理keepalive
    - [优化] 以http 1.1进行代理

## 部署 Nginx

复制一份`.env.sample`到`.env`，并配置好

```sh
cp .env.sample .env
vim .env
```

构建nginx

```sh
docker compose build
```

生成`nginx/dhparam.pem`

如果启动过程中报错了，可能是少了这一步。因为`ssl.conf`中强制引用了这个`dhparam.pem`

```sh
# 生成一个2048位的dh秘钥至./nginx/dhparam.pem
openssl dhparam -out ./nginx/dhparam.pem 2048
```

启动

```sh
docker compose up -d
```

## 添加网站

配置路径：`nginx/templates/www.example.com.conf.template`

配置文件一定以`.conf.template`结束，这是nginx官方docker镜像的配置文件模板功能所限制的

配置文件中可以使用docker的环境变量

templatep配置文件不支持热重启，需要重建容器`./nginx-recreate.sh`

## 可选部署项

### 使用 acme.sh 申请 ssl 证书

使用acme.sh申请ssl证书

```sh
# 用站点管理员邮箱注册acme
docker compose run --rm nginx acme.sh --register-account -m admin@example.com
# 申请多个泛域名的ssl证书
docker compose run --rm \
  -e Ali_Key=xxxxxxxxxxxxxxxxxxx \
  -e Ali_Secret=xxxxxxxxxxxxxxxx \
  nginx acme.sh --issue --keylength ec-256 \
  --dns dns_ali \
  -d www.example.com
# 创建证书安装目录
docker compose run --rm nginx mkdir -p /etc/nginx/cert/www.example.com
# 安装证书
docker compose run --rm \
  nginx \
  acme.sh --install-cert --ecc -d www.example.com \
  --cert-file /etc/nginx/cert/www.example.com/cert.pem \
  --key-file /etc/nginx/cert/www.example.com/key.pem \
  --fullchain-file /etc/nginx/cert/www.example.com/fullchain.pem \
  --reloadcmd "nginx -s reload"
```

这里reloadcmd可能会报错说nginx没有启动，可以忽略

之后配置好nginx站点使用`cert/fullchain.pem`和`cert/key.pem`

### 开启 PHP

以php8.1和wordpress为例

启动php8.1

```sh
cd php/81
docker compose build
docker compose up -d
```

配置`nginx/templates/www.example.com.conf.template`

```conf
server {
  listen 80;
  listen 443 ssl http2;

  server_name www.example.com;
  access_log /var/log/nginx/www.example.com_access.log main;

  ssl_certificate cert/www.example.com/fullchain.pem;
  ssl_certificate_key cert/www.example.com/key.pem;  

  include ssl.conf;

  root /wwwroot/www.example.com;
  
  #或者 fastcgi_pass unix:/var/run/php81.sock;
  include wordpress.conf;
}
```

重建nginx容器

```sh
./nginx-recreate.sh
```

### 使用 php composer

```sh
#进入对应php版本的容器
cd php/81
./shell-www-data.sh

#进入站点目录
cd /wwwroot/www.example.com
composer -V
```

## cron TODO

## 中国大陆境内部署

`Docker Hub`可以使用第三方mirror，自行查找

github访问加速可以在相关`Dockerfile`文件中增加

```Dockerfile
RUN git config --global url."https://gitclone.com/".insteadOf https://
```

## Licence

[WTFPL](./LICENCE)
