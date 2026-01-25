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
