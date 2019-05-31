FROM islandoracollabgroup/isle-ubuntu-basebox:1.1.1

## General Dependencies
RUN GEN_DEP_PACKS="software-properties-common \
    language-pack-en-base \
    tmpreaper \
    cron \
    xz-utils \
    zip \
    bzip2 \
    openssl \
    openssh-client \
    file" && \
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
    apt-get update && \
    apt-get install --no-install-recommends -y $GEN_DEP_PACKS && \
    ## CONFD
    curl -L -o /usr/local/bin/confd https://github.com/kelseyhightower/confd/releases/download/v0.16.0/confd-0.16.0-linux-amd64 && \
    chmod +x /usr/local/bin/confd && \
    ## Cleanup phase.
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV LC_ALL=en_US.UTF-8 \ 
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en

## tmpreaper - cleanup /tmp on the running container
RUN touch /var/log/cron.log && \
    touch /etc/cron.d/tmpreaper-cron && \
    echo "0 */12 * * * root /usr/sbin/tmpreaper -am 4d /tmp >> /var/log/cron.log 2>&1" | tee /etc/cron.d/tmpreaper-cron && \
    chmod 0644 /etc/cron.d/tmpreaper-cron

## Install Varnish && Varnish Agent
RUN BUILD_DEPS="gnupg-agent" && \
    VARNISH_DEPS="libmicrohttpd10" && \
    ## libmicrohttpd10 package removed in bionic, need to install for varnish agent
    cp /etc/apt/sources.list /etc/apt/sources.list.d/xenial_for_libmicrohttpd10.list && \
    sed -i 's/bionic/xenial/' /etc/apt/sources.list.d/xenial_for_libmicrohttpd10.list /etc/apt/sources.list.d/xenial_for_libmicrohttpd10.list && \
    touch /etc/apt/preferences.d/xenial_for_libmicrohttpd10-500 && \
    echo 'Package: *' > /etc/apt/preferences.d/xenial_for_libmicrohttpd10-500 && \
    echo 'Pin: release n=xenial' >> /etc/apt/preferences.d/xenial_for_libmicrohttpd10-500 && \
    echo 'Pin-Priority: 99' >> /etc/apt/preferences.d/xenial_for_libmicrohttpd10-500 && \
    echo '' >> /etc/apt/preferences.d/xenial_for_libmicrohttpd10-500 && \
    echo 'Package: libmicrohttpd10' >> /etc/apt/preferences.d/xenial_for_libmicrohttpd10-500 && \
    echo 'Pin: release n=xenial' >> /etc/apt/preferences.d/xenial_for_libmicrohttpd10-500 && \
    echo 'Pin-Priority: 500' >> /etc/apt/preferences.d/xenial_for_libmicrohttpd10-500 && \
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
    apt-get update && \
    apt-get install --no-install-recommends -y $BUILD_DEPS $VARNISH_DEPS && \
    ## Remove xenial repos as only used to install libmicrohttpd10 for varnish agent. Could cause conflicts
    rm /etc/apt/sources.list.d/xenial_for_libmicrohttpd10.list && \
    rm /etc/apt/preferences.d/xenial_for_libmicrohttpd10-500 && \
    ## No bionic packages exist yet, downgrading to xenial
    curl -s https://packagecloud.io/install/repositories/varnishcache/varnish41/script.deb.sh | os=ubuntu dist=xenial bash && \
    apt-get update && \
    apt-get install --no-install-recommends -y varnish varnish-agent=4.1.3-12~xenial && \
    ## Cleanup phase.
    apt-get purge -y $BUILD_DEPS --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="ISLE Varnish Image" \
      org.label-schema.description="Optional ISLE Varnish Image." \
      org.label-schema.url="https://islandora-collaboration-group.github.io" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/Islandora-Collaboration-Group/isle-varnish" \
      org.label-schema.vendor="Islandora Collaboration Group (ICG) - islandora-consortium-group@googlegroups.com" \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0" \
      traefik.port="6081" \
      traefik.frontend.entryPoints=http,https

COPY rootfs /

## Exposes ports for Varnish, admin panel and agent (if warranted)
EXPOSE 6081 6082

ENTRYPOINT ["/init"]