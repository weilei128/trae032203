# SpringBoot 应用 Docker 部署脚本 - PowerShell 5 兼容版
# 配置信息
$SERVER_IP = "49.235.161.106"
$SSH_PORT = "22"
$SSH_USER = "root"
$TARGET_DIR = "/opt/apps/memo-app"
$APP_NAME = "account-app"
$APP_VERSION = "1.0.0"
$LOCAL_JAR_PATH = "target\dogFooding.jar"
$LOCAL_DOCKERFILE_PATH = "Dockerfile"
$DOCKER_IMAGE_NAME = "${APP_NAME}:${APP_VERSION}"
$CONTAINER_NAME = $APP_NAME
$HOST_PORT = "10011"
$CONTAINER_PORT = "10011"
$JVM_OPTS = "-Xms256m -Xmx512m"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SpringBoot 应用 Docker 部署脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. 本地文件检查
Write-Host "`n[1/8] 检查本地文件..." -ForegroundColor Yellow
if (-not (Test-Path $LOCAL_JAR_PATH)) {
    Write-Host "错误: Jar包不存在！路径: $LOCAL_JAR_PATH" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $LOCAL_DOCKERFILE_PATH)) {
    Write-Host "错误: Dockerfile不存在！路径: $LOCAL_DOCKERFILE_PATH" -ForegroundColor Red
    exit 1
}
Write-Host "本地文件检查完成" -ForegroundColor Green

# 2. 服务器连接测试
Write-Host "`n[2/8] 测试服务器连接..." -ForegroundColor Yellow
try {
    $testResult = & ssh -p $SSH_PORT ${SSH_USER}@${SERVER_IP} "echo '连接成功'"
    if ($testResult -eq "连接成功") {
        Write-Host "服务器连接成功" -ForegroundColor Green
    } else {
        throw "连接失败"
    }
} catch {
    Write-Host "错误: 无法连接到服务器！请检查SSH密钥配置和网络连接" -ForegroundColor Red
    exit 1
}

# 3. 服务器环境检测
Write-Host "`n[3/8] 检测服务器环境..." -ForegroundColor Yellow
$dockerVersion = & ssh -p $SSH_PORT ${SSH_USER}@${SERVER_IP} "docker --version 2>/dev/null"
if (-not $dockerVersion) {
    Write-Host "警告: Docker未安装！请先在服务器上安装Docker" -ForegroundColor Red
    exit 1
}
Write-Host "Docker版本: $dockerVersion" -ForegroundColor Green

# 4. 检查服务器上是否已有Dockerfile
Write-Host "`n[4/8] 检查服务器现有配置..." -ForegroundColor Yellow
$remoteDockerfileExists = & ssh -p $SSH_PORT ${SSH_USER}@${SERVER_IP} "if [ -f $TARGET_DIR/Dockerfile ]; then echo 'YES'; else echo 'NO'; fi"
if ($remoteDockerfileExists -eq "YES") {
    Write-Host "服务器上已存在Dockerfile，将被覆盖" -ForegroundColor Yellow
} else {
    Write-Host "服务器上无Dockerfile" -ForegroundColor Green
}

# 5. 创建目标目录并上传文件
Write-Host "`n[5/8] 上传文件到服务器..." -ForegroundColor Yellow
& ssh -p $SSH_PORT ${SSH_USER}@${SERVER_IP} "mkdir -p $TARGET_DIR"
if ($LASTEXITCODE -ne 0) {
    Write-Host "错误: 创建目标目录失败！" -ForegroundColor Red
    exit 1
}

# 上传jar包
Write-Host "上传Jar包..."
& scp -P $SSH_PORT $LOCAL_JAR_PATH ${SSH_USER}@${SERVER_IP}:${TARGET_DIR}/
if ($LASTEXITCODE -ne 0) {
    Write-Host "错误: 上传jar包失败！" -ForegroundColor Red
    exit 1
}
Write-Host "Jar包上传成功" -ForegroundColor Green

# 上传Dockerfile
Write-Host "上传Dockerfile..."
& scp -P $SSH_PORT $LOCAL_DOCKERFILE_PATH ${SSH_USER}@${SERVER_IP}:${TARGET_DIR}/
if ($LASTEXITCODE -ne 0) {
    Write-Host "错误: 上传Dockerfile失败！" -ForegroundColor Red
    exit 1
}
Write-Host "Dockerfile上传成功" -ForegroundColor Green

# 6. 远程执行Docker构建和部署
Write-Host "`n[6/8] 远程部署应用..." -ForegroundColor Yellow

$deployScript = @"
cd $TARGET_DIR

# 停止并删除旧容器
if docker ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME\\$"; then
    echo "停止并删除旧容器: $CONTAINER_NAME"
    docker stop $CONTAINER_NAME
    docker rm $CONTAINER_NAME
fi

# 删除旧镜像
if docker images --format '{{.Repository}}:{{.Tag}}' | grep -w "^$DOCKER_IMAGE_NAME\\$"; then
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
"@

& ssh -p $SSH_PORT ${SSH_USER}@${SERVER_IP} $deployScript
if ($LASTEXITCODE -ne 0) {
    Write-Host "错误: 部署失败！" -ForegroundColor Red
    exit 1
}

# 7. 验证服务
Write-Host "`n[7/8] 验证服务状态..." -ForegroundColor Yellow
$maxAttempts = 10
$attempt = 0
$serviceOk = $false

while ($attempt -lt $maxAttempts) {
    try {
        $response = Invoke-WebRequest -Uri "http://${SERVER_IP}:${HOST_PORT}" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $serviceOk = $true
            break
        }
    } catch {
        # 请求失败，继续等待
    }
    $attempt++
    Write-Host "等待服务就绪... ($attempt/$maxAttempts)"
    Start-Sleep 5
}

if ($serviceOk) {
    Write-Host "服务验证成功！" -ForegroundColor Green
} else {
    Write-Host "警告: 服务可能未完全就绪，请稍后手动验证" -ForegroundColor Yellow
}

# 8. 显示访问信息
Write-Host "`n[8/8] 部署完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "应用名称: $APP_NAME" -ForegroundColor Green
Write-Host "版本: $APP_VERSION" -ForegroundColor Green
Write-Host "访问地址: http://${SERVER_IP}:${HOST_PORT}" -ForegroundColor Cyan
Write-Host "容器名称: $CONTAINER_NAME" -ForegroundColor Green
Write-Host "镜像名称: $DOCKER_IMAGE_NAME" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# 显示远程日志命令提示
Write-Host "`n查看容器日志命令:" -ForegroundColor Yellow
Write-Host "ssh -p $SSH_PORT ${SSH_USER}@${SERVER_IP} 'docker logs -f $CONTAINER_NAME'" -ForegroundColor Gray