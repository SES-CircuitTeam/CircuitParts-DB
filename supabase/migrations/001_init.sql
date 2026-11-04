-- CircuitParts-DB 初期スキーマ
-- Supabase ダッシュボードの SQL Editor に貼り付けて実行する

-- =========================================================
-- 認証・権限
-- =========================================================

-- このドメインのメールアドレスは自動で部員扱い
create table public.allowed_domains (
  domain text primary key
);

-- 個別に許可する人（OB・外部協力者など）と、管理者の指定
create table public.members (
  email      text primary key,
  name       text,
  role       text not null default 'member' check (role in ('admin', 'member')),
  created_at timestamptz not null default now()
);

create or replace function public.current_email()
returns text
language sql stable
as $$
  select lower(auth.jwt() ->> 'email')
$$;

create or replace function public.is_member()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (select 1 from members where email = current_email())
      or exists (select 1 from allowed_domains where current_email() like '%@' || domain);
$$;

create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (select 1 from members where email = current_email() and role = 'admin');
$$;

-- =========================================================
-- 部品データ
-- =========================================================

-- 保管場所（自己参照で階層: 部室 > 棚A > 引き出し2）
create table public.locations (
  id         bigint generated always as identity primary key,
  name       text not null,
  parent_id  bigint references public.locations (id) on delete restrict,
  note       text,
  created_at timestamptz not null default now(),
  unique (parent_id, name)
);

create table public.categories (
  id   bigint generated always as identity primary key,
  name text not null unique
);

create table public.parts (
  id                   bigint generated always as identity primary key,
  name                 text not null,
  part_number          text,
  manufacturer         text,
  category_id          bigint references public.categories (id) on delete set null,
  description          text,
  datasheet_url        text,
  supplier             text,
  supplier_part_number text,
  notes                text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  updated_by           text default public.current_email()
);

create index parts_part_number_idx on public.parts (part_number);
create index parts_supplier_pn_idx on public.parts (supplier, supplier_part_number);

-- どこに何個あるか（同じ部品が複数の場所にあってもよい）
create table public.stock (
  id            bigint generated always as identity primary key,
  part_id       bigint not null references public.parts (id) on delete cascade,
  location_id   bigint not null references public.locations (id) on delete restrict,
  quantity      integer not null default 0 check (quantity >= 0),
  low_threshold integer,
  updated_at    timestamptz not null default now(),
  updated_by    text default public.current_email(),
  unique (part_id, location_id)
);

-- 更新日時と更新者を自動で記録
create or replace function public.touch_updated()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  new.updated_by := public.current_email();
  return new;
end;
$$;

create trigger parts_touch before update on public.parts
  for each row execute function public.touch_updated();
create trigger stock_touch before update on public.stock
  for each row execute function public.touch_updated();

-- 場所のパンくず表示用（例: "部室 › 棚A › 引き出し2"）
create view public.location_paths with (security_invoker = true) as
with recursive t as (
  select id, parent_id, name::text as path
  from public.locations
  where parent_id is null
  union all
  select l.id, l.parent_id, t.path || ' › ' || l.name
  from public.locations l
  join t on l.parent_id = t.id
)
select id, parent_id, path from t;

-- 一覧画面用
create view public.stock_view with (security_invoker = true) as
select
  s.id            as stock_id,
  s.quantity,
  s.low_threshold,
  s.updated_at,
  s.updated_by,
  p.id            as part_id,
  p.name,
  p.part_number,
  p.manufacturer,
  p.description,
  p.datasheet_url,
  c.name          as category,
  s.location_id,
  lp.path         as location_path
from public.stock s
join public.parts p on p.id = s.part_id
left join public.categories c on c.id = p.category_id
left join public.location_paths lp on lp.id = s.location_id;

-- 在庫の増減（同時に押されても数がずれないよう DB 側で加算する）
create or replace function public.adjust_stock(p_stock_id bigint, p_delta integer)
returns integer
language sql
as $$
  update public.stock
     set quantity = greatest(quantity + p_delta, 0)
   where id = p_stock_id
  returning quantity;
$$;

-- =========================================================
-- RLS（部員だけが読み書きでき、削除などは管理者のみ）
-- =========================================================

alter table public.allowed_domains enable row level security;
alter table public.members         enable row level security;
alter table public.locations       enable row level security;
alter table public.categories      enable row level security;
alter table public.parts           enable row level security;
alter table public.stock           enable row level security;

create policy "admin manages domains" on public.allowed_domains
  for all using (public.is_admin()) with check (public.is_admin());

create policy "see own row or admin" on public.members
  for select using (email = public.current_email() or public.is_admin());
create policy "admin manages members" on public.members
  for all using (public.is_admin()) with check (public.is_admin());

-- locations / categories / parts: 部員は閲覧・追加・編集、削除は管理者
create policy "members read"   on public.locations for select using (public.is_member());
create policy "members insert" on public.locations for insert with check (public.is_member());
create policy "admin update"   on public.locations for update using (public.is_admin());
create policy "admin delete"   on public.locations for delete using (public.is_admin());

create policy "members read"   on public.categories for select using (public.is_member());
create policy "members insert" on public.categories for insert with check (public.is_member());
create policy "admin update"   on public.categories for update using (public.is_admin());
create policy "admin delete"   on public.categories for delete using (public.is_admin());

create policy "members read"   on public.parts for select using (public.is_member());
create policy "members insert" on public.parts for insert with check (public.is_member());
create policy "members update" on public.parts for update using (public.is_member());
create policy "admin delete"   on public.parts for delete using (public.is_admin());

-- stock: 在庫の移動・使い切りがあるので削除も部員に許可
create policy "members read"   on public.stock for select using (public.is_member());
create policy "members insert" on public.stock for insert with check (public.is_member());
create policy "members update" on public.stock for update using (public.is_member());
create policy "members delete" on public.stock for delete using (public.is_member());

-- =========================================================
-- アクセス権（"Automatically expose new tables" をオフにしたプロジェクト向け）
-- ログイン済みのユーザーにだけ API からの操作を許可し、実際の制限は上の RLS で行う
-- =========================================================

grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
grant execute on function
  public.current_email(),
  public.is_member(),
  public.is_admin(),
  public.adjust_stock(bigint, integer)
to authenticated;

-- =========================================================
-- 初期データ（自分たちの値に書き換えて実行）
-- =========================================================

-- insert into public.allowed_domains (domain) values ('example.com');
-- insert into public.members (email, name, role) values ('you@example.com', '管理者', 'admin');
