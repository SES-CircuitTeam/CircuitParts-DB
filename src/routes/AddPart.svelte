<script>
  import { onMount } from 'svelte';
  import { supabase } from '../lib/supabase.js';
  import { listLocations, listCategories, ensureCategory } from '../lib/api.js';

  let { onclose } = $props();

  let locations = $state([]);
  let categories = $state([]);
  let form = $state({
    name: '',
    part_number: '',
    manufacturer: '',
    category: '',
    description: '',
    datasheet_url: '',
    location_id: '',
    quantity: 0,
    low_threshold: '',
  });
  let busy = $state(false);
  let error = $state('');

  onMount(async () => {
    try {
      [locations, categories] = await Promise.all([listLocations(), listCategories()]);
    } catch (e) {
      error = e.message;
    }
  });

  async function save(e) {
    e.preventDefault();
    if (!form.location_id) {
      error = '保管場所を選んでください。場所がなければ「場所」タブで先に作成します。';
      return;
    }
    busy = true;
    error = '';
    try {
      const category_id = await ensureCategory(form.category);
      const { data: part, error: e1 } = await supabase
        .from('parts')
        .insert({
          name: form.name.trim(),
          part_number: form.part_number.trim() || null,
          manufacturer: form.manufacturer.trim() || null,
          category_id,
          description: form.description.trim() || null,
          datasheet_url: form.datasheet_url.trim() || null,
        })
        .select('id')
        .single();
      if (e1) throw e1;
      const { error: e2 } = await supabase.from('stock').insert({
        part_id: part.id,
        location_id: Number(form.location_id),
        quantity: Number(form.quantity) || 0,
        low_threshold: form.low_threshold === '' ? null : Number(form.low_threshold),
      });
      if (e2) throw e2;
      onclose();
    } catch (err) {
      error = err.message;
    }
    busy = false;
  }
</script>

<a href="#back" onclick={(e) => { e.preventDefault(); onclose(); }}>← 戻る</a>
<h3 style="margin-top: 1rem">部品を追加</h3>

<form onsubmit={save}>
  <label>名前 <input required bind:value={form.name} placeholder="10kΩ 抵抗 0603" /></label>
  <div class="grid">
    <label>品番 <input bind:value={form.part_number} placeholder="RC0603FR-0710KL" /></label>
    <label>メーカー <input bind:value={form.manufacturer} placeholder="YAGEO" /></label>
  </div>
  <label>
    カテゴリ
    <input bind:value={form.category} list="category-options" placeholder="抵抗" />
    <datalist id="category-options">
      {#each categories as c}<option value={c.name}></option>{/each}
    </datalist>
  </label>
  <label>
    保管場所
    <select required bind:value={form.location_id}>
      <option value="" disabled>選択してください</option>
      {#each locations as l}<option value={String(l.id)}>{l.path}</option>{/each}
    </select>
  </label>
  <div class="grid">
    <label>個数 <input type="number" min="0" bind:value={form.quantity} /></label>
    <label>この数以下で警告 <input type="number" min="0" bind:value={form.low_threshold} placeholder="任意" /></label>
  </div>
  <label>データシート URL <input type="url" bind:value={form.datasheet_url} placeholder="https://" /></label>
  <label>メモ <textarea bind:value={form.description} rows="2"></textarea></label>

  {#if error}<p class="danger">{error}</p>{/if}
  <button type="submit" aria-busy={busy} disabled={busy} style="width: 100%">登録する</button>
</form>
