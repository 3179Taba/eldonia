# 08. テスト・品質保証

## 8.1 テスト戦略概要

### 8.1.1 品質保証方針
- **品質第一**: ユーザー体験を最優先とした品質保証
- **自動化優先**: CI/CDパイプラインでの自動テスト実行
- **早期発見**: 開発初期段階でのバグ・問題の早期発見
- **継続的改善**: テスト結果に基づくプロセス改善
- **リスクベース**: ビジネス影響度に基づくテスト優先度設定

### 8.1.2 テスト対象範囲
- **機能テスト**: ユーザー認証、コンテンツ管理、コミュニティ機能
- **非機能テスト**: パフォーマンス、セキュリティ、可用性、スケーラビリティ
- **統合テスト**: API連携、データベース連携、外部サービス連携
- **ユーザビリティテスト**: UI/UX、アクセシビリティ、多言語対応
- **セキュリティテスト**: 認証・認可、データ保護、脆弱性診断

## 8.2 テストピラミッド

### 8.2.1 テスト戦略構成
```
                    E2E Tests (5%)
                    ┌─────────────┐
                    │ Playwright  │
                    │ Cypress     │
                    └─────────────┘
                         │
              Integration Tests (15%)
              ┌─────────────────────────┐
              │ API Testing             │
              │ Database Testing        │
              │ External Service Mock   │
              └─────────────────────────┘
                         │
              Unit Tests (80%)
              ┌─────────────────────────┐
              │ Jest (Backend)         │
              │ React Testing Library  │
              │ Vitest (Frontend)      │
              └─────────────────────────┘
```

### 8.2.2 各層の役割
- **Unit Tests (80%)**: 個別関数・コンポーネントの動作確認
- **Integration Tests (15%)**: モジュール間・サービス間の連携確認
- **E2E Tests (5%)**: ユーザー視点での全体フロー確認

## 8.3 自動化戦略

### 8.3.1 CI/CDパイプライン
```yaml
# .github/workflows/ci-cd.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  # 品質チェック
  quality-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      
      - name: Install dependencies
        run: |
          cd backend && npm ci
          cd ../frontend && npm ci
      
      - name: Lint Backend
        run: cd backend && npm run lint
      
      - name: Lint Frontend
        run: cd frontend && npm run lint
      
      - name: Type Check
        run: |
          cd backend && npm run type-check
          cd ../frontend && npm run type-check

  # バックエンドテスト
  backend-test:
    runs-on: ubuntu-latest
    needs: quality-check
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: eldonia_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      
      redis:
        image: redis:7-alpine
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      
      - name: Install dependencies
        run: cd backend && npm ci
      
      - name: Run tests
        run: cd backend && npm run test:coverage
        env:
          NODE_ENV: test
          DB_HOST: localhost
          DB_PORT: 5432
          DB_NAME: eldonia_test
          DB_USER: postgres
          DB_PASSWORD: postgres
          REDIS_HOST: localhost
          REDIS_PORT: 6379
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./backend/coverage/lcov.info
          flags: backend
          name: backend-coverage

  # フロントエンドテスト
  frontend-test:
    runs-on: ubuntu-latest
    needs: quality-check
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      
      - name: Install dependencies
        run: cd frontend && npm ci
      
      - name: Run tests
        run: cd frontend && npm run test:coverage
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./frontend/coverage/lcov.info
          flags: frontend
          name: frontend-coverage

  # E2Eテスト
  e2e-test:
    runs-on: ubuntu-latest
    needs: [backend-test, frontend-test]
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      
      - name: Install dependencies
        run: cd frontend && npm ci
      
      - name: Install Playwright
        run: cd frontend && npx playwright install --with-deps
      
      - name: Run E2E tests
        run: cd frontend && npm run e2e
      
      - name: Upload test results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: playwright-report
          path: frontend/test-results/
          retention-days: 30

  # セキュリティテスト
  security-test:
    runs-on: ubuntu-latest
    needs: [backend-test, frontend-test]
    steps:
      - uses: actions/checkout@v4
      
      - name: Run OWASP ZAP
        uses: zaproxy/action-full-scan@v0.8.0
        with:
          target: 'http://localhost:3000'
      
      - name: Run npm audit
        run: |
          cd backend && npm audit --audit-level=moderate
          cd ../frontend && npm audit --audit-level=moderate

  # デプロイ
  deploy:
    runs-on: ubuntu-latest
    needs: [e2e-test, security-test]
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      
      - name: Deploy to AWS
        run: |
          echo "Deploying to production..."
          # AWSデプロイスクリプト実行
```

### 8.3.2 テスト実行タイミング
- **Pre-commit**: コードフォーマット、リンター、型チェック
- **Pull Request**: 全自動テスト、カバレッジ測定、セキュリティチェック
- **Main Branch**: 本番デプロイ前の最終テスト
- **Scheduled**: 定期的なセキュリティスキャン、パフォーマンステスト

## 8.4 バックエンドテスト

### 8.4.1 ユニットテスト (Jest)
```typescript
// backend/src/__tests__/services/auth.test.ts
import { AuthService } from '../../services/auth';
import { UserRepository } from '../../repositories/user';
import { JWTService } from '../../services/jwt';
import bcrypt from 'bcrypt';

// モック設定
jest.mock('../../repositories/user');
jest.mock('../../services/jwt');
jest.mock('bcrypt');

describe('AuthService', () => {
  let authService: AuthService;
  let mockUserRepository: jest.Mocked<UserRepository>;
  let mockJWTService: jest.Mocked<JWTService>;

  beforeEach(() => {
    mockUserRepository = new UserRepository() as jest.Mocked<UserRepository>;
    mockJWTService = new JWTService() as jest.Mocked<JWTService>;
    authService = new AuthService(mockUserRepository, mockJWTService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('login', () => {
    it('should authenticate valid user and return JWT token', async () => {
      // Arrange
      const email = 'test@example.com';
      const password = 'password123';
      const hashedPassword = 'hashedPassword123';
      const user = {
        id: '1',
        email,
        password: hashedPassword,
        name: 'Test User',
        isActive: true
      };

      mockUserRepository.findByEmail.mockResolvedValue(user);
      (bcrypt.compare as jest.Mock).mockResolvedValue(true);
      mockJWTService.generateToken.mockResolvedValue('jwt-token');

      // Act
      const result = await authService.login(email, password);

      // Assert
      expect(result.success).toBe(true);
      expect(result.token).toBe('jwt-token');
      expect(result.user.email).toBe(email);
      expect(mockUserRepository.findByEmail).toHaveBeenCalledWith(email);
      expect(bcrypt.compare).toHaveBeenCalledWith(password, hashedPassword);
      expect(mockJWTService.generateToken).toHaveBeenCalledWith(user.id);
    });

    it('should reject invalid password', async () => {
      // Arrange
      const email = 'test@example.com';
      const password = 'wrongpassword';
      const hashedPassword = 'hashedPassword123';
      const user = {
        id: '1',
        email,
        password: hashedPassword,
        name: 'Test User',
        isActive: true
      };

      mockUserRepository.findByEmail.mockResolvedValue(user);
      (bcrypt.compare as jest.Mock).mockResolvedValue(false);

      // Act
      const result = await authService.login(email, password);

      // Assert
      expect(result.success).toBe(false);
      expect(result.error).toBe('Invalid credentials');
      expect(bcrypt.compare).toHaveBeenCalledWith(password, hashedPassword);
    });

    it('should reject non-existent user', async () => {
      // Arrange
      const email = 'nonexistent@example.com';
      const password = 'password123';

      mockUserRepository.findByEmail.mockResolvedValue(null);

      // Act
      const result = await authService.login(email, password);

      // Assert
      expect(result.success).toBe(false);
      expect(result.error).toBe('User not found');
      expect(mockUserRepository.findByEmail).toHaveBeenCalledWith(email);
    });

    it('should reject inactive user', async () => {
      // Arrange
      const email = 'test@example.com';
      const password = 'password123';
      const hashedPassword = 'hashedPassword123';
      const user = {
        id: '1',
        email,
        password: hashedPassword,
        name: 'Test User',
        isActive: false
      };

      mockUserRepository.findByEmail.mockResolvedValue(user);

      // Act
      const result = await authService.login(email, password);

      // Assert
      expect(result.success).toBe(false);
      expect(result.error).toBe('Account is deactivated');
    });
  });

  describe('register', () => {
    it('should create new user successfully', async () => {
      // Arrange
      const userData = {
        email: 'new@example.com',
        password: 'password123',
        name: 'New User'
      };
      const hashedPassword = 'hashedPassword123';
      const newUser = {
        id: '2',
        ...userData,
        password: hashedPassword,
        isActive: true
      };

      mockUserRepository.findByEmail.mockResolvedValue(null);
      (bcrypt.hash as jest.Mock).mockResolvedValue(hashedPassword);
      mockUserRepository.create.mockResolvedValue(newUser);

      // Act
      const result = await authService.register(userData);

      // Assert
      expect(result.success).toBe(true);
      expect(result.user.email).toBe(userData.email);
      expect(result.user.name).toBe(userData.name);
      expect(bcrypt.hash).toHaveBeenCalledWith(userData.password, 12);
      expect(mockUserRepository.create).toHaveBeenCalledWith({
        ...userData,
        password: hashedPassword
      });
    });

    it('should reject duplicate email', async () => {
      // Arrange
      const userData = {
        email: 'existing@example.com',
        password: 'password123',
        name: 'New User'
      };

      mockUserRepository.findByEmail.mockResolvedValue({
        id: '1',
        email: userData.email,
        password: 'hashed',
        name: 'Existing User',
        isActive: true
      });

      // Act
      const result = await authService.register(userData);

      // Assert
      expect(result.success).toBe(false);
      expect(result.error).toBe('Email already exists');
      expect(mockUserRepository.create).not.toHaveBeenCalled();
    });
  });
});
```

### 8.4.2 統合テスト (Supertest)
```typescript
// backend/src/__tests__/integration/auth.test.ts
import request from 'supertest';
import { app } from '../../server';
import { db } from '../../config/database';
import { createTestUser, clearTestData } from '../helpers/testHelpers';

describe('Auth API Integration Tests', () => {
  let testUser: any;

  beforeAll(async () => {
    await db.connect();
    testUser = await createTestUser();
  });

  afterAll(async () => {
    await clearTestData();
    await db.disconnect();
  });

  beforeEach(async () => {
    await clearTestData();
    testUser = await createTestUser();
  });

  describe('POST /api/auth/login', () => {
    it('should login with valid credentials', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: testUser.email,
          password: 'password123'
        })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.token).toBeDefined();
      expect(response.body.user.email).toBe(testUser.email);
      expect(response.body.user.password).toBeUndefined();
    });

    it('should reject invalid credentials', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: testUser.email,
          password: 'wrongpassword'
        })
        .expect(401);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Invalid credentials');
    });

    it('should validate required fields', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({})
        .expect(400);

      expect(response.body.errors).toContain('Email is required');
      expect(response.body.errors).toContain('Password is required');
    });
  });

  describe('POST /api/auth/register', () => {
    it('should register new user successfully', async () => {
      const newUserData = {
        email: 'newuser@example.com',
        password: 'newpassword123',
        name: 'New User'
      };

      const response = await request(app)
        .post('/api/auth/register')
        .send(newUserData)
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.user.email).toBe(newUserData.email);
      expect(response.body.user.name).toBe(newUserData.name);
      expect(response.body.user.password).toBeUndefined();
    });

    it('should reject duplicate email', async () => {
      const duplicateUserData = {
        email: testUser.email,
        password: 'password123',
        name: 'Duplicate User'
      };

      const response = await request(app)
        .post('/api/auth/register')
        .send(duplicateUserData)
        .expect(409);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Email already exists');
    });
  });

  describe('GET /api/auth/profile', () => {
    it('should return user profile with valid token', async () => {
      const loginResponse = await request(app)
        .post('/api/auth/login')
        .send({
          email: testUser.email,
          password: 'password123'
        });

      const token = loginResponse.body.token;

      const response = await request(app)
        .get('/api/auth/profile')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(response.body.user.email).toBe(testUser.email);
      expect(response.body.user.name).toBe(testUser.name);
    });

    it('should reject request without token', async () => {
      await request(app)
        .get('/api/auth/profile')
        .expect(401);
    });

    it('should reject invalid token', async () => {
      await request(app)
        .get('/api/auth/profile')
        .set('Authorization', 'Bearer invalid-token')
        .expect(401);
    });
  });
});
```

---

## 8.5 フロントエンドテスト

### 8.5.1 コンポーネントテスト (React Testing Library)
```typescript
// frontend/src/__tests__/components/LanguageSwitcher.test.tsx
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { useRouter, usePathname } from 'next/navigation';
import LanguageSwitcher from '../../components/LanguageSwitcher';

// Next.js フックのモック
jest.mock('next/navigation', () => ({
  useRouter: jest.fn(),
  usePathname: jest.fn()
}));

jest.mock('next-intl', () => ({
  useLocale: () => 'ja',
  useTranslations: () => (key: string) => key
}));

describe('LanguageSwitcher', () => {
  const mockPush = jest.fn();
  const mockPathname = '/ja/dashboard';

  beforeEach(() => {
    (useRouter as jest.Mock).mockReturnValue({
      push: mockPush
    });
    (usePathname as jest.Mock).mockReturnValue(mockPathname);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should render current language with flag', () => {
    render(<LanguageSwitcher />);
    
    expect(screen.getByText('🇯🇵')).toBeInTheDocument();
    expect(screen.getByText('日本語')).toBeInTheDocument();
  });

  it('should open language dropdown when clicked', () => {
    render(<LanguageSwitcher />);
    
    const button = screen.getByRole('button');
    fireEvent.click(button);
    
    expect(screen.getByText('English')).toBeInTheDocument();
    expect(screen.getByText('中文')).toBeInTheDocument();
    expect(screen.getByText('한국어')).toBeInTheDocument();
  });

  it('should change language when new language is selected', async () => {
    render(<LanguageSwitcher />);
    
    const button = screen.getByRole('button');
    fireEvent.click(button);
    
    const englishButton = screen.getByText('English');
    fireEvent.click(englishButton);
    
    await waitFor(() => {
      expect(mockPush).toHaveBeenCalledWith('/en/dashboard');
    });
  });

  it('should highlight current language in dropdown', () => {
    render(<LanguageSwitcher />);
    
    const button = screen.getByRole('button');
    fireEvent.click(button);
    
    const japaneseButton = screen.getByText('日本語').closest('button');
    expect(japaneseButton).toHaveClass('bg-blue-50', 'text-blue-600');
  });

  it('should close dropdown when clicking outside', () => {
    render(<LanguageSwitcher />);
    
    const button = screen.getByRole('button');
    fireEvent.click(button);
    
    expect(screen.getByText('English')).toBeInTheDocument();
    
    // 外側をクリック
    fireEvent.click(document.body);
    
    expect(screen.queryByText('English')).not.toBeInTheDocument();
  });
});
```

### 8.5.2 フックテスト
```typescript
// frontend/src/__tests__/hooks/useAuth.test.ts
import { renderHook, act } from '@testing-library/react';
import { useAuth } from '../../hooks/useAuth';
import { AuthContext } from '../../contexts/AuthContext';

// モック設定
const mockLogin = jest.fn();
const mockLogout = jest.fn();
const mockRegister = jest.fn();

const mockAuthContext = {
  user: null,
  isAuthenticated: false,
  isLoading: false,
  login: mockLogin,
  logout: mockLogout,
  register: mockRegister
};

const wrapper = ({ children }: { children: React.ReactNode }) => (
  <AuthContext.Provider value={mockAuthContext}>
    {children}
  </AuthContext.Provider>
);

describe('useAuth', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should return auth context values', () => {
    const { result } = renderHook(() => useAuth(), { wrapper });
    
    expect(result.current.user).toBe(null);
    expect(result.current.isAuthenticated).toBe(false);
    expect(result.current.isLoading).toBe(false);
    expect(typeof result.current.login).toBe('function');
    expect(typeof result.current.logout).toBe('function');
    expect(typeof result.current.register).toBe('function');
  });

  it('should call login function when login is triggered', async () => {
    const { result } = renderHook(() => useAuth(), { wrapper });
    
    const credentials = { email: 'test@example.com', password: 'password123' };
    
    await act(async () => {
      await result.current.login(credentials);
    });
    
    expect(mockLogin).toHaveBeenCalledWith(credentials);
  });

  it('should call logout function when logout is triggered', async () => {
    const { result } = renderHook(() => useAuth(), { wrapper });
    
    await act(async () => {
      await result.current.logout();
    });
    
    expect(mockLogout).toHaveBeenCalled();
  });

  it('should call register function when register is triggered', async () => {
    const { result } = renderHook(() => useAuth(), { wrapper });
    
    const userData = {
      email: 'new@example.com',
      password: 'password123',
      name: 'New User'
    };
    
    await act(async () => {
      await result.current.register(userData);
    });
    
    expect(mockRegister).toHaveBeenCalledWith(userData);
  });
});
```

## 8.6 E2Eテスト

### 8.6.1 Playwright設定
```typescript
// frontend/playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure'
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] }
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] }
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] }
    },
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] }
    },
    {
      name: 'Mobile Safari',
      use: { ...devices['iPhone 12'] }
    }
  ],

  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000
  }
});
```

### 8.6.2 E2Eテストケース
```typescript
// frontend/e2e/auth.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Authentication Flow', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should display login form', async ({ page }) => {
    await page.click('text=ログイン');
    
    await expect(page.locator('input[name="email"]')).toBeVisible();
    await expect(page.locator('input[name="password"]')).toBeVisible();
    await expect(page.locator('button[type="submit"]')).toBeVisible();
  });

  test('should show validation errors for empty fields', async ({ page }) => {
    await page.click('text=ログイン');
    await page.click('button[type="submit"]');
    
    await expect(page.locator('text=メールアドレスは必須です')).toBeVisible();
    await expect(page.locator('text=パスワードは必須です')).toBeVisible();
  });

  test('should show error for invalid credentials', async ({ page }) => {
    await page.click('text=ログイン');
    await page.fill('input[name="email"]', 'invalid@example.com');
    await page.fill('input[name="password"]', 'wrongpassword');
    await page.click('button[type="submit"]');
    
    await expect(page.locator('text=ログインに失敗しました')).toBeVisible();
  });

  test('should login successfully with valid credentials', async ({ page }) => {
    await page.click('text=ログイン');
    await page.fill('input[name="email"]', 'test@example.com');
    await page.fill('input[name="password"]', 'password123');
    await page.click('button[type="submit"]');
    
    await expect(page.locator('text=ログインしました')).toBeVisible();
    await expect(page.locator('text=ダッシュボード')).toBeVisible();
  });

  test('should navigate to registration form', async ({ page }) => {
    await page.click('text=ログイン');
    await page.click('text=アカウントをお持ちでない方');
    
    await expect(page.locator('text=ユーザー登録')).toBeVisible();
    await expect(page.locator('input[name="name"]')).toBeVisible();
  });

  test('should register new user successfully', async ({ page }) => {
    await page.click('text=ログイン');
    await page.click('text=アカウントをお持ちでない方');
    
    await page.fill('input[name="name"]', 'New User');
    await page.fill('input[name="email"]', 'newuser@example.com');
    await page.fill('input[name="password"]', 'newpassword123');
    await page.fill('input[name="confirmPassword"]', 'newpassword123');
    await page.click('button[type="submit"]');
    
    await expect(page.locator('text=登録しました')).toBeVisible();
  });
});

// frontend/e2e/content-upload.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Content Upload Flow', () => {
  test.beforeEach(async ({ page }) => {
    // ログイン
    await page.goto('/login');
    await page.fill('input[name="email"]', 'test@example.com');
    await page.fill('input[name="password"]', 'password123');
    await page.click('button[type="submit"]');
    await page.waitForURL('/dashboard');
  });

  test('should upload image successfully', async ({ page }) => {
    await page.click('text=アップロード');
    await page.click('text=画像');
    
    const fileInput = page.locator('input[type="file"]');
    await fileInput.setInputFiles('test-assets/sample-image.jpg');
    
    await page.fill('input[name="title"]', 'Test Image');
    await page.fill('textarea[name="description"]', 'This is a test image');
    await page.selectOption('select[name="category"]', 'image');
    
    await page.click('button[type="submit"]');
    
    await expect(page.locator('text=アップロードしました')).toBeVisible();
  });

  test('should show validation for required fields', async ({ page }) => {
    await page.click('text=アップロード');
    await page.click('text=画像');
    
    await page.click('button[type="submit"]');
    
    await expect(page.locator('text=タイトルは必須です')).toBeVisible();
    await expect(page.locator('text=ファイルは必須です')).toBeVisible();
  });

  test('should reject invalid file types', async ({ page }) => {
    await page.click('text=アップロード');
    await page.click('text=画像');
    
    const fileInput = page.locator('input[type="file"]');
    await fileInput.setInputFiles('test-assets/invalid-file.txt');
    
    await expect(page.locator('text=サポートされていないファイル形式です')).toBeVisible();
  });
});
```

## 8.7 パフォーマンステスト

### 8.7.1 Lighthouse CI設定
```yaml
# .lighthouserc.js
module.exports = {
  ci: {
    collect: {
      url: [
        'http://localhost:3000/',
        'http://localhost:3000/login',
        'http://localhost:3000/dashboard',
        'http://localhost:3000/community'
      ],
      numberOfRuns: 3,
      settings: {
        chromeFlags: '--no-sandbox --disable-dev-shm-usage'
      }
    },
    assert: {
      assertions: {
        'categories:performance': ['warn', { minScore: 0.8 }],
        'categories:accessibility': ['error', { minScore: 0.9 }],
        'categories:best-practices': ['warn', { minScore: 0.8 }],
        'categories:seo': ['warn', { minScore: 0.8 }],
        'first-contentful-paint': ['warn', { maxNumericValue: 2000 }],
        'largest-contentful-paint': ['warn', { maxNumericValue: 4000 }],
        'cumulative-layout-shift': ['warn', { maxNumericValue: 0.1 }],
        'total-blocking-time': ['warn', { maxNumericValue: 300 }]
      }
    },
    upload: {
      target: 'temporary-public-storage'
    }
  }
};
```

### 8.7.2 負荷テスト (Artillery)
```yaml
# artillery-config.yml
config:
  target: 'http://localhost:3001'
  phases:
    - duration: 60
      arrivalRate: 10
      name: "Warm up"
    - duration: 300
      arrivalRate: 50
      name: "Sustained load"
    - duration: 120
      arrivalRate: 100
      name: "Peak load"
    - duration: 60
      arrivalRate: 10
      name: "Cool down"
  
  defaults:
    headers:
      Content-Type: 'application/json'
  
  environments:
    development:
      target: 'http://localhost:3001'
    staging:
      target: 'https://staging.eldonia-nex.com'
    production:
      target: 'https://eldonia-nex.com'

scenarios:
  - name: "User Authentication Flow"
    weight: 30
    flow:
      - post:
          url: "/api/auth/login"
          json:
            email: "{{ $randomString() }}@example.com"
            password: "password123"
          capture:
            - json: "$.token"
              as: "authToken"
      
      - get:
          url: "/api/auth/profile"
          headers:
            Authorization: "Bearer {{ authToken }}"
      
      - post:
          url: "/api/auth/logout"
          headers:
            Authorization: "Bearer {{ authToken }}"

  - name: "Content Management"
    weight: 40
    flow:
      - post:
          url: "/api/auth/login"
          json:
            email: "{{ $randomString() }}@example.com"
            password: "password123"
          capture:
            - json: "$.token"
              as: "authToken"
      
      - get:
          url: "/api/content"
          headers:
            Authorization: "Bearer {{ authToken }}"
      
      - post:
          url: "/api/content"
          headers:
            Authorization: "Bearer {{ authToken }}"
          json:
            title: "{{ $randomString() }}"
            description: "{{ $randomString() }}"
            category: "image"
      
      - get:
          url: "/api/content/{{ $randomInt(1, 100) }}"
          headers:
            Authorization: "Bearer {{ authToken }}"

  - name: "Community Features"
    weight: 30
    flow:
      - post:
          url: "/api/auth/login"
          json:
            email: "{{ $randomString() }}@example.com"
            password: "password123"
          capture:
            - json: "$.token"
              as: "authToken"
      
      - get:
          url: "/api/community/posts"
          headers:
            Authorization: "Bearer {{ authToken }}"
      
      - post:
          url: "/api/community/posts"
          headers:
            Authorization: "Bearer {{ authToken }}"
          json:
            title: "{{ $randomString() }}"
            content: "{{ $randomString() }}"
            category: "general"
```

## 8.8 セキュリティテスト

### 8.8.1 OWASP ZAP設定
```yaml
# zap-config.yaml
# OWASP ZAP Security Testing Configuration
env:
  - name: ZAP_ALERT_LEVEL
    value: "Medium"
  
  - name: ZAP_FAIL_ON_HIGH
    value: "true"
  
  - name: ZAP_SCAN_LEVEL
    value: "Standard"

jobs:
  - name: "Security Scan"
    runs-on: ubuntu-latest
    steps:
      - name: "Run ZAP Baseline"
        uses: zaproxy/action-baseline@v0.8.0
        with:
          target: 'http://localhost:3000'
          rules_file_name: '.zap/rules.tsv'
          cmd_options: '-a'
      
      - name: "Run ZAP Full Scan"
        uses: zaproxy/action-full-scan@v0.8.0
        with:
          target: 'http://localhost:3000'
          rules_file_name: '.zap/rules.tsv'
          cmd_options: '-a'
      
      - name: "Generate Report"
        uses: zaproxy/action-report@v0.8.0
        with:
          target: 'http://localhost:3000'
          report_file_name: 'zap-report.html'
          report_file_format: 'html'
      
      - name: "Upload Report"
        uses: actions/upload-artifact@v3
        with:
          name: 'zap-security-report'
          path: 'zap-report.html'
          retention-days: 30

  - name: "Dependency Security Check"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: "Setup Node.js"
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      
      - name: "Audit Backend Dependencies"
        run: |
          cd backend
          npm audit --audit-level=moderate
          npm audit --audit-level=moderate --json > audit-report.json
      
      - name: "Audit Frontend Dependencies"
        run: |
          cd frontend
          npm audit --audit-level=moderate
          npm audit --audit-level=moderate --json > audit-report.json
      
      - name: "Upload Audit Reports"
        uses: actions/upload-artifact@v3
        with:
          name: 'dependency-audit-reports'
          path: |
            backend/audit-report.json
            frontend/audit-report.json
          retention-days: 30
```

### 8.8.2 セキュリティテストケース
```typescript
// backend/src/__tests__/security/security.test.ts
import request from 'supertest';
import { app } from '../../server';

describe('Security Tests', () => {
  describe('Authentication & Authorization', () => {
    it('should reject requests without authentication token', async () => {
      const response = await request(app)
        .get('/api/users/profile')
        .expect(401);
      
      expect(response.body.error).toBe('Authentication required');
    });

    it('should reject requests with invalid JWT token', async () => {
      const response = await request(app)
        .get('/api/users/profile')
        .set('Authorization', 'Bearer invalid-token')
        .expect(401);
      
      expect(response.body.error).toBe('Invalid token');
    });

    it('should reject requests with expired JWT token', async () => {
      // 期限切れトークンのテスト
      const expiredToken = 'expired.jwt.token';
      
      const response = await request(app)
        .get('/api/users/profile')
        .set('Authorization', `Bearer ${expiredToken}`)
        .expect(401);
      
      expect(response.body.error).toBe('Token expired');
    });
  });

  describe('Input Validation', () => {
    it('should reject SQL injection attempts', async () => {
      const maliciousInput = "'; DROP TABLE users; --";
      
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: maliciousInput,
          password: 'password123'
        })
        .expect(400);
      
      expect(response.body.errors).toContain('Invalid email format');
    });

    it('should reject XSS attempts', async () => {
      const maliciousInput = '<script>alert("XSS")</script>';
      
      const response = await request(app)
        .post('/api/community/posts')
        .set('Authorization', 'Bearer valid-token')
        .send({
          title: maliciousInput,
          content: 'Post content'
        })
        .expect(400);
      
      expect(response.body.errors).toContain('Invalid title format');
    });

    it('should reject path traversal attempts', async () => {
      const maliciousPath = '../../../etc/passwd';
      
      const response = await request(app)
        .get(`/api/files/${maliciousPath}`)
        .expect(400);
      
      expect(response.body.error).toBe('Invalid file path');
    });
  });

  describe('Rate Limiting', () => {
    it('should limit login attempts', async () => {
      const credentials = {
        email: 'test@example.com',
        password: 'wrongpassword'
      };

      // 複数回ログイン試行
      for (let i = 0; i < 5; i++) {
        await request(app)
          .post('/api/auth/login')
          .send(credentials)
          .expect(401);
      }

      // 6回目でレート制限
      const response = await request(app)
        .post('/api/auth/login')
        .send(credentials)
        .expect(429);
      
      expect(response.body.error).toBe('Too many requests');
    });

    it('should limit API requests', async () => {
      // 大量のAPIリクエスト
      for (let i = 0; i < 100; i++) {
        await request(app)
          .get('/api/health')
          .expect(200);
      }

      // 制限超過
      const response = await request(app)
        .get('/api/health')
        .expect(429);
      
      expect(response.body.error).toBe('Rate limit exceeded');
    });
  });

  describe('CSRF Protection', () => {
    it('should reject requests without CSRF token', async () => {
      const response = await request(app)
        .post('/api/users/profile')
        .set('Authorization', 'Bearer valid-token')
        .send({ name: 'New Name' })
        .expect(403);
      
      expect(response.body.error).toBe('CSRF token required');
    });

    it('should validate CSRF token', async () => {
      const response = await request(app)
        .post('/api/users/profile')
        .set('Authorization', 'Bearer valid-token')
        .set('X-CSRF-Token', 'invalid-token')
        .send({ name: 'New Name' })
        .expect(403);
      
      expect(response.body.error).toBe('Invalid CSRF token');
    });
  });
});
```

## 8.9 品質メトリクス

### 8.9.1 カバレッジ目標
```json
{
  "coverage": {
    "statements": 90,
    "branches": 85,
    "functions": 90,
    "lines": 90
  },
  "testMetrics": {
    "unitTests": {
      "total": 500,
      "passing": 495,
      "failing": 5,
      "successRate": 99.0
    },
    "integrationTests": {
      "total": 100,
      "passing": 98,
      "failing": 2,
      "successRate": 98.0
    },
    "e2eTests": {
      "total": 50,
      "passing": 48,
      "failing": 2,
      "successRate": 96.0
    }
  },
  "performance": {
    "lighthouse": {
      "performance": 85,
      "accessibility": 95,
      "bestPractices": 90,
      "seo": 90
    },
    "loadTesting": {
      "responseTime": {
        "p50": 200,
        "p95": 500,
        "p99": 1000
      },
      "throughput": 1000,
      "errorRate": 0.1
    }
  },
  "security": {
    "vulnerabilities": {
      "critical": 0,
      "high": 0,
      "medium": 2,
      "low": 5
    },
    "compliance": {
      "owasp": "Pass",
      "gdpr": "Pass",
      "pci": "Pass"
    }
  }
}
```

---

**次のセクション**: 09. 運用・監視設計
