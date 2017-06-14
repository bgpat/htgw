FROM openresty/openresty:1.11.2.3-alpine-fat

WORKDIR /usr/local/openresty

RUN apk add --update --no-cache git lua-dev openssl-dev openssl ca-certificates && \
	cp /usr/include/lauxlib.h luajit/include/luajit-2.1/ && \
	luarocks install luaossl && luarocks install lua-resty-http && \
	mkdir -p nginx/conf/vhosts letsencrypt && \
	openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
	-subj '/CN=resty-auto-ssl-fallback' \
	-keyout letsencrypt/fallback.key -out letsencrypt/fallback.crt && \
	chown -R nobody:nobody letsencrypt && \
	git clone https://github.com/bgpat/lua-resty-letsencrypt && \
	cp lua-resty-letsencrypt/letsencrypt.lua luajit/share/lua/5.1/ && \
	rm -rf lua-resty-letsencrypt

ADD entrypoint.sh entrypoint.sh

ENV WORKER_CONNECTIONS=1024 \
	KEEPALIVE_TIMEOUT=65 \
	RESOLVER=8.8.8.8 \
	ACME_SHARED_DICT_SIZE=1m \
	ACME_ROOT_DIR=/usr/local/openresty/letsencrypt/ \
	ACME_DIRECTRY_URL=https://acme-v01.api.letsencrypt.org/directry \
	ACME_CONTACT=mailto:admin@example.tld \
	ACME_AGREEMENT_URL=https://letsencrypt.org/docments/LE-SA-v1.1.1-August-1-2016.pdf \
	HTTP_PORT=80 HTTPS_PORT=443

EXPOSE 80 443

ENTRYPOINT ["./entrypoint.sh"]
