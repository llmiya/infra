# Infra 独立项目 SOP

## 目标
- 稳定 CI 容器执行额度
- 提供 Redis + PostgreSQL 可用性
- 提供可观测与告警通道

## 快速启动
```bash
docker compose -f infra/docker-compose.yml up -d
bash infra/scripts/infra_smoke_check.sh
```

## 服务端口
- PostgreSQL: 5432
- Redis: 6379
- Prometheus: 9090
- Alertmanager: 9093
- Grafana: 3000

## 告警通道
默认 webhook：
`http://host.docker.internal:18080/alerts`

如需改为你们自己的告警网关，请修改：
`infra/alertmanager/alertmanager.yml`

## 委派执行模板
1. 启动 `infra/docker-compose.yml`
2. 执行 `infra/scripts/infra_smoke_check.sh`
3. 提交 `docker compose ps`、Prometheus targets、Alertmanager receivers 截图
4. 若失败，提交 `docker compose -f infra/docker-compose.yml logs --tail=200`
