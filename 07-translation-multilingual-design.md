# 07. 翻訳・多言語設計

## 7.1 多言語対応概要

### 7.1.1 設計方針
- **グローバル展開**: 100+言語対応
- **高精度翻訳**: Google AI Studio Gemini API活用
- **リアルタイム翻訳**: チャット・掲示板での即座翻訳
- **ローカライゼーション**: 文化・習慣に配慮した翻訳
- **パフォーマンス**: 翻訳キャッシュ・効率化

### 7.1.2 対応言語
- **主要言語**: 日本語、英語、中国語（簡体字・繁体字）、韓国語
- **欧州言語**: ドイツ語、フランス語、スペイン語、イタリア語、ロシア語
- **アジア言語**: タイ語、ベトナム語、インドネシア語、マレー語
- **その他**: アラビア語、ヒンディー語、ポルトガル語、オランダ語

## 7.2 Google AI Studio連携

### 7.2.1 Gemini API設定
```typescript
// backend/src/services/gemini.ts
import { GoogleGenerativeAI } from '@google/generative-ai';

export class GeminiTranslationService {
  private genAI: GoogleGenerativeAI;
  private model: any;

  constructor() {
    this.genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!);
    this.model = this.genAI.getGenerativeModel({ model: 'gemini-pro' });
  }

  // テキスト翻訳
  async translateText(
    text: string,
    sourceLang: string,
    targetLang: string,
    context?: string
  ): Promise<string> {
    const prompt = `
以下のテキストを${this.getLanguageName(sourceLang)}から${this.getLanguageName(targetLang)}に翻訳してください。
${context ? `コンテキスト: ${context}` : ''}

テキスト: ${text}

翻訳のみを返してください。
    `;

    try {
      const result = await this.model.generateContent(prompt);
      const response = await result.response;
      return response.text().trim();
    } catch (error) {
      console.error('Gemini API Error:', error);
      throw new Error('翻訳に失敗しました');
    }
  }

  // 画像翻訳（OCR + 翻訳）
  async translateImage(
    imageBuffer: Buffer,
    sourceLang: string,
    targetLang: string
  ): Promise<string> {
    const prompt = `
この画像のテキストを${this.getLanguageName(sourceLang)}から${this.getLanguageName(targetLang)}に翻訳してください。
画像内のテキストを認識し、翻訳結果のみを返してください。
    `;

    try {
      const imageData = {
        inlineData: {
          data: imageBuffer.toString('base64'),
          mimeType: 'image/jpeg'
        }
      };

      const result = await this.model.generateContent([prompt, imageData]);
      const response = await result.response;
      return response.text().trim();
    } catch (error) {
      console.error('Gemini Image Translation Error:', error);
      throw new Error('画像翻訳に失敗しました');
    }
  }

  // 音声翻訳（音声認識 + 翻訳）
  async translateAudio(
    audioBuffer: Buffer,
    sourceLang: string,
    targetLang: string
  ): Promise<string> {
    // 音声認識APIと組み合わせて実装
    const recognizedText = await this.speechToText(audioBuffer, sourceLang);
    return await this.translateText(recognizedText, sourceLang, targetLang);
  }

  private getLanguageName(langCode: string): string {
    const languageNames: { [key: string]: string } = {
      'ja': '日本語',
      'en': '英語',
      'zh': '中国語',
      'ko': '韓国語',
      'de': 'ドイツ語',
      'fr': 'フランス語',
      'es': 'スペイン語',
      'it': 'イタリア語',
      'ru': 'ロシア語',
      'th': 'タイ語',
      'vi': 'ベトナム語',
      'id': 'インドネシア語',
      'ms': 'マレー語',
      'ar': 'アラビア語',
      'hi': 'ヒンディー語',
      'pt': 'ポルトガル語',
      'nl': 'オランダ語'
    };
    return languageNames[langCode] || langCode;
  }
}
```

### 7.2.2 翻訳品質管理
```typescript
// backend/src/services/translationQuality.ts
export class TranslationQualityManager {
  // 翻訳品質スコア計算
  async calculateQualityScore(
    originalText: string,
    translatedText: string,
    sourceLang: string,
    targetLang: string
  ): Promise<number> {
    let score = 0;
    
    // 長さの比率チェック
    const lengthRatio = translatedText.length / originalText.length;
    if (lengthRatio >= 0.8 && lengthRatio <= 1.2) score += 20;
    
    // 特殊文字・記号の保持
    const specialChars = this.extractSpecialChars(originalText);
    const preservedChars = specialChars.filter(char => 
      translatedText.includes(char)
    ).length;
    score += (preservedChars / specialChars.length) * 20;
    
    // 言語固有の品質チェック
    score += await this.languageSpecificCheck(
      translatedText, targetLang
    );
    
    return Math.min(score, 100);
  }

  // 翻訳の再翻訳による品質チェック
  async backTranslationCheck(
    originalText: string,
    translatedText: string,
    sourceLang: string,
    targetLang: string
  ): Promise<boolean> {
    try {
      // 翻訳結果を元の言語に戻す
      const backTranslated = await this.translateText(
        translatedText, targetLang, sourceLang
      );
      
      // 類似度を計算
      const similarity = this.calculateSimilarity(
        originalText, backTranslated
      );
      
      return similarity > 0.7; // 70%以上の類似度
    } catch (error) {
      console.error('Back translation check failed:', error);
      return false;
    }
  }

  private extractSpecialChars(text: string): string[] {
    return text.match(/[^\w\s]/g) || [];
  }

  private async languageSpecificCheck(
    text: string, lang: string
  ): Promise<number> {
    // 言語固有の文法・表記チェック
    switch (lang) {
      case 'ja':
        return this.checkJapaneseQuality(text);
      case 'zh':
        return this.checkChineseQuality(text);
      case 'ko':
        return this.checkKoreanQuality(text);
      default:
        return 20; // デフォルトスコア
    }
  }

  private calculateSimilarity(text1: string, text2: string): number {
    // レーベンシュタイン距離による類似度計算
    const distance = this.levenshteinDistance(text1, text2);
    const maxLength = Math.max(text1.length, text2.length);
    return 1 - (distance / maxLength);
  }

  private levenshteinDistance(str1: string, str2: string): number {
    const matrix = Array(str2.length + 1).fill(null).map(() => 
      Array(str1.length + 1).fill(null)
    );

    for (let i = 0; i <= str1.length; i++) matrix[0][i] = i;
    for (let j = 0; j <= str2.length; j++) matrix[j][0] = j;

    for (let j = 1; j <= str2.length; j++) {
      for (let i = 1; i <= str1.length; i++) {
        const indicator = str1[i - 1] === str2[j - 1] ? 0 : 1;
        matrix[j][i] = Math.min(
          matrix[j][i - 1] + 1,
          matrix[j - 1][i] + 1,
          matrix[j - 1][i - 1] + indicator
        );
      }
    }
    return matrix[str2.length][str1.length];
  }
}
```

## 7.3 多言語データベース設計

### 7.3.1 翻訳テーブル
```sql
-- 翻訳管理テーブル
CREATE TABLE translations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content_type VARCHAR(50) NOT NULL, -- 'ui_text', 'content', 'error_message'
  content_id UUID NOT NULL, -- 元コンテンツのID
  source_language VARCHAR(10) NOT NULL, -- 'ja', 'en', 'zh'
  target_language VARCHAR(10) NOT NULL,
  original_text TEXT NOT NULL,
  translated_text TEXT NOT NULL,
  translation_quality_score INTEGER DEFAULT 0,
  is_verified BOOLEAN DEFAULT FALSE,
  verified_by UUID REFERENCES users(id),
  verified_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(content_type, content_id, source_language, target_language)
);

-- 翻訳キャッシュテーブル
CREATE TABLE translation_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_text_hash VARCHAR(64) NOT NULL, -- SHA256ハッシュ
  source_language VARCHAR(10) NOT NULL,
  target_language VARCHAR(10) NOT NULL,
  translated_text TEXT NOT NULL,
  quality_score INTEGER DEFAULT 0,
  usage_count INTEGER DEFAULT 1,
  last_used_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(source_text_hash, source_language, target_language)
);

-- ユーザー言語設定テーブル
CREATE TABLE user_language_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  primary_language VARCHAR(10) NOT NULL DEFAULT 'ja',
  secondary_languages VARCHAR(10)[], -- 複数言語対応
  ui_language VARCHAR(10) NOT NULL DEFAULT 'ja',
  content_language VARCHAR(10) NOT NULL DEFAULT 'ja',
  auto_translate BOOLEAN DEFAULT TRUE,
  translation_quality_threshold INTEGER DEFAULT 70,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id)
);

-- サポート言語テーブル
CREATE TABLE supported_languages (
  language_code VARCHAR(10) PRIMARY KEY,
  language_name VARCHAR(100) NOT NULL,
  native_name VARCHAR(100) NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_default BOOLEAN DEFAULT FALSE,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 7.3.2 翻訳インデックス
```sql
-- 翻訳検索用インデックス
CREATE INDEX idx_translations_content_type_id ON translations(content_type, content_id);
CREATE INDEX idx_translations_languages ON translations(source_language, target_language);
CREATE INDEX idx_translations_quality ON translations(translation_quality_score DESC);

-- 翻訳キャッシュ検索用インデックス
CREATE INDEX idx_translation_cache_hash ON translation_cache(source_text_hash);
CREATE INDEX idx_translation_cache_languages ON translation_cache(source_language, target_language);
CREATE INDEX idx_translation_cache_usage ON translation_cache(usage_count DESC, last_used_at DESC);

-- ユーザー言語設定検索用インデックス
CREATE INDEX idx_user_language_preferences_user ON user_language_preferences(user_id);
CREATE INDEX idx_user_language_preferences_primary ON user_language_preferences(primary_language);
```

---

## 7.4 フロントエンド多言語対応

### 7.4.1 Next.js国際化設定
```typescript
// frontend/next.config.js
const withNextIntl = require('next-intl/plugin')();

module.exports = withNextIntl({
  // その他の設定
  experimental: {
    appDir: true
  }
});

// frontend/i18n.ts
import { createI18n } from 'next-intl';

export const i18n = createI18n({
  locales: ['ja', 'en', 'zh', 'ko', 'de', 'fr', 'es', 'it', 'ru'],
  defaultLocale: 'ja',
  localeDetection: true
});

// frontend/messages/ja.json
export const jaMessages = {
  common: {
    welcome: 'ようこそ',
    login: 'ログイン',
    register: '登録',
    logout: 'ログアウト',
    profile: 'プロフィール',
    settings: '設定',
    search: '検索',
    submit: '送信',
    cancel: 'キャンセル',
    save: '保存',
    delete: '削除',
    edit: '編集',
    view: '表示'
  },
  navigation: {
    home: 'ホーム',
    community: 'コミュニティ',
    shop: 'ショップ',
    events: 'イベント',
    upload: 'アップロード',
    dashboard: 'ダッシュボード'
  },
  auth: {
    email: 'メールアドレス',
    password: 'パスワード',
    confirmPassword: 'パスワード確認',
    forgotPassword: 'パスワードを忘れた方',
    loginSuccess: 'ログインしました',
    loginFailed: 'ログインに失敗しました',
    registerSuccess: '登録しました',
    registerFailed: '登録に失敗しました'
  },
  content: {
    title: 'タイトル',
    description: '説明',
    category: 'カテゴリ',
    tags: 'タグ',
    uploadSuccess: 'アップロードしました',
    uploadFailed: 'アップロードに失敗しました'
  },
  community: {
    createPost: '投稿を作成',
    reply: '返信',
    like: 'いいね',
    share: 'シェア',
    report: '報告',
    follow: 'フォロー',
    unfollow: 'フォロー解除'
  }
};

// frontend/messages/en.json
export const enMessages = {
  common: {
    welcome: 'Welcome',
    login: 'Login',
    register: 'Register',
    logout: 'Logout',
    profile: 'Profile',
    settings: 'Settings',
    search: 'Search',
    submit: 'Submit',
    cancel: 'Cancel',
    save: 'Save',
    delete: 'Delete',
    edit: 'Edit',
    view: 'View'
  },
  navigation: {
    home: 'Home',
    community: 'Community',
    shop: 'Shop',
    events: 'Events',
    upload: 'Upload',
    dashboard: 'Dashboard'
  },
  auth: {
    email: 'Email',
    password: 'Password',
    confirmPassword: 'Confirm Password',
    forgotPassword: 'Forgot Password',
    loginSuccess: 'Login successful',
    loginFailed: 'Login failed',
    registerSuccess: 'Registration successful',
    registerFailed: 'Registration failed'
  },
  content: {
    title: 'Title',
    description: 'Description',
    category: 'Category',
    tags: 'Tags',
    uploadSuccess: 'Upload successful',
    uploadFailed: 'Upload failed'
  },
  community: {
    createPost: 'Create Post',
    reply: 'Reply',
    like: 'Like',
    share: 'Share',
    report: 'Report',
    follow: 'Follow',
    unfollow: 'Unfollow'
  }
};
```

### 7.4.2 言語切り替えコンポーネント
```typescript
// frontend/components/LanguageSwitcher.tsx
'use client';

import { useLocale, useTranslations } from 'next-intl';
import { useRouter, usePathname } from 'next/navigation';
import { useState } from 'react';

interface Language {
  code: string;
  name: string;
  nativeName: string;
  flag: string;
}

const languages: Language[] = [
  { code: 'ja', name: 'Japanese', nativeName: '日本語', flag: '🇯🇵' },
  { code: 'en', name: 'English', nativeName: 'English', flag: '🇺🇸' },
  { code: 'zh', name: 'Chinese', nativeName: '中文', flag: '🇨🇳' },
  { code: 'ko', name: 'Korean', nativeName: '한국어', flag: '🇰🇷' },
  { code: 'de', name: 'German', nativeName: 'Deutsch', flag: '🇩🇪' },
  { code: 'fr', name: 'French', nativeName: 'Français', flag: '🇫🇷' },
  { code: 'es', name: 'Spanish', nativeName: 'Español', flag: '🇪🇸' },
  { code: 'it', name: 'Italian', nativeName: 'Italiano', flag: '🇮🇹' },
  { code: 'ru', name: 'Russian', nativeName: 'Русский', flag: '🇷🇺' }
];

export default function LanguageSwitcher() {
  const locale = useLocale();
  const router = useRouter();
  const pathname = usePathname();
  const t = useTranslations('common');
  const [isOpen, setIsOpen] = useState(false);

  const currentLanguage = languages.find(lang => lang.code === locale);

  const handleLanguageChange = (newLocale: string) => {
    const newPathname = pathname.replace(`/${locale}`, `/${newLocale}`);
    router.push(newPathname);
    setIsOpen(false);
  };

  return (
    <div className="relative">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center space-x-2 px-3 py-2 rounded-lg border border-gray-300 hover:border-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
      >
        <span className="text-lg">{currentLanguage?.flag}</span>
        <span className="hidden sm:block">{currentLanguage?.nativeName}</span>
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {isOpen && (
        <div className="absolute right-0 mt-2 w-48 bg-white rounded-lg shadow-lg border border-gray-200 z-50">
          {languages.map((language) => (
            <button
              key={language.code}
              onClick={() => handleLanguageChange(language.code)}
              className={`w-full text-left px-4 py-2 hover:bg-gray-100 flex items-center space-x-3 ${
                locale === language.code ? 'bg-blue-50 text-blue-600' : ''
              }`}
            >
              <span className="text-lg">{language.flag}</span>
              <div>
                <div className="font-medium">{language.nativeName}</div>
                <div className="text-sm text-gray-500">{language.name}</div>
              </div>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
```

## 7.5 リアルタイム翻訳

### 7.5.1 WebSocket翻訳サービス
```typescript
// backend/src/services/realtimeTranslation.ts
import WebSocket from 'ws';
import { GeminiTranslationService } from './gemini';
import { TranslationCacheService } from './translationCache';

export class RealtimeTranslationService {
  private wss: WebSocket.Server;
  private geminiService: GeminiTranslationService;
  private cacheService: TranslationCacheService;
  private clients: Map<string, WebSocket> = new Map();

  constructor(server: any) {
    this.wss = new WebSocket.Server({ server });
    this.geminiService = new GeminiTranslationService();
    this.cacheService = new TranslationCacheService();
    this.setupWebSocket();
  }

  private setupWebSocket(): void {
    this.wss.on('connection', (ws: WebSocket, req: any) => {
      const clientId = this.generateClientId();
      this.clients.set(clientId, ws);

      ws.on('message', async (message: string) => {
        try {
          const data = JSON.parse(message);
          await this.handleTranslationRequest(clientId, data);
        } catch (error) {
          console.error('WebSocket message error:', error);
          ws.send(JSON.stringify({
            type: 'error',
            message: 'Invalid message format'
          }));
        }
      });

      ws.on('close', () => {
        this.clients.delete(clientId);
      });

      // 接続確認
      ws.send(JSON.stringify({
        type: 'connected',
        clientId: clientId
      }));
    });
  }

  private async handleTranslationRequest(clientId: string, data: any): Promise<void> {
    const { type, text, sourceLang, targetLang, context } = data;
    const ws = this.clients.get(clientId);

    if (!ws) return;

    try {
      switch (type) {
        case 'translate_text':
          await this.handleTextTranslation(ws, text, sourceLang, targetLang, context);
          break;
        case 'translate_chat':
          await this.handleChatTranslation(ws, text, sourceLang, targetLang, context);
          break;
        case 'translate_content':
          await this.handleContentTranslation(ws, text, sourceLang, targetLang, context);
          break;
        default:
          ws.send(JSON.stringify({
            type: 'error',
            message: 'Unknown translation type'
          }));
      }
    } catch (error) {
      console.error('Translation error:', error);
      ws.send(JSON.stringify({
        type: 'error',
        message: 'Translation failed'
      }));
    }
  }

  private async handleTextTranslation(
    ws: WebSocket,
    text: string,
    sourceLang: string,
    targetLang: string,
    context?: string
  ): Promise<void> {
    // キャッシュチェック
    const cached = await this.cacheService.getCachedTranslation(
      text, sourceLang, targetLang
    );

    if (cached) {
      ws.send(JSON.stringify({
        type: 'translation_result',
        originalText: text,
        translatedText: cached.translatedText,
        sourceLang,
        targetLang,
        qualityScore: cached.qualityScore,
        fromCache: true
      }));
      return;
    }

    // 翻訳実行
    const translatedText = await this.geminiService.translateText(
      text, sourceLang, targetLang, context
    );

    // 品質スコア計算
    const qualityScore = await this.calculateQualityScore(
      text, translatedText, sourceLang, targetLang
    );

    // キャッシュ保存
    await this.cacheService.saveTranslation(
      text, translatedText, sourceLang, targetLang, qualityScore
    );

    // 結果送信
    ws.send(JSON.stringify({
      type: 'translation_result',
      originalText: text,
      translatedText,
      sourceLang,
      targetLang,
      qualityScore,
      fromCache: false
    }));
  }

  private async handleChatTranslation(
    ws: WebSocket,
    text: string,
    sourceLang: string,
    targetLang: string,
    context?: string
  ): Promise<void> {
    // チャット用の軽量翻訳（高速化のため）
    const translatedText = await this.geminiService.translateText(
      text, sourceLang, targetLang, `チャットメッセージ: ${context || ''}`
    );

    ws.send(JSON.stringify({
      type: 'chat_translation',
      originalText: text,
      translatedText,
      sourceLang,
      targetLang,
      timestamp: new Date().toISOString()
    }));
  }

  private async handleContentTranslation(
    ws: WebSocket,
    text: string,
    sourceLang: string,
    targetLang: string,
    context?: string
  ): Promise<void> {
    // コンテンツ用の高品質翻訳
    const translatedText = await this.geminiService.translateText(
      text, sourceLang, targetLang, `コンテンツ: ${context || ''}`
    );

    // 品質チェック
    const qualityScore = await this.calculateQualityScore(
      text, translatedText, sourceLang, targetLang
    );

    // データベースに保存
    await this.saveTranslationToDatabase(
      text, translatedText, sourceLang, targetLang, qualityScore
    );

    ws.send(JSON.stringify({
      type: 'content_translation',
      originalText: text,
      translatedText,
      sourceLang,
      targetLang,
      qualityScore,
      saved: true
    }));
  }

  private async calculateQualityScore(
    originalText: string,
    translatedText: string,
    sourceLang: string,
    targetLang: string
  ): Promise<number> {
    // 簡易品質スコア計算
    let score = 0;
    
    // 長さチェック
    const lengthRatio = translatedText.length / originalText.length;
    if (lengthRatio >= 0.8 && lengthRatio <= 1.2) score += 30;
    
    // 特殊文字保持
    const specialChars = originalText.match(/[^\w\s]/g) || [];
    const preservedChars = specialChars.filter(char => 
      translatedText.includes(char)
    ).length;
    score += (preservedChars / specialChars.length) * 40;
    
    // 基本スコア
    score += 30;
    
    return Math.min(score, 100);
  }

  private async saveTranslationToDatabase(
    originalText: string,
    translatedText: string,
    sourceLang: string,
    targetLang: string,
    qualityScore: number
  ): Promise<void> {
    // データベース保存処理
    const query = `
      INSERT INTO translations (
        content_type, content_id, source_language, target_language,
        original_text, translated_text, translation_quality_score
      ) VALUES ($1, $2, $3, $4, $5, $6, $7)
      ON CONFLICT (content_type, content_id, source_language, target_language)
      DO UPDATE SET
        translated_text = EXCLUDED.translated_text,
        translation_quality_score = EXCLUDED.translation_quality_score,
        updated_at = CURRENT_TIMESTAMP
    `;
    
    await db.query(query, [
      'user_content',
      crypto.randomUUID(),
      sourceLang,
      targetLang,
      originalText,
      translatedText,
      qualityScore
    ]);
  }

  private generateClientId(): string {
    return crypto.randomUUID();
  }

  // ブロードキャスト翻訳結果
  public broadcastTranslation(
    originalText: string,
    translatedText: string,
    sourceLang: string,
    targetLang: string
  ): void {
    const message = JSON.stringify({
      type: 'broadcast_translation',
      originalText,
      translatedText,
      sourceLang,
      targetLang,
      timestamp: new Date().toISOString()
    });

    this.clients.forEach((client) => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(message);
      }
    });
  }
}
```

## 7.6 ローカライゼーション

### 7.6.1 文化・習慣対応
```typescript
// backend/src/services/localization.ts
export class LocalizationService {
  // 日付・時刻のローカライゼーション
  formatDateTime(date: Date, locale: string, format: string = 'full'): string {
    const options: Intl.DateTimeFormatOptions = this.getDateTimeOptions(locale, format);
    return new Intl.DateTimeFormat(locale, options).format(date);
  }

  private getDateTimeOptions(locale: string, format: string): Intl.DateTimeFormatOptions {
    const baseOptions: Intl.DateTimeFormatOptions = {
      timeZone: this.getTimeZone(locale)
    };

    switch (format) {
      case 'short':
        return {
          ...baseOptions,
          year: 'numeric',
          month: 'short',
          day: 'numeric'
        };
      case 'medium':
        return {
          ...baseOptions,
          year: 'numeric',
          month: 'long',
          day: 'numeric',
          hour: '2-digit',
          minute: '2-digit'
        };
      case 'full':
        return {
          ...baseOptions,
          year: 'numeric',
          month: 'long',
          day: 'numeric',
          weekday: 'long',
          hour: '2-digit',
          minute: '2-digit',
          second: '2-digit'
        };
      default:
        return baseOptions;
    }
  }

  // 通貨のローカライゼーション
  formatCurrency(amount: number, locale: string, currency: string = 'auto'): string {
    const currencyCode = currency === 'auto' ? this.getDefaultCurrency(locale) : currency;
    return new Intl.NumberFormat(locale, {
      style: 'currency',
      currency: currencyCode
    }).format(amount);
  }

  // 数値のローカライゼーション
  formatNumber(number: number, locale: string, options?: Intl.NumberFormatOptions): string {
    return new Intl.NumberFormat(locale, options).format(number);
  }

  // 言語固有の設定
  getLocaleSpecificSettings(locale: string): any {
    const settings: { [key: string]: any } = {
      'ja': {
        timeFormat: '24h',
        dateFormat: 'YYYY/MM/DD',
        currency: 'JPY',
        timezone: 'Asia/Tokyo',
        numberFormat: {
          decimal: '.',
          thousands: ',',
          precision: 0
        }
      },
      'en': {
        timeFormat: '12h',
        dateFormat: 'MM/DD/YYYY',
        currency: 'USD',
        timezone: 'America/New_York',
        numberFormat: {
          decimal: '.',
          thousands: ',',
          precision: 2
        }
      },
      'zh': {
        timeFormat: '24h',
        dateFormat: 'YYYY-MM-DD',
        currency: 'CNY',
        timezone: 'Asia/Shanghai',
        numberFormat: {
          decimal: '.',
          thousands: ',',
          precision: 2
        }
      },
      'ko': {
        timeFormat: '24h',
        dateFormat: 'YYYY-MM-DD',
        currency: 'KRW',
        timezone: 'Asia/Seoul',
        numberFormat: {
          decimal: '.',
          thousands: ',',
          precision: 0
        }
      }
    };

    return settings[locale] || settings['en'];
  }

  private getTimeZone(locale: string): string {
    const timeZones: { [key: string]: string } = {
      'ja': 'Asia/Tokyo',
      'en': 'America/New_York',
      'zh': 'Asia/Shanghai',
      'ko': 'Asia/Seoul',
      'de': 'Europe/Berlin',
      'fr': 'Europe/Paris',
      'es': 'Europe/Madrid',
      'it': 'Europe/Rome',
      'ru': 'Europe/Moscow'
    };
    return timeZones[locale] || 'UTC';
  }

  private getDefaultCurrency(locale: string): string {
    const currencies: { [key: string]: string } = {
      'ja': 'JPY',
      'en': 'USD',
      'zh': 'CNY',
      'ko': 'KRW',
      'de': 'EUR',
      'fr': 'EUR',
      'es': 'EUR',
      'it': 'EUR',
      'ru': 'RUB'
    };
    return currencies[locale] || 'USD';
  }
}
```

---

**次のセクション**: 08. テスト・品質保証
