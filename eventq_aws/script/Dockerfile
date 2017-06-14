FROM codeguru/ruby:2.3.1-alpine-3.4

RUN apk add --update ca-certificates && update-ca-certificates && rm -rf /var/cache/apk/*

RUN set -ex \
	&& apk add --no-cache --virtual .gem-builddeps \
		ruby-dev build-base openssl-dev \
	&& gem install -N json --version "1.8.3" -- --use-system-libraries \
	&& gem install -N oj --version "2.15.0" -- --use-system-libraries \
	&& gem install -N openssl --version "2.0.4" -- --use-system-libraries \
	&& apk del .gem-builddeps