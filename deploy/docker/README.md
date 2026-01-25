# BFE Docker 镜像构建

本目录包含构建 BFE Docker 镜像所需的 Dockerfile 和配置文件。

## 快速开始

### 构建镜像

```bash
# 在 BFE 项目根目录执行

# 方式一：构建所有镜像（推荐）
make k8s-all VARIANT=prod

# 方式二：分步构建
make k8s-base-prod    # 构建基础镜像
make k8s-image        # 构建应用镜像
```

### 验证镜像

```bash
docker images | grep bfe
# 输出示例：
# bfe          v1.8.0        ...   45MB
# bfe          latest        ...   45MB
# bfe-base     v0.0.2        ...   10MB
```

### 本地测试

```bash
docker run --rm -p 8080:8080 -p 8421:8421 bfe:v1.8.0

# 另开终端验证
curl http://localhost:8421/monitor
```

## 镜像说明

### 基础镜像（bfe-base）

预装 conf-agent 的 Alpine Linux 镜像，分为两个版本：

| 版本 | 镜像标签 | 大小 | 包含工具 | 用途 |
|------|---------|------|---------|------|
| 生产版 | `bfe-base:v0.0.2` | ~10MB | ca-certificates | 生产部署 |
| 调试版 | `bfe-base:v0.0.2-debug` | ~35MB | bash/vim/curl/wget | 开发调试 |

### 应用镜像（bfe）

基于基础镜像，添加 BFE 二进制和配置文件：
- 镜像标签：`bfe:v1.8.0`、`bfe:latest`
- 版本号：从 VERSION 文件读取后统一添加 `v` 前缀
- 大小：~45MB（生产版基础）/ ~70MB（调试版基础）

## 构建参数

### 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `VARIANT` | `debug` | 基础镜像变体：`debug` 或 `prod` |
| `CONF_AGENT_VERSION` | 从文件读取 | conf-agent 版本（`deploy/docker/CONF_AGENT_VERSION`） |
| `PLATFORMS` | 当前架构 | 目标平台，如 `linux/amd64,linux/arm64` |
| `OUTPUT_TYPE` | `docker` | 输出类型：`docker` 或 `oci` |
| `NO_CACHE` | `false` | 是否禁用构建缓存 |
| `REGISTRY` | 无默认值 | 推送的镜像仓库地址（`k8s-push` 必需） |

### 使用示例

```bash
# 生产环境构建
VARIANT=prod make k8s-all

# 多架构构建并导出
OUTPUT_TYPE=oci PLATFORMS=linux/amd64,linux/arm64 make k8s-all


# 禁用缓存强制重新构建
NO_CACHE=true make k8s-image
```

## 多架构镜像

### 构建与推送

构建 amd64 + arm64 双架构镜像并推送到远程仓库：

```bash
# 1. 初始化多架构构建器（仅需执行一次）
make k8s-init-buildx

# 2. 登录镜像仓库
echo $GITHUB_TOKEN | docker login ghcr.io -u your-username --password-stdin

# 3. 构建并推送多架构镜像
make k8s-push REGISTRY=ghcr.io/your-username

# 4. 验证多架构支持
docker buildx imagetools inspect ghcr.io/your-username/bfe:v1.8.0
```

**输出示例**：
```
Manifests:
  Platform:  linux/amd64  ← x86 架构
  Platform:  linux/arm64  ← ARM 架构
```

## Makefile 目标说明

| 目标 | 说明 |
|------|------|
| `k8s-base-prod` | 构建生产版基础镜像 |
| `k8s-base-debug` | 构建调试版基础镜像 |
| `k8s-base` | 构建两个基础镜像 |
| `k8s-image` | 构建 BFE 应用镜像 |
| `k8s-all` | 构建所有镜像（推荐） |
| `k8s-init-buildx` | 初始化多架构构建器 |
| `k8s-push` | 构建并推送多架构镜像到仓库 |

## 文件说明

| 文件 | 说明 |
|------|------|
| [Dockerfile.base-debug](Dockerfile.base-debug) | 调试版基础镜像（包含调试工具） |
| [Dockerfile.base-prod](Dockerfile.base-prod) | 生产版基础镜像（最小化） |
| [Dockerfile](Dockerfile) | BFE 应用镜像（多阶段构建） |
| [entrypoint.sh](entrypoint.sh) | 容器启动脚本（启动 conf-agent 和 bfe） |
| [CONF_AGENT_VERSION](CONF_AGENT_VERSION) | conf-agent 版本号 |

## 部署到 Kubernetes

构建完成后，参考 [../kubernetes/README.md](../kubernetes/README.md) 进行部署。


## 版本管理

- **BFE 版本**：从 [../../VERSION](../../VERSION) 文件读取（如 `1.8.0`）
- **conf-agent 版本**：从 [CONF_AGENT_VERSION](CONF_AGENT_VERSION) 文件读取（如 `v0.0.2`）
  - 版本号必须来自 [conf-agent 官方 releases](https://github.com/bfenetworks/conf-agent/releases/)
  - 只能使用已发布的版本号
- **版本号统一**：构建时自动添加 `v` 前缀（`1.8.0` → `v1.8.0`）
- **基础镜像标签**：`bfe-base:v0.0.2`（生产版）、`bfe-base:v0.0.2-debug`（调试版）
- **应用镜像标签**：`bfe:v1.8.0`、`bfe:latest`

升级 conf-agent 只需修改 `CONF_AGENT_VERSION` 文件为官方 release 版本号，然后重新构建基础镜像。
