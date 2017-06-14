#!/bin/sh
#set -ue

DOMAINS=`env | grep ^VHOST_`

cat <<EOF > nginx/conf/nginx.conf
worker_process 1;

events {
  worker_connections $WORKER_CONNECTIONS;
}

http {
  include mime.types;
  default_type application/octet-stream;

  keepalive_timeout $KEEPALIVE_TIMEOUT;
  resolver $RESOLVER;

  lua_shared_dict acme $ACME_SHARED_DICT_SIZE;
  include /usr/local/openresty/nginx/conf/vhosts/*;

  server {
    listen $HTTP_PORT default_server;
    listen [::]:$HTTP_PORT;
    server_name _;

    location / {
      root /dev/null;
    }
  }

  init_by_lua_block {
    local conf = {
      domains = {},
      root = os.getenv('ACME_ROOT_DIR'),
      directry_url = os.getenv('ACME_DIRECTRY_URL'),
      contact = os.getenv('ACME_CONTACT'),
      agreement = os.getenv('ACME_AGREEMENT_URL'),
    }
    letsencrypt = (require 'letsencrypt').new(conf)
  }
}
EOF

for l in $DOMAINS; do
	NAME=`echo $l | sed -e 's/^VHOST_\([^=]*\)=.*$/\1/'`
	DOMAIN=`echo $NAME | tr _ . | tr '[:upper:]' '[:lower:]'`
	UPSTREAMS=(`echo $l | sed -e 's/^VHOST_[^=]*=\(.*\)$/\1/' | tr , ' '`)
	FILE="nginx/conf/vhosts/$DOMAIN"
	cat <<EOF > $FILE
upstream _$NAME {
EOF
	for u in ${UPSTREAMS[@]}; do
	  cat <<EOF >> $FILE
  server $u;
EOF
	done
	cat <<EOF >> $FILE
}

server {
  listen $HTTP_PORT;
  listen [::]:$HTTP_PORT;
  server_name $DOMAIN;

  location / {
    return 301 https://$DOMAIN/;
  }

  location /.well-known/acme-challenge {
    content_by_lua_block {
      letsencrypt:challenge()
    }
  }
}

server {
  listen $HTTPS_PORT ssl;
  listen [::]:$HTTPS_PORT ssl;
  server_name $DOMAIN;

  ssl_certificate ${ACME_ROOT_DIR}fallback.crt;
  ssl_certificate_key ${ACME_ROOT_DIR}fallback.key;
  ssl_certificate_by_lua_block {
    letsencrypt:ssl()
  }

  location / {
    proxy_pass _$NAME;
  }
}
EOF
done

nginx -g 'daemon off;'
