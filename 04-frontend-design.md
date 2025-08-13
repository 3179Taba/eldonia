# 04. フロントエンド設計

## 4.1 フロントエンド概要

### 4.1.1 設計方針
- **モダンなUI/UX**: 直感的で美しいインターフェース
- **レスポンシブデザイン**: デスクトップ、タブレット、モバイル対応
- **アクセシビリティ**: WCAG 2.1 AA準拠
- **パフォーマンス**: Core Web Vitals最適化
- **保守性**: コンポーネントベースの設計

### 4.1.2 技術スタック
- **フレームワーク**: Next.js 14 (App Router)
- **UIライブラリ**: React 18 + TypeScript 5.x
- **スタイリング**: Tailwind CSS 3.x + CSS Modules
- **状態管理**: Zustand + React Query
- **UIコンポーネント**: Radix UI + Headless UI
- **アニメーション**: Framer Motion + Lottie
- **テスト**: Jest + React Testing Library + Playwright

## 4.2 アーキテクチャ設計

### 4.2.1 ディレクトリ構造
```
src/
├── app/                    # Next.js App Router
│   ├── (auth)/            # 認証関連ページ
│   ├── (dashboard)/       # 管理画面
│   ├── (portal)/          # ポータルサイト
│   ├── api/               # API Routes
│   └── globals.css        # グローバルスタイル
├── components/             # 再利用可能コンポーネント
│   ├── ui/                # 基本UIコンポーネント
│   ├── forms/             # フォームコンポーネント
│   ├── layout/            # レイアウトコンポーネント
│   └── features/          # 機能別コンポーネント
├── hooks/                  # カスタムフック
├── lib/                    # ユーティリティ・設定
├── stores/                 # Zustandストア
├── types/                  # TypeScript型定義
└── utils/                  # ヘルパー関数
```

### 4.2.2 ページ構成
```
app/
├── page.tsx               # ホームページ
├── (auth)/
│   ├── login/page.tsx     # ログイン
│   ├── register/page.tsx  # 登録
│   └── forgot/page.tsx    # パスワードリセット
├── (portal)/
│   ├── profile/page.tsx   # ユーザープロフィール
│   ├── upload/page.tsx    # コンテンツアップロード
│   ├── community/page.tsx # コミュニティ
│   ├── shop/page.tsx      # ショップ
│   └── events/page.tsx    # イベント
└── (dashboard)/
    ├── page.tsx           # 管理ダッシュボード
    ├── users/page.tsx     # ユーザー管理
    ├── content/page.tsx   # コンテンツ管理
    ├── analytics/page.tsx # 分析・レポート
    └── settings/page.tsx  # システム設定
```

## 4.3 管理画面設計

### 4.3.1 管理画面概要
- **対象ユーザー**: 管理者、モデレーター、サポートスタッフ
- **アクセス制御**: ロールベースの権限管理
- **レスポンシブ**: デスクトップ最適化、タブレット対応

### 4.3.2 管理画面機能
```
管理ダッシュボード/
├── 概要・統計
│   ├── ユーザー数・成長率
│   ├── コンテンツ数・アップロード状況
│   ├── 売上・収益レポート
│   └── システム状況・パフォーマンス
├── ユーザー管理
│   ├── ユーザー一覧・検索・フィルタ
│   ├── 権限管理・ロール設定
│   ├── アカウント停止・復活
│   └── ユーザー詳細・履歴
├── コンテンツ管理
│   ├── 動画・音楽・マンガ・ストーリー管理
│   ├── モデレーション・承認・却下
│   ├── カテゴリ・タグ管理
│   └── コンテンツ分析・統計
├── コミュニティ管理
│   ├── グループ・掲示板管理
│   ├── 投稿・コメント管理
│   ├── 報告・通報対応
│   └── コミュニティ分析
├── ショップ管理
│   ├── 商品管理・在庫管理
│   ├── 注文・支払い管理
│   ├── 売上レポート
│   └── 商品分析
├── イベント管理
│   ├── イベント作成・編集
│   ├── 参加者管理
│   ├── イベント分析
│   └── 通知・リマインダー
└── システム設定
    ├── サイト設定・メタ情報
    ├── メール・通知設定
    ├── セキュリティ設定
    ├── バックアップ・復元
    └── ログ・監査
```

### 4.3.3 管理画面UI/UX
- **ダークテーマ**: 長時間作業に適した目に優しいデザイン
- **サイドバーナビゲーション**: 階層化されたメニュー構造
- **データテーブル**: ソート・フィルタ・ページネーション
- **ダッシュボード**: グラフ・チャート・KPI表示
- **モーダル・ドロワー**: 詳細表示・編集・確認
- **トースト通知**: 操作結果・エラー・警告表示

## 4.4 コンポーネント設計

### 4.4.1 基本UIコンポーネント
```typescript
// components/ui/Button.tsx
interface ButtonProps {
  variant: 'primary' | 'secondary' | 'danger' | 'ghost';
  size: 'sm' | 'md' | 'lg';
  loading?: boolean;
  disabled?: boolean;
  children: React.ReactNode;
  onClick?: () => void;
}

// components/ui/DataTable.tsx
interface DataTableProps<T> {
  data: T[];
  columns: Column<T>[];
  pagination?: PaginationProps;
  search?: SearchProps;
  filters?: FilterProps;
  actions?: ActionProps<T>;
}

// components/ui/Modal.tsx
interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  children: React.ReactNode;
  size?: 'sm' | 'md' | 'lg' | 'xl';
}
```

### 4.4.2 機能別コンポーネント
```typescript
// components/features/UserManagement/UserTable.tsx
interface UserTableProps {
  users: User[];
  onEdit: (user: User) => void;
  onDelete: (userId: string) => void;
  onToggleStatus: (userId: string, status: UserStatus) => void;
}

// components/features/ContentManagement/ContentUpload.tsx
interface ContentUploadProps {
  type: 'video' | 'music' | 'manga' | 'story' | 'image';
  onUpload: (file: File, metadata: ContentMetadata) => void;
  maxFileSize: number;
  allowedFormats: string[];
}

// components/features/Analytics/Dashboard.tsx
interface DashboardProps {
  period: 'day' | 'week' | 'month' | 'year';
  metrics: DashboardMetrics;
  onPeriodChange: (period: string) => void;
}
```

### 4.4.3 レイアウトコンポーネント
```typescript
// components/layout/AdminLayout.tsx
interface AdminLayoutProps {
  children: React.ReactNode;
  sidebar?: React.ReactNode;
  header?: React.ReactNode;
}

// components/layout/Sidebar.tsx
interface SidebarProps {
  items: MenuItem[];
  collapsed?: boolean;
  onToggle: () => void;
}

// components/layout/Header.tsx
interface HeaderProps {
  user: AdminUser;
  notifications: Notification[];
  onLogout: () => void;
}
```

## 4.5 状態管理設計

### 4.5.1 Zustandストア構成
```typescript
// stores/adminStore.ts
interface AdminStore {
  // ユーザー管理
  users: User[];
  selectedUser: User | null;
  userFilters: UserFilters;
  
  // コンテンツ管理
  contents: Content[];
  contentFilters: ContentFilters;
  selectedContent: Content | null;
  
  // 統計・分析
  dashboardMetrics: DashboardMetrics;
  analyticsData: AnalyticsData;
  
  // アクション
  fetchUsers: (filters?: UserFilters) => Promise<void>;
  updateUser: (userId: string, data: Partial<User>) => Promise<void>;
  deleteUser: (userId: string) => Promise<void>;
  fetchContents: (filters?: ContentFilters) => Promise<void>;
  updateContent: (contentId: string, data: Partial<Content>) => Promise<void>;
  fetchDashboardMetrics: (period: string) => Promise<void>;
}

// stores/authStore.ts
interface AuthStore {
  user: AdminUser | null;
  isAuthenticated: boolean;
  permissions: Permission[];
  
  login: (credentials: LoginCredentials) => Promise<void>;
  logout: () => void;
  checkAuth: () => Promise<void>;
}
```

### 4.5.2 React Query設定
```typescript
// hooks/useAdminQueries.ts
export const useUsers = (filters?: UserFilters) => {
  return useQuery({
    queryKey: ['users', filters],
    queryFn: () => adminApi.getUsers(filters),
    staleTime: 5 * 60 * 1000, // 5分
  });
};

export const useUser = (userId: string) => {
  return useQuery({
    queryKey: ['user', userId],
    queryFn: () => adminApi.getUser(userId),
    enabled: !!userId,
  });
};

export const useUpdateUser = () => {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: (data: UpdateUserData) => adminApi.updateUser(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
    },
  });
};
```

## 4.6 UI/UX設計

### 4.6.1 デザインシステム
- **カラーパレット**: プライマリ、セカンダリ、アクセント、ニュートラル
- **タイポグラフィ**: フォントファミリー、サイズ、ウェイト、行間
- **スペーシング**: 統一されたマージン・パディング
- **アイコン**: Heroicons、Lucide React
- **アニメーション**: Framer Motion、CSS Transitions

### 4.6.2 レスポンシブデザイン
```css
/* Tailwind CSS ブレークポイント */
/* sm: 640px, md: 768px, lg: 1024px, xl: 1280px, 2xl: 1536px */

.admin-layout {
  @apply grid;
  @apply grid-cols-1 md:grid-cols-4 lg:grid-cols-6;
}

.sidebar {
  @apply col-span-1;
  @apply hidden md:block;
  @apply lg:col-span-1;
}

.main-content {
  @apply col-span-1;
  @apply md:col-span-3 lg:col-span-5;
}
```

### 4.6.3 アクセシビリティ
- **キーボードナビゲーション**: Tab、Enter、Space、矢印キー
- **スクリーンリーダー**: ARIA属性、セマンティックHTML
- **コントラスト**: WCAG AA準拠の色コントラスト
- **フォーカス表示**: 明確なフォーカスインジケーター
- **代替テキスト**: 画像、アイコンの説明

## 4.7 パフォーマンス最適化

### 4.7.1 Next.js最適化
- **App Router**: ファイルベースルーティング
- **Server Components**: サーバーサイドレンダリング
- **Streaming**: 段階的なコンテンツ表示
- **Image Optimization**: next/image最適化
- **Font Optimization**: next/font最適化

### 4.7.2 React最適化
- **React.memo**: 不要な再レンダリング防止
- **useMemo/useCallback**: 計算・関数のメモ化
- **Code Splitting**: 動的インポート
- **Lazy Loading**: 遅延読み込み
- **Virtual Scrolling**: 大量データの効率的表示

### 4.7.3 バンドル最適化
- **Tree Shaking**: 未使用コード除去
- **Code Splitting**: チャンク分割
- **Bundle Analyzer**: バンドルサイズ分析
- **Dynamic Imports**: 必要時のみ読み込み

## 4.8 テスト戦略

### 4.8.1 テストピラミッド
```
    E2E Tests (Playwright)
        /\
       /  \
      /    \
   Integration Tests
      /\
     /  \
    /    \
 Unit Tests (Jest)
```

### 4.8.2 テスト対象
- **Unit Tests**: コンポーネント、フック、ユーティリティ
- **Integration Tests**: API連携、状態管理
- **E2E Tests**: ユーザーフロー、管理画面操作

### 4.8.3 テスト例
```typescript
// components/features/UserManagement/__tests__/UserTable.test.tsx
describe('UserTable', () => {
  it('should render user list correctly', () => {
    const mockUsers = [
      { id: '1', name: 'John Doe', email: 'john@example.com' },
      { id: '2', name: 'Jane Smith', email: 'jane@example.com' },
    ];
    
    render(<UserTable users={mockUsers} />);
    
    expect(screen.getByText('John Doe')).toBeInTheDocument();
    expect(screen.getByText('Jane Smith')).toBeInTheDocument();
  });
  
  it('should call onEdit when edit button is clicked', () => {
    const mockOnEdit = jest.fn();
    const mockUser = { id: '1', name: 'John Doe' };
    
    render(<UserTable users={[mockUser]} onEdit={mockOnEdit} />);
    
    fireEvent.click(screen.getByRole('button', { name: /edit/i }));
    expect(mockOnEdit).toHaveBeenCalledWith(mockUser);
  });
});
```

## 4.9 国際化・多言語対応

### 4.9.1 next-intl設定
```typescript
// lib/i18n.ts
import { createI18n } from 'next-intl';

export const i18n = createI18n({
  locales: ['ja', 'en', 'zh', 'ko'],
  defaultLocale: 'ja',
  messages: {
    ja: jaMessages,
    en: enMessages,
    zh: zhMessages,
    ko: koMessages,
  },
});
```

### 4.9.2 翻訳キー設計
```typescript
// messages/ja.json
{
  "admin": {
    "dashboard": {
      "title": "管理ダッシュボード",
      "users": "ユーザー管理",
      "content": "コンテンツ管理",
      "analytics": "分析・レポート"
    },
    "users": {
      "table": {
        "name": "名前",
        "email": "メールアドレス",
        "status": "ステータス",
        "actions": "操作"
      }
    }
  }
}
```

## 4.10 セキュリティ設計

### 4.10.1 フロントエンドセキュリティ
- **XSS対策**: Reactの自動エスケープ
- **CSRF対策**: CSRFトークン、SameSite Cookie
- **認証・認可**: JWT、ロールベースアクセス制御
- **入力検証**: クライアントサイド・サーバーサイド両方
- **HTTPS**: 強制HTTPS、HSTS

### 4.10.2 管理画面セキュリティ
- **セッション管理**: タイムアウト、自動ログアウト
- **操作ログ**: 全ての管理操作の記録
- **権限チェック**: ページ・コンポーネントレベル
- **監査ログ**: 変更履歴・操作者記録

---

**次のセクション**: 05. インフラ・DevOps設計
