echo setup starting.....
docker-compose rm

echo build docker image
docker build -t eventq/rabbitmq .

echo setup complete
