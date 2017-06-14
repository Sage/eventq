FROM codeguru/ruby:2.3.1-alpine-3.4

RUN set -ex \
	&& apk add --no-cache --virtual .gem-builddeps \
		autoconf \
		bison \
		bzip2 \
		bzip2-dev \
		ca-certificates \
		coreutils \
		gcc \
		gdbm-dev \
		glib-dev \
		libc-dev \
		libedit-dev \
		libffi-dev \
		libxml2-dev \
		libxslt-dev \
		linux-headers \
		make \
		ncurses-dev \
		openssl-dev \
		procps \
		yaml-dev \
		zlib-dev \
		libstdc++ \
		libssl1.0 \
		libcrypto1.0 \
		libgcc \
		musl \
		ruby-dev build-base \
	&& gem install -N json --version "1.8.3" -- --use-system-libraries \
    && gem install -N oj --version "2.15.0" -- --use-system-libraries \
    && gem install -N openssl --version "2.0.4" -- --use-system-libraries \
	&& apk del .gem-builddeps

RUN apk add --update --no-cache libstdc++ && rm -rf /var/cache/apk/*