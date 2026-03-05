# Infra 独立项目 SOP

## 目标
- 稳定 CI 容器执行额度
- 提供 Redis + PostgreSQL 可用性
- 提供可观测与告警通道
- 以 `infra/` 作为唯一主入口（兼容入口仅保留，不扩展）

## 快速启动
```bash
make -C infra up
make -C infra check
make -C infra ps
```

## 服务端口
- PostgreSQL: 5432
- Redis: 6379
- Prometheus: 9090
- Alertmanager: 9093
- Grafana: 3000（可通过 `GRAFANA_PORT` 覆盖）

## 密钥集中管理（macOS Keychain）

选型：`macOS Keychain + security CLI`。

### 初始化
```bash
make -C infra keychain-init
```
按提示录入：
- `POSTGRES_PASSWORD`
- `GF_SECURITY_ADMIN_PASSWORD`
- `DINGTALK_MODE`（`noop` / `webhook` / `stream`）
- `DINGTALK_WEBHOOK_URL`（webhook 模式）
- `DINGTALK_APP_KEY` / `DINGTALK_APP_SECRET`（stream 模式）
- `DINGTALK_ROBOT_CODE` / `DINGTALK_OPEN_CONVERSATION_ID`（stream 模式）
- `DINGTALK_CHAT_ID`（stream 模式，可用于自动换取 `openConversationId`）
- `DINGTALK_TARGET_MODE`（stream 目标：`group` / `user`）
- `DINGTALK_USER_IDS`（stream 用户直发，逗号分隔）
- `DINGTALK_USER_ID_FIELD`（stream 用户标识字段：`userIds` / `unionIds` / `openIds`）

### 注入并启动
```bash
make -C infra up-secure
make -C infra check-secure
```

### 密钥轮换
```bash
bash infra/scripts/secrets_keychain.sh set postgres_password '<new_password>'
bash infra/scripts/secrets_keychain.sh set grafana_admin_password '<new_password>'
bash infra/scripts/secrets_keychain.sh set dingtalk_mode 'stream'
bash infra/scripts/secrets_keychain.sh set dingtalk_app_key '<app_key>'
bash infra/scripts/secrets_keychain.sh set dingtalk_app_secret '<app_secret>'
bash infra/scripts/secrets_keychain.sh set dingtalk_robot_code '<robot_code>'
bash infra/scripts/secrets_keychain.sh set dingtalk_open_conversation_id '<open_conversation_id>'
bash infra/scripts/secrets_keychain.sh set dingtalk_target_mode 'user'
bash infra/scripts/secrets_keychain.sh set dingtalk_user_ids '016835526352-1530023321'
bash infra/scripts/secrets_keychain.sh set dingtalk_user_id_field 'userIds'
make -C infra restart
```

说明：`DINGTALK_USER_IDS` 需要填写钉钉 `staffId`，非手机号、unionId、openId。

约束：真实密钥不写 `.env` 明文、不提交仓库。

## 告警通道
默认 Alertmanager webhook：
`http://host.docker.internal:18080/alerts`

该地址由本机桥接进程 `infra/scripts/dingding_alert_bridge.py` 接收，再按模式转发：
- `DINGTALK_MODE=noop`：仅记录不转发
- `DINGTALK_MODE=webhook`：转发到 `DINGTALK_WEBHOOK_URL`
- `DINGTALK_MODE=stream`：使用 `appKey/appSecret/robotCode/openConversationId` 调用钉钉开放接口发送消息

说明：
- 当 `DINGTALK_TARGET_MODE=group`（默认）时，若未配置 `DINGTALK_OPEN_CONVERSATION_ID`，桥接器会尝试使用 `DINGTALK_CHAT_ID` 自动查询并换取 `openConversationId`。
- 当 `DINGTALK_TARGET_MODE=user` 时，桥接器使用 `DINGTALK_USER_IDS` 调用“单聊批量发送”接口，无需 `openConversationId`。

桥接进程操作：
```bash
make -C infra bridge-up
make -C infra bridge-status
make -C infra bridge-down
```

接入真实网关步骤：
1. 执行 `make -C infra keychain-init` 并录入钉钉凭据
2. webhook 模式执行 `make -C infra up-secure`；stream 模式执行 `make -C infra up-dingding-stream`
3. 执行 `bash infra/scripts/trigger_test_alert.sh`
4. 在接收端确认收到 `InfraSyntheticTestAlert`
5. 执行 `make -C infra bridge-status` 查看本机桥接发送日志

可观测校验命令：
```bash
curl -fsS http://127.0.0.1:9090/api/v1/targets | jq '{status: .status, activeTargets: [.data.activeTargets[] | {job: .labels.job, health: .health}]}'
curl -fsS http://127.0.0.1:9093/api/v2/receivers | jq .
```

## 资源与稳定性建议

### 容器资源上限建议
- PostgreSQL：`cpus=1.0`、`mem_limit=1g`
- Redis：`cpus=0.5`、`mem_limit=512m`

已在 `infra/docker-compose.yml` 预置为可覆写参数：
- `POSTGRES_CPU_LIMIT` / `POSTGRES_MEM_LIMIT`
- `REDIS_CPU_LIMIT` / `REDIS_MEM_LIMIT`

### CI 并发/重试/超时建议
- 并发：`2`
- 每个 Job 资源：`2 vCPU / 4GB RAM`
- 重试：`2`（网络拉取镜像失败重试）
- 单 Job 超时：`30m`
- 失败日志：开启并保留
- 工件保留：开启并保留（建议至少 14 天）
- 健康检查重试：保持脚本默认 `12 * 2s`

## PostgreSQL 备份与恢复（最小流程）

备份：
```bash
make -C infra backup
```

恢复（建议恢复到演练库）：
```bash
latest_backup=$(cd infra && ls -t backups/*.sql.gz | head -n 1)
TARGET_DB=ddg_restore make -C infra restore BACKUP_FILE="$latest_backup"
```

演练校验：
```bash
docker compose -f infra/docker-compose.yml exec -T postgres psql -U ddg -d ddg_restore -c 'select count(*) from infra_restore_drill;'
```

## 委派执行模板
1. 启动 `infra/docker-compose.yml`
2. 执行 `infra/scripts/infra_smoke_check.sh`
3. 提交 `docker compose ps`、Prometheus targets、Alertmanager receivers 截图
4. 若失败，提交 `docker compose -f infra/docker-compose.yml logs --tail=200`
