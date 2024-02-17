# DNMP

Docker Nginx ~~Mysql~~ Php

## 关于这个项目

这个编排脚本是本人工作日常积累得来，经过删减和整理后用于自建服务器。

仅面向单机部署Nginx或PHP网站使用，不适用于分布式部署。

数据库因为可能是独立部署的，这里不包含，自己部署就行了。

## 特性

- 可选择Nginx版本，默认使用stable-alpine
- 默认开启`gzip`和`brotli`压缩
- 内置`wordpress.conf` `proxy.conf` `ssl.conf`等配置模板，可直接include

## 部署Nginx

复制一份`.env.sample`到`.env`，并配置好

```sh
cp .env.sample .env
vim .env
```

构建nginx

```
docker compose build
```

生成`nginx/dhparam.pem`

```sh
# 生成一个2048位的dh秘钥至./nginx/dhparam.pem
openssl dhparam -out ./nginx/dhparam.pem 2048
```

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
  -d lensual.space \
  -d *.lensual.space
# 创建证书安装目录
docker compose run --rm nginx mkdir -p /etc/nginx/cert/lensual.space
# 安装证书
docker compose run --rm \
  nginx \
  acme.sh --install-cert --ecc -d lensual.space \
  --cert-file /etc/nginx/cert/lensual.space/cert.pem \
  --key-file /etc/nginx/cert/lensual.space/key.pem \
  --fullchain-file /etc/nginx/cert/lensual.space/fullchain.pem \
  --reloadcmd "nginx -s reload"
```

之后配置好nginx站点使用`fullchain.pem`和`key.pem`

启动

```sh
docker compose up -d
```

## 添加网站

## 开启PHP（可选）

以php8.1和wordpress为例

启动php8.1

```sh
cd php/81
docker compose build
docker compose up -d
```

配置`nginx/templates/mysite.conf.template`

```conf
server {
  listen 80;
  listen 443 ssl http2;

  server_name lensual.space;
  access_log /var/log/nginx/lensual.space_access.log main;

  ssl_certificate cert/lensual.space/fullchain.pem;
  ssl_certificate_key cert/lensual.space/key.pem;  

  include ssl.conf;

  root /wwwroot/lensual.space;
  
  include wordpress.conf;
}
```

重建nginx容器

```
./nginx-recreate.sh
```




## Licence

WTFPL