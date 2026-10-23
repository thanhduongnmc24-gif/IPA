-- ============================================================================
-- BẢNG ĐỒNG BỘ XƯỞNG CÁN TRÊN SUPABASE
-- Cách chạy: Mở https://supabase.com/dashboard -> Chọn project của bạn ->
-- Vào mục "SQL Editor" -> Dán toàn bộ đoạn mã dưới đây và bấm "Run".
-- ============================================================================

create table if not exists public.xuong_can_bang (
  id text primary key,
  ten_bang text not null,
  mo_ta text default '',
  du_lieu jsonb not null,
  updated_at timestamptz default now()
);

alter table public.xuong_can_bang enable row level security;

drop policy if exists "Cho phep doc ghi xuong_can_bang" on public.xuong_can_bang;

create policy "Cho phep doc ghi xuong_can_bang"
  on public.xuong_can_bang
  for all
  using (true)
  with check (true);
