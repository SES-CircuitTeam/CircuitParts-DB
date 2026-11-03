<script>
  import { onMount } from 'svelte';
  import { supabase } from '../lib/supabase.js';
  import { listLocations, searchStock, isLow } from '../lib/api.js';

  let locations = $state([]);
  let selected = $state(null);
  let items = $state([]);
  let newName = $state('');
  let newParent = $state('');
  let busy = $state(false);
  let error = $state('');

  const depth = (path) => path.split(' › ').length - 1;
  const leaf = (path) => path.split(' › ').at(-1);

  async function load() {
    try {
      locations = await listLocations();
    } catch (e) {
      error = e.message;
    }
  }

  async function open(loc) {
    selected = loc;
    items = [];
    try {
      items = await searchStock('', { locationId: loc.id });
    } catch (e) {
      error = e.message;
    }
  }

  async function add(e) {
    e.preventDefault();
    busy = true;
    error = '';
    const { error: err } = await supabase.from('locations').insert({
      name: newName.trim(),
      parent_id: newParent ? Number(newParent) : null,
    });
    busy = false;
    if (err) {
      error = err.code === '23505' ? '同じ場所に同じ名前があります。' : err.message;
      return;
    }
    newName = '';
    load();
  }

  onMount(load);
</script>

{#if selected}
  <a href="#back" onclick={(e) => { e.preventDefault(); selected = null; }}>← 戻る</a>
  <h3 style="margin-top: 1rem">{selected.path}</h3>
  <ul class="list">
    {#each items as r (r.stock_id)}
      <li style="cursor: default">
        <div class="title">{r.name}</div>
        <div class="muted" class:danger={isLow(r)}>{r.part_number ?? ''} ・ {r.quantity} 個</div>
      </li>
    {:else}
      <li class="muted" style="cursor: default">この場所には部品が登録されていません。</li>
    {/each}
  </ul>
{:else}
  <h3>保管場所</h3>
  <ul class="list">
    {#each locations as l (l.id)}
      <li style="padding-left: {depth(l.path) * 1.2}rem">
        <button class="item" onclick={() => open(l)}>{depth(l.path) > 0 ? '└ ' : ''}{leaf(l.path)}</button>
      </li>
    {:else}
      <li class="muted" style="cursor: default">まだ場所がありません。下のフォームから「部室」などを作成してください。</li>
    {/each}
  </ul>

  <details style="margin-top: 1.5rem">
    <summary>場所を追加</summary>
    <form onsubmit={add}>
      <label>
        親の場所
        <select bind:value={newParent}>
          <option value="">（いちばん上）</option>
          {#each locations as l}<option value={String(l.id)}>{l.path}</option>{/each}
        </select>
      </label>
      <label>名前 <input required bind:value={newName} placeholder="引き出し 3" /></label>
      <button type="submit" aria-busy={busy} disabled={busy}>追加</button>
    </form>
  </details>
{/if}

{#if error}<p class="danger">{error}</p>{/if}
