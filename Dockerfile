FROM golang:1.11
COPY go /src
WORKDIR /src
RUN ls
RUN CGO_ENABLED=0 go build -o confighandler cmd/confighandler/main.go
RUN CGO_ENABLED=0 go build -o storeid cmd/storeid/main.go
RUN CGO_ENABLED=0 go build -o loghelper cmd/loghelper/main.go



FROM alpine:3.9.2

EXPOSE 3128 3129 4827

RUN apk add --no-cache squid openssl ca-certificates sudo gettext iptables ip6tables iproute2 && rm -rf /var/cache/apk/*

ENV DNS_SERVERS="8.8.8.8 8.8.4.4"

COPY --from=0 /src/confighandler /usr/bin/
COPY --from=0 /src/storeid /usr/bin/
COPY --from=0 /src/loghelper /usr/bin/


COPY openssl.conf /

# Make a self-signed certificate to satisfy the requirements of the Squid config
RUN mkdir /ca-certificates \
 && openssl ecparam -name prime256v1 -out /ca-certificates/ec.param \
 && openssl req -new -newkey ec:/ca-certificates/ec.param -days 1825 -nodes -x509 -sha384 \
      -config openssl.conf \
      -keyout /ca-certificates/cache-selfsigned.key \
      -out /ca-certificates/cache-selfsignedCA.crt \
      -subj "/O=Veidemann harvester/OU=Veidemann cache/CN=veidemann-harvester" \
 && chmod -R 777 /ca-certificates

RUN echo "Cmnd_Alias CMDS = /init-squid.sh, /usr/bin/confighandler" >> /etc/sudoers.d/squid && \
    echo "squid ALL=(ALL) NOPASSWD: CMDS" >> /etc/sudoers.d/squid && \
    echo "Defaults:squid !requiretty, !env_reset" >> /etc/sudoers.d/squid && \
    chmod 440 /etc/sudoers.d/squid

# Use this mount to bring your own certificates
VOLUME /ca-certificates

VOLUME /var/cache/squid

COPY init-squid.sh /
COPY docker-entrypoint.sh /
COPY squid.conf /etc/squid/squid.conf.template
COPY squid-balancer.conf /etc/squid/squid-balancer.conf.template

USER squid

ENV SERVICE_NAME="veidemann-cache"

ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD [ "squid" ]
