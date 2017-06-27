#!/bin/sh

echo start rspec tests
docker-compose up -d

docker exec -it testrunner bash -c "cd gem_src && bundle install && bundle exec rspec $*" \
&& docker exec -it testrunner_jruby bash -c "cd gem_src && rm -rf Gemfile.lock && jruby -S bundle install && jruby -S rspec $*"