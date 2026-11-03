<script>
  import { adjustStock, isLow } from '../lib/api.js';

  let { row, onback } = $props();

  let quantity = $state(row.quantity);
  let busy = $state(false);
  let error = $state('');

  async function change(delta) {
    busy = true;
    error = '';
    try {
      quantity = await adjustStock(row.stock_id, delta);
    } catch (e) {
      error = e.message;
    }
    busy = false;
  }

  function timeAgo(iso) {
    const min = Math.round((Date.now() - new Date(iso).getTime()) / 60000);
    if (min < 60) return `${Math.max(min, 0)} 分前`;
    if (min < 60 * 24) return `${Math.round(min / 60)} 時間前`;
    return `${Math.round(min / 60 / 24)} 日前`;
  }
</script>

<a href="#back" onclick={(e) => { e.preventDefault(); onback(); }}>← 戻る</a>

<hgroup style="margin-top: 1rem">
  <h3>{row.name}</h3>
  <p>{[row.part_number, row.manufacturer, row.category].filter(Boolean).join(' ・ ')}</p>
</hgroup>

{#if row.description}<p>{row.description}</p>{/if}

<article>
  <small class="muted">場所</small>
  <div><strong>{row.location_path ?? '場所未設定'}</strong></div>
</article>

<div class="stepper">
  <button class="secondary" disabled={busy || quantity === 0} onclick={() => change(-1)} aria-label="1 個減らす">−</button>
  <div class="qty" class:danger={isLow({ ...row, quantity })}>{quantity}</div>
  <button class="secondary" disabled={busy} onclick={() => change(1)} aria-label="1 個増やす">＋</button>
</div>
{#if error}<p class="danger">{error}</p>{/if}

{#if row.datasheet_url}
  <p style="margin-top: 1rem"><a href={row.datasheet_url} target="_blank" rel="noopener">データシート</a></p>
{/if}

<p class="muted" style="margin-top: 1rem">最終更新: {row.updated_by ?? '不明'} ・ {timeAgo(row.updated_at)}</p>
