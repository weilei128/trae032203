#!/bin/bash
# SpringBoot 应用 Docker 部署脚本 (Bash版本)

# 配置信息
SERVER_IP="49.235.161.106"
SSH_PORT="22"
SSH_USER="root"
TARGET_DIR="/opt/apps/memo-app"
APP_NAME="account-app"
APP_VERSION="1.0.0"
LOCAL_JAR_PATH="target/dogFooding.jar"
LOCAL_DOCKERFILE_PATH="Dockerfile"
DOCKER_IMAGE_NAME="$APP_NAME:$APP_VERSION"
CONTAINER_NAME="$APP_NAME"
HOST_PORT="10011"
CONTAINER_PORT="10011"
JVM_OPTS="-Xms256m -Xmx512m"

echo "========================================"
echo "SpringBoot 应用 Docker 部署脚本"
echo "========================================"

# 1. 本地文件检查
echo ""
echo "[1/8] 检查本地文件..."
if [ ! -f "$LOCAL_JAR_PATH" ]; then
    echo "错误: Jar包不存在！路径: $LOCAL_JAR_PATH"
    exit 1
fi
if [ ! -f "$LOCAL_DOCKERFILE_PATH" ]; then
    echo "错误: Dockerfile不存在！路径: $LOCAL_DOCKERFILE_PATH"
    exit 1
fi
echo "本地文件检查完成"

# 2. 服务器连接测试
echo ""
echo "[2/8] 测试服务器连接..."
if ssh -p $SSH_PORT $SSH_USER@$SERVER_IP "echo '连接成功'" 2>/dev/null; then
    echo "服务器连接成功"
else
    echo "错误: 无法连接到服务器！请检查SSH密钥配置和网络连接"
    exit 1
fi

# 3. 服务器环境检测
echo ""
echo "[3/8] 检测服务器环境..."
DOCKER_VER=$(ssh -p $SSH_PORT $SSH_USER@$SERVER_IP "docker --version 2>/dev/null || echo 'NOT_INSTALLED'")
if [ "$DOCKER_VER" = "NOT_INSTALLED" ]; then
    echo "错误: Docker未安装！请先在服务器上安装Docker"
    exit 1
fi
echo "Docker版本: $DOCKER_VER"

# 4. 检查服务器上是否已有Dockerfile
echo ""
echo "[4/8] 检查服务器现有配置..."
if ssh -p $SSH_PORT $SSH_USER@$SERVER_IP "test -f $TARGET_DIR/Dockerfile"; then
    echo "服务器上已存在Dockerfile，将被覆盖"
else
    echo "服务器上无Dockerfile"
fi

# 5. 创建目标目录并上传文件
echo ""
echo "[5/8] 上传文件到服务器..."
ssh -p $SSH_PORT $SSH_USER@$SERVER_IP "mkdir -p $TARGET_DIR"

# 上传jar包
echo "上传Jar包..."
if scp -P $SSH_PORT "$LOCAL_JAR_PATH" $SSH_USER@$SERVER_IP:$TARGET_DIR/; then
    echo "Jar包上传成功"
else
    echo "错误: 上传jar包失败！"
    exit 1
fi

# 上传Dockerfile
echo "上传Dockerfile..."
if scp -P $SSH_PORT "$LOCAL_DOCKERFILE_PATH" $SSH_USER@$SERVER_IP:$TARGET_DIR/; then
    echo "Dockerfile上传成功"
else
    echo "错误: 上传Dockerfile失败！"
    exit 1
fi

# 6. 远程执行Docker构建和部署
echo ""
echo "[6/8] 远程部署应用..."
ssh -p $SSH_PORT $SSH_USER@$SERVER_IP << EOF
cd $TARGET_DIR

# 停止并删除旧容器
if docker ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME\$"; then
    echo "停止并删除旧容器: $CONTAINER_NAME"
    docker stop $CONTAINER_NAME
    docker rm $CONTAINER_NAME
fi

# 删除旧镜像
if docker images --format '{{.Repository}}:{{.Tag}}' | grep -w "^$DOCKER_IMAGE_NAME\$"; then
    echo "删除旧镜像: $DOCKER_IMAGE_NAME"
    docker rmi $DOCKER_IMAGE_NAME
fi

# 检查端口是否被占用
PORT_CONTAINER=\$(docker ps --format '{{.ID}} {{.Ports}}' | grep ":$HOST_PORT->" | awk '{print \$1}')
if [ -n "\$PORT_CONTAINER" ]; then
    echo "端口 $HOST_PORT 被占用，正在关闭容器: \$PORT_CONTAINER"
    docker stop \$PORT_CONTAINER
    docker rm \$PORT_CONTAINER
fi

# 构建新镜像
echo "构建新镜像: $DOCKER_IMAGE_NAME"
docker build -t $DOCKER_IMAGE_NAME .

# 运行容器
echo "启动新容器: $CONTAINER_NAME"
docker run -d \\
    --name $CONTAINER_NAME \\
    --restart=always \\
    -p $HOST_PORT:$CONTAINER_PORT \\
    -e JVM_OPTS="$JVM_OPTS" \\
    -v $TARGET_DIR/data:/app/data \\
    $DOCKER_IMAGE_NAME

echo "等待容器启动..."
sleep 10

# 检查容器状态
if docker ps --format '{{.Names}} {{.Status}}' | grep "^$CONTAINER_NAME " | grep "Up"; then
    echo "容器启动成功！"
    docker ps --filter "name=$CONTAINER_NAME"
else
    echo "容器启动失败！查看日志:"
    docker logs $CONTAINER_NAME
    exit 1
fi
EOF

if [ $? -ne 0 ]; then
    echo "错误: 部署失败！"
    exit 1
fi

# 7. 验证服务
echo ""
echo "[7/8] 验证服务状态..."
MAX_ATTEMPTS=10
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -s --connect-timeout 5 "http://$SERVER_IP:$HOST_PORT" > /dev/null; then
        echo "服务验证成功！"
        break
    fi
    ATTEMPT=$((ATTEMPT+1))
    echo "等待服务就绪... ($ATTEMPT/$MAX_ATTEMPTS)"
    sleep 5
done

# 8. 显示访问信息
echo ""
echo "[8/8] 部署完成！"
echo "========================================"
echo "应用名称: $APP_NAME"
echo "版本: $APP_VERSION"
echo "访问地址: http://$SERVER_IP:$HOST_PORT"
echo "容器名称: $CONTAINER_NAME"
echo "镜像名称: $DOCKER_IMAGE_NAME"
echo "========================================"

echo ""
echo "查看容器日志命令:"
echo "ssh -p $SSH_PORT $SSH_USER@$SERVER_IP 'docker logs -f $CONTAINER_NAME'"