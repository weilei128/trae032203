# SpringBoot Docker 自动化部署总结

## 部署信息

| 项目 | 内容 |
|------|------|
| 应用名称 | account-app |
| 版本 | 1.0.0 |
| 服务器 IP | 49.235.161.106 |
| 服务端口 | 10013 |
| 目标目录 | /opt/apps/memo-app |
| JVM 参数 | -Xms256m -Xmx512m |

## 访问地址

- **主页面**: http://49.235.161.106:10013/
- **状态**: ✅ 已正常运行

## 部署文件清单

### 本地文件
| 文件 | 说明 |
|------|------|
| `target/kimi.jar` | SpringBoot 可执行 jar 包 |
| `Dockerfile` | Docker 镜像构建文件 |
| `deploy.ps1` | Windows PowerShell 一键部署脚本 |
| `deploy_remote.sh` | 服务器端部署脚本 |
| `DEPLOY_SUMMARY.md` | 本部署总结文档 |

### 服务器文件 (位于 /opt/apps/memo-app/)
| 文件 | 说明 |
|------|------|
| `kimi.jar` | 应用程序 jar 包 |
| `Dockerfile` | Docker 构建文件 |
| `Dockerfile.kimi` | Kimi 应用专用 Dockerfile 备份 |
| `deploy_remote.sh` | 部署脚本 |
| `data/` | 数据持久化目录 |

## 部署流程

```
┌─────────────────┐
│ 1. Maven 打包    │  → 生成 target/personal-account-book-1.0.0.jar
└────────┬────────┘
         ↓
┌─────────────────┐
│ 2. 重命名 jar   │  → 复制为 target/kimi.jar
└────────┬────────┘
         ↓
┌─────────────────┐
│ 3. 上传文件     │  → scp 上传 jar 和 Dockerfile 到服务器
└────────┬────────┘
         ↓
┌─────────────────┐
│ 4. 环境检查     │  → 检查 Docker、端口占用情况
└────────┬────────┘
         ↓
┌─────────────────┐
│ 5. 清理旧资源   │  → 停止旧容器、删除旧镜像
└────────┬────────┘
         ↓
┌─────────────────┐
│ 6. 构建镜像     │  → docker build -t account-app:latest
└────────┬────────┘
         ↓
┌─────────────────┐
│ 7. 运行容器     │  → docker run -d -p 10013:10013
└────────┬────────┘
         ↓
┌─────────────────┐
│ 8. 验证服务     │  → HTTP 200 响应确认
└─────────────────┘
```

## Docker 配置

### Dockerfile 内容
```dockerfile
FROM openjdk:8-jdk-alpine
WORKDIR /app
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
COPY kimi.jar app.jar
RUN mkdir -p /app/data
EXPOSE 10013
ENV JAVA_OPTS="-Xms256m -Xmx512m"
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -Djava.security.egd=file:/dev/./urandom -jar app.jar --server.port=10013"]
```

### 容器配置
- **镜像**: account-app:latest
- **容器名**: account-app
- **端口映射**: 10013:10013
- **数据卷**: /opt/apps/memo-app/data:/app/data
- **重启策略**: unless-stopped
- **时区**: Asia/Shanghai

## 常用运维命令

### 查看容器状态
```bash
ssh root@49.235.161.106 "docker ps | grep account-app"
```

### 查看日志
```bash
# 实时日志
ssh root@49.235.161.106 "docker logs -f account-app"

# 最近 100 行
ssh root@49.235.161.106 "docker logs --tail 100 account-app"
```

### 重启服务
```bash
ssh root@49.235.161.106 "docker restart account-app"
```

### 停止服务
```bash
ssh root@49.235.161.106 "docker stop account-app"
```

### 进入容器
```bash
ssh root@49.235.161.106 "docker exec -it account-app sh"
```

## 自动化部署脚本使用

### Windows (PowerShell)
```powershell
# 在项目根目录执行
.\deploy.ps1
```

### 手动分步部署
```powershell
# 1. 打包
mvn clean package -DskipTests

# 2. 复制 jar
copy target\personal-account-book-1.0.0.jar target\kimi.jar

# 3. 上传文件
scp -P 22 target\kimi.jar root@49.235.161.106:/opt/apps/memo-app/
scp -P 22 Dockerfile root@49.235.161.106:/opt/apps/memo-app/Dockerfile.kimi

# 4. 执行远程部署
ssh -p 22 root@49.235.161.106 "cd /opt/apps/memo-app && bash deploy_remote.sh"
```

## 部署特性

- ✅ **端口自动检测**: 部署前自动检查端口占用，如有占用则停止旧容器
- ✅ **镜像自动清理**: 自动删除旧镜像，避免磁盘空间浪费
- ✅ **数据持久化**: 数据目录挂载到宿主机，容器重启数据不丢失
- ✅ **自动重启**: 配置 unless-stopped 策略，服务器重启后自动启动
- ✅ **时区配置**: 使用上海时区，日志时间正确
- ✅ **健康检查**: 部署后自动验证 HTTP 服务可用性

## 注意事项

1. **数据备份**: 数据存储在 `/opt/apps/memo-app/data/` 目录，建议定期备份
2. **端口冲突**: 确保 10013 端口未被其他服务占用
3. **防火墙**: 确保服务器防火墙开放 10013 端口
4. **资源限制**: JVM 内存限制为 256m-512m，可根据实际情况调整

## 部署时间

- 部署完成时间: 2026-03-22 15:23:20
- 总耗时: 约 2 分钟
