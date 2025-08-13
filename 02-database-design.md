# システム設計書 - データベース設計

## 2. データベース設計

### 2.1 データベース概要

#### 2.1.1 データベース構成
- **メインデータベース**: PostgreSQL 15+ (Aurora)
- **キャッシュデータベース**: Redis (ElastiCache)
- **検索エンジン**: Elasticsearch/OpenSearch
- **ファイルストレージ**: S3 + CloudFront

#### 2.1.2 設計方針
- **正規化**: 第3正規形まで適用
- **パフォーマンス**: 適切なインデックス設計
- **スケーラビリティ**: 水平分割・シャーディング対応
- **セキュリティ**: 暗号化・アクセス制御
- **バックアップ**: 日次フルバックアップ + 1時間間隔増分バックアップ

### 2.2 ER図

```
┌─────────────────────────────────────────────────────────────────┐
│                           ER図                                  │
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│  │    users    │    │user_profiles│    │subscription │        │
│  │             │    │             │    │   _plans    │        │
│  │ PK: id      │◄──►│ PK: id      │    │ PK: id      │        │
│  │ username    │    │ user_id     │    │ name        │        │
│  │ email       │    │ display_name│    │ price       │        │
│  │ password    │    │ avatar_url  │    │ features    │        │
│  │ plan        │    │ skills      │    └─────────────┘        │
│  └─────────────┘    └─────────────┘                           │
│         │                                                      │
│         │                                                      │
│         ▼                                                      │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│  │media_contents│    │  categories │    │     tags    │        │
│  │             │    │             │    │             │        │
│  │ PK: id      │    │ PK: id      │    │ PK: id      │        │
│  │ user_id     │    │ name        │    │ name        │        │
│  │ title       │    │ description │    │ usage_count │        │
│  │ content_type│    │ parent_id   │    └─────────────┘        │
│  │ file_url    │    └─────────────┘                           │
│  └─────────────┘                                              │
│         │                                                      │
│         │                                                      │
│         ▼                                                      │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│  │   groups    │    │group_members│    │forum_posts  │        │
│  │             │    │             │    │             │        │
│  │ PK: id      │    │ PK: id      │    │ PK: id      │        │
│  │ name        │    │ group_id    │    │ group_id    │        │
│  │ owner_id    │    │ user_id     │    │ user_id     │        │
│  │ description │    │ role        │    │ title       │        │
│  └─────────────┘    └─────────────┘    │ content     │        │
│         │                              └─────────────┘        │
│         │                                                      │
│         ▼                                                      │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│  │   events    │    │   products  │    │  payments   │        │
│  │             │    │             │    │             │        │
│  │ PK: id      │    │ PK: id      │    │ PK: id      │        │
│  │ title       │    │ seller_id   │    │ user_id     │        │
│  │ organizer_id│    │ name        │    │ amount      │        │
│  │ start_date  │    │ price       │    │ currency    │        │
│  │ end_date    │    │ stock_qty   │    │ status      │        │
│  └─────────────┘    └─────────────┘    └─────────────┘        │
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│  │translations │    │user_language│    │translation  │        │
│  │             │    │_preferences │    │   _cache    │        │
│  │ PK: id      │    │ PK: id      │    │ PK: id      │        │
│  │ content_id  │    │ user_id     │    │ text_hash   │        │
│  │ content_type│    │ primary_lang│    │ source_lang │        │
│  │ source_lang │    │ region      │    │ target_lang │        │
│  │ target_lang │    │ timezone    │    │ translated  │        │
│  │ translated  │    │ currency    │    │ expires_at  │        │
│  └─────────────┘    └─────────────┘    └─────────────┘        │
└─────────────────────────────────────────────────────────────────┘
```

### 2.3 テーブル設計詳細

#### 2.3.1 ユーザー管理テーブル

```sql
-- ユーザーテーブル
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username VARCHAR(50) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  profile_image_url VARCHAR(500),
  bio TEXT,
  website_url VARCHAR(500),
  location VARCHAR(100),
  is_verified BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  subscription_plan VARCHAR(20) DEFAULT 'free',
  email_verified_at TIMESTAMP,
  last_login_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ユーザープロフィール詳細
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  display_name VARCHAR(100),
  avatar_url VARCHAR(500),
  cover_image_url VARCHAR(500),
  social_links JSONB,
  skills TEXT[],
  achievements JSONB,
  birth_date DATE,
  gender VARCHAR(20),
  occupation VARCHAR(100),
  company VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- サブスクリプションプラン
CREATE TABLE subscription_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(50) NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  billing_cycle VARCHAR(20) DEFAULT 'monthly',
  features JSONB,
  max_uploads INTEGER,
  max_storage_gb INTEGER,
  max_groups INTEGER,
  max_events INTEGER,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ユーザーサブスクリプション履歴
CREATE TABLE user_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  plan_id UUID REFERENCES subscription_plans(id),
  status VARCHAR(20) DEFAULT 'active',
  start_date TIMESTAMP NOT NULL,
  end_date TIMESTAMP NOT NULL,
  auto_renew BOOLEAN DEFAULT TRUE,
  payment_method_id VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 2.3.2 コンテンツ管理テーブル

```sql
-- メディアコンテンツ
CREATE TABLE media_contents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(200) NOT NULL,
  description TEXT,
  content_type VARCHAR(20) NOT NULL CHECK (content_type IN ('video', 'music', 'manga', 'story', 'image')),
  file_url VARCHAR(500) NOT NULL,
  thumbnail_url VARCHAR(500),
  duration_seconds INTEGER,
  file_size_bytes BIGINT,
  resolution VARCHAR(20),
  format VARCHAR(20),
  tags TEXT[],
  category_id UUID REFERENCES categories(id),
  is_public BOOLEAN DEFAULT TRUE,
  is_featured BOOLEAN DEFAULT FALSE,
  view_count INTEGER DEFAULT 0,
  like_count INTEGER DEFAULT 0,
  share_count INTEGER DEFAULT 0,
  download_count INTEGER DEFAULT 0,
  status VARCHAR(20) DEFAULT 'published',
  published_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- カテゴリ
CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  description TEXT,
  slug VARCHAR(100) UNIQUE NOT NULL,
  parent_id UUID REFERENCES categories(id),
  icon_url VARCHAR(500),
  color VARCHAR(7),
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- タグ
CREATE TABLE tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(50) UNIQUE NOT NULL,
  slug VARCHAR(50) UNIQUE NOT NULL,
  description TEXT,
  usage_count INTEGER DEFAULT 0,
  is_trending BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- コンテンツタグ関連
CREATE TABLE content_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content_id UUID REFERENCES media_contents(id) ON DELETE CASCADE,
  tag_id UUID REFERENCES tags(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(content_id, tag_id)
);
```

#### 2.3.3 コミュニティ機能テーブル

```sql
-- グループ・コミュニティ
CREATE TABLE groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  description TEXT,
  slug VARCHAR(100) UNIQUE NOT NULL,
  owner_id UUID REFERENCES users(id),
  cover_image_url VARCHAR(500),
  icon_url VARCHAR(500),
  is_public BOOLEAN DEFAULT TRUE,
  is_featured BOOLEAN DEFAULT FALSE,
  member_count INTEGER DEFAULT 0,
  post_count INTEGER DEFAULT 0,
  rules TEXT[],
  tags TEXT[],
  status VARCHAR(20) DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- グループメンバー
CREATE TABLE group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'moderator', 'member')),
  joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  invited_by UUID REFERENCES users(id),
  status VARCHAR(20) DEFAULT 'active',
  UNIQUE(group_id, user_id)
);

-- 掲示板投稿
CREATE TABLE forum_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES forum_posts(id),
  title VARCHAR(200) NOT NULL,
  content TEXT NOT NULL,
  content_html TEXT,
  is_pinned BOOLEAN DEFAULT FALSE,
  is_locked BOOLEAN DEFAULT FALSE,
  view_count INTEGER DEFAULT 0,
  reply_count INTEGER DEFAULT 0,
  like_count INTEGER DEFAULT 0,
  status VARCHAR(20) DEFAULT 'published',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 投稿いいね
CREATE TABLE post_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES forum_posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(post_id, user_id)
);
```

#### 2.3.4 イベント・ショップテーブル

```sql
-- イベント
CREATE TABLE events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(200) NOT NULL,
  description TEXT,
  slug VARCHAR(200) UNIQUE NOT NULL,
  organizer_id UUID REFERENCES users(id),
  start_date TIMESTAMP NOT NULL,
  end_date TIMESTAMP NOT NULL,
  location VARCHAR(200),
  venue_type VARCHAR(50) CHECK (venue_type IN ('online', 'offline', 'hybrid')),
  venue_url VARCHAR(500),
  max_participants INTEGER,
  current_participants INTEGER DEFAULT 0,
  ticket_price DECIMAL(10,2),
  currency VARCHAR(3) DEFAULT 'JPY',
  cover_image_url VARCHAR(500),
  tags TEXT[],
  category_id UUID REFERENCES categories(id),
  status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'cancelled', 'completed')),
  is_featured BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- イベント参加者
CREATE TABLE event_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  ticket_type VARCHAR(50),
  payment_status VARCHAR(20) DEFAULT 'pending',
  joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(event_id, user_id)
);

-- 商品
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id UUID REFERENCES users(id),
  name VARCHAR(200) NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL,
  currency VARCHAR(3) DEFAULT 'JPY',
  stock_quantity INTEGER DEFAULT 0,
  category_id UUID REFERENCES categories(id),
  images JSONB,
  tags TEXT[],
  is_active BOOLEAN DEFAULT TRUE,
  is_featured BOOLEAN DEFAULT FALSE,
  view_count INTEGER DEFAULT 0,
  sold_count INTEGER DEFAULT 0,
  status VARCHAR(20) DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 2.3.5 多言語・翻訳テーブル

```sql
-- 多言語・翻訳管理
CREATE TABLE translations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content_id UUID NOT NULL,
  content_type VARCHAR(20) NOT NULL CHECK (content_type IN ('user', 'media', 'group', 'event', 'product', 'post')),
  original_language VARCHAR(10) NOT NULL,
  target_language VARCHAR(10) NOT NULL,
  field_name VARCHAR(50) NOT NULL, -- title, description, content
  original_text TEXT NOT NULL,
  translated_text TEXT NOT NULL,
  translation_quality_score DECIMAL(3,2),
  is_ai_generated BOOLEAN DEFAULT TRUE,
  translator_id UUID REFERENCES users(id),
  review_status VARCHAR(20) DEFAULT 'pending',
  reviewed_by UUID REFERENCES users(id),
  reviewed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(content_id, content_type, target_language, field_name)
);

-- 言語設定・地域設定
CREATE TABLE user_language_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  primary_language VARCHAR(10) NOT NULL DEFAULT 'ja',
  secondary_languages VARCHAR(10)[],
  region VARCHAR(10),
  timezone VARCHAR(50),
  currency VARCHAR(3) DEFAULT 'JPY',
  date_format VARCHAR(20) DEFAULT 'YYYY-MM-DD',
  time_format VARCHAR(20) DEFAULT '24h',
  number_format VARCHAR(20) DEFAULT '1,234.56',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 翻訳キャッシュ
CREATE TABLE translation_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  original_text_hash VARCHAR(64) NOT NULL,
  source_language VARCHAR(10) NOT NULL,
  target_language VARCHAR(10) NOT NULL,
  translated_text TEXT NOT NULL,
  cache_expires_at TIMESTAMP NOT NULL,
  usage_count INTEGER DEFAULT 0,
  last_used_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(original_text_hash, source_language, target_language)
);

-- サポート言語
CREATE TABLE supported_languages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  language_code VARCHAR(10) UNIQUE NOT NULL,
  language_name VARCHAR(100) NOT NULL,
  native_name VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_default BOOLEAN DEFAULT FALSE,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 2.4 インデックス設計

#### 2.4.1 主要インデックス

```sql
-- ユーザーテーブル
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_subscription_plan ON users(subscription_plan);
CREATE INDEX idx_users_created_at ON users(created_at);

-- メディアコンテンツ
CREATE INDEX idx_media_contents_user_id ON media_contents(user_id);
CREATE INDEX idx_media_contents_content_type ON media_contents(content_type);
CREATE INDEX idx_media_contents_category_id ON media_contents(category_id);
CREATE INDEX idx_media_contents_created_at ON media_contents(created_at);
CREATE INDEX idx_media_contents_status ON media_contents(status);
CREATE INDEX idx_media_contents_tags ON media_contents USING GIN(tags);

-- グループ
CREATE INDEX idx_groups_owner_id ON groups(owner_id);
CREATE INDEX idx_groups_status ON groups(status);
CREATE INDEX idx_groups_created_at ON groups(created_at);
CREATE INDEX idx_groups_tags ON groups USING GIN(tags);

-- イベント
CREATE INDEX idx_events_organizer_id ON events(organizer_id);
CREATE INDEX idx_events_start_date ON events(start_date);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_category_id ON events(category_id);

-- 翻訳
CREATE INDEX idx_translations_content ON translations(content_id, content_type);
CREATE INDEX idx_translations_language ON translations(original_language, target_language);
CREATE INDEX idx_translations_quality ON translations(translation_quality_score);

-- 翻訳キャッシュ
CREATE INDEX idx_translation_cache_hash ON translation_cache(original_text_hash);
CREATE INDEX idx_translation_cache_expires ON translation_cache(cache_expires_at);
```

#### 2.4.2 複合インデックス

```sql
-- 検索最適化
CREATE INDEX idx_media_search ON media_contents(content_type, status, created_at) 
  WHERE is_public = true;

-- ユーザーアクティビティ
CREATE INDEX idx_user_activity ON media_contents(user_id, created_at, content_type);

-- グループ投稿
CREATE INDEX idx_group_posts ON forum_posts(group_id, created_at, status);

-- イベント検索
CREATE INDEX idx_event_search ON events(status, start_date, venue_type) 
  WHERE status = 'published';
```

### 2.5 パーティショニング戦略

#### 2.5.1 テーブルパーティショニング

```sql
-- メディアコンテンツ（日付別パーティショニング）
CREATE TABLE media_contents_2024 PARTITION OF media_contents
  FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

CREATE TABLE media_contents_2025 PARTITION OF media_contents
  FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

-- 翻訳キャッシュ（言語別パーティショニング）
CREATE TABLE translation_cache_ja_en PARTITION OF translation_cache
  FOR VALUES IN ('ja', 'en');

CREATE TABLE translation_cache_other PARTITION OF translation_cache
  FOR VALUES IN ('ko', 'zh', 'es', 'fr', 'de');
```

### 2.6 データ移行・バックアップ戦略

#### 2.6.1 バックアップ戦略
- **フルバックアップ**: 日次（深夜2時）
- **増分バックアップ**: 1時間間隔
- **WALアーカイブ**: リアルタイム
- **S3への長期保存**: 30日間保持

#### 2.6.2 データ移行戦略
- **ゼロダウンタイム移行**: レプリケーション活用
- **段階的移行**: 機能別・テーブル別移行
- **ロールバック計画**: 移行前スナップショット保持

---

**文書情報**
- 作成日: 2024年12月
- バージョン: 1.0
- 作成者: データベース設計チーム
- 承認者: システムアーキテクト
