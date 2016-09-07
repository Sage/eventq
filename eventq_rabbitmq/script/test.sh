#!/bin/sh

echo start rspec tests
docker-compose up -d


spec_path='spec'

if [[ $1 ]]; then
  spec_path=$1
fi

docker exec -it gem_test_runner bash -c "cd gem_src && bundle install && bundle exec rspec ${spec_path}"
