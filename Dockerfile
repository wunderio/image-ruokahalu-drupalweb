# wunder/fuzzy-alpine-nginx-pagespeed
#
# VERSION v0.1.1-1
#
FROM quay.io/wunder/fuzzy-alpine-base:v3.4
MAINTAINER james.nesbitt@wunder.io


######
#
# NGINX BUILD
#
######

# Based on https://github.com/pagespeed/ngx_pagespeed/issues/1181#issuecomment-250776751.
# Secret Google tarball releases of mod_pagespeed from here https://github.com/pagespeed/mod_pagespeed/issues/968.

# Set versions as environment variables so that they can be inspected later.
ENV LIBPNG_VERSION=1.2.56 \
    # mod_pagespeed requires an old version of http://www.libpng.org/pub/png/libpng.html.
    PAGESPEED_VERSION=1.11.33.4 \
    # Check https://github.com/pagespeed/ngx_pagespeed/releases for the latest version.
    NGINX_VERSION=1.11.7
    # Check http://nginx.org/en/download.html for the latest version.

# Add dependencies.
RUN apk --no-cache add \
        ca-certificates \
        libuuid \
        apr \
        apr-util \
        libjpeg-turbo \
        icu \
        icu-libs \
        openssl \
        pcre \
        zlib

# Add build dependencies
# and build mod_pagespeed from source for Alpine for Nginx with ngx_pagespeed.
RUN set -x && \
    apk --no-cache add -t .build-deps \
        apache2-dev \
        apr-dev \
        apr-util-dev \
        build-base \
        curl \
        icu-dev \
        libjpeg-turbo-dev \
        linux-headers \
        gperf \
        openssl-dev \
        pcre-dev \
        python \
        zlib-dev && \
    # Build libpng.
    cd /tmp && \
    curl -L http://prdownloads.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.gz | tar -zx && \
    cd /tmp/libpng-${LIBPNG_VERSION} && \
    ./configure --build=$CBUILD --host=$CHOST --prefix=/usr --enable-shared --with-libpng-compat && \
    make install V=0 && \
    # Build PageSpeed.
    cd /tmp && \
    curl -L https://dl.google.com/dl/linux/mod-pagespeed/tar/beta/mod-pagespeed-beta-${PAGESPEED_VERSION}-r0.tar.bz2 | tar -jx && \
    curl -L https://github.com/pagespeed/ngx_pagespeed/archive/v${PAGESPEED_VERSION}-beta.tar.gz | tar -zx && \
    cd /tmp/modpagespeed-${PAGESPEED_VERSION} && \
    curl -L https://raw.githubusercontent.com/wunderkraut/alpine-nginx-pagespeed/master/patches/automatic_makefile.patch | patch -p1 && \
    curl -L https://raw.githubusercontent.com/wunderkraut/alpine-nginx-pagespeed/master/patches/libpng_cflags.patch | patch -p1 && \
    curl -L https://raw.githubusercontent.com/wunderkraut/alpine-nginx-pagespeed/master/patches/pthread_nonrecursive_np.patch | patch -p1 && \
    curl -L https://raw.githubusercontent.com/wunderkraut/alpine-nginx-pagespeed/master/patches/rename_c_symbols.patch | patch -p1 && \
    curl -L https://raw.githubusercontent.com/wunderkraut/alpine-nginx-pagespeed/master/patches/stack_trace_posix.patch | patch -p1 && \
    ./generate.sh -D use_system_libs=1 -D _GLIBCXX_USE_CXX11_ABI=0 -D use_system_icu=1 && \
    cd /tmp/modpagespeed-${PAGESPEED_VERSION}/src && \
    make BUILDTYPE=Release CXXFLAGS=" -I/usr/include/apr-1 -I/tmp/libpng-${LIBPNG_VERSION} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" CFLAGS=" -I/usr/include/apr-1 -I/tmp/libpng-${LIBPNG_VERSION} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" && \
    cd /tmp/modpagespeed-${PAGESPEED_VERSION}/src/pagespeed/automatic/ && \
    make psol BUILDTYPE=Release CXXFLAGS=" -I/usr/include/apr-1 -I/tmp/libpng-${LIBPNG_VERSION} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" CFLAGS=" -I/usr/include/apr-1 -I/tmp/libpng-${LIBPNG_VERSION} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" && \
    mkdir -p /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol && \
    mkdir -p /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/lib/Release/linux/x64 && \
    mkdir -p /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/out/Release && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/out/Release/obj /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/out/Release/ && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/net /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/testing /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/pagespeed /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/third_party /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/tools /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/url /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/pagespeed/automatic/pagespeed_automatic.a /tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta/psol/lib/Release/linux/x64 && \
    # Build Nginx with support for PageSpeed.
    cd /tmp && \
    curl -L http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar -zx && \
    cd /tmp/nginx-${NGINX_VERSION} && \
    LD_LIBRARY_PATH=/tmp/modpagespeed-${PAGESPEED_VERSION}/usr/lib ./configure \
        --sbin-path=/usr/sbin \
        --modules-path=/usr/lib/nginx \
        --with-http_ssl_module \
        --with-http_gzip_static_module \
        --with-file-aio \
        --with-http_v2_module \
        --with-http_stub_status_module \
        --with-http_realip_module \
        --without-http_autoindex_module \
        --without-http_browser_module \
        --without-http_geo_module \
        --without-http_map_module \
        --without-http_memcached_module \
        --without-http_userid_module \
        --without-mail_pop3_module \
        --without-mail_imap_module \
        --without-mail_smtp_module \
        --without-http_split_clients_module \
        --without-http_scgi_module \
        --without-http_referer_module \
        --without-http_upstream_ip_hash_module \
        --prefix=/etc/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --pid-path=/var/run/nginx.pid \
        --add-module=/tmp/ngx_pagespeed-${PAGESPEED_VERSION}-beta \
        --with-cc-opt="-fPIC -I /usr/include/apr-1" \
        --with-ld-opt="-luuid -lapr-1 -laprutil-1 -licudata -licuuc -L/tmp/modpagespeed-${PAGESPEED_VERSION}/usr/lib -lpng12 -lturbojpeg -ljpeg" && \
    make install --silent && \
    # Make sure /etc/nginx/conf.d folder is available for images extending
    # this one.
    mkdir -p /etc/nginx/conf.d && \
    # Clean-up.
    cd && \
    apk del .build-deps && \
    rm -rf /tmp/* && \
    # Forward request and error logs to docker log collector.
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    # Make PageSpeed cache writable.
    mkdir -p /var/cache/ngx_pagespeed && \
    chmod -R o+wr /var/cache/ngx_pagespeed

# Make our nginx.conf available on the container.
ADD etc/nginx/nginx.conf /etc/nginx/nginx.conf

# Separate the logs into their own volume to keep them out of the container.
VOLUME ["/var/log/nginx"]

# Expose the HTTP and HTTPS ports.
EXPOSE 80 443

# Set nginx directly as the entrypoint.
#ENTRYPOINT ["nginx", "-g", "daemon off;"]

# Add Drupal specific configurations.
#ADD etc/nginx/conf.d/app_drupal.conf /etc/nginx/conf.d/app_drupal.conf
#ADD etc/nginx/conf.d/fastcgi_drupal.conf /etc/nginx/conf.d/fastcgi_drupal.conf
#ADD etc/nginx/conf.d/nginx_app.conf /etc/nginx/conf.d/nginx_app.conf
#ADD etc/nginx/conf.d/nginx_upstream.conf /etc/nginx/conf.d/nginx_upstream.conf
ADD etc/nginx/conf.d /etc/nginx/conf.d

# The above expects the following paths to exist
RUN mkdir /app/web && mkdir /app/vendor && chown -R app:app /app

#####
#
# PHP-FPM INSTALLATION
#
#####

####
# Install php7 packages from edge repositories
#
RUN echo http://dl-cdn.alpinelinux.org/alpine/edge/community >> /etc/apk/repositories && \
    echo http://dl-cdn.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories && \
    echo http://dl-cdn.alpinelinux.org/alpine/edge/main >> /etc/apk/repositories && \
    apk --no-cache --update add \
        php7-fpm \
        php7-apcu \
        php7-common \
        php7-curl \
        php7-memcached \
        php7-xml \
        php7-xmlrpc \
        php7-pdo \
        php7-pdo_mysql \
        php7-pdo_pgsql \
        php7-pdo_sqlite \
        php7-mysqlnd \
        php7-mysqli \
        php7-mcrypt \
        php7-opcache \
        php7-json \
        php7-pear \
        php7-mbstring \
        php7-soap \
        php7-ctype \
        php7-gd \
        php7-dom \
        php7-bcmath \
        php7-gmagick && \
    # Cleanup
    rm -rf /tmp/* && \
    rm -rf /var/cache/apk/*

####
# Add a www php-fpm service definition
#
ADD etc/php7/php-fpm.d/www.conf /etc/php7/php-fpm.d/www.conf

####
# Add php settings and extension control from Wunder
#
ADD etc/php7/conf.d/90_wunder.ini /etc/php7/conf.d/90_wunder.ini

####
# Some default ENV values
#
ENV HOSTNAME phpfpm7
ENV ENVIRONMENT develop

# Expose the php port
EXPOSE 9000

# Set php-fpm as the entrypoint
#ENTRYPOINT ["/usr/sbin/php-fpm7", "--nodaemonize"]


#####
#
# Web site sanity check
#
# This files are added to provide a default PHP landing page,
# in case you have not overlayed or build in any source code
#
#####

ADD /app/web /app/web
ADD /app/vendor /app/vendor
RUN chmod -R app:app /app/web && chmod -R app:app /app/vendor

#####
#
# S6 process management
#
#####

# Install s6
# @TODO

# add the s6 process scripts for PHP & nginx
# @TODO

ENTRYPOINT ["/usr/bin/s6-svscan","/etc/s6"]
CMD []