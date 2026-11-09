<template>
  <v-container class="workout pa-4" style="max-width: 600px;">

    <!-- ヘッダー -->
    <div class="w-top">
      <div>
        <div class="w-date">{{ todayLabel }}</div>
        <div class="w-title">今日のワークアウト</div>
      </div>
      <div class="w-vol">
        <span class="num">{{ totalVolume.toLocaleString() }}</span>
        <small>総挙上量 kg</small>
      </div>
    </div>

    <!-- インターバルタイマー -->
    <section class="w-timer" :class="{ flash: isFlashing }">
      <div class="ring" :class="{ warn: timerRunning && timerRemaining <= 10 }">
        <svg viewBox="0 0 120 120">
          <circle class="trk" cx="60" cy="60" r="52" />
          <circle
            class="prog"
            cx="60" cy="60" r="52"
            :stroke-dasharray="RING_LEN"
            :stroke-dashoffset="ringOffset"
          />
        </svg>
        <div class="ring-in">
          <span class="num">{{ formattedTime }}</span>
          <small>{{ timerLabel }}</small>
        </div>
      </div>
      <div class="t-ctl">
        <div class="t-chips">
          <button
            v-for="sec in TIMER_PRESETS"
            :key="sec"
            class="num"
            :class="{ on: timerSeconds === sec }"
            @click="setTimer(sec)"
          >{{ sec < 120 ? `${sec}s` : `${sec / 60}m` }}</button>
        </div>
        <div class="t-btns">
          <button class="play" :class="{ run: timerRunning }" @click="toggleTimer">
            <v-icon size="20">{{ timerRunning ? 'mdi-pause' : 'mdi-play' }}</v-icon>
            {{ timerRunning ? '一時停止' : 'スタート' }}
          </button>
          <button class="rst" aria-label="リセット" @click="resetTimer">
            <v-icon size="20">mdi-restore</v-icon>
          </button>
        </div>
      </div>
    </section>

    <!-- 部位フィルター + 検索 -->
    <div class="w-parts">
      <button
        v-for="p in partOptions"
        :key="p"
        :class="{ on: filterPart === p }"
        @click="filterPart = p"
      >{{ p }}</button>
      <button class="search" aria-label="種目を検索" @click="searchOpen = true">
        <v-icon size="18">mdi-magnify</v-icon>
      </button>
    </div>

    <!-- 種目カード -->
    <div ref="exListEl" class="w-exs">
      <button
        v-for="ex in filteredExercises"
        :key="ex.id"
        class="ex-card"
        :class="{ on: selectedExercise?.id === ex.id }"
        :data-id="ex.id"
        @click="selectExercise(ex)"
      >
        <b>{{ ex.name }}</b>
        <span v-if="prevByExercise[ex.id]">
          前回 {{ fmtW(prevByExercise[ex.id].weight) }}kg × {{ prevByExercise[ex.id].reps }}
        </span>
        <span v-else>{{ ex.part }}・{{ ex.equipment }}</span>
      </button>
      <div v-if="filteredExercises.length === 0" class="ex-empty">
        種目がありません。「種目」タブから登録してください
      </div>
    </div>

    <!-- 重量・回数 -->
    <div class="w-steps">
      <div class="step">
        <label for="w-weight">重量 kg</label>
        <div class="row">
          <button aria-label="重量を減らす" @click="bumpWeight(-WEIGHT_STEP)"><v-icon>mdi-minus</v-icon></button>
          <input
            id="w-weight"
            v-model.number="inputWeight"
            class="num"
            type="number"
            inputmode="decimal"
            step="0.5"
            min="0"
          />
          <button aria-label="重量を増やす" @click="bumpWeight(WEIGHT_STEP)"><v-icon>mdi-plus</v-icon></button>
        </div>
        <span class="prev">{{ lastRecord ? `前回 ${fmtW(lastRecord.weight)}kg` : '前回 —' }}</span>
      </div>
      <div class="step">
        <label for="w-reps">回数</label>
        <div class="row">
          <button aria-label="回数を減らす" @click="bumpReps(-1)"><v-icon>mdi-minus</v-icon></button>
          <input
            id="w-reps"
            v-model.number="inputReps"
            class="num"
            type="number"
            inputmode="numeric"
            min="1"
          />
          <button aria-label="回数を増やす" @click="bumpReps(1)"><v-icon>mdi-plus</v-icon></button>
        </div>
        <span class="prev">{{ lastRecord ? `前回 ${lastRecord.reps}回` : '前回 —' }}</span>
      </div>
    </div>

    <v-btn
      block
      color="primary"
      height="52"
      rounded="lg"
      class="w-rec"
      :disabled="!selectedExercise || !inputWeight || !inputReps"
      :loading="adding"
      @click="addSet"
    >
      <v-icon start>mdi-check</v-icon>
      {{ selectedExercise ? `${selectedExercise.name} を記録` : '種目を選んでください' }}
    </v-btn>

    <!-- 本日の記録 -->
    <div class="w-sec">本日の記録</div>
    <div v-if="groupedSets.length === 0" class="w-empty">まだ記録がありません</div>
    <div class="w-log">
      <div v-for="g in groupedSets" :key="g.exerciseId" class="grp">
        <b>{{ g.name }}</b>
        <div class="pills">
          <v-menu v-for="log in g.sets" :key="log.id" location="top">
            <template #activator="{ props }">
              <button v-bind="props" class="pill num" :class="{ new: log.id === lastAddedId }">
                {{ fmtW(log.weight) }}×{{ log.reps }}
              </button>
            </template>
            <v-list density="compact">
              <v-list-item
                prepend-icon="mdi-delete-outline"
                base-color="error"
                :title="`${log.set_number}セット目 ${fmtW(log.weight)}kg×${log.reps} を削除`"
                @click="deleteSet(log.id)"
              />
            </v-list>
          </v-menu>
        </div>
      </div>
    </div>

    <!-- 種目検索 -->
    <v-dialog v-model="searchOpen" max-width="480">
      <v-card rounded="lg">
        <v-card-text>
          <v-autocomplete
            :items="exercises"
            item-title="name"
            item-value="id"
            label="種目を検索"
            variant="outlined"
            density="compact"
            hide-details
            autofocus
            return-object
            @update:model-value="onSearchSelect"
          >
            <template #item="{ props, item }">
              <v-list-item v-bind="props" :subtitle="`${item.raw.part}・${item.raw.equipment}`" />
            </template>
          </v-autocomplete>
        </v-card-text>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snackbar" :timeout="snackbarColor === 'error' ? 6000 : 2000" :color="snackbarColor">{{ snackbarText }}</v-snackbar>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/composables/useAuth'
import { toLocalDateStr } from '@/lib/date'
import type { ExerciseMaster, WorkoutLog } from '@/types'
import { PARTS } from '@/types'

const { user } = useAuth()

const TIMER_PRESETS = [60, 90, 180]
const WEIGHT_STEP = 2.5
const RING_LEN = 2 * Math.PI * 52

const exercises = ref<ExerciseMaster[]>([])
const selectedExercise = ref<ExerciseMaster | null>(null)
const filterPart = ref('すべて')
const inputWeight = ref<number | null>(null)
const inputReps = ref<number | null>(null)
const todaySets = ref<WorkoutLog[]>([])
/** 種目ごとの前回（今日より前で最新の日の最終セット） */
const prevByExercise = ref<Record<string, WorkoutLog>>({})
const lastAddedId = ref<number | null>(null)
const searchOpen = ref(false)
const exListEl = ref<HTMLElement | null>(null)
const snackbar = ref(false)
const snackbarText = ref('')
const snackbarColor = ref<'success' | 'error'>('success')
const adding = ref(false)

const lastRecord = computed(() =>
  selectedExercise.value ? prevByExercise.value[selectedExercise.value.id] ?? null : null
)

const todayLabel = computed(() =>
  new Date().toLocaleDateString('ja-JP', { month: 'long', day: 'numeric', weekday: 'short' })
)

const totalVolume = computed(() =>
  Math.round(todaySets.value.reduce((sum, s) => sum + s.weight * s.reps, 0))
)

// 登録済みの種目にある部位だけをチップに出す（並びは PARTS 順）
const partOptions = computed(() => {
  const used = new Set(exercises.value.map((e) => e.part))
  return ['すべて', ...PARTS.filter((p) => used.has(p))]
})

const filteredExercises = computed(() =>
  exercises.value.filter((e) => filterPart.value === 'すべて' || e.part === filterPart.value)
)

// 本日の記録を種目ごとにまとめる（最初に記録した順）
const groupedSets = computed(() => {
  const map = new Map<string, { exerciseId: string; name: string; sets: WorkoutLog[] }>()
  for (const log of todaySets.value) {
    let g = map.get(log.exercise_id)
    if (!g) {
      const name = log.exercise?.name ?? exercises.value.find((e) => e.id === log.exercise_id)?.name ?? '不明な種目'
      g = { exerciseId: log.exercise_id, name, sets: [] }
      map.set(log.exercise_id, g)
    }
    g.sets.push(log)
  }
  return [...map.values()]
})

function fmtW(w: number) {
  return Number.isInteger(w) ? String(w) : String(Math.round(w * 100) / 100)
}

function selectExercise(ex: ExerciseMaster) {
  selectedExercise.value = ex
  // 今日すでにやっていればその最終セット、なければ前回値を初期値にする
  const todayLast = [...todaySets.value].reverse().find((s) => s.exercise_id === ex.id)
  const base = todayLast ?? prevByExercise.value[ex.id]
  if (base) {
    inputWeight.value = base.weight
    inputReps.value = base.reps
  }
}

function onSearchSelect(ex: ExerciseMaster | null) {
  if (!ex) return
  searchOpen.value = false
  if (filterPart.value !== 'すべて' && filterPart.value !== ex.part) filterPart.value = 'すべて'
  selectExercise(ex)
  nextTick(() => {
    exListEl.value
      ?.querySelector<HTMLElement>(`[data-id="${ex.id}"]`)
      ?.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' })
  })
}

function bumpWeight(delta: number) {
  inputWeight.value = Math.max(0, Math.round(((inputWeight.value ?? 0) + delta) * 100) / 100)
}

function bumpReps(delta: number) {
  inputReps.value = Math.max(1, (inputReps.value ?? 0) + delta)
}

// タイマー (バックグラウンド対応: 絶対タイムスタンプ方式)
const timerSeconds = ref(90)
const timerRemaining = ref(90)
const timerRunning = ref(false)
const isFlashing = ref(false)

let timerInterval: ReturnType<typeof setInterval> | null = null
let timerEndAt: number | null = null
let notifTimeout: ReturnType<typeof setTimeout> | null = null
const LS_END_KEY = 'kintore_timer_end_at'

const formattedTime = computed(() => {
  const m = Math.floor(timerRemaining.value / 60)
  const s = timerRemaining.value % 60
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
})

const timerLabel = computed(() => {
  if (timerRunning.value) return '休憩中'
  return timerRemaining.value === 0 ? '休憩終了' : '待機中'
})

const ringOffset = computed(() => {
  const ratio = timerSeconds.value > 0 ? Math.min(1, timerRemaining.value / timerSeconds.value) : 0
  return RING_LEN * (1 - ratio)
})

function tick() {
  if (!timerEndAt) return
  const remaining = Math.ceil((timerEndAt - Date.now()) / 1000)
  if (remaining <= 0) {
    timerRemaining.value = 0
    stopTick()
    timerRunning.value = false
    timerEndAt = null
    localStorage.removeItem(LS_END_KEY)
    onTimerEnd()
  } else {
    timerRemaining.value = remaining
  }
}

function stopTick() {
  if (timerInterval) { clearInterval(timerInterval); timerInterval = null }
  if (notifTimeout) { clearTimeout(notifTimeout); notifTimeout = null }
}

function startTimer() {
  timerEndAt = Date.now() + timerRemaining.value * 1000
  localStorage.setItem(LS_END_KEY, String(timerEndAt))
  timerRunning.value = true
  timerInterval = setInterval(tick, 500)
  scheduleNotification(timerRemaining.value)
}

function setTimer(secs: number) {
  stopTick()
  timerSeconds.value = secs
  timerRemaining.value = secs
  timerRunning.value = false
  timerEndAt = null
  localStorage.removeItem(LS_END_KEY)
}

function toggleTimer() {
  if (timerRunning.value) {
    stopTick()
    timerRunning.value = false
    timerEndAt = null
    localStorage.removeItem(LS_END_KEY)
  } else {
    if (timerRemaining.value <= 0) timerRemaining.value = timerSeconds.value
    startTimer()
  }
}

function resetTimer() {
  stopTick()
  timerRunning.value = false
  timerEndAt = null
  localStorage.removeItem(LS_END_KEY)
  timerRemaining.value = timerSeconds.value
}

function onTimerEnd() {
  if (navigator.vibrate) navigator.vibrate([300, 100, 300, 100, 300])
  let count = 0
  const flash = setInterval(() => {
    isFlashing.value = !isFlashing.value
    if (++count >= 6) { clearInterval(flash); isFlashing.value = false }
  }, 200)
}

async function scheduleNotification(seconds: number) {
  if (!('Notification' in window)) return
  if (Notification.permission === 'default') {
    await Notification.requestPermission()
  }
  if (Notification.permission !== 'granted') return
  notifTimeout = setTimeout(() => {
    if (!timerRunning.value) return
    new Notification('休憩終了！', {
      body: '次のセットを始めましょう 💪',
      icon: '/pwa-192x192.png',
    })
  }, seconds * 1000)
}

function handleVisibilityChange() {
  if (!document.hidden && timerRunning.value && timerEndAt) {
    // 復帰時に即座に残り時間を再計算してインターバルを再起動
    tick()
    if (timerRunning.value) {
      if (timerInterval) clearInterval(timerInterval)
      timerInterval = setInterval(tick, 500)
    }
  }
}

onUnmounted(() => {
  stopTick()
  document.removeEventListener('visibilitychange', handleVisibilityChange)
})

async function loadExercises() {
  const { data } = await supabase
    .from('exercise_masters')
    .select('*')
    .eq('user_id', user.value!.id)
    .order('name')
  exercises.value = data ?? []
}

async function loadTodaySets() {
  const today = toLocalDateStr()
  const { data } = await supabase
    .from('workout_logs')
    .select('*, exercise:exercise_masters(name)')
    .eq('user_id', user.value!.id)
    .eq('date', today)
    .order('created_at')
  todaySets.value = (data as WorkoutLog[]) ?? []
}

// 種目ごとの前回値を一括取得（新しい順に並べ、種目ごとに最初の1件を採用）
async function loadPrevRecords() {
  const today = toLocalDateStr()
  const { data } = await supabase
    .from('workout_logs')
    .select('*')
    .eq('user_id', user.value!.id)
    .lt('date', today)
    .order('date', { ascending: false })
    .order('set_number', { ascending: false })
    .limit(1000)
  const map: Record<string, WorkoutLog> = {}
  for (const log of (data as WorkoutLog[]) ?? []) {
    if (!map[log.exercise_id]) map[log.exercise_id] = log
  }
  prevByExercise.value = map
}

async function addSet() {
  if (adding.value) return
  if (!selectedExercise.value || !inputWeight.value || !inputReps.value) return
  adding.value = true
  try {
    const today = toLocalDateStr()
    const nextSet = todaySets.value.filter((s) => s.exercise_id === selectedExercise.value!.id).length + 1
    const { data, error } = await supabase
      .from('workout_logs')
      .insert({
        user_id: user.value!.id,
        date: today,
        exercise_id: selectedExercise.value.id,
        weight: inputWeight.value,
        reps: inputReps.value,
        set_number: nextSet,
      })
      .select('*, exercise:exercise_masters(name)')
      .single()
    if (error) throw error

    // 保存結果をそのまま一覧に反映（再取得を待たない）
    todaySets.value.push(data as WorkoutLog)
    lastAddedId.value = (data as WorkoutLog).id
    showSnackbar(`${selectedExercise.value.name} ${fmtW(inputWeight.value)}kg×${inputReps.value} を記録しました`, 'success')

    // インターバル中でも、新しいセットの記録でタイマーを頭からかけ直す
    stopTick()
    timerRemaining.value = timerSeconds.value
    startTimer()
  } catch (e: any) {
    console.error('[addSet] failed', e)
    showSnackbar(`記録に失敗しました: ${e?.message ?? e}`, 'error')
  } finally {
    adding.value = false
  }
}

function showSnackbar(text: string, color: 'success' | 'error') {
  snackbarText.value = text
  snackbarColor.value = color
  snackbar.value = true
}

async function deleteSet(id: number) {
  const { error } = await supabase.from('workout_logs').delete().eq('id', id)
  if (error) {
    console.error('[deleteSet] failed', error)
    showSnackbar(`削除に失敗しました: ${error.message}`, 'error')
    return
  }
  todaySets.value = todaySets.value.filter((s) => s.id !== id)
}

onMounted(() => {
  loadExercises()
  loadTodaySets()
  loadPrevRecords()
  document.addEventListener('visibilitychange', handleVisibilityChange)

  // ページ再読み込み時にタイマー状態を復元
  const saved = localStorage.getItem(LS_END_KEY)
  if (saved) {
    const endAt = parseInt(saved)
    const remaining = Math.ceil((endAt - Date.now()) / 1000)
    if (remaining > 0) {
      timerEndAt = endAt
      timerRemaining.value = remaining
      timerRunning.value = true
      timerInterval = setInterval(tick, 500)
    } else {
      localStorage.removeItem(LS_END_KEY)
      onTimerEnd()
    }
  }
})
</script>

<style scoped>
.workout {
  --c-surface: rgb(var(--v-theme-surface));
  --c-raised: rgb(var(--v-theme-surface-variant));
  --c-primary: rgb(var(--v-theme-primary));
  --c-warn: rgb(var(--v-theme-warning));
  --c-fg: rgb(var(--v-theme-on-background));
  --c-muted: #8b95a3;
  --c-line: #2f3540;
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.num {
  font-family: 'Barlow Condensed', 'Arial Narrow', sans-serif;
  font-variant-numeric: tabular-nums;
}
button {
  font: inherit;
  color: inherit;
  border: 0;
  background: none;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

/* ヘッダー */
.w-top { display: flex; justify-content: space-between; align-items: flex-end; }
.w-date { font-size: .75rem; color: var(--c-muted); }
.w-title { font-size: 1.15rem; font-weight: 700; }
.w-vol { text-align: right; line-height: 1.1; }
.w-vol .num { font-size: 1.5rem; font-weight: 700; }
.w-vol small { display: block; font-size: .66rem; color: var(--c-muted); }

/* タイマー */
.w-timer {
  background: var(--c-surface);
  border-radius: 20px;
  padding: 14px;
  display: flex;
  gap: 14px;
  align-items: center;
  transition: background-color .1s;
}
.w-timer.flash { background: rgba(76, 141, 255, .35); }
.ring { position: relative; width: 104px; height: 104px; flex: none; }
.ring svg { width: 100%; height: 100%; transform: rotate(-90deg); }
.ring circle { fill: none; stroke-width: 9; }
.ring .trk { stroke: var(--c-line); }
.ring .prog { stroke: var(--c-primary); stroke-linecap: round; transition: stroke-dashoffset .4s linear; }
.ring.warn .prog { stroke: var(--c-warn); }
.ring-in { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; }
.ring-in .num { font-size: 1.75rem; font-weight: 600; line-height: 1; }
.ring-in small { font-size: .62rem; color: var(--c-muted); }
.t-ctl { display: flex; flex-direction: column; gap: 10px; flex: 1; min-width: 0; }
.t-chips { display: flex; gap: 6px; }
.t-chips button {
  flex: 1; padding: 5px 0; border-radius: 8px;
  background: var(--c-raised); font-weight: 600; font-size: .95rem; color: #b9c2ce;
}
.t-chips button.on { background: rgba(76, 141, 255, .18); color: #8fb8ff; }
.t-btns { display: flex; gap: 8px; }
.t-btns .play {
  flex: 1; height: 40px; border-radius: 12px; background: var(--c-primary); color: #fff;
  display: flex; align-items: center; justify-content: center; gap: 6px; font-size: .85rem; font-weight: 700;
}
.t-btns .play.run { background: var(--c-line); color: var(--c-fg); }
.t-btns .rst {
  width: 40px; height: 40px; border-radius: 12px; background: var(--c-raised);
  display: flex; align-items: center; justify-content: center;
}

/* 部位チップ */
.w-parts { display: flex; gap: 6px; overflow-x: auto; scrollbar-width: none; align-items: center; }
.w-parts button {
  padding: 4px 12px; border-radius: 999px; border: 1px solid var(--c-line);
  font-size: .78rem; color: #b9c2ce; white-space: nowrap; flex: none;
}
.w-parts button.on { background: var(--c-fg); color: rgb(var(--v-theme-background)); border-color: var(--c-fg); }
.w-parts .search { margin-left: auto; padding: 4px 8px; display: flex; align-items: center; }

/* 種目カード */
.w-exs {
  display: flex; gap: 8px; overflow-x: auto; scrollbar-width: none;
  margin: 0 -16px; padding: 0 16px;
}
.ex-card {
  flex: none; width: 138px; text-align: left; background: var(--c-surface);
  border: 1.5px solid transparent; border-radius: 14px; padding: 10px 12px;
  display: flex; flex-direction: column; gap: 4px;
}
.ex-card.on { border-color: var(--c-primary); background: #1a2433; }
.ex-card b { font-size: .84rem; line-height: 1.3; font-weight: 700; }
.ex-card span { font-size: .7rem; color: var(--c-muted); }
.ex-empty { font-size: .8rem; color: var(--c-muted); padding: 8px 0; }

/* ステッパー */
.w-steps { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.step {
  background: var(--c-surface); border-radius: 16px; padding: 10px;
  display: flex; flex-direction: column; align-items: center; gap: 4px;
}
.step label { font-size: .7rem; color: var(--c-muted); }
.step .row { display: flex; align-items: center; justify-content: space-between; width: 100%; gap: 4px; }
.step .row button {
  width: 36px; height: 36px; border-radius: 10px; background: var(--c-raised);
  display: flex; align-items: center; justify-content: center; flex: none;
}
.step input {
  width: 100%; min-width: 0; text-align: center; background: transparent; border: 0;
  color: var(--c-fg); font-size: 2rem; font-weight: 600; line-height: 1; padding: 0;
  -moz-appearance: textfield; appearance: textfield;
}
.step input:focus { outline: none; border-bottom: 2px solid var(--c-primary); }
.step input::-webkit-outer-spin-button,
.step input::-webkit-inner-spin-button { -webkit-appearance: none; margin: 0; }
.step .prev { font-size: .66rem; color: #6f7988; }

.w-rec { font-weight: 700; letter-spacing: 0; }

/* 本日の記録 */
.w-sec { font-size: .72rem; color: var(--c-muted); letter-spacing: .08em; margin-top: 4px; }
.w-empty { font-size: .8rem; color: var(--c-muted); }
.w-log { display: flex; flex-direction: column; gap: 8px; }
.grp {
  background: var(--c-surface); border-radius: 14px; padding: 10px 12px;
  display: flex; flex-direction: column; gap: 8px;
}
.grp b { font-size: .84rem; }
.pills { display: flex; flex-wrap: wrap; gap: 6px; }
.pill {
  background: var(--c-raised); border-radius: 8px; padding: 2px 9px;
  font-size: .95rem; font-weight: 600; color: #cfd6df;
}
@keyframes pop { from { background: rgba(76, 141, 255, .45); } to { background: var(--c-raised); } }
.pill.new { animation: pop 1.4s ease-out; }

button:focus-visible, input:focus-visible { outline: 2px solid var(--c-warn); outline-offset: 2px; }
@media (prefers-reduced-motion: reduce) {
  .pill.new { animation: none; }
  .ring .prog { transition: none; }
}
</style>
