FROM golang:1.16-alpine as helpers

WORKDIR /go/src/helpers

COPY go/go.mod go/go.sum ./
RUN go mod download

COPY go ./
RUN CGO_ENABLED=0 go install ./...


FROM alpine:20210804 as certificates

RUN apk add --no-cache openssl ca-certificates

COPY openssl.conf /

# Make a self-signed certificate to satisfy the requirements of the Squid config
RUN openssl ecparam -name prime256v1 -out ec.param \
 && openssl req -new -newkey ec:ec.param -days 1825 -nodes -x509 -sha384 \
      -config openssl.conf \
      -keyout cache-selfsigned.key \
      -out cache-selfsignedCA.crt \
      -subj "/O=Veidemann harvester/OU=Veidemann cache/CN=veidemann-harvester"

FROM alpine:20210804

RUN apk add --no-cache squid tini ca-certificates sudo gettext iptables ip6tables iproute2 && rm -rf /var/cache/apk/*

COPY --from=helpers /go/bin/confighandler /usr/bin/
COPY --from=helpers /go/bin/storeid /usr/bin/
COPY --from=helpers /go/bin/loghelper /usr/bin/

COPY --from=certificates --chown=squid:squid /ec.param /ca-certificates/
COPY --from=certificates --chown=squid:squid /cache-selfsigned.key /ca-certificates/
COPY --from=certificates --chown=squid:squid /cache-selfsignedCA.crt /ca-certificates/

RUN echo "Cmnd_Alias CMDS = /init-squid.sh, /usr/bin/confighandler" >> /etc/sudoers.d/squid && \
    echo "squid ALL=(ALL) NOPASSWD: CMDS" >> /etc/sudoers.d/squid && \
    echo "Defaults:squid !requiretty, !env_reset" >> /etc/sudoers.d/squid && \
    chmod 440 /etc/sudoers.d/squid

# Use this mount to bring your own certificates
VOLUME /ca-certificates

VOLUME /var/cache/squid

COPY init-squid.sh /
COPY docker-entrypoint.sh /
COPY squid.conf.template /etc/squid/
COPY squid-balancer.conf.template /etc/squid/

USER squid

ENV SERVICE_NAME="veidemann-cache"
ENV DNS_SERVERS="8.8.8.8 8.8.4.4"

EXPOSE 3128 3129 4827

ENTRYPOINT [ "/sbin/tini", "--", "/docker-entrypoint.sh" ]
