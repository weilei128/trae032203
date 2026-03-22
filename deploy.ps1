# SpringBoot Docker 自动化部署脚本
# 服务器信息
$SERVER_IP = "49.235.161.106"
$SERVER_PORT = "22"
$SERVER_USER = "root"
$TARGET_DIR = "/opt/apps/memo-app"

# 应用信息
$APP_NAME = "account-app"
$APP_VERSION = "1.0.0"
$JAR_NAME = "kimi.jar"
$CONTAINER_PORT = "10013"
$IMAGE_NAME = "account-app"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SpringBoot Docker 自动化部署脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 步骤 1: 本地 Maven 打包
Write-Host "[1/7] 开始本地 Maven 打包..." -ForegroundColor Yellow
mvn clean package -DskipTests
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Maven 打包失败!" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Maven 打包成功" -ForegroundColor Green

# 复制并重命名 jar 包
Copy-Item "target\personal-account-book-1.0.0.jar" "target\$JAR_NAME" -Force
Write-Host "✅ Jar 包已重命名为 $JAR_NAME" -ForegroundColor Green
Write-Host ""

# 步骤 2: 检查并创建 Dockerfile
Write-Host "[2/7] 检查 Dockerfile..." -ForegroundColor Yellow
if (-not (Test-Path "Dockerfile")) {
    Write-Host "❌ Dockerfile 不存在!" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Dockerfile 已存在" -ForegroundColor Green
Write-Host ""

# 步骤 3: 上传文件到服务器
Write-Host "[3/7] 上传文件到服务器..." -ForegroundColor Yellow

# 创建目标目录
$createDirCmd = "mkdir -p $TARGET_DIR"
ssh -p $SERVER_PORT "${SERVER_USER}@${SERVER_IP}" $createDirCmd

# 上传 jar 包
scp -P $SERVER_PORT "target\$JAR_NAME" "${SERVER_USER}@${SERVER_IP}:${TARGET_DIR}/"
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 上传 jar 包失败!" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Jar 包上传成功" -ForegroundColor Green

# 上传 Dockerfile
scp -P $SERVER_PORT "Dockerfile" "${SERVER_USER}@${SERVER_IP}:${TARGET_DIR}/"
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 上传 Dockerfile 失败!" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Dockerfile 上传成功" -ForegroundColor Green
Write-Host ""

# 步骤 4: 远程执行 Docker 部署
Write-Host "[4/7] 远程执行 Docker 部署..." -ForegroundColor Yellow

$remoteScript = @"
#!/bin/bash
set -e

echo "========================================"
echo "  服务器端部署脚本"
echo "========================================"
echo ""

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi
echo "✅ Docker 已安装"

# 进入目标目录
cd $TARGET_DIR

# 检查端口是否被占用
echo "[1/5] 检查端口 $CONTAINER_PORT 是否被占用..."
CONTAINER_ID=\$(docker ps -q --filter "publish=\$CONTAINER_PORT")
if [ ! -z "\$CONTAINER_ID" ]; then
    echo "⚠️  端口 \$CONTAINER_PORT 已被容器 \$CONTAINER_ID 占用，正在停止..."
    docker stop \$CONTAINER_ID
    docker rm \$CONTAINER_ID
    echo "✅ 已停止并删除旧容器"
else
    echo "✅ 端口 \$CONTAINER_PORT 未被占用"
fi

# 检查是否有同名镜像
echo "[2/5] 检查镜像..."
if docker images | grep -q "^$IMAGE_NAME"; then
    echo "⚠️  发现旧镜像，正在删除..."
    docker rmi -f $IMAGE_NAME:latest || true
    echo "✅ 旧镜像已删除"
fi

# 构建新镜像
echo "[3/5] 构建 Docker 镜像..."
docker build -t $IMAGE_NAME:$APP_VERSION -t $IMAGE_NAME:latest .
echo "✅ 镜像构建成功"

# 运行容器
echo "[4/5] 运行 Docker 容器..."
docker run -d \
    --name $APP_NAME \
    -p $CONTAINER_PORT:$CONTAINER_PORT \
    -v $TARGET_DIR/data:/app/data \
    --restart unless-stopped \
    $IMAGE_NAME:latest

echo "✅ 容器启动成功"

# 等待服务启动
echo "[5/5] 等待服务启动..."
sleep 10

# 检查容器状态
echo ""
echo "========================================"
echo "  部署状态检查"
echo "========================================"
docker ps | grep $APP_NAME
echo ""
docker logs --tail 20 $APP_NAME
echo ""
echo "✅ 部署完成!"
"@

# 保存并执行远程脚本
$remoteScript | ssh -p $SERVER_PORT "${SERVER_USER}@${SERVER_IP}" "cat > /tmp/deploy_remote.sh && chmod +x /tmp/deploy_remote.sh && bash /tmp/deploy_remote.sh"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 远程部署失败!" -ForegroundColor Red
    exit 1
}
Write-Host "✅ 远程部署成功" -ForegroundColor Green
Write-Host ""

# 步骤 5: 验证服务
Write-Host "[5/7] 验证服务状态..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

try {
    $response = Invoke-WebRequest -Uri "http://${SERVER_IP}:${CONTAINER_PORT}/" -Method GET -TimeoutSec 10 -ErrorAction SilentlyContinue
    Write-Host "✅ 服务响应正常，状态码: \$($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "⚠️  服务可能还在启动中，请稍后手动检查" -ForegroundColor Yellow
}
Write-Host ""

# 步骤 6: 输出访问地址
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  部署完成!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 应用信息:" -ForegroundColor White
Write-Host "   应用名称: $APP_NAME" -ForegroundColor Gray
Write-Host "   版本: $APP_VERSION" -ForegroundColor Gray
Write-Host "   容器端口: $CONTAINER_PORT" -ForegroundColor Gray
Write-Host ""
Write-Host "🌐 访问地址:" -ForegroundColor White
Write-Host "   HTTP: http://${SERVER_IP}:${CONTAINER_PORT}/" -ForegroundColor Green
Write-Host ""
Write-Host "🔧 常用命令:" -ForegroundColor White
Write-Host "   查看日志: ssh ${SERVER_USER}@${SERVER_IP} 'docker logs -f $APP_NAME'" -ForegroundColor Gray
Write-Host "   进入容器: ssh ${SERVER_USER}@${SERVER_IP} 'docker exec -it $APP_NAME sh'" -ForegroundColor Gray
Write-Host "   停止服务: ssh ${SERVER_USER}@${SERVER_IP} 'docker stop $APP_NAME'" -ForegroundColor Gray
Write-Host "   重启服务: ssh ${SERVER_USER}@${SERVER_IP} 'docker restart $APP_NAME'" -ForegroundColor Gray
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
