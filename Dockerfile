FROM ruby:2.4-alpine3.8

RUN apk add --update ca-certificates bash && update-ca-certificates && rm -rf /var/cache/apk/*
RUN apk update && apk add --no-cache build-base

RUN set -ex \
	&& apk add --no-cache --virtual .gem-builddeps \
		ruby-dev build-base libressl-dev

ENV APP_HOME /src
RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME

COPY . $APP_HOME
RUN bundle install
RUN apk del .gem-builddeps

