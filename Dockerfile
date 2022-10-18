# Set the base image
FROM postgres:13.7-alpine

RUN apk -v --update add \
        py-pip \
        curl \
        && \
    pip install --upgrade awscli s3cmd && \
    rm /var/cache/apk/*

# Set Default Environment Variables
ENV TARGET_DATABASE_PORT=8500
ENV SLACK_ENABLED=false
ENV SLACK_USERNAME=kubernetes-s3-consul-backup

# Copy Slack Alert script and make executable
#COPY resources/slack-alert.sh /
#RUN chmod +x /slack-alert.sh

# Copy backup script and execute
COPY resources/perform-backup.sh /
RUN chmod +x /perform-backup.sh
CMD ["sh", "/perform-backup.sh"]
