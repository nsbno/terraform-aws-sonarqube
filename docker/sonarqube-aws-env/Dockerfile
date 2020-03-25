FROM sonarqube:8.2-community
USER root
RUN curl -L https://github.com/telia-oss/aws-env/releases/download/v0.3.0/aws-env-linux-amd64 > /usr/local/bin/aws-env && \
      echo f80addd4adf9aa8d4ecf1b16de402ba4  /usr/local/bin/aws-env | md5sum -c && \
      chmod +x /usr/local/bin/aws-env

COPY post-init.sh start.sh start-with-params.sh entrypoint.sh ./

ENTRYPOINT ["./entrypoint.sh"]