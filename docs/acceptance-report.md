# Infra 验收回传（2026-03-05）

## 1) 启动与验收日志

### make -C infra up
```text
docker compose -f docker-compose.yml up -d
[+] Running 7/7
 ✔ Container ddg-redis              Healthy
 ✔ Container ddg-postgres           Healthy
 ✔ Container ddg-alertmanager       Started
 ✔ Container ddg-redis-exporter     Running
 ✔ Container ddg-postgres-exporter  Running
 ✔ Container ddg-prometheus         Running
 ✔ Container ddg-grafana            Running
```

### make -C infra check
```text
bash scripts/infra_smoke_check.sh
[1/4] Checking container states
[2/4] Checking service health
[OK] service 'postgres' status=healthy
[OK] service 'redis' status=healthy
[OK] service 'prometheus' status=running
[OK] service 'alertmanager' status=running
[OK] service 'grafana' status=running
[3/4] Checking HTTP endpoints
[OK] prometheus/alertmanager/grafana ready
[4/4] Checking exporter targets
[OK] exporter targets discovered
[DONE] Infra smoke check passed
```

### make -C infra ps
```text
docker compose -f docker-compose.yml ps
NAME                    STATUS                    PORTS
ddg-postgres            Up (healthy)              0.0.0.0:5432->5432/tcp
ddg-redis               Up (healthy)              0.0.0.0:6379->6379/tcp
ddg-prometheus          Up                        0.0.0.0:9090->9090/tcp
ddg-alertmanager        Up                        0.0.0.0:9093->9093/tcp
ddg-grafana             Up                        0.0.0.0:3000->3000/tcp
ddg-postgres-exporter   Up                        0.0.0.0:9187->9187/tcp
ddg-redis-exporter      Up                        0.0.0.0:9121->9121/tcp
```

## 2) 可观测验证

### Prometheus targets
```bash
curl -fsS http://127.0.0.1:9090/api/v1/targets | jq '{status: .status, activeTargets: [.data.activeTargets[] | {job: .labels.job, health: .health}]}'
```

```json
{
  "status": "success",
  "activeTargets": [
    {"job": "postgres_exporter", "health": "up"},
    {"job": "prometheus", "health": "up"},
    {"job": "redis_exporter", "health": "up"}
  ]
}
```

### Alertmanager receivers
```bash
curl -fsS http://127.0.0.1:9093/api/v2/receivers | jq .
```

```json
[
  {"name": "ops-webhook"}
]
```

## 2.1) 开发/测试连接能力验证

### PostgreSQL
```bash
docker compose -f infra/docker-compose.yml exec -T postgres psql -U ddg -d ddg -c 'select 1 as pg_ok;'
```

```text
 pg_ok
-------
     1
```

### Redis
```bash
docker compose -f infra/docker-compose.yml exec -T redis redis-cli ping
```

```text
PONG
```

## 3) 告警通道验证

本次基线验证使用本机桥接进程 `infra/scripts/dingding_alert_bridge.py`（默认 `DINGTALK_MODE=noop`）接收 Alertmanager webhook。桥接支持 `webhook` 与 `stream` 两种真实发送模式。

### 触发命令
```bash
bash infra/scripts/trigger_test_alert.sh
```

### 接收端日志（已收到）
```text
[INFO] dingding bridge listening on 0.0.0.0:18080, mode=noop
[INFO] mode=noop payload_status=firing receiver=ops-webhook
[INFO] noop mode, skip delivery
```

## 4) 密钥管理说明（macOS Keychain）

### 选型
- `macOS Keychain + security CLI`

### 初始化
```bash
make -C infra keychain-init
```

### 注入并启动
```bash
make -C infra up-secure
make -C infra check-secure
```

### 轮换
```bash
bash infra/scripts/secrets_keychain.sh set postgres_password '<new_password>'
bash infra/scripts/secrets_keychain.sh set grafana_admin_password '<new_password>'
bash infra/scripts/secrets_keychain.sh set dingtalk_mode 'stream'
bash infra/scripts/secrets_keychain.sh set dingtalk_app_key '<app_key>'
bash infra/scripts/secrets_keychain.sh set dingtalk_app_secret '<app_secret>'
bash infra/scripts/secrets_keychain.sh set dingtalk_robot_code '<robot_code>'
bash infra/scripts/secrets_keychain.sh set dingtalk_open_conversation_id '<open_conversation_id>'
make -C infra restart
```

## 5) 备份恢复报告

### 备份文件
- `infra/backups/ddg_20260305_122415.sql.gz`

### 演练过程
1. 在源库写入演练表与测试数据 `infra_restore_drill`
2. 执行 `make -C infra backup`
3. 执行 `TARGET_DB=ddg_restore make -C infra restore BACKUP_FILE="backups/ddg_20260305_122415.sql.gz"`
4. 查询恢复库验证数据

### 恢复校验结果
```text
rows_in_restore_table
-----------------------
1
```

## 6) 待真实网关最终确认项

若要满足“真实告警通道可达并可收到测试告警”，请在 Keychain 中设置真实钉钉凭据后，执行：

```bash
make -C infra keychain-init
make -C infra up-dingding-stream
bash infra/scripts/trigger_test_alert.sh
make -C infra bridge-status
```

并补充接收端截图（Prometheus targets / Alertmanager receivers / 告警接收端）。

## 7) CI 计算额度申请参数

- 并发：`2`
- 每个 Job 资源：`2 vCPU / 4GB RAM`
- 单 Job 超时：`30m`
- 失败日志：开启并保留
- 工件保留：开启并保留
