#!/bin/bash
set -e

echo "========================================"
echo "  Kimi 应用 Docker 部署脚本"
echo "========================================"
echo ""

# 配置
APP_NAME="account-app"
IMAGE_NAME="account-app"
APP_VERSION="1.0.0"
CONTAINER_PORT=10013
JAR_NAME="kimi.jar"

echo "[1/6] 检查 Docker 环境..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装"
    exit 1
fi
echo "✅ Docker 已安装: $(docker --version)"
echo ""

echo "[2/6] 检查端口 $CONTAINER_PORT 占用情况..."
# 检查是否有容器占用该端口
CONTAINER_ID=$(docker ps -q --filter "publish=$CONTAINER_PORT")
if [ ! -z "$CONTAINER_ID" ]; then
    echo "⚠️  端口 $CONTAINER_PORT 被容器 $CONTAINER_ID 占用"
    echo "    正在停止并删除旧容器..."
    docker stop $CONTAINER_ID
    docker rm $CONTAINER_ID
    echo "✅ 旧容器已清理"
else
    echo "✅ 端口 $CONTAINER_PORT 可用"
fi
echo ""

echo "[3/6] 检查并清理旧镜像..."
# 检查是否有同名容器在运行
OLD_CONTAINER=$(docker ps -aq --filter "name=$APP_NAME")
if [ ! -z "$OLD_CONTAINER" ]; then
    echo "⚠️  发现同名容器，正在停止并删除..."
    docker stop $OLD_CONTAINER 2>/dev/null || true
    docker rm $OLD_CONTAINER 2>/dev/null || true
    echo "✅ 旧容器已清理"
fi

# 检查并删除旧镜像
if docker images | grep -q "^$IMAGE_NAME "; then
    echo "⚠️  发现旧镜像，正在删除..."
    docker rmi -f ${IMAGE_NAME}:${APP_VERSION} 2>/dev/null || true
    docker rmi -f ${IMAGE_NAME}:latest 2>/dev/null || true
    echo "✅ 旧镜像已清理"
else
    echo "✅ 无旧镜像需要清理"
fi
echo ""

echo "[4/6] 构建 Docker 镜像..."
# 使用专门的 Dockerfile
cd /opt/apps/memo-app
cp Dockerfile.kimi Dockerfile
docker build -t ${IMAGE_NAME}:${APP_VERSION} -t ${IMAGE_NAME}:latest .
echo "✅ 镜像构建成功"
echo ""

echo "[5/6] 启动 Docker 容器..."
docker run -d \
    --name $APP_NAME \
    -p ${CONTAINER_PORT}:${CONTAINER_PORT} \
    -v /opt/apps/memo-app/data:/app/data \
    --restart unless-stopped \
    ${IMAGE_NAME}:latest

echo "✅ 容器已启动"
echo ""

echo "[6/6] 等待服务启动并验证..."
sleep 10

echo ""
echo "========================================"
echo "  容器状态"
echo "========================================"
docker ps --filter "name=$APP_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "========================================"
echo "  最近日志"
echo "========================================"
docker logs --tail 30 $APP_NAME 2>&1 || echo "暂无日志"
echo ""

echo "========================================"
echo "  ✅ 部署完成!"
echo "========================================"
SERVER_IP=$(curl -s ifconfig.me)
echo "  访问地址: http://${SERVER_IP}:${CONTAINER_PORT}"
echo "========================================"
