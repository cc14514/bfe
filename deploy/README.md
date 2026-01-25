# BFE 部署指南

本目录包含 BFE 在不同环境下的部署配置和文档。

## 目录结构

```
deploy/
├── docker/          # Docker 镜像构建
│   ├── README.md                 # 镜像构建指南
│   ├── CONF_AGENT_VERSION        # conf-agent 版本号
│   ├── Dockerfile                # BFE 应用镜像
│   ├── Dockerfile.base-debug     # 调试版基础镜像
│   ├── Dockerfile.base-prod      # 生产版基础镜像
│   └── entrypoint.sh             # 容器启动脚本
└── kubernetes/      # Kubernetes 部署
    ├── README.md                 # K8s 部署指南
    ├── conf-example/             # 配置示例目录
    │   ├── bfe.conf              # BFE 配置示例
    │   └── conf-agent.toml       # conf-agent 配置示例
    ├── namespace.yaml            # 命名空间
    ├── deployment.yaml           # Deployment 配置
    ├── service.yaml              # Service 配置
    └── kustomization.yaml        # Kustomize 配置
```

## 快速开始

### 1. 构建 Docker 镜像

```bash
# 在项目根目录执行
cd /path/to/bfe

# 构建生产版镜像（推荐）
make k8s-all VARIANT=prod

# 或构建调试版镜像（包含 bash/vim 等工具）
make k8s-all VARIANT=debug
```

详细说明：[docker/README.md](docker/README.md)

### 2. 部署到 Kubernetes

```bash
cd deploy/kubernetes

# 修改 deployment.yaml 中的镜像地址
# 创建 ConfigMap 和部署
kubectl create namespace bfe-system
kubectl create configmap bfe-config --from-file=conf-example/bfe.conf -n bfe-system
kubectl create configmap conf-agent-config --from-file=conf-example/conf-agent.toml -n bfe-system
kubectl apply -k .
```

详细说明：[kubernetes/README.md](kubernetes/README.md)

## 文档

| 文档 | 说明 |
|------|------|
| [docker/README.md](docker/README.md) | Docker 镜像构建指南 |
| [kubernetes/README.md](kubernetes/README.md) | Kubernetes 部署指南 |

## 镜像说明

BFE 镜像分为两层：

### 基础镜像（bfe-base）
- **用途**：预装 conf-agent 的 Alpine Linux 基础镜像
- **版本**：根据 conf-agent 版本标记（如 `v0.0.2`）
- **变体**：
  - `bfe-base:v0.0.2-debug` - 调试版，包含 bash/vim/curl 等工具（~35MB）
  - `bfe-base:v0.0.2` - 生产版，最小镜像，仅包含必要组件（~10MB）

### 应用镜像（bfe）
- **用途**：基于基础镜像，添加 BFE 二进制和配置
- **版本**：根据 BFE 版本标记（从 `VERSION` 文件读取）
- **包含**：BFE 二进制、默认配置、启动脚本

## 常用命令

```bash
# 【镜像构建】
# 构建生产版（所有镜像）
make k8s-all VARIANT=prod

# 仅构建基础镜像
make k8s-base-prod

# 仅构建应用镜像
make k8s-image VARIANT=prod

# 【多架构构建】
# 初始化多架构构建器
make k8s-init-buildx

# 构建并推送多架构镜像
make k8s-push REGISTRY=ghcr.io/your-org

# 【K8s 部署】
# 部署到集群
kubectl apply -k kubernetes/

# 查看状态
kubectl -n bfe-system get pods

# 查看日志
kubectl -n bfe-system logs -l app=bfe --tail=100

# 端口转发测试
kubectl -n bfe-system port-forward svc/bfe 8421:8421
```

## conf-agent 集成

BFE 镜像内置了 [conf-agent](https://github.com/bfenetworks/conf-agent)，用于从控制面自动同步配置。

- **BFE 配置**：通过 ConfigMap 挂载 `bfe.conf` 等配置文件到 `/home/work/bfe/conf/`（**必需**）
  - 参考示例：[kubernetes/conf-example/bfe.conf](kubernetes/conf-example/bfe.conf)
- **conf-agent 配置**：通过 ConfigMap 挂载 `conf-agent.toml` 到 `/home/work/conf-agent/conf/`（**必需**）
  - 参考示例：[kubernetes/conf-example/conf-agent.toml](kubernetes/conf-example/conf-agent.toml)
- **工作目录**：`/home/work/conf-agent/`

详细说明：[docker/CONF_AGENT_STARTUP.md](docker/CONF_AGENT_STARTUP.md)

## 版本管理

- **BFE 版本**：从 [VERSION](../VERSION) 文件读取（如 `1.8.0`）
- **conf-agent 版本**：从 [docker/CONF_AGENT_VERSION](docker/CONF_AGENT_VERSION) 文件读取（如 `v0.0.2`）
  - 版本号必须来自 [conf-agent 官方 releases](https://github.com/bfenetworks/conf-agent/releases/)
  - 只能使用已发布的版本号
- **版本号统一**：构建时自动添加 `v` 前缀（`1.8.0` → `v1.8.0`）
- **基础镜像标签**：使用 conf-agent 版本号（如 `bfe-base:v0.0.2`）
- **应用镜像标签**：每次构建同时打三个标签
  - `bfe:v1.8.0`（主标签，推荐使用）
  - `bfe:v1.8.0-arm64`（带架构后缀，用于明确区分）
  - `bfe:latest`（最新版本）


## 镜像变体

| 变体 | 大小 | 包含工具 | 用途 |
|------|------|---------|------|
| `prod` | ~10MB | 仅必要组件 | 生产部署 |
| `debug` | ~35MB | bash/vim/curl/wget | 开发调试 |

## 相关链接

- [BFE 官方文档](../../docs/)
- [BFE GitHub](https://github.com/bfenetworks/bfe)
- [conf-agent GitHub](https://github.com/bfenetworks/conf-agent)
- [Makefile 说明](../../Makefile)

## 贡献

欢迎提交 Issue 和 Pull Request 改进部署配置和文档！
