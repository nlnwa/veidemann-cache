FROM golang:1.19-alpine as helpers

WORKDIR /go/src/helpers

COPY go/go.mod go/go.sum ./
RUN go mod download

COPY go ./
RUN CGO_ENABLED=0 go install ./...


FROM alpine:3.17 as certificates

RUN apk add --no-cache gnutls-utils

COPY cert.cfg /
RUN certtool --generate-privkey --outfile tls.key \
    && certtool --generate-self-signed --load-privkey tls.key --template cert.cfg --outfile tls.crt \
    && certtool --generate-dh-params --sec-param medium > dhparams.pem


FROM debian:bullseye-20221219-slim

ENV TZ=UTC
ENV SERVICE_NAME="veidemann-cache"
ENV DNS_SERVERS="8.8.8.8 8.8.4.4"

RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends squid-openssl ca-certificates tzdata; \
    DEBIAN_FRONTEND=noninteractive apt-get remove --purge --auto-remove -y; \
    rm -rf /var/lib/apt/lists/*; \
    sed -i 's/^#http_access allow localnet$/http_access allow localnet/' /etc/squid/conf.d/debian.conf; \
    echo "# Set max_filedescriptors to avoid using system's RLIMIT_NOFILE. See LP: #1978272" > /etc/squid/conf.d/rock.conf; \
    echo 'max_filedescriptors 65536' >> /etc/squid/conf.d/rock.conf; \
    /usr/sbin/squid --version;

# RUN echo "proxy ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/proxy && \
#    echo "Defaults:proxy !requiretty, !env_reset" >> /etc/sudoers.d/proxy && \
#    chmod 440 /etc/sudoers.d/proxy

# Use this mount to bring your own certificates
VOLUME /ca-certificates
VOLUME /var/spool/squid

COPY --from=helpers /go/bin/confighandler /go/bin/storeid /go/bin/loghelper /usr/local/sbin/
COPY --from=certificates --chown=proxy:proxy /dhparams.pem /tls.key /tls.crt /ca-certificates/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY squid.conf squid.conf.template squid-balancer.conf.template /etc/squid/

EXPOSE 3128

ENTRYPOINT [ "entrypoint.sh"]
