FROM ruby:2.4-alpine

RUN apk add --update ca-certificates bash && update-ca-certificates && rm -rf /var/cache/apk/*

RUN set -ex \
	&& apk add --no-cache --virtual .gem-builddeps \
		ruby-dev build-base libressl-dev \
	&& gem install -N json --version "1.8.5" -- --use-system-libraries \
	&& gem install -N oj --version "2.16.1" -- --use-system-libraries \
	&& gem install -N openssl --version "2.0.4" -- --use-system-libraries \
	&& gem install -N byebug --version "10.0.2" -- --use-system-libraries \
	&& apk del .gem-builddeps
