# BFE Kubernetes 部署

快速部署 BFE 到 Kubernetes 集群。

## 快速开始

### 1. 修改镜像地址

编辑 [deployment.yaml](deployment.yaml) 第 22 行：

```yaml
image: ghcr.io/your-org/bfe:v1.8.0  # 替换为实际镜像地址
```

### 2. 创建 ConfigMap

ConfigMap 已直接提供为 YAML（见 `configmap-bfe.yaml` / `configmap-conf-agent.yaml`），因此不再需要手动 `kubectl create configmap ...`。

### 3. 部署

```bash
cd examples/kubernetes
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

ConfigMap YAML：
- [configmap-bfe.yaml](configmap-bfe.yaml)
- [configmap-conf-agent.yaml](configmap-conf-agent.yaml)

生产环境使用前请根据实际需求修改 ConfigMap 内容。

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
