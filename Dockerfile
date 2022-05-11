FROM debian:stable

RUN apt-get update \
  && apt-get install -y \
       build-essential \
       curl \
       rclone \
       ruby \
       ruby-dev \
       unzip \
  && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock /
RUN gem install bundler \
  && bundle

COPY run-rclone.sh rclone-wrapper.rb /
