# infra 变更说明（2026-03-05）

## 本次目标
- 落地本地基础设施安全运行基线
- 使用 Keychain 管理敏感凭据，移除明文依赖
- 保障提交阶段不引入明文 secret

## 主要变更
- 新增提交前密钥扫描：
  - `.githooks/pre-commit`
  - `scripts/check_no_plain_secrets.sh`
- 使用 `secrets_keychain.sh` 初始化并导出关键环境变量
- 验证 `make check-secure` 可在 Keychain 模式下通过

## 安全改进
- 拦截常见明文凭据提交（token/password/webhook 等）
- 运行时从 macOS Keychain 读取敏感配置

## 验证结果
- `make check-secure` 通过
- Prometheus / Alertmanager / Grafana / Postgres / Redis 健康
- exporter target 发现正常

## 关联提交
- `ef035e9` chore(security): add pre-commit plaintext secret guard
