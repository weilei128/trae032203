FROM openjdk:8-jdk-alpine

LABEL maintainer="account-app"
LABEL version="1.0.0"
LABEL description="Personal Account Book Application"

WORKDIR /app

ENV JAVA_OPTS="-Xms256m -Xmx512m"
ENV TZ=Asia/Shanghai

RUN apk add --no-cache tzdata && \
    cp /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo "${TZ}" > /etc/timezone && \
    apk del tzdata

COPY GLM.jar app.jar

EXPOSE 10012

ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -Djava.security.egd=file:/dev/./urandom -jar app.jar"]
