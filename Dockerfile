FROM openjdk:8-jre-alpine

# 设置工作目录
WORKDIR /app

# 设置时区
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN echo 'Asia/Shanghai' > /etc/timezone

# 复制jar包
COPY dogFooding.jar /app/

# 暴露端口
EXPOSE 10011

# JVM参数
ENV JVM_OPTS="-Xms256m -Xmx512m"

# 启动命令
ENTRYPOINT ["sh", "-c", "java $JVM_OPTS -jar dogFooding.jar"]