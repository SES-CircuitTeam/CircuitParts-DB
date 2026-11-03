# CircuitParts-DB

回路部品の保管場所と在庫を部内で共有するための PWA です。

- フロントエンド: Vite + Svelte + Pico.css（GitHub Pages で配信）
- バックエンド: Supabase（PostgreSQL + 認証 + RLS）
- ログイン: Google ログイン、またはメールに届く 6 桁コード

部のドメインのアカウントなら自動で利用でき、それ以外の人は `members` テーブルに追加すると利用できます。

## セットアップ（最初の 1 回だけ）

### 1. Supabase プロジェクトを作る

1. https://supabase.com でプロジェクトを作成する
2. SQL Editor で [`supabase/migrations/001_init.sql`](supabase/migrations/001_init.sql) を実行する
3. 続けて、部のドメインと最初の管理者を登録する

   ```sql
   insert into public.allowed_domains (domain) values ('example.com');
   insert into public.members (email, name, role) values ('you@example.com', '管理者', 'admin');
   ```

### 2. Google ログインを有効にする

1. Google Cloud Console で OAuth クライアント（ウェブアプリケーション）を作成する
   - 承認済みのリダイレクト URI: `https://<project-ref>.supabase.co/auth/v1/callback`
   - Google Workspace を使っているなら、OAuth 同意画面の種類を「内部」にすると部のアカウント以外はログイン自体ができなくなる
2. Supabase の Authentication > Sign In / Providers > Google に、クライアント ID とシークレットを入力する
3. Authentication > URL Configuration
   - Site URL: `https://ses-circuitteam.github.io/CircuitParts-DB/`
   - Redirect URLs: 上記に加えて開発用の `http://localhost:5173/CircuitParts-DB/`

### 3. メールのコードログインを有効にする

1. Authentication > Emails > Templates の「Magic Link」に `{{ .Token }}` を含める（6 桁コードがメールに載る）
2. Supabase 標準のメール送信は 1 時間あたりの送信数が少ないので、Authentication > Emails > SMTP Settings で部のドメインから送れる SMTP（Resend など）を設定する

### 4. GitHub に設定する

リポジトリの Settings > Secrets and variables > Actions > **Variables** に次を登録します（どれも公開されて問題ない値です）。

| 名前 | 値 |
|---|---|
| `VITE_SUPABASE_URL` | Supabase の Project URL |
| `VITE_SUPABASE_KEY` | anon key または publishable key |
| `VITE_ALLOWED_DOMAIN` | 部のドメイン |
| `VITE_BASE` | 通常は空欄。カスタムドメインで配信するときだけ `/` |

`main` に push すると GitHub Actions がビルドして GitHub Pages に公開します。

## ローカルで開発する

```bash
npm install
cp .env.example .env.local   # 値を書き換える
npm run dev
```

アイコンを変えたときは `public/favicon.svg` を編集して `npm run icons` を実行します。

## 権限

| ロール | できること |
|---|---|
| 部員（ドメインのアカウント、または `members` の `member`） | 閲覧、部品・場所の追加、在庫数の変更 |
| 管理者（`members` の `admin`） | 上記に加え、部品・場所の削除や編集、部員の管理 |

## 今後の予定

- [ ] カメラでの QR / DataMatrix 読み取り
- [ ] Digi-Key API 連携（Supabase Edge Function 経由）による自動登録
- [ ] 保管場所の QR ラベル印刷
- [ ] 入出庫履歴
