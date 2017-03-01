echo setup starting.....
docker-compose rm

echo build docker image
docker build -t eventq/aws .

echo setup complete
