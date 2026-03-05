# Infra 主入口

`infra/` 是本仓库唯一基础设施主入口。兼容入口仅保留，不再新增能力。

## 启动与验收（仓库根目录执行）

```bash
make -C infra up
make -C infra check
make -C infra ps
```

## 密钥管理（macOS Keychain）

```bash
make -C infra keychain-init
make -C infra up-secure
make -C infra check-secure
```

说明：真实密钥只存储在本机 Keychain，不写入 `.env` 明文，不提交仓库。

## 钉钉告警桥接（支持 webhook / stream）

```bash
make -C infra bridge-up
make -C infra bridge-status
make -C infra alert-test
```

Stream 模式启动：
```bash
make -C infra keychain-init
make -C infra up-dingding-stream
```

## 备份与恢复

```bash
make -C infra backup
latest_backup=$(cd infra && ls -t backups/*.sql.gz | head -n 1)
TARGET_DB=ddg_restore make -C infra restore BACKUP_FILE="$latest_backup"
```

## 常用命令

- `make -C infra up`：启动基础设施
- `make -C infra check`：执行健康检查
- `make -C infra ps`：查看服务状态
- `make -C infra logs`：查看最近日志
- `make -C infra down`：停止基础设施
- `make -C infra restart`：重启全部服务
- `make -C infra bridge-up`：启动钉钉桥接进程
- `make -C infra bridge-down`：停止钉钉桥接进程
- `make -C infra bridge-status`：查看钉钉桥接状态与日志
- `make -C infra up-dingding-stream`：以 Stream 模式启动并加载 Keychain 密钥

## 文档

- 操作手册：`infra/docs/infra-sop.md`
- 验收回传：`infra/docs/acceptance-report.md`
