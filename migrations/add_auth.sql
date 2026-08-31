-- Supabase認証機能 データベース移行スクリプト
-- このスクリプトはSupabase Dashboard > SQL Editorで実行してください

-- ========================================
-- ステップ1: user_idカラムの追加
-- ========================================

ALTER TABLE exercise_masters ADD COLUMN user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE workout_logs ADD COLUMN user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE body_compositions ADD COLUMN user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- ========================================
-- ステップ2: body_compositionsのUNIQUE制約を更新
-- ========================================

-- 既存のUNIQUE制約を削除
ALTER TABLE body_compositions DROP CONSTRAINT IF EXISTS body_compositions_date_key;

-- 新しい複合UNIQUE制約を追加 (date + user_id)
ALTER TABLE body_compositions ADD CONSTRAINT body_compositions_date_user_id_key UNIQUE (date, user_id);

-- ========================================
-- ステップ3: RLS有効化
-- ========================================

ALTER TABLE exercise_masters ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE body_compositions ENABLE ROW LEVEL SECURITY;

-- ========================================
-- ステップ4: RLSポリシー作成
-- ========================================

-- exercise_masters用ポリシー
CREATE POLICY "Users can view their own exercise masters"
  ON exercise_masters FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own exercise masters"
  ON exercise_masters FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own exercise masters"
  ON exercise_masters FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own exercise masters"
  ON exercise_masters FOR DELETE
  USING (auth.uid() = user_id);

-- workout_logs用ポリシー
CREATE POLICY "Users can view their own workout logs"
  ON workout_logs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own workout logs"
  ON workout_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own workout logs"
  ON workout_logs FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own workout logs"
  ON workout_logs FOR DELETE
  USING (auth.uid() = user_id);

-- body_compositions用ポリシー
CREATE POLICY "Users can view their own body compositions"
  ON body_compositions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own body compositions"
  ON body_compositions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own body compositions"
  ON body_compositions FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own body compositions"
  ON body_compositions FOR DELETE
  USING (auth.uid() = user_id);

-- ========================================
-- ステップ5: インデックス追加（パフォーマンス向上）
-- ========================================

CREATE INDEX idx_exercise_masters_user_id ON exercise_masters(user_id);
CREATE INDEX idx_workout_logs_user_id ON workout_logs(user_id);
CREATE INDEX idx_body_compositions_user_id ON body_compositions(user_id);

-- ========================================
-- ⚠️ 重要: 以下の手順を実行してください
-- ========================================

-- 1. このスクリプトをSupabase Dashboard > SQL Editorで実行
-- 2. フロントエンドアプリで最初のユーザーをサインアップ
-- 3. 以下のSQLでユーザーIDを取得:
--    SELECT id FROM auth.users WHERE email = 'あなたのメールアドレス';
--
-- 4. 既存データに取得したuser_idを設定（<YOUR_USER_ID>を実際のUUIDに置き換える）:
--
--    UPDATE exercise_masters SET user_id = '<YOUR_USER_ID>' WHERE user_id IS NULL;
--    UPDATE workout_logs SET user_id = '<YOUR_USER_ID>' WHERE user_id IS NULL;
--    UPDATE body_compositions SET user_id = '<YOUR_USER_ID>' WHERE user_id IS NULL;
--
-- 5. user_idカラムをNOT NULLに変更:
--
--    ALTER TABLE exercise_masters ALTER COLUMN user_id SET NOT NULL;
--    ALTER TABLE workout_logs ALTER COLUMN user_id SET NOT NULL;
--    ALTER TABLE body_compositions ALTER COLUMN user_id SET NOT NULL;
--
-- 6. データ移行が正しく完了したか確認:
--
--    SELECT COUNT(*) FROM exercise_masters WHERE user_id IS NULL; -- 0件であること
--    SELECT COUNT(*) FROM workout_logs WHERE user_id IS NULL; -- 0件であること
--    SELECT COUNT(*) FROM body_compositions WHERE user_id IS NULL; -- 0件であること
