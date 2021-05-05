FROM sonarqube:8.9-community
USER root
RUN apk add --update --no-cache curl gcc libc-dev \
    && curl -L https://github.com/telia-oss/aws-env/releases/download/v0.3.0/aws-env-linux-amd64 > /usr/local/bin/aws-env \
    && echo "f80addd4adf9aa8d4ecf1b16de402ba4  /usr/local/bin/aws-env" | md5sum -c \
    && chmod +x /usr/local/bin/aws-env
RUN  set -ex; \
     \
     curl -o /usr/local/bin/su-exec.c https://raw.githubusercontent.com/ncopa/su-exec/master/su-exec.c; \
     \
     gcc -Wall \
         /usr/local/bin/su-exec.c -o/usr/local/bin/su-exec; \
     chown root:root /usr/local/bin/su-exec; \
     chmod 0755 /usr/local/bin/su-exec; \
     rm /usr/local/bin/su-exec.c; \
     apk del gcc libc-dev; \
     echo "-Des.enforce.bootstrap.checks=false" >> /opt/sonarqube/elasticsearch/config/jvm.options


COPY post-init.sh start.sh start-with-params.sh entrypoint.sh ./

ENTRYPOINT ["./entrypoint.sh"]