import { createClient } from '@supabase/supabase-js';

export const ALLOWED_DOMAIN = import.meta.env.VITE_ALLOWED_DOMAIN ?? '';

export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_KEY,
);
