FROM golang:1.19-alpine as helpers

WORKDIR /go/src/helpers

COPY go/go.mod go/go.sum ./
RUN go mod download

COPY go ./
RUN CGO_ENABLED=0 go install ./...


FROM alpine:3.17 as certificates

RUN apk add --no-cache gnutls-utils

COPY cert.cfg /
RUN certtool --generate-privkey --outfile ca-key.pem \
    && certtool --generate-self-signed --load-privkey ca-key.pem --template cert.cfg --outfile ca-cert.pem \
    && certtool --generate-dh-params --sec-param medium > dhparams.pem

FROM alpine:3.17

RUN apk add --no-cache squid tini ca-certificates sudo gettext iptables ip6tables iproute2 && rm -rf /var/cache/apk/*

COPY --from=helpers /go/bin/confighandler /usr/bin/
COPY --from=helpers /go/bin/storeid /usr/bin/
COPY --from=helpers /go/bin/loghelper /usr/bin/

COPY --from=certificates --chown=squid:squid /dhparams.pem /ca-certificates/
COPY --from=certificates --chown=squid:squid /ca-key.pem /ca-certificates/
COPY --from=certificates --chown=squid:squid /ca-cert.pem /ca-certificates/

RUN echo "squid ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/squid && \
    echo "Defaults:squid !requiretty, !env_reset" >> /etc/sudoers.d/squid && \
    chmod 440 /etc/sudoers.d/squid

# Use this mount to bring your own certificates
VOLUME /ca-certificates

VOLUME /var/cache/squid

COPY docker-entrypoint.sh /
COPY squid.conf.template /etc/squid/
COPY squid-balancer.conf.template /etc/squid/

USER squid

ENV SERVICE_NAME="veidemann-cache"
ENV DNS_SERVERS="8.8.8.8 8.8.4.4"

EXPOSE 3128 3129 4827

ENTRYPOINT [ "/sbin/tini", "--", "/docker-entrypoint.sh" ]
