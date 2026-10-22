# Variant of nginx.dockerfile that builds Baikal from a Git branch instead of
# using a release zip, e.g. to test changes that are not released yet.
#
# Multi-stage build, see https://docs.docker.com/develop/develop-images/multistage-build/
# Baikal is plain PHP, so the builder stage only runs on the build platform
FROM --platform=$BUILDPLATFORM composer:2 AS builder

ARG BAIKAL_REPOSITORY=https://github.com/wnhrt/Baikal.git
ARG BAIKAL_REF=feature/birthday-calendar

# Build Baikal the same way as the release zip, see Baikal's Makefile
RUN apk add --no-cache make rsync zip
RUN git clone --depth 1 --branch "$BAIKAL_REF" "$BAIKAL_REPOSITORY" /baikal-src
RUN cd /baikal-src && make dist && mv build/baikal /baikal

# Final Docker image
FROM nginx:1

# Install dependencies: PHP & SQLite3
RUN curl -o /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg &&\
  apt update                  &&\
  apt install -y lsb-release  &&\
  echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list &&\
  apt remove -y lsb-release   &&\
  apt update                  &&\
  apt install -y            \
  php8.5-curl               \
  php8.5-fpm                \
  php8.5-mbstring           \
  php8.5-mysql              \
  php8.5-pgsql              \
  php8.5-sqlite3            \
  php8.5-xml                \
  php8.5-imap               \
  sqlite3                   \
  msmtp msmtp-mta           &&\
  rm -rf /var/lib/apt/lists/* &&\
  sed -i 's/www-data/nginx/' /etc/php/8.5/fpm/pool.d/www.conf &&\
  sed -i 's/^listen = .*/listen = \/var\/run\/php-fpm.sock/' /etc/php/8.5/fpm/pool.d/www.conf

# Add Baikal & nginx configuration
COPY files/docker-entrypoint.d/*.sh files/docker-entrypoint.d/*.php files/docker-entrypoint.d/nginx/ /docker-entrypoint.d/
COPY --from=builder --chown=nginx:nginx /baikal /var/www/baikal
COPY files/favicon.ico /var/www/baikal/html
COPY files/nginx.conf /etc/nginx/conf.d/default.conf

VOLUME /var/www/baikal/config
VOLUME /var/www/baikal/Specific
