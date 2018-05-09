FROM debian

RUN apt-get update \
  && apt-get install -y \
       build-essential \
       curl \
       ruby \
       ruby-dev \
       unzip \
  && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock /
RUN gem install bundler \
  && bundle

RUN curl https://downloads.rclone.org/v1.41/rclone-v1.41-linux-amd64.zip > /tmp/rclone.zip \
  && unzip /tmp/rclone.zip -d /tmp \
  && mv /tmp/rclone*/rclone /usr/bin \
  && rm -rf /tmp/rclone*

COPY rclone-report.rb /
