# 05. インフラ・DevOps設計

## 5.1 インフラ概要

### 5.1.1 設計方針
- **スケーラビリティ**: 水平・垂直スケーリング対応
- **高可用性**: 99.9%以上の稼働率
- **セキュリティ**: 多層防御、暗号化、監査
- **コスト最適化**: 使用量ベース課金、リソース最適化
- **運用効率**: 自動化、監視、アラート

### 5.1.2 アーキテクチャ概要
```
Internet
    ↓
Route 53 (DNS)
    ↓
CloudFront (CDN)
    ↓
Application Load Balancer
    ↓
ECS Fargate (Node.js Backend)
    ↓
RDS Aurora (PostgreSQL)
    ↓
ElastiCache (Redis)
    ↓
S3 (Media Storage)
```

## 5.2 AWSサービス構成

### 5.2.1 コンピューティング
- **ECS Fargate**: サーバーレスコンテナオーケストレーション
  - Node.js 20.x LTS
  - 自動スケーリング (CPU/メモリ使用率ベース)
  - タスク定義: 最小1、最大10インスタンス
  - ヘルスチェック: `/health`エンドポイント

- **Lambda**: サーバーレス関数
  - 画像処理、ファイル変換
  - バッチ処理、定期タスク
  - イベント駆動処理

### 5.2.2 データベース・ストレージ
- **RDS Aurora PostgreSQL**: メインデータベース
  - インスタンスクラス: db.r6g.large (開発) → db.r6g.xlarge (本番)
  - マルチAZ配置 (本番環境)
  - 自動バックアップ: 7日間保持
  - 読み取りレプリカ: 2台 (本番環境)

- **ElastiCache Redis**: セッション・キャッシュ
  - ノードタイプ: cache.r6g.large
  - クラスターモード: 有効
  - データ永続化: AOF (Append Only File)

- **S3**: メディアファイルストレージ
  - ストレージクラス: Standard → Intelligent Tiering
  - ライフサイクルポリシー: 90日後 → IA、365日後 → Glacier
  - バージョニング: 有効
  - 暗号化: SSE-S3

### 5.2.3 ネットワーク・セキュリティ
- **VPC**: カスタムVPC
  - CIDR: 10.0.0.0/16
  - パブリックサブネット: 10.0.1.0/24, 10.0.2.0/24
  - プライベートサブネット: 10.0.10.0/24, 10.0.20.0/24
  - NAT Gateway: プライベートサブネット用

- **Security Groups**: セキュリティグループ
  - ALB: 80, 443 (HTTP/HTTPS)
  - ECS: 3001 (Node.js)
  - RDS: 5432 (PostgreSQL)
  - Redis: 6379

- **WAF**: Web Application Firewall
  - SQLインジェクション対策
  - XSS対策
  - レート制限: IPアドレスベース

### 5.2.4 CDN・ロードバランサー
- **CloudFront**: コンテンツ配信
  - オリジン: S3 + ALB
  - キャッシュポリシー: 画像24時間、JS/CSS1週間
  - 地理的制限: 必要に応じて設定
  - HTTPS強制、HSTS有効

- **Application Load Balancer**: ロードバランサー
  - ターゲットグループ: ECS Fargate
  - ヘルスチェック: `/health`、30秒間隔
  - SSL証明書: ACM
  - アクセスログ: S3

## 5.3 コンテナ化・オーケストレーション

### 5.3.1 Dockerfile設計
```dockerfile
# backend/Dockerfile
FROM node:20-alpine

WORKDIR /app

# 依存関係インストール
COPY package*.json ./
RUN npm ci --only=production

# アプリケーションコード
COPY . .

# 非rootユーザー作成
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001
USER nodejs

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3001/health || exit 1

EXPOSE 3001

CMD ["npm", "start"]
```

### 5.3.2 ECSタスク定義
```json
{
  "family": "eldonia-backend",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::123456789012:role/eldonia-backend-task-role",
  "containerDefinitions": [
    {
      "name": "eldonia-backend",
      "image": "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/eldonia-backend:latest",
      "portMappings": [
        {
          "containerPort": 3001,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "NODE_ENV",
          "value": "production"
        },
        {
          "name": "PORT",
          "value": "3001"
        }
      ],
      "secrets": [
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:eldonia/db-password"
        },
        {
          "name": "JWT_SECRET",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:eldonia/jwt-secret"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/eldonia-backend",
          "awslogs-region": "ap-northeast-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

### 5.3.3 ECSサービス設定
```json
{
  "serviceName": "eldonia-backend",
  "cluster": "eldonia-cluster",
  "taskDefinition": "eldonia-backend",
  "desiredCount": 2,
  "launchType": "FARGATE",
  "networkConfiguration": {
    "awsvpcConfiguration": {
      "subnets": ["subnet-12345678", "subnet-87654321"],
      "securityGroups": ["sg-12345678"],
      "assignPublicIp": "DISABLED"
    }
  },
  "loadBalancers": [
    {
      "targetGroupArn": "arn:aws:elasticloadbalancing:ap-northeast-1:123456789012:targetgroup/eldonia-backend/1234567890123456",
      "containerName": "eldonia-backend",
      "containerPort": 3001
    }
  ],
  "deploymentConfiguration": {
    "maximumPercent": 200,
    "minimumHealthyPercent": 50
  },
  "healthCheckGracePeriodSeconds": 60
}
```

## 5.4 CI/CDパイプライン

### 5.4.1 GitHub Actions設定
```yaml
# .github/workflows/deploy.yml
name: Deploy to AWS

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  AWS_REGION: ap-northeast-1
  ECR_REPOSITORY: eldonia-backend
  ECS_CLUSTER: eldonia-cluster
  ECS_SERVICE: eldonia-backend

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: backend/package-lock.json
      
      - name: Install dependencies
        run: |
          cd backend
          npm ci
      
      - name: Run tests
        run: |
          cd backend
          npm test
      
      - name: Run linting
        run: |
          cd backend
          npm run lint

  build-and-deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Build, tag, and push image to Amazon ECR
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          cd backend
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
          echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT
      
      - name: Update ECS service
        run: |
          aws ecs update-service \
            --cluster $ECS_CLUSTER \
            --service $ECS_SERVICE \
            --force-new-deployment
      
      - name: Wait for deployment
        run: |
          aws ecs wait services-stable \
            --cluster $ECS_CLUSTER \
            --services $ECS_SERVICE
```

### 5.4.2 AWS CodePipeline設定
```json
{
  "pipelineName": "eldonia-backend-pipeline",
  "pipelineType": "V2",
  "stages": [
    {
      "name": "Source",
      "actions": [
        {
          "name": "Source",
          "actionTypeId": {
            "category": "Source",
            "owner": "AWS",
            "provider": "CodeStarSourceConnection",
            "version": "1"
          },
          "configuration": {
            "ConnectionArn": "arn:aws:codestar-connections:ap-northeast-1:123456789012:connection/12345678-1234-1234-1234-123456789012",
            "FullRepositoryId": "eldonia/eldonia-backend",
            "BranchName": "main"
          }
        }
      ]
    },
    {
      "name": "Build",
      "actions": [
        {
          "name": "Build",
          "actionTypeId": {
            "category": "Build",
            "owner": "AWS",
            "provider": "CodeBuild",
            "version": "1"
          },
          "configuration": {
            "ProjectName": "eldonia-backend-build"
          }
        }
      ]
    },
    {
      "name": "Deploy",
      "actions": [
        {
          "name": "Deploy",
          "actionTypeId": {
            "category": "Deploy",
            "owner": "AWS",
            "provider": "ECS",
            "version": "1"
          },
          "configuration": {
            "ClusterName": "eldonia-cluster",
            "ServiceName": "eldonia-backend",
            "FileName": "imagedefinitions.json"
          }
        }
      ]
    }
  ]
}
```

## 5.5 監視・ログ管理

### 5.5.1 CloudWatch設定
- **メトリクス**: CPU使用率、メモリ使用率、ネットワークI/O
- **ダッシュボード**: リアルタイム監視、アラート設定
- **ログ**: アプリケーションログ、アクセスログ、エラーログ
- **アラーム**: 閾値ベースの通知

### 5.5.2 DataDog設定
```yaml
# datadog.yaml
api_key: "your-datadog-api-key"
site: "datadoghq.com"

logs:
  - type: "docker"
    service: "eldonia-backend"
    source: "nodejs"

apm_config:
  enabled: true
  apm_non_local_traffic: true

process_config:
  enabled: true
  process_collection:
    enabled: true
```

### 5.5.3 Sentry設定
```javascript
// backend/src/config/sentry.js
const Sentry = require('@sentry/node');

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: 1.0,
  integrations: [
    new Sentry.Integrations.Http({ tracing: true }),
    new Sentry.Integrations.Express({ app }),
  ],
});

app.use(Sentry.Handlers.requestHandler());
app.use(Sentry.Handlers.errorHandler());
```

## 5.6 スケーリング戦略

### 5.6.1 自動スケーリング
- **ECS Service Auto Scaling**: CPU/メモリ使用率ベース
- **RDS Aurora Auto Scaling**: 読み取りレプリカ自動追加
- **ElastiCache Auto Scaling**: ノード自動追加

### 5.6.2 負荷分散
- **ALB**: ラウンドロビン、最小接続数
- **CloudFront**: 地理的分散、エッジロケーション
- **Route 53**: 地理的ルーティング、ヘルスチェック

### 5.6.3 キャッシュ戦略
- **Redis**: セッション、ユーザー情報、APIレスポンス
- **CloudFront**: 静的コンテンツ、画像、JS/CSS
- **ブラウザキャッシュ**: ETag、Cache-Control

## 5.7 バックアップ・災害復旧

### 5.7.1 バックアップ戦略
- **RDS Aurora**: 自動バックアップ、ポイントインタイム復旧
- **S3**: バージョニング、ライフサイクルポリシー
- **EBS**: スナップショット、暗号化

### 5.7.2 災害復旧
- **マルチリージョン**: 東京 + 大阪
- **RTO**: 4時間以内
- **RPO**: 15分以内
- **フェイルオーバー**: 自動・手動切り替え

## 5.8 セキュリティ設定

### 5.8.1 IAM設定
- **最小権限の原則**: 必要最小限の権限のみ付与
- **ロールベースアクセス**: ECSタスクロール、サービスロール
- **一時認証情報**: STS、セッショントークン

### 5.8.2 暗号化
- **転送時暗号化**: TLS 1.3、HTTPS強制
- **保存時暗号化**: AES-256、KMS管理
- **データベース暗号化**: RDS暗号化、TDE

### 5.8.3 監査・コンプライアンス
- **CloudTrail**: API呼び出しログ
- **Config**: リソース設定変更追跡
- **GuardDuty**: 脅威検知、異常検知

## 5.9 コスト最適化

### 5.9.1 リソース最適化
- **EC2 Spot**: 開発・テスト環境
- **RDS Reserved**: 本番データベース
- **S3 Intelligent Tiering**: 自動ストレージクラス最適化

### 5.9.2 監視・アラート
- **AWS Cost Explorer**: コスト分析、予測
- **Billing Alerts**: 予算超過アラート
- **Resource Tagging**: コスト配分、リソース管理

---

**次のセクション**: 06. セキュリティ設計
