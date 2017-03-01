FROM 522104923602.dkr.ecr.eu-west-1.amazonaws.com/sageone/ruby:20161215

RUN apk --update add --virtual build_deps alpine-sdk ruby-dev openssl-dev && \
        gem install -N openssl --version '2.0.3' -- --use-system-libraries && \
        apk del build_deps