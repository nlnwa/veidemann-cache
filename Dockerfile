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


FROM debian:bullseye-20221219-slim

RUN apt-get update && apt-get install -y \
    sudo squid-openssl tini ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=helpers /go/bin/confighandler /go/bin/storeid /go/bin/loghelper /usr/local/sbin/
COPY --from=certificates --chown=proxy:proxy /dhparams.pem /ca-key.pem /ca-cert.pem /ca-certificates/

RUN echo "proxy ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/proxy && \
    echo "Defaults:proxy !requiretty, !env_reset" >> /etc/sudoers.d/proxy && \
    chmod 440 /etc/sudoers.d/proxy

# Use this mount to bring your own certificates
VOLUME /ca-certificates

VOLUME /var/cache/squid

COPY docker-entrypoint.sh /
COPY squid.conf.template /etc/squid/
COPY squid-balancer.conf.template /etc/squid/

ENV SERVICE_NAME="veidemann-cache"
ENV DNS_SERVERS="8.8.8.8 8.8.4.4"

EXPOSE 3128 3129 4827

ENTRYPOINT [ "/usr/bin/tini", "--", "/docker-entrypoint.sh" ]
