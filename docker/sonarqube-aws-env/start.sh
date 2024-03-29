#!/bin/bash
./post-init.sh &
java -jar lib/sonar-application-$SONAR_VERSION.jar \
  -Dsonar.forceAuthentication=true \
  -Dsonar.log.console=true \
  -Dsonar.jdbc.username="$SONARQUBE_JDBC_USERNAME" \
  -Dsonar.jdbc.password="$SONARQUBE_JDBC_PASSWORD" \
  -Dsonar.jdbc.url="$SONARQUBE_JDBC_URL" \
  -Dsonar.web.javaAdditionalOpts="$SONARQUBE_WEB_JVM_OPTS -Djava.security.egd=file:/dev/./urandom" \
  -Dsonar.search.javaAdditionalOpts="$SONARQUBE_SEARCH_JVM_OPTS" \
  "$@"