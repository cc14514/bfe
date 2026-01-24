# BFE Kustomize 部署示例

本目录展示使用 Kustomize 管理 BFE 多环境部署配置的示例。

## 使用方式

```bash
# 使用此目录的 Kustomize 配置部署
kubectl apply -k .
```

## 说明

- 基于上级目录的基础配置
- 可通过 Kustomize patches 自定义不同环境的配置
- 监控端口：8421（`/monitor` 接口）
