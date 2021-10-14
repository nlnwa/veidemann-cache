FROM golang:1.16-alpine as helpers

WORKDIR /go/src

COPY go/go.mod go/go.sum ./
RUN go mod download

COPY go ./
RUN CGO_ENABLED=0 go install ./...


FROM alpine:3.14.2



RUN apk add --no-cache squid openssl ca-certificates sudo gettext iptables ip6tables iproute2 && rm -rf /var/cache/apk/*

COPY --from=helpers /go/bin/confighandler /usr/bin/
COPY --from=helpers /go/bin/storeid /usr/bin/
COPY --from=helpers /go/bin/loghelper /usr/bin/

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
COPY squid.conf /etc/squid/squid.conf
COPY squid-balancer.conf /etc/squid/squid-balancer.conf.template

USER squid

ENV SERVICE_NAME="veidemann-cache"
ENV DNS_SERVERS="8.8.8.8 8.8.4.4"
# cache dir size should be no more than 80% of volume space (/var/cache/squid) size
ENV CACHE_DIR_MB=100

EXPOSE 3128 3129 4827

ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD [ "squid" ]
