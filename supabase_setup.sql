-- ① 種目マスタテーブル
create table if not exists exercise_masters (
  id         uuid primary key default gen_random_uuid(),
  name       varchar not null,
  part       varchar not null,
  equipment  varchar not null,
  created_at timestamptz default now()
);

-- ② 筋トレ記録テーブル（1セット＝1レコード）
create table if not exists workout_logs (
  id          bigint primary key generated always as identity,
  date        date not null default current_date,
  exercise_id uuid references exercise_masters(id) on delete cascade,
  weight      numeric not null,
  reps        integer not null,
  set_number  integer not null,
  created_at  timestamptz default now()
);

-- ③ 体組成テーブル（1日1レコード）
create table if not exists body_compositions (
  id                   bigint primary key generated always as identity,
  date                 date not null unique,
  weight               numeric not null,
  body_fat_percentage  numeric,
  created_at           timestamptz default now()
);

-- RLS無効化（個人専用アプリ）
alter table exercise_masters disable row level security;
alter table workout_logs     disable row level security;
alter table body_compositions disable row level security;

-- デフォルト種目データ
insert into exercise_masters (name, part, equipment) values
  ('ベンチプレス',       '胸',   'バーベル'),
  ('インクラインベンチ', '胸',   'バーベル'),
  ('ダンベルフライ',     '胸',   'ダンベル'),
  ('ケーブルクロスオーバー', '胸', 'ケーブル'),
  ('チェストプレス',     '胸',   'マシン'),
  ('デッドリフト',       '背中', 'バーベル'),
  ('バーベルロウ',       '背中', 'バーベル'),
  ('ラットプルダウン',   '背中', 'マシン'),
  ('ケーブルロウ',       '背中', 'ケーブル'),
  ('懸垂',              '背中', '自重'),
  ('スクワット',         '脚',   'バーベル'),
  ('レッグプレス',       '脚',   'マシン'),
  ('レッグカール',       '脚',   'マシン'),
  ('レッグエクステンション', '脚', 'マシン'),
  ('カーフレイズ',       '脚',   'マシン'),
  ('ショルダープレス',   '肩',   'バーベル'),
  ('ダンベルショルダープレス', '肩', 'ダンベル'),
  ('サイドレイズ',       '肩',   'ダンベル'),
  ('フロントレイズ',     '肩',   'ダンベル'),
  ('バーベルカール',     '腕',   'バーベル'),
  ('ダンベルカール',     '腕',   'ダンベル'),
  ('トライセプスプッシュダウン', '腕', 'ケーブル'),
  ('スカルクラッシャー', '腕',   'バーベル'),
  ('クランチ',          '腹',   '自重'),
  ('レッグレイズ',       '腹',   '自重')
;
