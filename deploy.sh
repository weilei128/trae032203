#!/bin/bash
# SpringBoot Docker Deployment Script
# Application: account-app v1.0.0
# Server: 49.235.161.106
# Port: 10012
# JVM: -Xms256m -Xmx512m

set -e

SERVER_IP="49.235.161.106"
SERVER_USER="root"
SERVER_DIR="/opt/apps/memo-app"
APP_NAME="account-app"
APP_VERSION="1.0.0"
APP_PORT="10012"
JAR_NAME="GLM.jar"

echo "=========================================="
echo "  SpringBoot Docker Deployment Script"
echo "=========================================="

echo "[Step 1] Maven Build..."
mvn clean package -DskipTests
cp target/personal-account-book-1.0.0.jar target/GLM.jar

echo "[Step 2] Check Server Environment..."
ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${SERVER_IP} "docker --version"

echo "[Step 3] Upload Files to Server..."
scp -o StrictHostKeyChecking=no target/${JAR_NAME} ${SERVER_USER}@${SERVER_IP}:${SERVER_DIR}/${JAR_NAME}
scp -o StrictHostKeyChecking=no Dockerfile ${SERVER_USER}@${SERVER_IP}:${SERVER_DIR}/Dockerfile

echo "[Step 4] Stop Old Container if Port is Occupied..."
EXISTING_CONTAINER=$(ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${SERVER_IP} "docker ps --format '{{.Names}}' | grep -E 'account|10012' || true")
if [ -n "$EXISTING_CONTAINER" ]; then
    echo "Stopping existing container: $EXISTING_CONTAINER"
    ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${SERVER_IP} "docker stop ${EXISTING_CONTAINER} && docker rm ${EXISTING_CONTAINER}"
fi

echo "[Step 5] Remove Old Image..."
ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${SERVER_IP} "docker rmi ${APP_NAME}:${APP_VERSION} 2>/dev/null || echo 'No old image'"

echo "[Step 6] Build Docker Image..."
ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${SERVER_IP} "cd ${SERVER_DIR} && docker build --no-cache -t ${APP_NAME}:${APP_VERSION} ."

echo "[Step 7] Run Container..."
ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${SERVER_IP} "docker run -d \
    --name ${APP_NAME} \
    -p ${APP_PORT}:${APP_PORT} \
    -v ${SERVER_DIR}/data:/app/data \
    --restart=unless-stopped \
    ${APP_NAME}:${APP_VERSION}"

echo "[Step 8] Verify Service..."
sleep 5
ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${SERVER_IP} "docker ps --filter 'name=${APP_NAME}'"
ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${SERVER_IP} "curl -s -o /dev/null -w 'HTTP Status: %{http_code}\n' http://localhost:${APP_PORT}/"

echo "=========================================="
echo "  Deployment Completed!"
echo "=========================================="
echo "Access URL: http://${SERVER_IP}:${APP_PORT}/"
echo "Container Name: ${APP_NAME}"
echo "Image: ${APP_NAME}:${APP_VERSION}"
