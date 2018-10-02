FROM alpine:3.8

EXPOSE 3128 3129

RUN apk add --no-cache squid openssl ca-certificates sudo gettext iptables ip6tables iproute2 && rm -rf /var/cache/apk/*

ENV DNS_SERVERS="8.8.8.8 8.8.4.4"

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

RUN echo "squid ALL=(ALL) NOPASSWD: /init-squid.sh" >> /etc/sudoers.d/squid && \
    echo "Defaults:squid !requiretty" >> /etc/sudoers.d/squid && \
    chmod 440 /etc/sudoers.d/squid

# Use this mount to bring your own certificates
VOLUME /ca-certificates

VOLUME /var/cache/squid

COPY init-squid.sh /
COPY docker-entrypoint.sh /
COPY log_helper.sh /
COPY store_id_helper.sh /
COPY squid.conf /etc/squid/squid.conf.template

USER squid

ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD [ "squid" ]