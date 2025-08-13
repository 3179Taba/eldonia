# 09. 運用・監視設計

## 9.1 運用方針概要

### 9.1.1 運用理念
- **24/7可用性**: 99.9%以上のアップタイム維持
- **プロアクティブ監視**: 問題の早期発見・予防的対応
- **自動化優先**: 運用作業の自動化による人的ミス削減
- **迅速な復旧**: 障害発生時の迅速な対応・復旧
- **継続的改善**: 運用データに基づくプロセス改善

### 9.1.2 運用体制
- **1次対応**: 開発チーム（24時間以内）
- **2次対応**: インフラチーム（4時間以内）
- **3次対応**: 外部ベンダー（8時間以内）
- **エスカレーション**: 重大障害時の経営層への報告

## 9.2 監視戦略

### 9.2.1 監視対象
```
監視レイヤー構成
┌─────────────────────────────────────┐
│ Application Layer (アプリケーション層) │
│ ├── API Response Time               │
│ ├── Error Rate                      │
│ ├── Throughput                      │
│ └── Business Metrics                │
├─────────────────────────────────────┤
│ Infrastructure Layer (インフラ層)    │
│ ├── CPU, Memory, Disk              │
│ ├── Network I/O                     │
│ ├── Container Health               │
│ └── Service Discovery              │
├─────────────────────────────────────┤
│ Database Layer (データベース層)      │
│ ├── Query Performance              │
│ ├── Connection Pool                │
│ ├── Replication Lag                │
│ └── Storage Usage                  │
├─────────────────────────────────────┤
│ External Services (外部サービス層)   │
│ ├── AWS Service Health             │
│ ├── Third-party API Status         │
│ ├── CDN Performance                │
│ └── Payment Gateway                │
└─────────────────────────────────────┘
```

### 9.2.2 監視ツール構成
```yaml
# monitoring-stack.yml
version: '3.8'
services:
  # メトリクス収集
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'

  # ログ収集
  fluentd:
    image: fluent/fluentd:v1.16-1
    volumes:
      - ./fluentd/conf:/fluentd/etc
      - ./logs:/var/log
    ports:
      - "24224:24224"
      - "24224:24224/udp"

  # 可視化
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana

  # アラート管理
  alertmanager:
    image: prom/alertmanager:latest
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager_data:/alertmanager

  # 分散トレーシング
  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "16686:16686"
      - "14268:14268"

volumes:
  prometheus_data:
  grafana_data:
  alertmanager_data:
```

## 9.3 ログ管理設計

### 9.3.1 ログ構造
```typescript
// backend/src/utils/logger.ts
import winston from 'winston';
import { ElasticsearchTransport } from 'winston-elasticsearch';

export interface LogEntry {
  timestamp: string;
  level: 'error' | 'warn' | 'info' | 'debug';
  service: string;
  component: string;
  operation: string;
  userId?: string;
  sessionId?: string;
  requestId?: string;
  ipAddress?: string;
  userAgent?: string;
  message: string;
  metadata?: Record<string, any>;
  error?: {
    name: string;
    message: string;
    stack?: string;
    code?: string;
  };
  performance?: {
    duration: number;
    memoryUsage: number;
    cpuUsage: number;
  };
}

export class Logger {
  private logger: winston.Logger;

  constructor(service: string) {
    this.logger = winston.createLogger({
      level: process.env.LOG_LEVEL || 'info',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
      ),
      defaultMeta: { service },
      transports: [
        // コンソール出力
        new winston.transports.Console({
          format: winston.format.combine(
            winston.format.colorize(),
            winston.format.simple()
          )
        }),
        
        // ファイル出力
        new winston.transports.File({
          filename: 'logs/error.log',
          level: 'error',
          maxsize: 5242880, // 5MB
          maxFiles: 5
        }),
        
        new winston.transports.File({
          filename: 'logs/combined.log',
          maxsize: 5242880, // 5MB
          maxFiles: 5
        }),
        
        // Elasticsearch出力
        new ElasticsearchTransport({
          level: 'info',
          clientOpts: {
            node: process.env.ELASTICSEARCH_URL || 'http://localhost:9200',
            index: `eldonia-logs-${service}`,
            auth: {
              username: process.env.ELASTICSEARCH_USER,
              password: process.env.ELASTICSEARCH_PASSWORD
            }
          },
          indexPrefix: 'eldonia-logs',
          ensureMappingTemplate: true,
          mappingTemplate: {
            index_patterns: ['eldonia-logs-*'],
            settings: {
              number_of_shards: 1,
              number_of_replicas: 0
            },
            mappings: {
              properties: {
                '@timestamp': { type: 'date' },
                level: { type: 'keyword' },
                service: { type: 'keyword' },
                component: { type: 'keyword' },
                operation: { type: 'keyword' },
                userId: { type: 'keyword' },
                requestId: { type: 'keyword' },
                message: { type: 'text' },
                metadata: { type: 'object', dynamic: true }
              }
            }
          }
        })
      ]
    });
  }

  // 構造化ログ出力
  log(level: string, message: string, metadata?: Partial<LogEntry>): void {
    const logEntry: LogEntry = {
      timestamp: new Date().toISOString(),
      level: level as LogEntry['level'],
      service: metadata?.service || this.logger.defaultMeta?.service || 'unknown',
      component: metadata?.component || 'unknown',
      operation: metadata?.operation || 'unknown',
      userId: metadata?.userId,
      sessionId: metadata?.sessionId,
      requestId: metadata?.requestId,
      ipAddress: metadata?.ipAddress,
      userAgent: metadata?.userAgent,
      message,
      metadata: metadata?.metadata,
      error: metadata?.error,
      performance: metadata?.performance
    };

    this.logger.log(level, message, logEntry);
  }

  // エラーログ
  error(message: string, error?: Error, metadata?: Partial<LogEntry>): void {
    this.log('error', message, {
      ...metadata,
      error: error ? {
        name: error.name,
        message: error.message,
        stack: error.stack,
        code: (error as any).code
      } : undefined
    });
  }

  // 警告ログ
  warn(message: string, metadata?: Partial<LogEntry>): void {
    this.log('warn', message, metadata);
  }

  // 情報ログ
  info(message: string, metadata?: Partial<LogEntry>): void {
    this.log('info', message, metadata);
  }

  // デバッグログ
  debug(message: string, metadata?: Partial<LogEntry>): void {
    this.log('debug', message, metadata);
  }

  // パフォーマンスログ
  performance(operation: string, duration: number, metadata?: Partial<LogEntry>): void {
    this.log('info', `Performance: ${operation} completed in ${duration}ms`, {
      ...metadata,
      operation,
      performance: {
        duration,
        memoryUsage: process.memoryUsage().heapUsed,
        cpuUsage: process.cpuUsage().user
      }
    });
  }

  // セキュリティログ
  security(event: string, userId?: string, metadata?: Partial<LogEntry>): void {
    this.log('warn', `Security Event: ${event}`, {
      ...metadata,
      userId,
      component: 'security'
    });
  }

  // ビジネスログ
  business(event: string, userId?: string, metadata?: Partial<LogEntry>): void {
    this.log('info', `Business Event: ${event}`, {
      ...metadata,
      userId,
      component: 'business'
    });
  }
}

// ログインスタンス作成
export const logger = new Logger('eldonia-backend');
export const securityLogger = new Logger('eldonia-security');
export const businessLogger = new Logger('eldonia-business');
```

### 9.3.2 ログローテーション設定
```yaml
# fluentd/conf/fluent.conf
<source>
  @type tail
  path /var/log/eldonia/*.log
  pos_file /var/log/fluentd/eldonia.pos
  tag eldonia.*
  read_from_head true
  <parse>
    @type json
    time_key timestamp
    time_format %Y-%m-%dT%H:%M:%S.%LZ
  </parse>
</source>

<filter eldonia.**>
  @type record_transformer
  <record>
    environment "#{ENV['NODE_ENV'] || 'development'}"
    hostname "#{Socket.gethostname}"
  </record>
</filter>

<match eldonia.error>
  @type elasticsearch
  host elasticsearch
  port 9200
  logstash_format true
  logstash_prefix eldonia-error-logs
  <buffer>
    @type file
    path /var/log/fluentd/buffer/error
    flush_interval 5s
    chunk_limit_size 2M
    queue_limit_length 8
  </buffer>
</match>

<match eldonia.**>
  @type elasticsearch
  host elasticsearch
  port 9200
  logstash_format true
  logstash_prefix eldonia-logs
  <buffer>
    @type file
    path /var/log/fluentd/buffer/general
    flush_interval 10s
    chunk_limit_size 5M
    queue_limit_length 16
  </buffer>
</match>

# ログ保持期間設定
<match eldonia.**>
  @type elasticsearch
  host elasticsearch
  port 9200
  logstash_format true
  logstash_prefix eldonia-logs
  index_name eldonia-logs-%Y.%m.%d
  <buffer>
    @type file
    path /var/log/fluentd/buffer/retention
    flush_interval 1h
    chunk_limit_size 10M
    queue_limit_length 32
  </buffer>
</match>
```

## 9.4 アラート設定

### 9.4.1 Prometheus アラートルール
```yaml
# prometheus/alerts.yml
groups:
  - name: eldonia-alerts
    rules:
      # アプリケーションアラート
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 2m
        labels:
          severity: critical
          service: application
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} errors per second"

      - alert: HighResponseTime
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
        for: 5m
        labels:
          severity: warning
          service: application
        annotations:
          summary: "High response time detected"
          description: "95th percentile response time is {{ $value }}s"

      - alert: LowThroughput
        expr: rate(http_requests_total[5m]) < 10
        for: 10m
        labels:
          severity: warning
          service: application
        annotations:
          summary: "Low throughput detected"
          description: "Request rate is {{ $value }} requests per second"

      # インフラアラート
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
          service: infrastructure
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is {{ $value }}%"

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
        for: 5m
        labels:
          severity: warning
          service: infrastructure
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is {{ $value }}%"

      - alert: HighDiskUsage
        expr: (node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100 > 85
        for: 5m
        labels:
          severity: warning
          service: infrastructure
        annotations:
          summary: "High disk usage detected"
          description: "Disk usage is {{ $value }}%"

      # データベースアラート
      - alert: DatabaseConnectionHigh
        expr: pg_stat_database_numbackends > 80
        for: 2m
        labels:
          severity: warning
          service: database
        annotations:
          summary: "High database connections"
          description: "Database has {{ $value }} active connections"

      - alert: DatabaseSlowQueries
        expr: rate(pg_stat_activity_max_tx_duration{datname!=""}[5m]) > 30
        for: 5m
        labels:
          severity: warning
          service: database
        annotations:
          summary: "Slow database queries detected"
          description: "Average query duration is {{ $value }}s"

      # 外部サービスアラート
      - alert: AWSServiceDown
        expr: up{job="aws-exporter"} == 0
        for: 1m
        labels:
          severity: critical
          service: aws
        annotations:
          summary: "AWS service is down"
          description: "AWS exporter is not responding"

      - alert: PaymentGatewayError
        expr: rate(payment_requests_total{status="error"}[5m]) > 0.05
        for: 2m
        labels:
          severity: critical
          service: payment
        annotations:
          summary: "Payment gateway errors detected"
          description: "Payment error rate is {{ $value }} errors per second"

      # セキュリティアラート
      - alert: HighFailedLogins
        expr: rate(auth_failed_logins_total[5m]) > 10
        for: 2m
        labels:
          severity: warning
          service: security
        annotations:
          summary: "High number of failed login attempts"
          description: "{{ $value }} failed logins per second"

      - alert: SuspiciousActivity
        expr: rate(security_events_total{type="suspicious"}[5m]) > 5
        for: 1m
        labels:
          severity: critical
          service: security
        annotations:
          summary: "Suspicious activity detected"
          description: "{{ $value }} suspicious events per second"
```

### 9.4.2 Alertmanager設定
```yaml
# alertmanager/alertmanager.yml
global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/services/YOUR_SLACK_WEBHOOK'

route:
  group_by: ['alertname', 'service']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'slack-notifications'
  routes:
    - match:
        severity: critical
      receiver: 'pager-duty-critical'
      continue: true
    
    - match:
        severity: warning
      receiver: 'slack-notifications'
    
    - match:
        service: security
      receiver: 'security-team'
      continue: true

receivers:
  - name: 'slack-notifications'
    slack_configs:
      - channel: '#eldonia-alerts'
        title: '{{ template "slack.eldonia.title" . }}'
        text: '{{ template "slack.eldonia.text" . }}'
        actions:
          - type: button
            text: 'View in Grafana'
            url: '{{ template "slack.eldonia.grafana" . }}'
        send_resolved: true

  - name: 'pager-duty-critical'
    pagerduty_configs:
      - routing_key: YOUR_PAGERDUTY_KEY
        description: '{{ template "pagerduty.eldonia.description" . }}'
        severity: '{{ if eq .GroupLabels.severity "critical" }}critical{{ else }}warning{{ end }}'
        client: 'Eldonia Monitoring'
        client_url: '{{ template "pagerduty.eldonia.clientURL" . }}'

  - name: 'security-team'
    slack_configs:
      - channel: '#eldonia-security'
        title: '{{ template "slack.eldonia.security.title" . }}'
        text: '{{ template "slack.eldonia.security.text" . }}'
        send_resolved: true

templates:
  - '/etc/alertmanager/template/*.tmpl'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'service']
```

---

## 9.5 障害対応

### 9.5.1 障害レベル定義
```typescript
// backend/src/types/incident.ts
export enum IncidentSeverity {
  CRITICAL = 'critical',    // サービス完全停止
  HIGH = 'high',           // 主要機能停止
  MEDIUM = 'medium',       // 部分機能停止
  LOW = 'low',             // 機能劣化
  INFO = 'info'            // 情報提供
}

export enum IncidentStatus {
  OPEN = 'open',           // 対応中
  INVESTIGATING = 'investigating', // 調査中
  RESOLVED = 'resolved',   // 解決済み
  CLOSED = 'closed',       // 完了
  ESCALATED = 'escalated'  // エスカレーション
}

export interface Incident {
  id: string;
  title: string;
  description: string;
  severity: IncidentSeverity;
  status: IncidentStatus;
  service: string;
  component: string;
  detectedAt: Date;
  resolvedAt?: Date;
  assignedTo?: string;
  escalationLevel: number;
  impact: {
    users: number;
    revenue: number;
    reputation: string;
  };
  rootCause?: string;
  resolution?: string;
  lessonsLearned?: string;
  createdAt: Date;
  updatedAt: Date;
}

// 障害対応フロー
export class IncidentResponse {
  private incident: Incident;
  private logger: any;

  constructor(incident: Incident) {
    this.incident = incident;
    this.logger = require('../utils/logger').logger;
  }

  // 初期対応
  async initialResponse(): Promise<void> {
    this.logger.info('Incident initial response started', {
      incidentId: this.incident.id,
      severity: this.incident.severity,
      service: this.incident.service
    });

    // 1. 状況確認・影響範囲調査
    await this.assessImpact();
    
    // 2. 初期対応チーム編成
    await this.assembleResponseTeam();
    
    // 3. ステークホルダーへの通知
    await this.notifyStakeholders();
    
    // 4. 一時的回避策の実施
    await this.implementWorkaround();
  }

  // 詳細調査
  async investigate(): Promise<void> {
    this.logger.info('Incident investigation started', {
      incidentId: this.incident.id
    });

    // 1. ログ・メトリクス分析
    await this.analyzeLogsAndMetrics();
    
    // 2. 根本原因特定
    await this.identifyRootCause();
    
    // 3. 影響範囲の詳細評価
    await this.detailedImpactAssessment();
    
    // 4. 復旧計画策定
    await this.createRecoveryPlan();
  }

  // 復旧作業
  async recover(): Promise<void> {
    this.logger.info('Incident recovery started', {
      incidentId: this.incident.id
    });

    // 1. 復旧計画の実行
    await this.executeRecoveryPlan();
    
    // 2. 機能テスト
    await this.testFunctionality();
    
    // 3. 監視強化
    await this.enhanceMonitoring();
    
    // 4. 復旧確認
    await this.verifyRecovery();
  }

  // 事後対応
  async postIncident(): Promise<void> {
    this.logger.info('Post-incident activities started', {
      incidentId: this.incident.id
    });

    // 1. 事後分析
    await this.postIncidentAnalysis();
    
    // 2. 改善策の策定・実行
    await this.implementImprovements();
    
    // 3. ドキュメント更新
    await this.updateDocumentation();
    
    // 4. チーム振り返り
    await this.teamRetrospective();
  }

  private async assessImpact(): Promise<void> {
    // 影響範囲の評価ロジック
    const impact = await this.calculateImpact();
    this.incident.impact = impact;
    
    this.logger.info('Impact assessment completed', {
      incidentId: this.incident.id,
      impact: this.incident.impact
    });
  }

  private async assembleResponseTeam(): Promise<void> {
    // 対応チーム編成ロジック
    const team = await this.determineResponseTeam();
    
    this.logger.info('Response team assembled', {
      incidentId: this.incident.id,
      team: team
    });
  }

  private async notifyStakeholders(): Promise<void> {
    // ステークホルダー通知ロジック
    await this.sendNotifications();
    
    this.logger.info('Stakeholders notified', {
      incidentId: this.incident.id
    });
  }

  private async implementWorkaround(): Promise<void> {
    // 一時的回避策の実装
    await this.applyWorkaround();
    
    this.logger.info('Workaround implemented', {
      incidentId: this.incident.id
    });
  }

  private async analyzeLogsAndMetrics(): Promise<void> {
    // ログ・メトリクス分析
    const analysis = await this.performAnalysis();
    
    this.logger.info('Logs and metrics analyzed', {
      incidentId: this.incident.id,
      analysis: analysis
    });
  }

  private async identifyRootCause(): Promise<void> {
    // 根本原因特定
    const rootCause = await this.findRootCause();
    this.incident.rootCause = rootCause;
    
    this.logger.info('Root cause identified', {
      incidentId: this.incident.id,
      rootCause: rootCause
    });
  }

  private async createRecoveryPlan(): Promise<void> {
    // 復旧計画策定
    const plan = await this.developRecoveryPlan();
    
    this.logger.info('Recovery plan created', {
      incidentId: this.incident.id,
      plan: plan
    });
  }

  private async executeRecoveryPlan(): Promise<void> {
    // 復旧計画実行
    await this.implementRecoveryPlan();
    
    this.logger.info('Recovery plan executed', {
      incidentId: this.incident.id
    });
  }

  private async testFunctionality(): Promise<void> {
    // 機能テスト
    const testResults = await this.runFunctionalityTests();
    
    this.logger.info('Functionality tests completed', {
      incidentId: this.incident.id,
      testResults: testResults
    });
  }

  private async verifyRecovery(): Promise<void> {
    // 復旧確認
    const recoveryStatus = await this.checkRecoveryStatus();
    
    if (recoveryStatus.success) {
      this.incident.status = IncidentStatus.RESOLVED;
      this.incident.resolvedAt = new Date();
      
      this.logger.info('Incident resolved', {
        incidentId: this.incident.id,
        resolutionTime: this.incident.resolvedAt
      });
    }
  }

  // ヘルパーメソッド（実際の実装は省略）
  private async calculateImpact() { return { users: 0, revenue: 0, reputation: 'low' }; }
  private async determineResponseTeam() { return ['dev1', 'dev2']; }
  private async sendNotifications() { /* 通知ロジック */ }
  private async applyWorkaround() { /* 回避策実装 */ }
  private async performAnalysis() { return {}; }
  private async findRootCause() { return 'Unknown'; }
  private async developRecoveryPlan() { return {}; }
  private async implementRecoveryPlan() { /* 復旧計画実行 */ }
  private async runFunctionalityTests() { return { success: true }; }
  private async checkRecoveryStatus() { return { success: true }; }
}
```

### 9.5.2 障害対応手順書
```markdown
# 障害対応手順書

## 1. 障害検知時の対応

### 1.1 即座の対応
- [ ] アラートの確認・状況把握
- [ ] 影響範囲の初期評価
- [ ] 対応チームの召集
- [ ] ステークホルダーへの初期報告

### 1.2 状況確認
- [ ] システム状態の確認
- [ ] ログ・メトリクスの確認
- [ ] ユーザーへの影響確認
- [ ] ビジネスインパクトの評価

## 2. 障害レベル別対応

### 2.1 Critical（サービス完全停止）
**対応時間**: 15分以内
**対応者**: 全チーム + 経営層

- [ ] 全チームメンバーの召集
- [ ] 経営層への即座の報告
- [ ] 外部ベンダーへの連絡
- [ ] 24時間体制での対応開始

### 2.2 High（主要機能停止）
**対応時間**: 1時間以内
**対応者**: 開発チーム + インフラチーム

- [ ] 開発チームの召集
- [ ] インフラチームの支援要請
- [ ] 一時的回避策の検討・実装
- [ ] 復旧作業の開始

### 2.3 Medium（部分機能停止）
**対応時間**: 4時間以内
**対応者**: 開発チーム

- [ ] 開発チームでの対応開始
- [ ] 影響範囲の詳細調査
- [ ] 復旧計画の策定
- [ ] 復旧作業の実行

## 3. 復旧作業

### 3.1 一時的回避策
- [ ] 機能の無効化・制限
- [ ] 負荷分散・スケールアウト
- [ ] 代替手段の提供
- [ ] ユーザーへの案内

### 3.2 根本的解決
- [ ] 根本原因の特定
- [ ] 修正コードの開発
- [ ] テスト・検証
- [ ] 本番環境への適用

## 4. 事後対応

### 4.1 事後分析
- [ ] 障害の詳細分析
- [ ] 対応プロセスの評価
- [ ] 改善点の特定
- [ ] 再発防止策の策定

### 4.2 改善・予防
- [ ] 監視の強化
- [ ] 自動化の推進
- [ ] ドキュメントの更新
- [ ] チーム研修の実施

## 5. 報告・記録

### 5.1 報告書の作成
- [ ] 障害の概要
- [ ] 影響範囲・被害
- [ ] 対応経過
- [ ] 根本原因
- [ ] 再発防止策
- [ ] 教訓・改善点

### 5.2 関係者への報告
- [ ] 経営層への報告
- [ ] ユーザーへの説明
- [ ] チーム内での共有
- [ ] 外部への公表（必要に応じて）
```

## 9.6 パフォーマンス監視

### 9.6.1 パフォーマンスメトリクス
```typescript
// backend/src/monitoring/performance.ts
import { performance } from 'perf_hooks';
import { logger } from '../utils/logger';

export interface PerformanceMetrics {
  timestamp: Date;
  operation: string;
  duration: number;
  memoryUsage: NodeJS.MemoryUsage;
  cpuUsage: NodeJS.CpuUsage;
  databaseQueries: number;
  cacheHits: number;
  cacheMisses: number;
  externalApiCalls: number;
  errors: number;
}

export class PerformanceMonitor {
  private metrics: PerformanceMetrics[] = [];
  private startTimes: Map<string, number> = new Map();

  // パフォーマンス測定開始
  startTimer(operation: string): void {
    this.startTimes.set(operation, performance.now());
  }

  // パフォーマンス測定終了
  endTimer(operation: string, metadata?: Partial<PerformanceMetrics>): void {
    const startTime = this.startTimes.get(operation);
    if (!startTime) return;

    const duration = performance.now() - startTime;
    const metrics: PerformanceMetrics = {
      timestamp: new Date(),
      operation,
      duration,
      memoryUsage: process.memoryUsage(),
      cpuUsage: process.cpuUsage(),
      databaseQueries: metadata?.databaseQueries || 0,
      cacheHits: metadata?.cacheHits || 0,
      cacheMisses: metadata?.cacheMisses || 0,
      externalApiCalls: metadata?.externalApiCalls || 0,
      errors: metadata?.errors || 0
    };

    this.metrics.push(metrics);
    this.startTimes.delete(operation);

    // パフォーマンスログ出力
    logger.performance(operation, duration, {
      operation,
      metadata: {
        memoryUsage: metrics.memoryUsage,
        cpuUsage: metrics.cpuUsage,
        databaseQueries: metrics.databaseQueries,
        cacheHits: metrics.cacheHits,
        cacheMisses: metrics.cacheMisses,
        externalApiCalls: metrics.externalApiCalls,
        errors: metrics.errors
      }
    });

    // アラート条件チェック
    this.checkPerformanceAlerts(metrics);
  }

  // パフォーマンスアラートチェック
  private checkPerformanceAlerts(metrics: PerformanceMetrics): void {
    // レスポンス時間アラート
    if (metrics.duration > 2000) { // 2秒以上
      logger.warn('Performance alert: Slow operation detected', {
        operation: metrics.operation,
        duration: metrics.duration,
        threshold: 2000
      });
    }

    // メモリ使用量アラート
    const memoryUsagePercent = (metrics.memoryUsage.heapUsed / metrics.memoryUsage.heapTotal) * 100;
    if (memoryUsagePercent > 80) {
      logger.warn('Performance alert: High memory usage', {
        operation: metrics.operation,
        memoryUsagePercent,
        threshold: 80
      });
    }

    // エラー率アラート
    if (metrics.errors > 0) {
      logger.warn('Performance alert: Errors detected during operation', {
        operation: metrics.operation,
        errorCount: metrics.errors
      });
    }
  }

  // パフォーマンスレポート生成
  generateReport(): any {
    const totalOperations = this.metrics.length;
    if (totalOperations === 0) return null;

    const avgDuration = this.metrics.reduce((sum, m) => sum + m.duration, 0) / totalOperations;
    const maxDuration = Math.max(...this.metrics.map(m => m.duration));
    const minDuration = Math.min(...this.metrics.map(m => m.duration));

    const totalErrors = this.metrics.reduce((sum, m) => sum + m.errors, 0);
    const errorRate = (totalErrors / totalOperations) * 100;

    const totalDatabaseQueries = this.metrics.reduce((sum, m) => sum + m.databaseQueries, 0);
    const avgDatabaseQueries = totalDatabaseQueries / totalOperations;

    const totalCacheHits = this.metrics.reduce((sum, m) => sum + m.cacheHits, 0);
    const totalCacheMisses = this.metrics.reduce((sum, m) => sum + m.cacheMisses, 0);
    const cacheHitRate = totalCacheHits + totalCacheMisses > 0 
      ? (totalCacheHits / (totalCacheHits + totalCacheMisses)) * 100 
      : 0;

    return {
      summary: {
        totalOperations,
        avgDuration: Math.round(avgDuration * 100) / 100,
        maxDuration: Math.round(maxDuration * 100) / 100,
        minDuration: Math.round(minDuration * 100) / 100,
        errorRate: Math.round(errorRate * 100) / 100,
        avgDatabaseQueries: Math.round(avgDatabaseQueries * 100) / 100,
        cacheHitRate: Math.round(cacheHitRate * 100) / 100
      },
      operations: this.metrics.map(m => ({
        operation: m.operation,
        duration: m.duration,
        timestamp: m.timestamp,
        errors: m.errors
      }))
    };
  }

  // メトリクスクリア
  clearMetrics(): void {
    this.metrics = [];
    this.startTimes.clear();
  }
}

// パフォーマンス監視インスタンス
export const performanceMonitor = new PerformanceMonitor();

// ミドルウェアとして使用
export const performanceMiddleware = (req: any, res: any, next: any) => {
  const operation = `${req.method} ${req.path}`;
  performanceMonitor.startTimer(operation);

  // レスポンス終了時の処理
  res.on('finish', () => {
    performanceMonitor.endTimer(operation, {
      databaseQueries: req.databaseQueries || 0,
      cacheHits: req.cacheHits || 0,
      cacheMisses: req.cacheMisses || 0,
      externalApiCalls: req.externalApiCalls || 0,
      errors: res.statusCode >= 400 ? 1 : 0
    });
  });

  next();
};
```

## 9.7 セキュリティ監視

### 9.7.1 セキュリティイベント監視
```typescript
// backend/src/monitoring/security.ts
import { logger } from '../utils/logger';
import { securityLogger } from '../utils/logger';

export interface SecurityEvent {
  id: string;
  timestamp: Date;
  type: SecurityEventType;
  severity: SecurityEventSeverity;
  userId?: string;
  ipAddress?: string;
  userAgent?: string;
  sessionId?: string;
  details: any;
  source: string;
  status: SecurityEventStatus;
}

export enum SecurityEventType {
  FAILED_LOGIN = 'failed_login',
  SUSPICIOUS_ACTIVITY = 'suspicious_activity',
  UNAUTHORIZED_ACCESS = 'unauthorized_access',
  DATA_ACCESS = 'data_access',
  CONFIGURATION_CHANGE = 'configuration_change',
  MALWARE_DETECTED = 'malware_detected',
  BRUTE_FORCE_ATTEMPT = 'brute_force_attempt',
  SQL_INJECTION_ATTEMPT = 'sql_injection_attempt',
  XSS_ATTEMPT = 'xss_attempt',
  CSRF_ATTEMPT = 'csrf_attempt'
}

export enum SecurityEventSeverity {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  CRITICAL = 'critical'
}

export enum SecurityEventStatus {
  OPEN = 'open',
  INVESTIGATING = 'investigating',
  RESOLVED = 'resolved',
  FALSE_POSITIVE = 'false_positive'
}

export class SecurityMonitor {
  private events: SecurityEvent[] = [];
  private alertThresholds: Map<SecurityEventType, number> = new Map();
  private timeWindows: Map<SecurityEventType, number> = new Map();

  constructor() {
    this.initializeThresholds();
  }

  private initializeThresholds(): void {
    // セキュリティイベントの閾値設定
    this.alertThresholds.set(SecurityEventType.FAILED_LOGIN, 5);
    this.alertThresholds.set(SecurityEventType.SUSPICIOUS_ACTIVITY, 3);
    this.alertThresholds.set(SecurityEventType.UNAUTHORIZED_ACCESS, 1);
    this.alertThresholds.set(SecurityEventType.BRUTE_FORCE_ATTEMPT, 10);
    this.alertThresholds.set(SecurityEventType.SQL_INJECTION_ATTEMPT, 1);
    this.alertThresholds.set(SecurityEventType.XSS_ATTEMPT, 1);
    this.alertThresholds.set(SecurityEventType.CSRF_ATTEMPT, 1);

    // 時間窓設定（分）
    this.timeWindows.set(SecurityEventType.FAILED_LOGIN, 5);
    this.timeWindows.set(SecurityEventType.SUSPICIOUS_ACTIVITY, 10);
    this.timeWindows.set(SecurityEventType.UNAUTHORIZED_ACCESS, 1);
    this.alertThresholds.set(SecurityEventType.BRUTE_FORCE_ATTEMPT, 5);
    this.alertThresholds.set(SecurityEventType.SQL_INJECTION_ATTEMPT, 1);
    this.alertThresholds.set(SecurityEventType.XSS_ATTEMPT, 1);
    this.alertThresholds.set(SecurityEventType.CSRF_ATTEMPT, 1);
  }

  // セキュリティイベント記録
  recordEvent(
    type: SecurityEventType,
    severity: SecurityEventSeverity,
    details: any,
    source: string,
    userId?: string,
    ipAddress?: string,
    userAgent?: string,
    sessionId?: string
  ): void {
    const event: SecurityEvent = {
      id: this.generateEventId(),
      timestamp: new Date(),
      type,
      severity,
      userId,
      ipAddress,
      userAgent,
      sessionId,
      details,
      source,
      status: SecurityEventStatus.OPEN
    };

    this.events.push(event);

    // セキュリティログ出力
    securityLogger.security(`Security event: ${type}`, userId, {
      eventType: type,
      severity,
      ipAddress,
      userAgent,
      sessionId,
      details,
      source
    });

    // アラートチェック
    this.checkSecurityAlerts(type, event);
  }

  // セキュリティアラートチェック
  private checkSecurityAlerts(type: SecurityEventType, event: SecurityEvent): void {
    const threshold = this.alertThresholds.get(type);
    const timeWindow = this.timeWindows.get(type);

    if (!threshold || !timeWindow) return;

    const recentEvents = this.events.filter(e => 
      e.type === type && 
      e.timestamp.getTime() > Date.now() - (timeWindow * 60 * 1000)
    );

    if (recentEvents.length >= threshold) {
      this.triggerSecurityAlert(type, recentEvents, threshold, timeWindow);
    }
  }

  // セキュリティアラート発火
  private triggerSecurityAlert(
    type: SecurityEventType,
    events: SecurityEvent[],
    threshold: number,
    timeWindow: number
  ): void {
    const alertMessage = `Security alert: ${type} threshold exceeded`;
    const alertDetails = {
      eventType: type,
      eventCount: events.length,
      threshold,
      timeWindow,
      events: events.map(e => ({
        id: e.id,
        timestamp: e.timestamp,
        userId: e.userId,
        ipAddress: e.ipAddress,
        details: e.details
      }))
    };

    // アラートログ出力
    securityLogger.error(alertMessage, undefined, {
      eventType: 'security_alert',
      component: 'security_monitor',
      metadata: alertDetails
    });

    // 外部アラートシステムへの通知
    this.sendSecurityAlert(alertMessage, alertDetails);
  }

  // 外部アラートシステムへの通知
  private async sendSecurityAlert(message: string, details: any): Promise<void> {
    try {
      // Slack通知
      await this.sendSlackAlert(message, details);
      
      // PagerDuty通知（重大な場合）
      if (this.hasCriticalEvents(details.events)) {
        await this.sendPagerDutyAlert(message, details);
      }
      
      // セキュリティチームへの通知
      await this.notifySecurityTeam(message, details);
    } catch (error) {
      logger.error('Failed to send security alert', error);
    }
  }

  // 重大イベントの判定
  private hasCriticalEvents(events: any[]): boolean {
    return events.some(e => e.severity === SecurityEventSeverity.CRITICAL);
  }

  // Slack通知
  private async sendSlackAlert(message: string, details: any): Promise<void> {
    // Slack通知の実装
    console.log('Slack alert sent:', message, details);
  }

  // PagerDuty通知
  private async sendPagerDutyAlert(message: string, details: any): Promise<void> {
    // PagerDuty通知の実装
    console.log('PagerDuty alert sent:', message, details);
  }

  // セキュリティチーム通知
  private async notifySecurityTeam(message: string, details: any): Promise<void> {
    // セキュリティチーム通知の実装
    console.log('Security team notified:', message, details);
  }

  // イベントID生成
  private generateEventId(): string {
    return `sec_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  // セキュリティレポート生成
  generateSecurityReport(): any {
    const totalEvents = this.events.length;
    if (totalEvents === 0) return null;

    const eventsByType = this.groupEventsByType();
    const eventsBySeverity = this.groupEventsBySeverity();
    const eventsByStatus = this.groupEventsByStatus();

    return {
      summary: {
        totalEvents,
        eventsByType,
        eventsBySeverity,
        eventsByStatus
      },
      recentEvents: this.events
        .sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime())
        .slice(0, 100)
    };
  }

  private groupEventsByType(): Record<string, number> {
    return this.events.reduce((acc, event) => {
      acc[event.type] = (acc[event.type] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);
  }

  private groupEventsBySeverity(): Record<string, number> {
    return this.events.reduce((acc, event) => {
      acc[event.severity] = (acc[event.severity] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);
  }

  private groupEventsByStatus(): Record<string, number> {
    return this.events.reduce((acc, event) => {
      acc[event.status] = (acc[event.status] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);
  }
}

// セキュリティ監視インスタンス
export const securityMonitor = new SecurityMonitor();
```

## 9.8 運用自動化

### 9.8.1 自動復旧スクリプト
```bash
#!/bin/bash
# auto-recovery.sh - 自動復旧スクリプト

set -e

# 設定
SERVICE_NAME="eldonia-backend"
HEALTH_CHECK_URL="http://localhost:3001/health"
MAX_RESTART_ATTEMPTS=3
RESTART_DELAY=30
LOG_FILE="/var/log/eldonia/auto-recovery.log"

# ログ関数
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# ヘルスチェック
check_health() {
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_CHECK_URL" 2>/dev/null || echo "000")
    
    if [ "$response" = "200" ]; then
        return 0
    else
        return 1
    fi
}

# サービス再起動
restart_service() {
    log "Restarting $SERVICE_NAME..."
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl restart "$SERVICE_NAME"
        log "Service restarted successfully"
    else
        systemctl start "$SERVICE_NAME"
        log "Service started successfully"
    fi
}

# メイン処理
main() {
    log "Auto-recovery script started"
    
    local attempt=1
    
    while [ $attempt -le $MAX_RESTART_ATTEMPTS ]; do
        log "Health check attempt $attempt/$MAX_RESTART_ATTEMPTS"
        
        if check_health; then
            log "Service is healthy. Exiting."
            exit 0
        else
            log "Service is unhealthy. Attempting restart..."
            restart_service
            
            log "Waiting $RESTART_DELAY seconds for service to stabilize..."
            sleep $RESTART_DELAY
            
            if check_health; then
                log "Service recovered after restart. Exiting."
                exit 0
            else
                log "Service still unhealthy after restart."
                attempt=$((attempt + 1))
            fi
        fi
    done
    
    log "Maximum restart attempts reached. Service recovery failed."
    log "Sending critical alert to operations team."
    
    # 重大アラートの送信
    send_critical_alert
    
    exit 1
}

# 重大アラート送信
send_critical_alert() {
    # Slack通知
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"🚨 CRITICAL: $SERVICE_NAME auto-recovery failed after $MAX_RESTART_ATTEMPTS attempts. Manual intervention required.\"}" \
        "$SLACK_WEBHOOK_URL" 2>/dev/null || true
    
    # PagerDuty通知
    curl -X POST -H 'Content-type: application/json' \
        -H "Authorization: Token token=$PAGERDUTY_API_KEY" \
        --data "{\"incident\":{\"type\":\"incident\",\"title\":\"$SERVICE_NAME Auto-Recovery Failed\",\"service\":{\"id\":\"$PAGERDUTY_SERVICE_ID\",\"type\":\"service_reference\"},\"urgency\":\"high\"}}" \
        "https://api.pagerduty.com/incidents" 2>/dev/null || true
}

# スクリプト実行
main "$@"
```

---

**次のセクション**: 10. 開発・運用プロセス
