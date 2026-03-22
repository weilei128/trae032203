# 简单部署脚本

# 配置
$SERVER = "root@49.235.161.106"
$PORT = "22"
$DIR = "/opt/apps/memo-app"

Write-Host "=== 开始部署 ===" -ForegroundColor Cyan

# 1. 检查本地文件
if (-not (Test-Path "target\dogFooding.jar")) {
    Write-Host "错误: Jar包不存在" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path "Dockerfile")) {
    Write-Host "错误: Dockerfile不存在" -ForegroundColor Red
    exit 1
}
Write-Host "本地文件检查完成" -ForegroundColor Green

# 2. 测试连接
Write-Host "测试服务器连接..."
& ssh -p $PORT $SERVER "echo OK"
if ($LASTEXITCODE -ne 0) {
    Write-Host "连接失败" -ForegroundColor Red
    exit 1
}
Write-Host "服务器连接成功" -ForegroundColor Green

# 3. 创建目录并上传文件
Write-Host "创建目录..."
& ssh -p $PORT $SERVER "mkdir -p $DIR"

Write-Host "上传Jar包..."
& scp -P $PORT "target\dogFooding.jar" "$($SERVER):$DIR/"

Write-Host "上传Dockerfile..."
& scp -P $PORT "Dockerfile" "$($SERVER):$DIR/"

Write-Host "上传data目录..."
& scp -r -P $PORT "data" "$($SERVER):$DIR/"

# 4. 远程部署
Write-Host "开始远程部署..."

$remoteScript = @"
cd $DIR
pwd

echo "停止旧容器"
docker stop account-app 2>/dev/null
docker rm account-app 2>/dev/null

echo "删除旧镜像"
docker rmi account-app:1.0.0 2>/dev/null

echo "检查端口"
OLD_CONTAINER=\$(docker ps -q --filter publish=10011)
if [ -n "\$OLD_CONTAINER" ]; then
    echo "关闭占用端口的容器: \$OLD_CONTAINER"
    docker stop \$OLD_CONTAINER
    docker rm \$OLD_CONTAINER
fi

echo "构建新镜像"
docker build -t account-app:1.0.0 .

echo "启动容器"
docker run -d --name account-app --restart=always -p 10011:10011 -e JVM_OPTS="-Xms256m -Xmx512m" -v $DIR/data:/app/data account-app:1.0.0

sleep 5

echo "容器状态:"
docker ps | grep account-app
"@

& ssh -p $PORT $SERVER $remoteScript

if ($LASTEXITCODE -eq 0) {
    Write-Host "部署完成" -ForegroundColor Green
    
    # 验证
    Write-Host "验证服务..."
    Start-Sleep 10
    
    try {
        $response = Invoke-WebRequest -Uri "http://49.235.161.106:10011" -TimeoutSec 10 -UseBasicParsing
        Write-Host "服务状态: $($response.StatusCode)"
        Write-Host "部署成功！" -ForegroundColor Green
        Write-Host "访问地址: http://49.235.161.106:10011" -ForegroundColor Cyan
    } catch {
        Write-Host "服务可能还在启动中，请稍后访问: http://49.235.161.106:10011" -ForegroundColor Yellow
    }
} else {
    Write-Host "部署失败" -ForegroundColor Red
    exit 1
}
