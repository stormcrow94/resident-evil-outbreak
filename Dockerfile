# Biohazard / Resident Evil: Outbreak — DNAS + bioserver (File #1 & #2)
# Based on https://github.com/corbin-zip/bioserver-docker with pinned deps and JDBC host support.
# Build args document upstream URLs (change if mirrors move).

ARG DEBIAN_VERSION=bullseye-slim
FROM debian:${DEBIAN_VERSION}

ARG VARIANT=allinone

# Pin source tarballs (see https://www.openssl.org/source/ , https://httpd.apache.org/download.cgi , https://apr.apache.org/)
ARG OPENSSL_TARBALL_URL=https://www.openssl.org/source/openssl-1.0.2q.tar.gz
ARG HTTPD_TARBALL_URL=https://archive.apache.org/dist/httpd/httpd-2.4.56.tar.gz
ARG APR_TARBALL_URL=https://archive.apache.org/dist/apr/apr-1.7.2.tar.gz
ARG APR_UTIL_TARBALL_URL=https://archive.apache.org/dist/apr/apr-util-1.6.3.tar.gz
ARG MYSQL_CONNECTOR_DEB_URL=https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j_8.0.32-1debian11_all.deb

RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo make gcc dnsmasq dnsutils unzip php-fpm \
    php7.4-mysql openjdk-17-jre-headless openjdk-17-jre default-jdk \
    libpcre3 libpcre3-dev libexpat1 libexpat1-dev \
    libxml2 libxml2-dev libxslt1-dev libxslt1.1 git \
    curl vim wget ca-certificates zlib1g-dev \
    && if [ "$VARIANT" = "allinone" ]; then apt-get install -y --no-install-recommends mariadb-server; fi \
    && if [ "$VARIANT" = "split" ]; then apt-get install -y --no-install-recommends mariadb-client; fi \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /openssl && curl -SL "${OPENSSL_TARBALL_URL}" \
    | tar -xzC /openssl --strip-components=1

RUN cd /openssl && \
    ./config --prefix=/opt/openssl-1.0.2 --openssldir=/etc/ssl \
    shared enable-weak-ssl-ciphers enable-ssl3 enable-ssl3-method \
    enable-ssl2 -Wl,-rpath=/opt/openssl-1.0.2/lib && \
    make && make install

RUN ARCH=$(uname -m) && \
    { echo "# custom OpenSSL"; echo "/opt/openssl-1.0.2/lib"; } >> /etc/ld.so.conf.d/${ARCH}-linux-gnu.conf \
    && ldconfig

WORKDIR /root

RUN curl -fsSL -o httpd.tar.gz "${HTTPD_TARBALL_URL}" \
    && curl -fsSL -o apr.tar.gz "${APR_TARBALL_URL}" \
    && curl -fsSL -o apr-util.tar.gz "${APR_UTIL_TARBALL_URL}" \
    && tar -xzf /root/httpd.tar.gz \
    && mv httpd-* httpd

WORKDIR /root/httpd/srclib/

RUN tar -xzf /root/apr.tar.gz \
    && tar -xzf /root/apr-util.tar.gz \
    && ln -s apr-1.7.2 apr \
    && ln -s apr-util-1.6.3 apr-util \
    && rm -f /root/*.tar.gz

WORKDIR /root/httpd/

RUN ./configure --prefix=/opt/apache \
    --with-included-apr \
    --with-ssl=/opt/openssl-1.0.2 \
    --enable-ssl \
    && make && make install

WORKDIR /root

RUN git clone --depth 1 https://github.com/corbin-ch/DNASrep.git \
    && mv DNASrep/etc/dnas /etc/dnas \
    && chown -R 0:0 /etc/dnas \
    && mkdir -p /var/www \
    && mv DNASrep/www/dnas /var/www/dnas \
    && chown -R www-data:www-data /var/www/dnas

RUN git clone --depth 1 https://github.com/corbin-ch/bioserver.git

COPY patches/bioserv1/bioserver/*.java /root/bioserver/bioserv1/bioserver/
COPY patches/bioserv2/bioserver/*.java /root/bioserver/bioserv2/bioserver/
COPY patches/bioserv1/config.properties /root/bioserver/bioserv1/bioserver/config.properties
COPY patches/bioserv2/config.properties /root/bioserver/bioserv2/bioserver/config.properties

WORKDIR /root/bioserver/

RUN mkdir /var/www/bhof1 \
    && mkdir /var/www/bhof2 \
    && cp bioserv1/www/* /var/www/bhof1 \
    && cp bioserv2/www/* /var/www/bhof2 \
    && chown -R www-data:www-data /var/www/bhof1 \
    && chown -R www-data:www-data /var/www/bhof2 \
    && ln -sf /var/www/bhof1 /var/www/dnas/00000002 \
    && ln -sf /var/www/bhof2 /var/www/dnas/00000010

RUN curl -fsSL -o /tmp/mysql-connector.deb "${MYSQL_CONNECTOR_DEB_URL}" \
    && dpkg --install /tmp/mysql-connector.deb \
    && rm -f /tmp/mysql-connector.deb

WORKDIR /root/bioserver/bioserv1/bioserver

RUN javac -cp /usr/share/java/mysql-connector-j-8.0.32.jar:. *.java

WORKDIR /root/bioserver/bioserv1

RUN mkdir -p bin/bioserver \
    && mv bioserver/*.class bin/bioserver \
    && mv bioserver/config.properties . \
    && mkdir lib \
    && ln -sf /usr/share/java/mysql-connector-j-8.0.32.jar lib/mysql-connector.jar \
    && chmod +x run_file1.sh

WORKDIR /root/bioserver/bioserv2/bioserver

RUN javac -cp /usr/share/java/mysql-connector-j-8.0.32.jar:. *.java

WORKDIR /root/bioserver/bioserv2

RUN mkdir -p bin/bioserver \
    && mv bioserver/*.class bin/bioserver \
    && mv bioserver/config.properties . \
    && mkdir lib \
    && ln -sf /usr/share/java/mysql-connector-j-8.0.32.jar lib/mysql-connector.jar \
    && chmod +x run_file2.sh

RUN mkdir -p /run/php \
    && chown www-data:www-data /run/php \
    && chmod 755 /run/php

COPY config/entrypoint.sh /root/entrypoint-allinone.sh
COPY config/entrypoint-app.sh /root/entrypoint-app.sh
COPY config/end_of_httpd.conf /root/end_of_httpd.conf

RUN chmod +x /root/entrypoint-allinone.sh /root/entrypoint-app.sh \
    && if [ "$VARIANT" = "split" ]; then ln -sf /root/entrypoint-app.sh /root/entrypoint-active.sh; \
    else ln -sf /root/entrypoint-allinone.sh /root/entrypoint-active.sh; fi

EXPOSE 53 80 443 8200 8300 8590 8690

ENTRYPOINT ["/bin/bash", "/root/entrypoint-active.sh"]
