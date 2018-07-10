echo setup starting.....
docker-compose rm

echo build docker image
docker build --no-cache -t eventq .

echo setup complete
