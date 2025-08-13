# 06. セキュリティ設計

## 6.1 セキュリティ概要

### 6.1.1 設計方針
- **多層防御**: 複数のセキュリティレイヤーによる保護
- **最小権限の原則**: 必要最小限の権限のみ付与
- **ゼロトラスト**: 全てのアクセスを検証・認証
- **セキュリティバイデザイン**: 開発初期からのセキュリティ考慮
- **継続的改善**: 定期的なセキュリティ評価・更新

### 6.1.2 セキュリティフレームワーク
- **OWASP Top 10**: Webアプリケーションセキュリティ
- **NIST Cybersecurity Framework**: サイバーセキュリティフレームワーク
- **ISO 27001**: 情報セキュリティマネジメント
- **GDPR**: 個人データ保護規制
- **PCI DSS**: 決済カード業界データセキュリティ基準

## 6.2 認証・認可システム

### 6.2.1 認証方式
- **JWT (JSON Web Token)**: ステートレス認証
  - アクセストークン: 15分有効期限
  - リフレッシュトークン: 7日有効期限
  - 署名アルゴリズム: RS256 (非対称暗号)
  - ペイロード暗号化: 機密情報の暗号化

- **OAuth 2.0**: サードパーティ認証
  - 認可コードフロー: Webアプリケーション
  - クライアントクレデンシャルフロー: サーバー間通信
  - PKCE: モバイルアプリケーション

- **2FA (二要素認証)**: 多要素認証
  - TOTP (Time-based One-Time Password)
  - SMS認証 (バックアップ用)
  - 認証アプリ: Google Authenticator, Authy

### 6.2.2 認可・権限管理
```typescript
// backend/src/types/auth.ts
enum UserRole {
  USER = 'user',
  CREATOR = 'creator',
  MODERATOR = 'moderator',
  ADMIN = 'admin',
  SUPER_ADMIN = 'super_admin'
}

enum Permission {
  // ユーザー管理
  USER_READ = 'user:read',
  USER_CREATE = 'user:create',
  USER_UPDATE = 'user:update',
  USER_DELETE = 'user:delete',
  
  // コンテンツ管理
  CONTENT_READ = 'content:read',
  CONTENT_CREATE = 'content:create',
  CONTENT_UPDATE = 'content:update',
  CONTENT_DELETE = 'content:delete',
  CONTENT_MODERATE = 'content:moderate',
  
  // システム管理
  SYSTEM_CONFIG = 'system:config',
  SYSTEM_MONITOR = 'system:monitor',
  SYSTEM_BACKUP = 'system:backup'
}

interface RolePermission {
  role: UserRole;
  permissions: Permission[];
}

const ROLE_PERMISSIONS: RolePermission[] = [
  {
    role: UserRole.USER,
    permissions: [Permission.CONTENT_READ, Permission.USER_READ]
  },
  {
    role: UserRole.CREATOR,
    permissions: [
      Permission.CONTENT_READ,
      Permission.CONTENT_CREATE,
      Permission.CONTENT_UPDATE,
      Permission.USER_READ
    ]
  },
  {
    role: UserRole.MODERATOR,
    permissions: [
      Permission.CONTENT_READ,
      Permission.CONTENT_MODERATE,
      Permission.USER_READ,
      Permission.USER_UPDATE
    ]
  },
  {
    role: UserRole.ADMIN,
    permissions: [
      Permission.USER_READ,
      Permission.USER_CREATE,
      Permission.USER_UPDATE,
      Permission.USER_DELETE,
      Permission.CONTENT_READ,
      Permission.CONTENT_CREATE,
      Permission.CONTENT_UPDATE,
      Permission.CONTENT_DELETE,
      Permission.CONTENT_MODERATE,
      Permission.SYSTEM_CONFIG,
      Permission.SYSTEM_MONITOR
    ]
  },
  {
    role: UserRole.SUPER_ADMIN,
    permissions: Object.values(Permission)
  }
];
```

### 6.2.3 セッション管理
```typescript
// backend/src/middleware/session.ts
interface SessionConfig {
  secret: string;
  resave: boolean;
  saveUninitialized: boolean;
  cookie: {
    secure: boolean;
    httpOnly: boolean;
    maxAge: number;
    sameSite: 'strict' | 'lax' | 'none';
  };
  store: RedisStore;
}

const sessionConfig: SessionConfig = {
  secret: process.env.SESSION_SECRET!,
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production',
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000, // 24時間
    sameSite: 'strict'
  },
  store: new RedisStore({
    client: redisClient,
    prefix: 'sess:',
    ttl: 24 * 60 * 60 // 24時間
  })
};
```

## 6.3 暗号化・ハッシュ化

### 6.3.1 パスワードセキュリティ
```typescript
// backend/src/utils/crypto.ts
import bcrypt from 'bcryptjs';
import crypto from 'crypto';

export class PasswordManager {
  private static readonly SALT_ROUNDS = 12;
  private static readonly PEPPER = process.env.PASSWORD_PEPPER || 'eldonia-pepper';

  // パスワードハッシュ化
  static async hashPassword(password: string): Promise<string> {
    const pepperedPassword = password + this.PEPPER;
    return await bcrypt.hash(pepperedPassword, this.SALT_ROUNDS);
  }

  // パスワード検証
  static async verifyPassword(password: string, hash: string): Promise<boolean> {
    const pepperedPassword = password + this.PEPPER;
    return await bcrypt.compare(pepperedPassword, hash);
  }

  // 強力なパスワード生成
  static generateStrongPassword(length: number = 16): string {
    const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
    let password = '';
    
    // 最低1文字ずつ含める
    password += charset[Math.floor(Math.random() * 26)]; // 大文字
    password += charset[26 + Math.floor(Math.random() * 26)]; // 小文字
    password += charset[52 + Math.floor(Math.random() * 10)]; // 数字
    password += charset[62 + Math.floor(Math.random() * 8)]; // 記号
    
    // 残りをランダムに生成
    for (let i = 4; i < length; i++) {
      password += charset[Math.floor(Math.random() * charset.length)];
    }
    
    // シャッフル
    return password.split('').sort(() => Math.random() - 0.5).join('');
  }

  // パスワード強度チェック
  static validatePasswordStrength(password: string): {
    isValid: boolean;
    score: number;
    feedback: string[];
  } {
    const feedback: string[] = [];
    let score = 0;

    if (password.length >= 8) score += 1;
    else feedback.push('パスワードは8文字以上である必要があります');

    if (/[a-z]/.test(password)) score += 1;
    else feedback.push('小文字を含める必要があります');

    if (/[A-Z]/.test(password)) score += 1;
    else feedback.push('大文字を含める必要があります');

    if (/[0-9]/.test(password)) score += 1;
    else feedback.push('数字を含める必要があります');

    if (/[!@#$%^&*]/.test(password)) score += 1;
    else feedback.push('記号を含める必要があります');

    const isValid = score >= 4;

    return { isValid, score, feedback };
  }
}
```

### 6.3.2 データ暗号化
```typescript
// backend/src/utils/encryption.ts
import crypto from 'crypto';

export class EncryptionManager {
  private static readonly ALGORITHM = 'aes-256-gcm';
  private static readonly KEY_LENGTH = 32;
  private static readonly IV_LENGTH = 16;
  private static readonly TAG_LENGTH = 16;

  // 対称暗号化
  static encrypt(data: string, key: string): string {
    const iv = crypto.randomBytes(this.IV_LENGTH);
    const cipher = crypto.createCipher(this.ALGORITHM, key);
    
    let encrypted = cipher.update(data, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    
    const tag = cipher.getAuthTag();
    
    return iv.toString('hex') + ':' + tag.toString('hex') + ':' + encrypted;
  }

  // 対称復号化
  static decrypt(encryptedData: string, key: string): string {
    const parts = encryptedData.split(':');
    const iv = Buffer.from(parts[0], 'hex');
    const tag = Buffer.from(parts[1], 'hex');
    const encrypted = parts[2];
    
    const decipher = crypto.createDecipher(this.ALGORITHM, key);
    decipher.setAuthTag(tag);
    
    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    
    return decrypted;
  }

  // ハッシュ化 (一方向)
  static hash(data: string, salt?: string): string {
    const hash = crypto.createHash('sha256');
    const dataToHash = salt ? data + salt : data;
    return hash.update(dataToHash).digest('hex');
  }

  // 安全な乱数生成
  static generateRandomBytes(length: number): Buffer {
    return crypto.randomBytes(length);
  }

  // 安全なUUID生成
  static generateUUID(): string {
    return crypto.randomUUID();
  }
}
```

## 6.4 セキュリティミドルウェア

### 6.4.1 基本セキュリティヘッダー
```typescript
// backend/src/middleware/security.ts
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import slowDown from 'express-slow-down';

export const securityMiddleware = [
  // セキュリティヘッダー
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
        fontSrc: ["'self'", "https://fonts.gstatic.com"],
        imgSrc: ["'self'", "data:", "https:"],
        scriptSrc: ["'self'"],
        connectSrc: ["'self'", "https://api.eldonia.com"],
        frameSrc: ["'none'"],
        objectSrc: ["'none'"],
        upgradeInsecureRequests: []
      }
    },
    hsts: {
      maxAge: 31536000,
      includeSubDomains: true,
      preload: true
    },
    noSniff: true,
    referrerPolicy: { policy: 'strict-origin-when-cross-origin' }
  }),

  // レート制限
  rateLimit({
    windowMs: 15 * 60 * 1000, // 15分
    max: 100, // 最大100リクエスト
    message: {
      error: 'Too many requests',
      message: 'Please try again later'
    },
    standardHeaders: true,
    legacyHeaders: false
  }),

  // スローダウン
  slowDown({
    windowMs: 15 * 60 * 1000, // 15分
    delayAfter: 50, // 50リクエスト後に遅延開始
    delayMs: 500 // 500ms遅延
  })
];
```

### 6.4.2 認証ミドルウェア
```typescript
// backend/src/middleware/auth.ts
import jwt from 'jsonwebtoken';
import { Request, Response, NextFunction } from 'express';

interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email: string;
    role: string;
    permissions: string[];
  };
}

export const authenticateToken = (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): void => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    res.status(401).json({ error: 'Access token required' });
    return;
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET!) as any;
    req.user = {
      id: decoded.id,
      email: decoded.email,
      role: decoded.role,
      permissions: decoded.permissions
    };
    next();
  } catch (error) {
    res.status(403).json({ error: 'Invalid or expired token' });
  }
};

export const requirePermission = (permission: string) => {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction): void => {
    if (!req.user) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    if (!req.user.permissions.includes(permission)) {
      res.status(403).json({ error: 'Insufficient permissions' });
      return;
    }

    next();
  };
};

export const requireRole = (role: string) => {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction): void => {
    if (!req.user) {
      res.status(401).json({ error: 'Authentication required' });
      return;
    }

    if (req.user.role !== role) {
      res.status(403).json({ error: 'Insufficient role' });
      return;
    }

    next();
  };
};
```

### 6.4.3 入力検証・サニタイゼーション
```typescript
// backend/src/middleware/validation.ts
import Joi from 'joi';
import { Request, Response, NextFunction } from 'express';
import DOMPurify from 'isomorphic-dompurify';

// 入力検証スキーマ
export const validationSchemas = {
  userRegistration: Joi.object({
    email: Joi.string().email().required(),
    password: Joi.string().min(8).required(),
    name: Joi.string().min(2).max(50).required(),
    agreeToTerms: Joi.boolean().valid(true).required()
  }),

  userLogin: Joi.object({
    email: Joi.string().email().required(),
    password: Joi.string().required()
  }),

  contentUpload: Joi.object({
    title: Joi.string().min(1).max(200).required(),
    description: Joi.string().max(1000).optional(),
    category: Joi.string().required(),
    tags: Joi.array().items(Joi.string()).max(10).optional()
  })
};

// 入力検証ミドルウェア
export const validateInput = (schema: Joi.ObjectSchema) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    const { error } = schema.validate(req.body);
    
    if (error) {
      res.status(400).json({
        error: 'Validation failed',
        details: error.details.map(detail => detail.message)
      });
      return;
    }
    
    next();
  };
};

// XSS対策・サニタイゼーション
export const sanitizeInput = (req: Request, res: Response, next: NextFunction): void => {
  if (req.body) {
    Object.keys(req.body).forEach(key => {
      if (typeof req.body[key] === 'string') {
        req.body[key] = DOMPurify.sanitize(req.body[key]);
      }
    });
  }
  
  next();
};

// SQLインジェクション対策
export const preventSQLInjection = (req: Request, res: Response, next: NextFunction): void => {
  const sqlPatterns = [
    /(\b(select|insert|update|delete|drop|create|alter|exec|execute|union|script)\b)/i,
    /(--|#|\/\*|\*\/|xp_|sp_)/i,
    /(\b(and|or)\b\s+\d+\s*[=<>])/i
  ];

  const checkValue = (value: any): boolean => {
    if (typeof value === 'string') {
      return sqlPatterns.some(pattern => pattern.test(value));
    }
    if (typeof value === 'object' && value !== null) {
      return Object.values(value).some(checkValue);
    }
    return false;
  };

  if (checkValue(req.body) || checkValue(req.query) || checkValue(req.params)) {
    res.status(400).json({ error: 'Invalid input detected' });
    return;
  }

  next();
};
```

## 6.5 監査・ログ管理

### 6.5.1 セキュリティログ
```typescript
// backend/src/utils/audit.ts
interface AuditLog {
  id: string;
  timestamp: Date;
  userId?: string;
  userEmail?: string;
  action: string;
  resource: string;
  resourceId?: string;
  details: any;
  ipAddress: string;
  userAgent: string;
  success: boolean;
  errorMessage?: string;
}

export class AuditLogger {
  static async logSecurityEvent(
    userId: string | undefined,
    userEmail: string | undefined,
    action: string,
    resource: string,
    resourceId: string | undefined,
    details: any,
    req: Request,
    success: boolean,
    errorMessage?: string
  ): Promise<void> {
    const auditLog: AuditLog = {
      id: crypto.randomUUID(),
      timestamp: new Date(),
      userId,
      userEmail,
      action,
      resource,
      resourceId,
      details,
      ipAddress: req.ip || req.connection.remoteAddress || 'unknown',
      userAgent: req.get('User-Agent') || 'unknown',
      success,
      errorMessage
    };

    // データベースに保存
    await this.saveAuditLog(auditLog);
    
    // セキュリティイベントの場合は即座にアラート
    if (!success || this.isSecurityEvent(action)) {
      await this.sendSecurityAlert(auditLog);
    }
  }

  private static isSecurityEvent(action: string): boolean {
    const securityActions = [
      'login_failed',
      'permission_denied',
      'suspicious_activity',
      'data_access_unauthorized',
      'admin_action'
    ];
    return securityActions.includes(action);
  }

  private static async saveAuditLog(log: AuditLog): Promise<void> {
    // PostgreSQLに保存
    const query = `
      INSERT INTO audit_logs (
        id, timestamp, user_id, user_email, action, resource, 
        resource_id, details, ip_address, user_agent, success, error_message
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
    `;
    
    await db.query(query, [
      log.id, log.timestamp, log.userId, log.userEmail, log.action,
      log.resource, log.resourceId, log.details, log.ipAddress,
      log.userAgent, log.success, log.errorMessage
    ]);
  }

  private static async sendSecurityAlert(log: AuditLog): Promise<void> {
    // Slack、メール、SMSなどでアラート送信
    const alertMessage = `
🚨 Security Alert
Action: ${log.action}
Resource: ${log.resource}
User: ${log.userEmail || 'Unknown'}
IP: ${log.ipAddress}
Time: ${log.timestamp.toISOString()}
Success: ${log.success}
${log.errorMessage ? `Error: ${log.errorMessage}` : ''}
    `;
    
    // アラート送信処理
    await this.sendSlackAlert(alertMessage);
    await this.sendEmailAlert(alertMessage);
  }
}
```

### 6.5.2 ログ監視・アラート
```typescript
// backend/src/utils/logMonitor.ts
export class LogMonitor {
  private static readonly SUSPICIOUS_PATTERNS = [
    /failed login attempts/i,
    /permission denied/i,
    /sql injection/i,
    /xss attack/i,
    /brute force/i,
    /suspicious ip/i
  ];

  private static readonly RATE_LIMITS = {
    failedLogins: { max: 5, window: 15 * 60 * 1000 }, // 15分で5回
    suspiciousActions: { max: 10, window: 60 * 60 * 1000 }, // 1時間で10回
    adminActions: { max: 50, window: 60 * 60 * 1000 } // 1時間で50回
  };

  static async analyzeLogs(): Promise<void> {
    // リアルタイムログ分析
    const recentLogs = await this.getRecentLogs();
    
    for (const log of recentLogs) {
      await this.checkSuspiciousPatterns(log);
      await this.checkRateLimits(log);
      await this.checkAnomalies(log);
    }
  }

  private static async checkSuspiciousPatterns(log: any): Promise<void> {
    const logContent = JSON.stringify(log).toLowerCase();
    
    for (const pattern of this.SUSPICIOUS_PATTERNS) {
      if (pattern.test(logContent)) {
        await this.triggerAlert('Suspicious pattern detected', log);
      }
    }
  }

  private static async checkRateLimits(log: any): Promise<void> {
    const key = `${log.userId || log.ipAddress}:${log.action}`;
    const count = await this.getActionCount(key, this.RATE_LIMITS.failedLogins.window);
    
    if (count > this.RATE_LIMITS.failedLogins.max) {
      await this.triggerAlert('Rate limit exceeded', log);
      await this.blockUser(log.userId || log.ipAddress);
    }
  }

  private static async checkAnomalies(log: any): Promise<void> {
    // 機械学習による異常検知
    const anomalyScore = await this.calculateAnomalyScore(log);
    
    if (anomalyScore > 0.8) {
      await this.triggerAlert('Anomaly detected', log);
    }
  }
}
```

## 6.6 脅威モデリング

### 6.6.1 STRIDE脅威モデル
```
S - Spoofing (なりすまし)
├── ユーザー認証の偽装
├── セッションの乗っ取り
└── フィッシング攻撃

T - Tampering (改ざん)
├── データの不正変更
├── 設定ファイルの改ざん
└── ログの改ざん

R - Repudiation (否認)
├── 操作ログの削除
├── 監査証跡の改ざん
└── アクセス履歴の偽装

I - Information Disclosure (情報漏洩)
├── 機密データの露出
├── エラーメッセージからの情報収集
└── 設定情報の漏洩

D - Denial of Service (サービス拒否)
├── DDoS攻撃
├── リソース枯渇攻撃
└── アプリケーション層攻撃

E - Elevation of Privilege (権限昇格)
├── 管理者権限の不正取得
├── ロールの不正変更
└── 権限の越権使用
```

### 6.6.2 脅威対策マトリックス
| 脅威 | リスクレベル | 対策 | 実装状況 |
|------|-------------|------|----------|
| SQLインジェクション | 高 | プリペアドステートメント、入力検証 | ✅ |
| XSS攻撃 | 高 | 出力エスケープ、CSP | ✅ |
| CSRF攻撃 | 中 | CSRFトークン、SameSite Cookie | ✅ |
| セッションハイジャック | 高 | HTTPS、HttpOnly Cookie | ✅ |
| ブルートフォース | 中 | レート制限、アカウントロック | ✅ |
| 権限昇格 | 高 | RBAC、最小権限の原則 | ✅ |

## 6.7 セキュリティテスト

### 6.7.1 自動化セキュリティテスト
```typescript
// backend/src/tests/security.test.ts
import request from 'supertest';
import app from '../server';

describe('Security Tests', () => {
  describe('Authentication & Authorization', () => {
    it('should reject requests without valid JWT', async () => {
      const response = await request(app)
        .get('/api/users/profile')
        .expect(401);
      
      expect(response.body.error).toBe('Access token required');
    });

    it('should reject expired JWT', async () => {
      const expiredToken = 'expired.jwt.token';
      
      const response = await request(app)
        .get('/api/users/profile')
        .set('Authorization', `Bearer ${expiredToken}`)
        .expect(403);
      
      expect(response.body.error).toBe('Invalid or expired token');
    });

    it('should enforce role-based access control', async () => {
      const userToken = await generateUserToken('user');
      
      const response = await request(app)
        .get('/api/admin/users')
        .set('Authorization', `Bearer ${userToken}`)
        .expect(403);
      
      expect(response.body.error).toBe('Insufficient permissions');
    });
  });

  describe('Input Validation', () => {
    it('should prevent SQL injection', async () => {
      const maliciousInput = "'; DROP TABLE users; --";
      
      const response = await request(app)
        .post('/api/users/search')
        .send({ query: maliciousInput })
        .expect(400);
      
      expect(response.body.error).toBe('Invalid input detected');
    });

    it('should prevent XSS attacks', async () => {
      const maliciousInput = '<script>alert("XSS")</script>';
      
      const response = await request(app)
        .post('/api/content')
        .send({ title: maliciousInput })
        .expect(400);
      
      expect(response.body.error).toBe('Validation failed');
    });
  });

  describe('Rate Limiting', () => {
    it('should enforce rate limits', async () => {
      const promises = Array(101).fill(0).map(() =>
        request(app)
          .post('/api/auth/login')
          .send({ email: 'test@example.com', password: 'password' })
      );
      
      const responses = await Promise.all(promises);
      const tooManyRequests = responses.filter(r => r.status === 429);
      
      expect(tooManyRequests.length).toBeGreaterThan(0);
    });
  });
});
```

### 6.7.2 ペネトレーションテスト
```bash
# OWASP ZAP による自動スキャン
zap-cli quick-scan --self-contained \
  --spider http://localhost:3001 \
  --ajax-spider \
  --scan \
  --alert-level High \
  --output-format json \
  --output eldonia-security-scan.json

# Nmap によるポートスキャン
nmap -sS -sV -O -p- localhost

# SQLMap によるSQLインジェクションテスト
sqlmap -u "http://localhost:3001/api/users/search" \
  --data="query=test" \
  --level=5 \
  --risk=3 \
  --batch

# Nikto によるWeb脆弱性スキャン
nikto -h http://localhost:3001 -o eldonia-nikto-scan.txt
```

## 6.8 インシデント対応

### 6.8.1 セキュリティインシデント対応手順
```
1. 検知・報告
   ├── 自動検知システム
   ├── ユーザー報告
   └── 外部からの報告

2. 初期対応
   ├── 影響範囲の特定
   ├── 一時的な対策実施
   └── 関係者への通知

3. 調査・分析
   ├── ログ分析
   ├── フォレンジック調査
   └── 原因特定

4. 復旧・対策
   ├── システム復旧
   ├── 恒久的対策実施
   └── セキュリティ強化

5. 事後対応
   ├── 報告書作成
   ├── 再発防止策
   └── 従業員教育
```

### 6.8.2 緊急時連絡体制
```
セキュリティインシデント発生時
├── 即座の対応
│   ├── システム管理者 (24時間対応)
│   ├── セキュリティチーム
│   └── 経営陣
├── 30分以内
│   ├── 技術チーム全員
│   ├── 法務・コンプライアンス
│   └── 広報・PR
└── 1時間以内
    ├── 顧客・パートナー
    ├── 規制当局
    └── メディア対応
```

---

**次のセクション**: 07. 翻訳・多言語設計
