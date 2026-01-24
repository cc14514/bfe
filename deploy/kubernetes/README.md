# BFE Kubernetes 部署

本目录包含 BFE 在 Kubernetes 集群中的部署配置文件。

> **前置要求**：需要先构建 BFE Docker 镜像，参考 [../docker/README.md](../docker/README.md)

## 快速开始

### 1. 构建镜像

```bash
# 在项目根目录执行
make k8s-all VARIANT=prod
```

### 2. 本地集群加载镜像

```bash
# minikube
minikube image load bfe:1.8.0

# kind
kind load docker-image bfe:1.8.0
```

或推送到镜像仓库：

```bash
docker tag bfe:1.8.0 ghcr.io/your-org/bfe:1.8.0
docker push ghcr.io/your-org/bfe:1.8.0
```

### 3. 修改镜像地址

编辑 [deployment.yaml](deployment.yaml)：

```yaml
containers:
- name: bfe
  image: bfe:1.8.0  # 或 ghcr.io/your-org/bfe:1.8.0
```

### 4. 部署

```bash
kubectl apply -k .
```

### 5. 验证

```bash
# 查看 Pod
kubectl -n bfe-system get pods

# 查看日志
kubectl -n bfe-system logs -l app=bfe --tail=20

# 端口转发测试
kubectl -n bfe-system port-forward svc/bfe 8421:8421
curl http://localhost:8421/monitor
```

## 配置挂载

### BFE 配置（必需）

创建 ConfigMap 并挂载到 `/home/work/bfe/conf/`：

```bash
# 从项目配置目录创建
kubectl create configmap bfe-config \
  --from-file=conf/bfe.conf \
  -n bfe-system
```

在 [deployment.yaml](deployment.yaml) 中添加：

```yaml
volumeMounts:
- name: bfe-config
  mountPath: /home/work/bfe/conf
  readOnly: true
volumes:
- name: bfe-config
  configMap:
    name: bfe-config
```

### conf-agent 配置（可选）

创建 conf-agent ConfigMap：

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: conf-agent-config
  namespace: bfe-system
data:
  conf-agent.toml: |
    [server]
    addr = "http://bfe-api-server:8080"
    interval = 10
    [local]
    config_path = "/home/work/bfe/conf"
    [log]
    level = "info"
EOF
```

在 [deployment.yaml](deployment.yaml) 中添加：

```yaml
volumeMounts:
- name: conf-agent-config
  mountPath: /home/work/conf-agent/conf
  readOnly: true
volumes:
- name: conf-agent-config
  configMap:
    name: conf-agent-config
```

## 部署资源

### 基础资源

使用 `kubectl apply -k .` 会创建：

| 资源 | 名称 | 说明 |
|------|------|------|
| Namespace | `bfe-system` | BFE 专用命名空间 |
| Deployment | `bfe` | BFE 应用部署（包含 conf-agent） |
| Service | `bfe` | ClusterIP 服务（8080/8421端口） |

### 资源配置调整

修改 [deployment.yaml](deployment.yaml)：

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
            memory: 1Gi
```

## 高级配置

### 持久化日志

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: bfe-logs
  namespace: bfe-system
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
---
# 在 deployment.yaml 中添加
volumeMounts:
- name: bfe-logs
  mountPath: /home/work/bfe/log
volumes:
- name: bfe-logs
  persistentVolumeClaim:
    claimName: bfe-logs
```

### Ingress 暴露

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bfe
  namespace: bfe-system
spec:
  ingressClassName: nginx
  rules:
  - host: bfe.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: bfe
            port:
              number: 8080
```

## 文件说明

| 文件 | 说明 |
|------|------|
| [namespace.yaml](namespace.yaml) | 命名空间定义 |
| [deployment.yaml](deployment.yaml) | BFE 部署配置 |
| [service.yaml](service.yaml) | Service 配置 |
| [kustomization.yaml](kustomization.yaml) | Kustomize 配置 |
| [conf-agent.toml.example](conf-agent.toml.example) | conf-agent 配置示例 |
| [bfe/](bfe/) | Kustomize 多环境示例 |

## 清理部署

```bash
kubectl delete -k .
```
