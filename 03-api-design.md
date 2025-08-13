# システム設計書 - API設計

## 3. API設計

### 3.1 API概要

#### 3.1.1 API設計方針
- **RESTful API**: 標準的なHTTPメソッドとステータスコードの使用
- **GraphQL API**: 柔軟なデータ取得のためのGraphQLエンドポイント
- **OpenAPI 3.0**: 標準化されたAPI仕様書の作成
- **バージョニング**: URLパスによるAPIバージョン管理
- **認証・認可**: JWT + OAuth 2.0によるセキュアな認証

#### 3.1.2 API構成
```
Base URL: https://api.creator-community.com/v1
GraphQL: https://api.creator-community.com/graphql
WebSocket: wss://api.creator-community.com/ws
```

### 3.2 RESTful API設計

#### 3.2.1 認証・認可API

```yaml
# OpenAPI 3.0 仕様
openapi: 3.0.3
info:
  title: クリエイターコミュニティAPI
  version: 1.0.0
  description: クリエイターコミュニティポータルサイトのAPI仕様

paths:
  /auth/register:
    post:
      summary: ユーザー登録
      tags: [認証]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - username
                - email
                - password
              properties:
                username:
                  type: string
                  minLength: 3
                  maxLength: 50
                email:
                  type: string
                  format: email
                password:
                  type: string
                  minLength: 8
                display_name:
                  type: string
                  maxLength: 100
      responses:
        '201':
          description: ユーザー登録成功
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'
        '400':
          description: バリデーションエラー
        '409':
          description: ユーザー名またはメールアドレスが既に存在

  /auth/login:
    post:
      summary: ユーザーログイン
      tags: [認証]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - email
                - password
              properties:
                email:
                  type: string
                  format: email
                password:
                  type: string
      responses:
        '200':
          description: ログイン成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  user:
                    $ref: '#/components/schemas/User'
                  access_token:
                    type: string
                  refresh_token:
                    type: string
                  expires_in:
                    type: integer
        '401':
          description: 認証失敗

  /auth/refresh:
    post:
      summary: アクセストークン更新
      tags: [認証]
      security:
        - BearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - refresh_token
              properties:
                refresh_token:
                  type: string
      responses:
        '200':
          description: トークン更新成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  access_token:
                    type: string
                  expires_in:
                    type: integer

  /auth/logout:
    post:
      summary: ログアウト
      tags: [認証]
      security:
        - BearerAuth: []
      responses:
        '200':
          description: ログアウト成功

  /auth/2fa/enable:
    post:
      summary: 2FA有効化
      tags: [認証]
      security:
        - BearerAuth: []
      responses:
        '200':
          description: 2FA有効化成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  qr_code:
                    type: string
                  secret:
                    type: string

  /auth/2fa/verify:
    post:
      summary: 2FA認証
      tags: [認証]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - token
              properties:
                token:
                  type: string
                  minLength: 6
                  maxLength: 6
      responses:
        '200':
          description: 2FA認証成功
```

#### 3.2.2 ユーザー管理API

```yaml
  /users:
    get:
      summary: ユーザー一覧取得
      tags: [ユーザー]
      security:
        - BearerAuth: []
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            minimum: 1
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            minimum: 1
            maximum: 100
            default: 20
        - name: search
          in: query
          schema:
            type: string
        - name: category
          in: query
          schema:
            type: string
      responses:
        '200':
          description: ユーザー一覧取得成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  users:
                    type: array
                    items:
                      $ref: '#/components/schemas/User'
                  pagination:
                    $ref: '#/components/schemas/Pagination'

  /users/{user_id}:
    get:
      summary: ユーザー詳細取得
      tags: [ユーザー]
      parameters:
        - name: user_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: ユーザー詳細取得成功
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserDetail'
        '404':
          description: ユーザーが見つかりません

    put:
      summary: ユーザー情報更新
      tags: [ユーザー]
      security:
        - BearerAuth: []
      parameters:
        - name: user_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/UserUpdate'
      responses:
        '200':
          description: ユーザー情報更新成功
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'

  /users/{user_id}/profile:
    get:
      summary: ユーザープロフィール取得
      tags: [ユーザー]
      parameters:
        - name: user_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: プロフィール取得成功
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserProfile'

  /users/{user_id}/contents:
    get:
      summary: ユーザーコンテンツ一覧取得
      tags: [ユーザー]
      parameters:
        - name: user_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
        - name: content_type
          in: query
          schema:
            type: string
            enum: [video, music, manga, story, image]
        - name: page
          in: query
          schema:
            type: integer
            minimum: 1
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            minimum: 1
            maximum: 100
            default: 20
      responses:
        '200':
          description: コンテンツ一覧取得成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  contents:
                    type: array
                    items:
                      $ref: '#/components/schemas/MediaContent'
                  pagination:
                    $ref: '#/components/schemas/Pagination'
```

#### 3.2.3 コンテンツ管理API

```yaml
  /contents:
    get:
      summary: コンテンツ一覧取得
      tags: [コンテンツ]
      parameters:
        - name: content_type
          in: query
          schema:
            type: string
            enum: [video, music, manga, story, image]
        - name: category_id
          in: query
          schema:
            type: string
            format: uuid
        - name: tags
          in: query
          schema:
            type: string
        - name: sort
          in: query
          schema:
            type: string
            enum: [latest, popular, trending]
            default: latest
        - name: page
          in: query
          schema:
            type: integer
            minimum: 1
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            minimum: 1
            maximum: 100
            default: 20
      responses:
        '200':
          description: コンテンツ一覧取得成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  contents:
                    type: array
                    items:
                      $ref: '#/components/schemas/MediaContent'
                  pagination:
                    $ref: '#/components/schemas/Pagination'

    post:
      summary: コンテンツ作成
      tags: [コンテンツ]
      security:
        - BearerAuth: []
      requestBody:
        required: true
        content:
          multipart/form-data:
            schema:
              type: object
              required:
                - title
                - content_type
                - file
              properties:
                title:
                  type: string
                  maxLength: 200
                description:
                  type: string
                content_type:
                  type: string
                  enum: [video, music, manga, story, image]
                file:
                  type: string
                  format: binary
                thumbnail:
                  type: string
                  format: binary
                tags:
                  type: string
                category_id:
                  type: string
                  format: uuid
                is_public:
                  type: boolean
                  default: true
      responses:
        '201':
          description: コンテンツ作成成功
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/MediaContent'

  /contents/{content_id}:
    get:
      summary: コンテンツ詳細取得
      tags: [コンテンツ]
      parameters:
        - name: content_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: コンテンツ詳細取得成功
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/MediaContentDetail'
        '404':
          description: コンテンツが見つかりません

    put:
      summary: コンテンツ更新
      tags: [コンテンツ]
      security:
        - BearerAuth: []
      parameters:
        - name: content_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/MediaContentUpdate'
      responses:
        '200':
          description: コンテンツ更新成功
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/MediaContent'

    delete:
      summary: コンテンツ削除
      tags: [コンテンツ]
      security:
        - BearerAuth: []
      parameters:
        - name: content_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '204':
          description: コンテンツ削除成功

  /contents/{content_id}/like:
    post:
      summary: コンテンツいいね
      tags: [コンテンツ]
      security:
        - BearerAuth: []
      parameters:
        - name: content_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: いいね成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  liked:
                    type: boolean
                  like_count:
                    type: integer

  /contents/{content_id}/share:
    post:
      summary: コンテンツシェア
      tags: [コンテンツ]
      security:
        - BearerAuth: []
      parameters:
        - name: content_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: シェア成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  share_count:
                    type: integer
                  share_url:
                    type: string
```

#### 3.2.4 コミュニティ機能API

```yaml
  /groups:
    get:
      summary: グループ一覧取得
      tags: [コミュニティ]
      parameters:
        - name: category
          in: query
          schema:
            type: string
        - name: tags
          in: query
          schema:
            type: string
        - name: sort
          in: query
          schema:
            type: string
            enum: [latest, popular, member_count]
            default: latest
        - name: page
          in: query
          schema:
            type: integer
            minimum: 1
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            minimum: 1
            maximum: 100
            default: 20
      responses:
        '200':
          description: グループ一覧取得成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  groups:
                    type: array
                    items:
                      $ref: '#/components/schemas/Group'
                  pagination:
                    $ref: '#/components/schemas/Pagination'

    post:
      summary: グループ作成
      tags: [コミュニティ]
      security:
        - BearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/GroupCreate'
      responses:
        '201':
          description: グループ作成成功
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Group'

  /groups/{group_id}:
    get:
      summary: グループ詳細取得
      tags: [コミュニティ]
      parameters:
        - name: group_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: グループ詳細取得成功
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/GroupDetail'
        '404':
          description: グループが見つかりません

  /groups/{group_id}/posts:
    get:
      summary: グループ投稿一覧取得
      tags: [コミュニティ]
      parameters:
        - name: group_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
        - name: sort
          in: query
          schema:
            type: string
            enum: [latest, popular, pinned]
            default: latest
        - name: page
          in: query
          schema:
            type: integer
            minimum: 1
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            minimum: 1
            maximum: 100
            default: 20
      responses:
        '200':
          description: 投稿一覧取得成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  posts:
                    type: array
                    items:
                      $ref: '#/components/schemas/ForumPost'
                  pagination:
                    $ref: '#/components/schemas/Pagination'

    post:
      summary: グループ投稿作成
      tags: [コミュニティ]
      security:
        - BearerAuth: []
      parameters:
        - name: group_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ForumPostCreate'
      responses:
        '201':
          description: 投稿作成成功
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ForumPost'
```

#### 3.2.5 多言語・翻訳API

```yaml
  /translate:
    post:
      summary: テキスト翻訳
      tags: [翻訳]
      security:
        - BearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - text
                - target_language
              properties:
                text:
                  type: string
                  maxLength: 5000
                source_language:
                  type: string
                  default: 'auto'
                target_language:
                  type: string
                content_type:
                  type: string
                  enum: [general, technical, creative, formal]
                  default: 'general'
                preserve_formatting:
                  type: boolean
                  default: true
      responses:
        '200':
          description: 翻訳成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  translated_text:
                    type: string
                  source_language:
                    type: string
                  target_language:
                    type: string
                  confidence_score:
                    type: number
                    minimum: 0
                    maximum: 1
                  translation_time_ms:
                    type: integer

  /translate/batch:
    post:
      summary: バッチ翻訳
      tags: [翻訳]
      security:
        - BearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - texts
                - target_language
              properties:
                texts:
                  type: array
                  items:
                    type: object
                    properties:
                      id:
                        type: string
                      text:
                        type: string
                      content_type:
                        type: string
                target_language:
                  type: string
                source_language:
                  type: string
                  default: 'auto'
      responses:
        '200':
          description: バッチ翻訳成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  translations:
                    type: array
                    items:
                      type: object
                      properties:
                        id:
                          type: string
                        translated_text:
                          type: string
                        confidence_score:
                          type: number

  /translate/content/{content_id}:
    get:
      summary: コンテンツ翻訳取得
      tags: [翻訳]
      parameters:
        - name: content_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
        - name: target_language
          in: query
          required: true
          schema:
            type: string
        - name: fields
          in: query
          schema:
            type: string
            description: カンマ区切りのフィールド名
      responses:
        '200':
          description: 翻訳取得成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  content_id:
                    type: string
                    format: uuid
                  target_language:
                    type: string
                  translations:
                    type: object
                    additionalProperties:
                      type: string

    post:
      summary: コンテンツ翻訳作成・更新
      tags: [翻訳]
      security:
        - BearerAuth: []
      parameters:
        - name: content_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - target_language
                - translations
              properties:
                target_language:
                  type: string
                translations:
                  type: object
                  additionalProperties:
                    type: string
                auto_translate:
                  type: boolean
                  default: true
      responses:
        '200':
          description: 翻訳作成・更新成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  content_id:
                    type: string
                    format: uuid
                  target_language:
                    type: string
                  translations:
                    type: object
                    additionalProperties:
                      type: string

  /languages:
    get:
      summary: サポート言語一覧取得
      tags: [翻訳]
      responses:
        '200':
          description: 言語一覧取得成功
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/SupportedLanguage'

  /languages/{language_code}/detect:
    post:
      summary: 言語検出
      tags: [翻訳]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - text
              properties:
                text:
                  type: string
                  maxLength: 1000
      responses:
        '200':
          description: 言語検出成功
          content:
            application/json:
              schema:
                type: object
                properties:
                  detected_language:
                    type: string
                  confidence_score:
                    type: number
                    minimum: 0
                    maximum: 1
```

### 3.3 GraphQL API設計

#### 3.3.1 GraphQLスキーマ

```graphql
# GraphQL Schema
type Query {
  # ユーザー関連
  user(id: ID!): User
  users(
    first: Int = 20
    after: String
    search: String
    category: String
  ): UserConnection!
  
  # コンテンツ関連
  content(id: ID!): MediaContent
  contents(
    first: Int = 20
    after: String
    contentType: ContentType
    categoryId: ID
    tags: [String!]
    sort: ContentSort = LATEST
  ): MediaContentConnection!
  
  # グループ関連
  group(id: ID!): Group
  groups(
    first: Int = 20
    after: String
    category: String
    tags: [String!]
    sort: GroupSort = LATEST
  ): GroupConnection!
  
  # イベント関連
  event(id: ID!): Event
  events(
    first: Int = 20
    after: String
    status: EventStatus
    startDate: DateTime
    venueType: VenueType
  ): EventConnection!
  
  # 翻訳関連
  translation(
    contentId: ID!
    targetLanguage: String!
    fields: [String!]
  ): Translation
}

type Mutation {
  # 認証関連
  register(input: RegisterInput!): AuthPayload!
  login(input: LoginInput!): AuthPayload!
  refreshToken(input: RefreshTokenInput!): AuthPayload!
  logout: Boolean!
  
  # ユーザー関連
  updateUser(id: ID!, input: UpdateUserInput!): User!
  updateProfile(id: ID!, input: UpdateProfileInput!): UserProfile!
  
  # コンテンツ関連
  createContent(input: CreateContentInput!): MediaContent!
  updateContent(id: ID!, input: UpdateContentInput!): MediaContent!
  deleteContent(id: ID!): Boolean!
  likeContent(id: ID!): LikePayload!
  shareContent(id: ID!): SharePayload!
  
  # グループ関連
  createGroup(input: CreateGroupInput!): Group!
  updateGroup(id: ID!, input: UpdateGroupInput!): Group!
  deleteGroup(id: ID!): Boolean!
  joinGroup(id: ID!): GroupMember!
  leaveGroup(id: ID!): Boolean!
  
  # 投稿関連
  createPost(input: CreatePostInput!): ForumPost!
  updatePost(id: ID!, input: UpdatePostInput!): ForumPost!
  deletePost(id: ID!): Boolean!
  likePost(id: ID!): LikePayload!
  
  # 翻訳関連
  translateText(input: TranslateTextInput!): TranslationResult!
  translateContent(input: TranslateContentInput!): Translation!
}

type Subscription {
  # リアルタイム更新
  contentUpdated(contentId: ID!): MediaContent!
  postCreated(groupId: ID!): ForumPost!
  userJoinedGroup(groupId: ID!): GroupMember!
}

# 型定義
type User {
  id: ID!
  username: String!
  email: String!
  displayName: String
  avatarUrl: String
  bio: String
  subscriptionPlan: SubscriptionPlan!
  profile: UserProfile
  contents: MediaContentConnection!
  groups: GroupConnection!
  createdAt: DateTime!
  updatedAt: DateTime!
}

type MediaContent {
  id: ID!
  title: String!
  description: String
  contentType: ContentType!
  fileUrl: String!
  thumbnailUrl: String
  durationSeconds: Int
  fileSizeBytes: BigInt
  tags: [String!]!
  category: Category
  user: User!
  isPublic: Boolean!
  viewCount: Int!
  likeCount: Int!
  shareCount: Int!
  translations: [Translation!]!
  createdAt: DateTime!
  updatedAt: DateTime!
}

type Group {
  id: ID!
  name: String!
  description: String
  slug: String!
  owner: User!
  coverImageUrl: String
  iconUrl: String
  isPublic: Boolean!
  memberCount: Int!
  postCount: Int!
  rules: [String!]!
  tags: [String!]!
  members: GroupMemberConnection!
  posts: ForumPostConnection!
  createdAt: DateTime!
  updatedAt: DateTime!
}

type Translation {
  id: ID!
  contentId: ID!
  contentType: String!
  fieldName: String!
  originalLanguage: String!
  targetLanguage: String!
  originalText: String!
  translatedText: String!
  qualityScore: Float
  isAiGenerated: Boolean!
  createdAt: DateTime!
  updatedAt: DateTime!
}

# 入力型
input RegisterInput {
  username: String!
  email: String!
  password: String!
  displayName: String
}

input CreateContentInput {
  title: String!
  description: String
  contentType: ContentType!
  file: Upload!
  thumbnail: Upload
  tags: [String!]
  categoryId: ID
  isPublic: Boolean = true
}

input TranslateTextInput {
  text: String!
  sourceLanguage: String
  targetLanguage: String!
  contentType: String = "general"
  preserveFormatting: Boolean = true
}

# 列挙型
enum ContentType {
  VIDEO
  MUSIC
  MANGA
  STORY
  IMAGE
}

enum ContentSort {
  LATEST
  POPULAR
  TRENDING
}

enum SubscriptionPlan {
  FREE
  STANDARD
  PRO
  BUSINESS
}

enum EventStatus {
  DRAFT
  PUBLISHED
  CANCELLED
  COMPLETED
}

enum VenueType {
  ONLINE
  OFFLINE
  HYBRID
}

# 接続型
type MediaContentConnection {
  edges: [MediaContentEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type MediaContentEdge {
  node: MediaContent!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}
```

### 3.4 WebSocket API設計

#### 3.4.1 WebSocket接続

```typescript
// WebSocket接続管理
interface WebSocketMessage {
  type: string;
  payload: any;
  timestamp: number;
  messageId: string;
}

// 接続確立
const ws = new WebSocket('wss://api.creator-community.com/ws');

// 認証
ws.send(JSON.stringify({
  type: 'AUTH',
  payload: {
    token: accessToken
  },
  timestamp: Date.now(),
  messageId: generateMessageId()
}));

// リアルタイム翻訳
ws.send(JSON.stringify({
  type: 'TRANSLATE_REQUEST',
  payload: {
    text: 'Hello World',
    targetLanguage: 'ja',
    contentType: 'general'
  },
  timestamp: Date.now(),
  messageId: generateMessageId()
}));

// 翻訳結果受信
ws.onmessage = (event) => {
  const message: WebSocketMessage = JSON.parse(event.data);
  
  switch (message.type) {
    case 'TRANSLATION_RESULT':
      handleTranslationResult(message.payload);
      break;
    case 'CONTENT_UPDATE':
      handleContentUpdate(message.payload);
      break;
    case 'NEW_POST':
      handleNewPost(message.payload);
      break;
    case 'USER_JOINED_GROUP':
      handleUserJoinedGroup(message.payload);
      break;
  }
};
```

### 3.5 APIセキュリティ

#### 3.5.1 認証・認可

```typescript
// JWT認証ミドルウェア
const authenticateToken = (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'アクセストークンが必要です' });
  }

  jwt.verify(token, process.env.JWT_SECRET, (err: any, user: any) => {
    if (err) {
      return res.status(403).json({ error: 'トークンが無効です' });
    }
    req.user = user;
    next();
  });
};

// 権限チェックミドルウェア
const checkPermission = (resource: string, action: string) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const user = req.user;
    const resourceId = req.params.id;
    
    // リソース所有者チェック
    if (action === 'update' || action === 'delete') {
      const isOwner = await checkResourceOwnership(resource, resourceId, user.id);
      if (!isOwner) {
        return res.status(403).json({ error: '権限がありません' });
      }
    }
    
    next();
  };
};

// レート制限
const rateLimit = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分
  max: 100, // 最大100リクエスト
  message: 'リクエストが多すぎます。しばらく待ってから再試行してください。'
});
```

#### 3.5.2 入力バリデーション

```typescript
// Joiスキーマ
const createContentSchema = Joi.object({
  title: Joi.string().min(1).max(200).required(),
  description: Joi.string().max(5000).optional(),
  contentType: Joi.string().valid('video', 'music', 'manga', 'story', 'image').required(),
  tags: Joi.array().items(Joi.string().max(50)).max(20).optional(),
  categoryId: Joi.string().uuid().optional(),
  isPublic: Joi.boolean().default(true)
});

// Zodスキーマ
const translateTextSchema = z.object({
  text: z.string().min(1).max(5000),
  sourceLanguage: z.string().optional(),
  targetLanguage: z.string().min(2).max(10),
  contentType: z.enum(['general', 'technical', 'creative', 'formal']).default('general'),
  preserveFormatting: z.boolean().default(true)
});

// バリデーションミドルウェア
const validateRequest = (schema: Joi.ObjectSchema) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const { error } = schema.validate(req.body);
    if (error) {
      return res.status(400).json({
        error: 'バリデーションエラー',
        details: error.details.map(d => d.message)
      });
    }
    next();
  };
};
```

### 3.6 APIテスト

#### 3.6.1 テスト戦略

```typescript
// Jest + Supertest によるAPIテスト
describe('Content API', () => {
  let authToken: string;
  let testContentId: string;

  beforeAll(async () => {
    // テストユーザー作成・ログイン
    const response = await request(app)
      .post('/auth/login')
      .send({
        email: 'test@example.com',
        password: 'testpassword'
      });
    authToken = response.body.access_token;
  });

  describe('POST /contents', () => {
    it('should create content successfully', async () => {
      const response = await request(app)
        .post('/contents')
        .set('Authorization', `Bearer ${authToken}`)
        .field('title', 'Test Content')
        .field('content_type', 'image')
        .field('is_public', 'true')
        .attach('file', 'test-image.jpg');

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('id');
      expect(response.body.title).toBe('Test Content');
      
      testContentId = response.body.id;
    });

    it('should return 400 for invalid content type', async () => {
      const response = await request(app)
        .post('/contents')
        .set('Authorization', `Bearer ${authToken}`)
        .field('title', 'Test Content')
        .field('content_type', 'invalid_type')
        .attach('file', 'test-image.jpg');

      expect(response.status).toBe(400);
    });
  });

  describe('GET /contents/:id', () => {
    it('should return content by id', async () => {
      const response = await request(app)
        .get(`/contents/${testContentId}`);

      expect(response.status).toBe(200);
      expect(response.body.id).toBe(testContentId);
    });

    it('should return 404 for non-existent content', async () => {
      const response = await request(app)
        .get('/contents/non-existent-id');

      expect(response.status).toBe(404);
    });
  });
});
```

---

**文書情報**
- 作成日: 2024年12月
- バージョン: 1.0
- 作成者: API設計チーム
- 承認者: システムアーキテクト
