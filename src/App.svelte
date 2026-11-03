<script>
  import { onMount } from 'svelte';
  import { supabase } from './lib/supabase.js';
  import Login from './routes/Login.svelte';
  import PartsList from './routes/PartsList.svelte';
  import Locations from './routes/Locations.svelte';
  import Scan from './routes/Scan.svelte';

  let loaded = $state(false);
  let session = $state(null);
  // null: 確認中 / true: 部員 / false: 権限なし
  let member = $state(null);
  let tab = $state('list');

  const tabs = [
    { id: 'list', label: '一覧', icon: '☰' },
    { id: 'scan', label: 'スキャン', icon: '⌗' },
    { id: 'locations', label: '場所', icon: '⌂' },
  ];

  async function checkMember() {
    if (!session) {
      member = null;
      return;
    }
    const { data, error } = await supabase.rpc('is_member');
    member = !error && data === true;
  }

  onMount(() => {
    const { data } = supabase.auth.onAuthStateChange((event, s) => {
      const changedUser = s?.user?.id !== session?.user?.id;
      session = s;
      loaded = true;
      // コールバック内で直接 Supabase を呼ぶとロックが絡むので次のタスクに回す
      if (changedUser) setTimeout(checkMember, 0);
    });
    return () => data.subscription.unsubscribe();
  });

  function signOut() {
    supabase.auth.signOut();
  }
</script>

{#if !loaded}
  <main class="container"><p aria-busy="true">読み込み中</p></main>
{:else if !session}
  <Login />
{:else if member === null}
  <main class="container"><p aria-busy="true">権限を確認中</p></main>
{:else if member === false}
  <main class="container">
    <article>
      <h3>このアカウントには権限がありません</h3>
      <p>{session.user.email} は部員として登録されていません。部のアカウントでログインし直すか、管理者に追加を依頼してください。</p>
      <button class="secondary" onclick={signOut}>ログアウト</button>
    </article>
  </main>
{:else}
  <main class="container">
    {#if tab === 'list'}
      <PartsList />
    {:else if tab === 'scan'}
      <Scan />
    {:else}
      <Locations />
    {/if}
    <p class="muted" style="margin-top:2rem">
      {session.user.email} ・ <a href="#logout" onclick={(e) => { e.preventDefault(); signOut(); }}>ログアウト</a>
    </p>
  </main>
  <nav class="tabs">
    {#each tabs as t}
      <button class:active={tab === t.id} onclick={() => (tab = t.id)}>
        <span class="icon" aria-hidden="true">{t.icon}</span>{t.label}
      </button>
    {/each}
  </nav>
{/if}
