FROM ruby:3.2-alpine3.18

ENV APP_HOME=/src
RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME

RUN apk add --update ca-certificates bash && update-ca-certificates && rm -rf /var/cache/apk/*
RUN apk update && apk add --no-cache build-base libressl-dev

RUN set -ex \
	&& apk add --no-cache --virtual .gem-builddeps \
		ruby-dev build-base


COPY Gemfile $APP_HOME
COPY eventq.gemspec $APP_HOME
COPY EVENTQ_VERSION $APP_HOME

RUN bundle install --no-cache \
	&& apk del .gem-builddeps
