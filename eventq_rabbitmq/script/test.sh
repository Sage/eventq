#!/bin/sh

echo start rspec tests
docker-compose up -d

docker exec -it gem_test_runner bash -c "cd gem_src && sleep 2 && bundle install && bundle exec rspec $*"
