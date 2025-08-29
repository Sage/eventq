#!/bin/sh

echo start rspec tests
docker compose up -d

docker exec -it testrunner bash -c "bundle install && bundle exec rspec $*"
