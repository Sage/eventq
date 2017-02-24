FROM 522104923602.dkr.ecr.eu-west-1.amazonaws.com/sageone/ruby:20161215

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
	&& gem install -N openssl --version "2.0.3" -- --use-system-libraries \
	&& apk del .gem-builddeps

RUN apk add --update --no-cache libstdc++ && rm -rf /var/cache/apk/*