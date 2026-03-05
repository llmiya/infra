# DDG CI 计算额度申请文案

项目：DDG

系统代码仓库：`git@github.com:llmiya/DDGG.git`

申请内容：
- CI 并发：`2`
- 每个 Job 资源：`2 vCPU / 4GB RAM`
- 单 Job 超时：`30m`
- 开启失败日志并保留
- 开启工件保留

配套基础设施诉求：
- 需提供开发/测试环境的 PostgreSQL、Redis 连接能力
- 需预留 Prometheus / Alertmanager / Grafana 基础观测接入

现状说明（infra 基线）：
- 已具备 `make -C infra up/check/ps` 一键启动与验收
- 已具备 PostgreSQL/Redis 连通验证
- 已具备 Prometheus/Alertmanager/Grafana 基础观测
- 已支持钉钉告警桥接（webhook/stream）
