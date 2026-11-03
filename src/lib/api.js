import { supabase } from './supabase.js';

// PostgREST の or() 構文を壊す文字を取り除く
function sanitize(q) {
  return q.replace(/[,()%*\\]/g, ' ').trim();
}

export async function searchStock(q, { locationId } = {}) {
  let query = supabase.from('stock_view').select('*').order('name').limit(200);
  const s = sanitize(q ?? '');
  if (s) {
    query = query.or(
      `name.ilike.%${s}%,part_number.ilike.%${s}%,manufacturer.ilike.%${s}%,category.ilike.%${s}%`,
    );
  }
  if (locationId) query = query.eq('location_id', locationId);
  const { data, error } = await query;
  if (error) throw error;
  return data;
}

export async function listLocations() {
  const { data, error } = await supabase.from('location_paths').select('*').order('path');
  if (error) throw error;
  return data;
}

export async function listCategories() {
  const { data, error } = await supabase.from('categories').select('*').order('name');
  if (error) throw error;
  return data;
}

// 名前でカテゴリを探し、なければ作る
export async function ensureCategory(name) {
  const n = name.trim();
  if (!n) return null;
  const { data: found } = await supabase.from('categories').select('id').eq('name', n).maybeSingle();
  if (found) return found.id;
  const { data, error } = await supabase.from('categories').insert({ name: n }).select('id').single();
  if (error) throw error;
  return data.id;
}

export async function adjustStock(stockId, delta) {
  const { data, error } = await supabase.rpc('adjust_stock', { p_stock_id: stockId, p_delta: delta });
  if (error) throw error;
  return data;
}

export function isLow(row) {
  return row.quantity === 0 || (row.low_threshold != null && row.quantity <= row.low_threshold);
}
