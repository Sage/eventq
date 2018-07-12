#!/bin/sh

echo start rspec tests
docker-compose up -d

docker exec -it testrunner bash -c "cd src && bundle install && bundle exec rspec $*"

#docker exec -it testrunner bash -c "cd src && bundle install && bundle exec rspec $*" \
#&& docker exec -it testrunner_jruby bash -c "cd src && rm -rf Gemfile.lock && jruby -S bundle install && jruby -S rspec $*"
