FROM codeguru/ruby:2.3.1-alpine-3.4

RUN set -ex \
	&& apk add --no-cache --virtual .gem-builddeps \
		ruby-dev build-base \
	&& gem install -N json --version "1.8.3" -- --use-system-libraries \
	&& gem install -N oj --version "2.15.0" -- --use-system-libraries \
	&& apk del .gem-builddeps
