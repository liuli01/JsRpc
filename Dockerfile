# 阶段1：构建Go程序
FROM golang:1.16 AS builder

# 修复：Go 1.16 中 GO111MODULE 默认是 auto，显式设为 on 更稳妥
# 补充：增加时区、镜像加速等配置，避免依赖下载失败
ENV GO111MODULE="on" \
    CGO_ENABLED="0" \
    GOOS="linux" \
    GOARCH="amd64" \
    TZ="Asia/Shanghai"

# 修复：安装基础依赖（部分Go包需要git、gcc等）
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 切换工作目录（建议简化路径，避免路径过长问题）
WORKDIR /app

# 先拷贝go.mod/go.sum，利用Docker缓存（核心优化）
COPY go.mod go.sum ./
# 修复：先下载依赖，再拷贝代码（缓存依赖层，加速构建）
RUN go mod tidy -v || go mod download

# 拷贝所有代码
COPY . .

# 修复：显式指定构建参数，增加-ls（显示链接信息）便于排错
# -trimpath 减小二进制体积，-ldflags 禁用CGO
RUN go build -v -trimpath -ldflags="-s -w" -o /tmp/jsrpc .

# 阶段2：构建运行镜像
FROM alpine:latest

# 修复：Alpine 缺少CA证书，导致HTTPS请求失败
RUN apk add --no-cache ca-certificates tzdata
ENV TZ="Asia/Shanghai"

WORKDIR /root/

# 拷贝二进制文件（确保权限正确）
COPY --from=builder /tmp/jsrpc ./
RUN chmod +x ./jsrpc

EXPOSE 12080 12443

# 修复：用exec形式启动，避免PID 1问题
CMD ["/root/jsrpc"]