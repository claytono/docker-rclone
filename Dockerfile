FROM debian

RUN apt-get update \
  && apt-get install curl unzip -y \
  && rm -rf /var/lib/apt/lists/*

RUN curl https://downloads.rclone.org/v1.41/rclone-v1.41-linux-amd64.zip > /tmp/rclone.zip \
  && unzip /tmp/rclone.zip -d /tmp \
  && mv /tmp/rclone*/rclone /usr/bin \
  && rm -rf /tmp/rclone*
