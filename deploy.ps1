# SpringBoot Docker Deployment Script (PowerShell)
# Application: account-app v1.0.0
# Server: 49.235.161.106
# Port: 10012
# JVM: -Xms256m -Xmx512m

$ErrorActionPreference = "Stop"

$SERVER_IP = "49.235.161.106"
$SERVER_USER = "root"
$SERVER_DIR = "/opt/apps/memo-app"
$APP_NAME = "account-app"
$APP_VERSION = "1.0.0"
$APP_PORT = "10012"
$JAR_NAME = "GLM.jar"

Write-Host "=========================================="
Write-Host "  SpringBoot Docker Deployment Script"
Write-Host "=========================================="

Write-Host "[Step 1] Maven Build..."
mvn clean package -DskipTests
Copy-Item "target\personal-account-book-1.0.0.jar" "target\$JAR_NAME" -Force

Write-Host "[Step 2] Check Server Environment..."
ssh -o StrictHostKeyChecking=no "${SERVER_USER}@${SERVER_IP}" "docker --version"

Write-Host "[Step 3] Upload Files to Server..."
scp -o StrictHostKeyChecking=no "target\$JAR_NAME" "${SERVER_USER}@${SERVER_IP}:${SERVER_DIR}/${JAR_NAME}"
scp -o StrictHostKeyChecking=no "Dockerfile" "${SERVER_USER}@${SERVER_IP}:${SERVER_DIR}/Dockerfile"

Write-Host "[Step 4] Stop Old Container if Port is Occupied..."
$existingContainer = ssh -o StrictHostKeyChecking=no "${SERVER_USER}@${SERVER_IP}" "docker ps --format '{{.Names}}' | grep -E 'account|10012' || true"
if ($existingContainer) {
    Write-Host "Stopping existing container: $existingContainer"
    ssh -o StrictHostKeyChecking=no "${SERVER_USER}@${SERVER_IP}" "docker stop $existingContainer && docker rm $existingContainer"
}

Write-Host "[Step 5] Remove Old Image..."
ssh -o StrictHostKeyChecking=no "${SERVER_USER}@${SERVER_IP}" "docker rmi ${APP_NAME}:${APP_VERSION} 2>/dev/null || echo 'No old image'"

Write-Host "[Step 6] Build Docker Image..."
ssh -o StrictHostKeyChecking=no "${SERVER_USER}@${SERVER_IP}" "cd ${SERVER_DIR} && docker build --no-cache -t ${APP_NAME}:${APP_VERSION} ."

Write-Host "[Step 7] Run Container..."
ssh -o StrictHostKeyChecking=no "${SERVER_USER}@${SERVER_IP}" "docker run -d --name ${APP_NAME} -p ${APP_PORT}:${APP_PORT} -v ${SERVER_DIR}/data:/app/data --restart=unless-stopped ${APP_NAME}:${APP_VERSION}"

Write-Host "[Step 8] Verify Service..."
Start-Sleep -Seconds 5
ssh -o StrictHostKeyChecking=no "${SERVER_USER}@${SERVER_IP}" "docker ps --filter 'name=${APP_NAME}'"
ssh -o StrictHostKeyChecking=no "${SERVER_USER}@${SERVER_IP}" "curl -s -o /dev/null -w 'HTTP Status: %{http_code}\n' http://localhost:${APP_PORT}/"

Write-Host "=========================================="
Write-Host "  Deployment Completed!"
Write-Host "=========================================="
Write-Host "Access URL: http://${SERVER_IP}:${APP_PORT}/"
Write-Host "Container Name: ${APP_NAME}"
Write-Host "Image: ${APP_NAME}:${APP_VERSION}"
