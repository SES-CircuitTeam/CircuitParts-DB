<script>
  import { supabase, ALLOWED_DOMAIN } from '../lib/supabase.js';

  let step = $state('start'); // start → code
  let email = $state('');
  let code = $state('');
  let busy = $state(false);
  let error = $state('');

  async function signInWithGoogle() {
    error = '';
    const { error: e } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: location.origin + import.meta.env.BASE_URL,
        // Google のアカウント選択を部のドメインに絞る（制限そのものは DB 側で行う）
        queryParams: ALLOWED_DOMAIN ? { hd: ALLOWED_DOMAIN } : undefined,
      },
    });
    if (e) error = e.message;
  }

  async function sendCode(e) {
    e.preventDefault();
    error = '';
    busy = true;
    const { error: err } = await supabase.auth.signInWithOtp({ email: email.trim() });
    busy = false;
    if (err) {
      error = err.message;
      return;
    }
    step = 'code';
  }

  async function verifyCode(e) {
    e.preventDefault();
    error = '';
    busy = true;
    const { error: err } = await supabase.auth.verifyOtp({
      email: email.trim(),
      token: code.trim(),
      type: 'email',
    });
    busy = false;
    if (err) error = 'コードが正しくないか、期限切れです。もう一度送信してください。';
  }
</script>

<main class="container" style="max-width: 28rem">
  <hgroup style="margin-top: 3rem">
    <h2>CircuitParts-DB</h2>
    <p>部品の保管場所と在庫の管理</p>
  </hgroup>

  {#if step === 'start'}
    <button onclick={signInWithGoogle} style="width: 100%">Google でログイン</button>

    <p class="muted" style="text-align: center; margin: 1.5rem 0 1rem">
      または、メールに届くコードでログイン（iPhone のホーム画面アプリ向け）
    </p>
    <form onsubmit={sendCode}>
      <input
        type="email"
        required
        bind:value={email}
        placeholder={ALLOWED_DOMAIN ? `name@${ALLOWED_DOMAIN}` : 'name@example.com'}
        autocomplete="email"
      />
      <button type="submit" class="secondary" aria-busy={busy} disabled={busy} style="width: 100%">
        コードを送信
      </button>
    </form>
  {:else}
    <p>{email} に 6 桁のコードを送りました。</p>
    <form onsubmit={verifyCode}>
      <input
        inputmode="numeric"
        autocomplete="one-time-code"
        required
        bind:value={code}
        placeholder="123456"
      />
      <button type="submit" aria-busy={busy} disabled={busy} style="width: 100%">ログイン</button>
    </form>
    <button class="outline secondary" onclick={() => { step = 'start'; code = ''; }} style="width: 100%">
      メールアドレスを変更
    </button>
  {/if}

  {#if error}
    <p class="danger">{error}</p>
  {/if}
</main>
