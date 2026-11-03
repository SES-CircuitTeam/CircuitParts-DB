<script>
  import { onMount } from 'svelte';
  import { searchStock, isLow } from '../lib/api.js';
  import PartDetail from './PartDetail.svelte';
  import AddPart from './AddPart.svelte';

  let q = $state('');
  let rows = $state([]);
  let loading = $state(false);
  let error = $state('');
  let selected = $state(null);
  let adding = $state(false);
  let timer;

  async function load() {
    loading = true;
    error = '';
    try {
      rows = await searchStock(q);
    } catch (e) {
      error = e.message;
    }
    loading = false;
  }

  function onInput() {
    clearTimeout(timer);
    timer = setTimeout(load, 250);
  }

  onMount(load);
</script>

{#if selected}
  <PartDetail row={selected} onback={() => { selected = null; load(); }} />
{:else if adding}
  <AddPart onclose={() => { adding = false; load(); }} />
{:else}
  <div class="row">
    <input type="search" bind:value={q} oninput={onInput} placeholder="品番・名前・カテゴリで検索" />
    <button onclick={() => (adding = true)} style="white-space: nowrap">＋ 追加</button>
  </div>

  {#if error}<p class="danger">{error}</p>{/if}
  {#if loading && rows.length === 0}<p aria-busy="true"></p>{/if}

  <ul class="list" style="margin-top: 1rem">
    {#each rows as r (r.stock_id)}
      <li>
        <button class="item" onclick={() => (selected = r)}>
          <div class="title">{r.name}{#if r.part_number && r.part_number !== r.name}<span class="muted"> {r.part_number}</span>{/if}</div>
          <div class="muted" class:danger={isLow(r)}>
            {r.location_path ?? '場所未設定'} ・ {r.quantity} 個{#if isLow(r)}（残りわずか）{/if}
          </div>
        </button>
      </li>
    {:else}
      {#if !loading}<li class="muted" style="cursor: default">見つかりませんでした。「＋ 追加」から登録できます。</li>{/if}
    {/each}
  </ul>
{/if}
