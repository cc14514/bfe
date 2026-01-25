# BFE Kubernetes 部署

快速部署 BFE 到 Kubernetes 集群。镜像构建参考 [../docker/README.md](../docker/README.md)。

## 快速开始

### 1. 修改镜像地址

编辑 [deployment.yaml](deployment.yaml) 第 22 行：

```yaml
image: ghcr.io/your-org/bfe:v1.8.0  # 替换为实际镜像地址
```

### 2. 创建 ConfigMap

```bash
cd deploy/kubernetes

kubectl create namespace bfe-system
kubectl create configmap bfe-config --from-file=conf-example/bfe.conf -n bfe-system
kubectl create configmap conf-agent-config --from-file=conf-example/conf-agent.toml -n bfe-system
```

### 3. 部署

```bash
kubectl apply -k .
```

### 4. 验证

```bash
# 查看 Pod 状态
kubectl -n bfe-system get pods

# 测试服务
kubectl -n bfe-system port-forward svc/bfe 8421:8421
curl http://localhost:8421/monitor
```

## 配置说明

ConfigMap 配置文件位于 [conf-example/](conf-example/) 目录：

- **bfe.conf** - BFE 主配置文件
- **conf-agent.toml** - conf-agent 配置文件

生产环境使用前请根据实际需求修改配置。

## 部署资源

| 资源 | 名称 | 说明 |
|------|------|------|
| Namespace | `bfe-system` | BFE 专用命名空间 |
| Deployment | `bfe` | BFE 应用（2副本） |
| Service | `bfe` | ClusterIP 服务（8080/8421） |
| ConfigMap | `bfe-config` | BFE 配置 |
| ConfigMap | `conf-agent-config` | conf-agent 配置 |

## 资源调整

修改 [deployment.yaml](deployment.yaml) 调整副本数和资源限制：

```yaml
spec:
  replicas: 2  # 副本数
  template:
    spec:
      containers:
      - name: bfe
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 1000m
            memory: 512Mi
```

## 清理

```bash
kubectl delete -k .
```
