# DDG Infra Project

这是从主项目中拆出的基础设施子项目，目标是让 Infra 可独立维护、独立交付。

## 包含内容
- Docker Compose 编排（PostgreSQL / Redis / Prometheus / Alertmanager / Grafana）
- 告警规则与路由模板
- 一键 smoke-check 脚本
- 委派给其他 agent 的 SOP

## 运行
```bash
cd infra
make up
make check
```

## 常用命令
- `make up`：启动基础设施
- `make check`：执行一键健康检查
- `make ps`：查看服务状态
- `make logs`：查看最近日志
- `make down`：停止基础设施
- `make restart`：重启全部服务

> 兼容入口仍保留在仓库根目录：`make infra-up` 等命令会自动转发到 `infra/Makefile`。

## 建议下一步
- 将 `infra/` 目录拆为独立仓库
- 在 CI 中增加专用 Infra Pipeline（lint + compose up + smoke-check）
- 接入企业告警网关（Slack/飞书/钉钉）
