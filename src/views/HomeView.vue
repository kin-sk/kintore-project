<template>
  <v-container class="home pa-4" style="max-width: 600px">

    <!-- まとめ -->
    <div class="tiles">
      <div class="tile">
        <span class="lbl">今月</span>
        <span class="num">{{ stats.thisMonth }}<small>回</small></span>
        <em>先月 {{ stats.prevMonth }}回</em>
      </div>
      <div class="tile">
        <span class="lbl">先週</span>
        <span class="num">{{ stats.lastWeek }}<small>回</small></span>
        <em>今週 {{ stats.thisWeek }}回</em>
      </div>
      <div class="tile">
        <span class="lbl">体重</span>
        <span class="num">{{ latestBody ? fmt1(latestBody.weight) : '—' }}<small>kg</small></span>
        <em v-if="weightDiff != null" :class="diffClass(weightDiff)">{{ formatDiff(weightDiff) }}</em>
        <em v-else>{{ latestBody ? formatMd(latestBody.date) : '未記録' }}</em>
      </div>
    </div>

    <!-- アクション -->
    <div class="actions">
      <v-btn to="/workout" color="primary" height="52" rounded="lg" class="act-main">
        <v-icon start>mdi-dumbbell</v-icon>筋トレを始める
      </v-btn>
      <button class="act-sub" @click="openBodySheet(todayStr, todayBody)">
        <v-icon size="22">mdi-scale-bathroom</v-icon>
        <span>体重<small>{{ todayBody ? `今日 ${fmt1(todayBody.weight)}kg` : '今日 未入力' }}</small></span>
      </button>
    </div>

    <!-- カレンダー -->
    <section class="card">
      <div class="cal-h">
        <button aria-label="前の月" @click="prevMonth"><v-icon>mdi-chevron-left</v-icon></button>
        <b>{{ currentYear }}年{{ currentMonth }}月</b>
        <button aria-label="次の月" :disabled="isCurrentMonth" @click="nextMonth"><v-icon>mdi-chevron-right</v-icon></button>
      </div>
      <div class="cal">
        <div
          v-for="(d, i) in weekDays"
          :key="d"
          class="wd"
          :class="{ sun: i === 0, sat: i === 6 }"
        >{{ d }}</div>
        <template v-for="(day, i) in calendarCells" :key="i">
          <div v-if="day === null" />
          <button
            v-else
            class="d num"
            :class="{
              w: workoutDates.has(day),
              t: isToday(day),
              sel: selectedDay === day,
              f: isFuture(day),
            }"
            :disabled="isFuture(day)"
            @click="selectDay(day)"
          >{{ day }}</button>
        </template>
      </div>
    </section>

    <!-- 選択日の記録 -->
    <section class="card det">
      <template v-if="selectedDay == null">
        <span class="lbl">日付をタップすると、その日の記録が表示されます</span>
      </template>
      <template v-else>
        <div class="det-h">
          <b>{{ selectedDayLabel }}</b>
          <button class="det-body" @click="openBodySheet(selectedDayDateStr, selectedDayBody)">
            <template v-if="selectedDayBody">
              体重 <span class="num">{{ fmt1(selectedDayBody.weight) }}</span>kg
              <template v-if="selectedDayBody.body_fat_percentage != null">
                ・体脂肪 <span class="num">{{ fmt1(selectedDayBody.body_fat_percentage) }}</span>%
              </template>
            </template>
            <template v-else>体重 未入力</template>
            <v-icon size="14">mdi-pencil</v-icon>
          </button>
        </div>
        <v-progress-linear v-if="dayDetailLoading" indeterminate color="primary" rounded />
        <template v-else>
          <div v-for="g in selectedDayWorkoutGroups" :key="g.exerciseName" class="det-ex">
            <span class="n">{{ g.exerciseName }}</span>
            <div class="pills">
              <span v-for="log in g.logs" :key="log.id" class="num">{{ fmtW(log.weight) }}<small>kg</small> × {{ log.reps }}</span>
            </div>
          </div>
          <span v-if="selectedDayWorkoutGroups.length === 0" class="lbl">トレーニングの記録はありません</span>
        </template>
      </template>
    </section>

    <!-- 体組成入力 -->
    <v-bottom-sheet v-model="bodySheet" max-width="600">
      <v-card class="sheet" rounded="t-xl">
        <div class="sheet-h">
          <b>{{ bodySheetTitle }}</b>
          <span v-if="latestBody" class="lbl">前回 {{ fmt1(latestBody.weight) }}kg</span>
        </div>
        <div class="sheet-row">
          <label for="h-weight">体重 kg</label>
          <div class="stepper">
            <button aria-label="体重を減らす" @click="bump('w', -0.1)"><v-icon>mdi-minus</v-icon></button>
            <input id="h-weight" v-model.number="inputWeight" class="num" type="number" inputmode="decimal" step="0.1" />
            <button aria-label="体重を増やす" @click="bump('w', 0.1)"><v-icon>mdi-plus</v-icon></button>
          </div>
        </div>
        <div class="sheet-row">
          <label for="h-fat">体脂肪率 %</label>
          <div class="stepper">
            <button aria-label="体脂肪率を減らす" @click="bump('f', -0.1)"><v-icon>mdi-minus</v-icon></button>
            <input id="h-fat" v-model.number="inputBodyFat" class="num" type="number" inputmode="decimal" step="0.1" placeholder="—" />
            <button aria-label="体脂肪率を増やす" @click="bump('f', 0.1)"><v-icon>mdi-plus</v-icon></button>
          </div>
        </div>
        <div class="sheet-btns">
          <v-btn variant="text" @click="bodySheet = false">キャンセル</v-btn>
          <v-btn color="primary" rounded="lg" :disabled="!inputWeight" :loading="saving" @click="saveBodyComposition">保存</v-btn>
        </div>
      </v-card>
    </v-bottom-sheet>

    <v-snackbar
      :model-value="!!saveErrorMessage"
      color="error"
      timeout="8000"
      @update:model-value="saveErrorMessage = ''"
    >
      保存に失敗しました: {{ saveErrorMessage }}
    </v-snackbar>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/composables/useAuth'
import { toLocalDateStr } from '@/lib/date'
import type { BodyComposition, WorkoutLog } from '@/types'

const { user } = useAuth()

const today = new Date()
const todayStr = toLocalDateStr(today)
const currentYear = ref(today.getFullYear())
const currentMonth = ref(today.getMonth() + 1)
const weekDays = ['日', '月', '火', '水', '木', '金', '土']

const isCurrentMonth = computed(
  () => currentYear.value === today.getFullYear() && currentMonth.value === today.getMonth() + 1,
)

function prevMonth() {
  if (currentMonth.value === 1) { currentYear.value--; currentMonth.value = 12 } else currentMonth.value--
}
function nextMonth() {
  if (currentMonth.value === 12) { currentYear.value++; currentMonth.value = 1 } else currentMonth.value++
}

// ---------- 表示ヘルパー ----------
function fmt1(n: number) { return (Math.round(n * 10) / 10).toFixed(1) }
function fmtW(w: number) { return Number.isInteger(w) ? String(w) : String(Math.round(w * 100) / 100) }
function formatDiff(n: number) {
  const v = Math.round(n * 10) / 10
  if (v > 0) return `▲${v.toFixed(1)}`
  if (v < 0) return `▼${Math.abs(v).toFixed(1)}`
  return '±0.0'
}
function diffClass(n: number) { return n < 0 ? 'down' : n > 0 ? 'up' : '' }
function formatMd(date: string) {
  const [, m, d] = date.split('-')
  return `${Number(m)}/${Number(d)}`
}
function dateStrOf(day: number) {
  return `${currentYear.value}-${String(currentMonth.value).padStart(2, '0')}-${String(day).padStart(2, '0')}`
}

// ---------- まとめ ----------
const stats = ref({ thisMonth: 0, prevMonth: 0, thisWeek: 0, lastWeek: 0 })
const latestTwo = ref<BodyComposition[]>([])
const latestBody = computed(() => latestTwo.value[0] ?? null)
const todayBody = computed(() => (latestBody.value?.date === todayStr ? latestBody.value : null))
const weightDiff = computed(() =>
  latestTwo.value.length >= 2 ? latestTwo.value[0].weight - latestTwo.value[1].weight : null,
)

async function loadStats() {
  const prevMonthStart = new Date(today.getFullYear(), today.getMonth() - 1, 1)
  const thisMonthStart = toLocalDateStr(new Date(today.getFullYear(), today.getMonth(), 1))
  const thisMonday = new Date(today)
  thisMonday.setDate(today.getDate() - ((today.getDay() + 6) % 7))
  const lastMonday = new Date(thisMonday)
  lastMonday.setDate(thisMonday.getDate() - 7)
  const thisMon = toLocalDateStr(thisMonday)
  const lastMon = toLocalDateStr(lastMonday)

  // 先週の月曜は必ず「先月1日」以降なので、この範囲だけ取れば全部数えられる
  const { data } = await supabase
    .from('workout_logs')
    .select('date')
    .eq('user_id', user.value!.id)
    .gte('date', toLocalDateStr(prevMonthStart))
    .lte('date', todayStr)
  const dates = [...new Set((data ?? []).map((r) => r.date as string))]
  stats.value = {
    thisMonth: dates.filter((d) => d >= thisMonthStart).length,
    prevMonth: dates.filter((d) => d < thisMonthStart).length,
    thisWeek: dates.filter((d) => d >= thisMon).length,
    lastWeek: dates.filter((d) => d >= lastMon && d < thisMon).length,
  }
}

async function loadLatestBody() {
  const { data } = await supabase
    .from('body_compositions')
    .select('*')
    .eq('user_id', user.value!.id)
    .order('date', { ascending: false })
    .limit(2)
  latestTwo.value = (data as BodyComposition[]) ?? []
}

// ---------- カレンダー ----------
const workoutDates = ref<Set<number>>(new Set())

const calendarCells = computed(() => {
  const firstDay = new Date(currentYear.value, currentMonth.value - 1, 1).getDay()
  const daysInMonth = new Date(currentYear.value, currentMonth.value, 0).getDate()
  const cells: (number | null)[] = Array(firstDay).fill(null)
  for (let d = 1; d <= daysInMonth; d++) cells.push(d)
  return cells
})

function isToday(day: number) {
  return isCurrentMonth.value && day === today.getDate()
}
function isFuture(day: number) {
  return dateStrOf(day) > todayStr
}

async function loadWorkoutDates() {
  const y = currentYear.value
  const m = currentMonth.value
  const lastDay = new Date(y, m, 0).getDate()
  const { data } = await supabase
    .from('workout_logs')
    .select('date')
    .eq('user_id', user.value!.id)
    .gte('date', `${y}-${String(m).padStart(2, '0')}-01`)
    .lte('date', `${y}-${String(m).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`)
  workoutDates.value = new Set((data ?? []).map((r) => Number((r.date as string).split('-')[2])))
}

watch([currentYear, currentMonth], () => {
  workoutDates.value = new Set()
  selectedDay.value = null
  loadWorkoutDates()
})

// ---------- 選択日の記録 ----------
const selectedDay = ref<number | null>(null)
const selectedDayBody = ref<BodyComposition | null>(null)
const selectedDayWorkouts = ref<WorkoutLog[]>([])
const dayDetailLoading = ref(false)

const selectedDayDateStr = computed(() => (selectedDay.value == null ? '' : dateStrOf(selectedDay.value)))
const selectedDayLabel = computed(() => {
  if (selectedDay.value == null) return ''
  const d = new Date(currentYear.value, currentMonth.value - 1, selectedDay.value)
  const suffix = selectedDayDateStr.value === todayStr ? '・今日' : ''
  return `${currentMonth.value}月${selectedDay.value}日（${weekDays[d.getDay()]}${suffix}）`
})

const selectedDayWorkoutGroups = computed(() => {
  const map = new Map<string, WorkoutLog[]>()
  for (const log of selectedDayWorkouts.value) {
    const name = log.exercise?.name ?? log.exercise_id
    if (!map.has(name)) map.set(name, [])
    map.get(name)!.push(log)
  }
  return Array.from(map.entries()).map(([exerciseName, logs]) => ({
    exerciseName,
    logs: logs.sort((a, b) => a.set_number - b.set_number),
  }))
})

async function selectDay(day: number) {
  selectedDay.value = day
  dayDetailLoading.value = true
  const dateStr = selectedDayDateStr.value
  const [workoutResult, bodyResult] = await Promise.all([
    supabase
      .from('workout_logs')
      .select('*, exercise:exercise_masters(*)')
      .eq('user_id', user.value!.id)
      .eq('date', dateStr)
      .order('exercise_id')
      .order('set_number'),
    supabase
      .from('body_compositions')
      .select('*')
      .eq('user_id', user.value!.id)
      .eq('date', dateStr)
      .maybeSingle(),
  ])
  // 読み込み中に別の日を押されたら古い結果は捨てる
  if (selectedDayDateStr.value !== dateStr) return
  selectedDayWorkouts.value = (workoutResult.data ?? []) as WorkoutLog[]
  selectedDayBody.value = bodyResult.data
  dayDetailLoading.value = false
}

// ---------- 体組成入力 ----------
const bodySheet = ref(false)
const bodySheetDate = ref('')
const inputWeight = ref<number | null>(null)
const inputBodyFat = ref<number | null>(null)
const saving = ref(false)
const saveErrorMessage = ref('')

const bodySheetTitle = computed(() => {
  if (!bodySheetDate.value || bodySheetDate.value === todayStr) return '今日の体組成'
  const [, m, d] = bodySheetDate.value.split('-')
  return `${Number(m)}月${Number(d)}日の体組成`
})

function openBodySheet(dateStr: string, existing: BodyComposition | null) {
  bodySheetDate.value = dateStr
  // 未入力の日は前回値から始めると ± で調整しやすい
  inputWeight.value = existing?.weight ?? latestBody.value?.weight ?? null
  inputBodyFat.value = existing?.body_fat_percentage ?? latestBody.value?.body_fat_percentage ?? null
  saveErrorMessage.value = ''
  bodySheet.value = true
}

function bump(key: 'w' | 'f', delta: number) {
  const target = key === 'w' ? inputWeight : inputBodyFat
  const base = target.value ?? (key === 'w' ? 60 : 20)
  target.value = Math.max(0, Math.round((base + delta) * 10) / 10)
}

async function saveBodyComposition() {
  if (!inputWeight.value || !bodySheetDate.value) return
  const targetDate = bodySheetDate.value
  saving.value = true
  const { error } = await supabase.from('body_compositions').upsert(
    {
      user_id: user.value!.id,
      date: targetDate,
      weight: inputWeight.value,
      body_fat_percentage: inputBodyFat.value || null,
    },
    { onConflict: 'date,user_id' },
  )
  saving.value = false
  if (error) {
    saveErrorMessage.value = error.message
    return
  }
  bodySheet.value = false
  await loadLatestBody()
  if (targetDate === selectedDayDateStr.value) {
    const { data } = await supabase
      .from('body_compositions')
      .select('*')
      .eq('user_id', user.value!.id)
      .eq('date', targetDate)
      .maybeSingle()
    selectedDayBody.value = data
  }
}

onMounted(() => {
  loadStats()
  loadLatestBody()
  loadWorkoutDates()
  selectDay(today.getDate())
})
</script>

<style scoped>
.home {
  --c-surface: var(--k-surface);
  --c-raised: var(--k-raised);
  --c-primary: var(--k-primary);
  --c-primary-soft: var(--k-primary-soft);
  --c-primary-text: var(--k-primary-text);
  --c-fg: var(--k-fg);
  --c-muted: var(--k-muted);
  --c-ok: var(--k-ok);
  --c-up: var(--k-up);
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.num { font-family: 'Barlow Condensed', 'Arial Narrow', sans-serif; font-variant-numeric: tabular-nums; }
button {
  font: inherit; color: inherit; border: 0; background: none; cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
button:focus-visible, input:focus-visible { outline: 2px solid var(--k-warn); outline-offset: 2px; }
.lbl { font-size: .72rem; color: var(--c-muted); letter-spacing: .04em; }
.down { color: var(--c-ok); }
.up { color: var(--c-up); }

/* まとめ */
.tiles { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
.tile { background: var(--c-surface); border-radius: 14px; padding: 9px 11px; display: flex; flex-direction: column; gap: 1px; min-width: 0; }
.tile .num { font-size: 1.6rem; font-weight: 600; line-height: 1.1; }
.tile .num small { font-size: .8rem; color: var(--c-muted); margin-left: 2px; }
.tile em { font-style: normal; font-size: .68rem; color: var(--c-muted); }
.tile em.down { color: var(--c-ok); }
.tile em.up { color: var(--c-up); }

/* アクション */
.actions { display: grid; grid-template-columns: 1.25fr 1fr; gap: 8px; }
.act-main { font-weight: 700; letter-spacing: 0; }
.act-sub {
  height: 52px; border-radius: 12px; background: var(--c-surface);
  display: flex; align-items: center; justify-content: center; gap: 8px;
  font-weight: 700; font-size: .88rem; line-height: 1.2; text-align: left;
}
.act-sub small { display: block; font-weight: 400; color: var(--c-muted); font-size: .72rem; }

/* カード */
.card { background: var(--c-surface); border-radius: 18px; padding: 12px; }

/* カレンダー */
.cal-h { display: flex; align-items: center; justify-content: space-between; margin-bottom: 6px; }
.cal-h b { font-size: .95rem; }
.cal-h button { width: 32px; height: 32px; border-radius: 9px; display: flex; align-items: center; justify-content: center; color: var(--c-muted); }
.cal-h button:disabled { opacity: .3; cursor: default; }
.cal { display: grid; grid-template-columns: repeat(7, 1fr); gap: 4px; text-align: center; }
.cal .wd { font-size: .66rem; color: var(--c-muted); padding-bottom: 2px; }
.cal .wd.sun { color: #ff8a8a; }
.cal .wd.sat { color: var(--c-primary-text); }
.cal .d {
  aspect-ratio: 1; max-width: 100%; border-radius: 10px; font-weight: 600; font-size: 1rem;
  display: flex; align-items: center; justify-content: center; color: #aab3bf;
}
.cal .d.w { background: var(--c-primary-soft); color: var(--c-primary-text); }
.cal .d.t { box-shadow: inset 0 0 0 2px var(--c-primary); color: var(--c-fg); }
.cal .d.sel { background: var(--c-primary); color: #fff; }
.cal .d.f { color: #4a525e; cursor: default; }

/* 選択日 */
.det { display: flex; flex-direction: column; gap: 10px; }
.det-h { display: flex; justify-content: space-between; align-items: center; gap: 8px; flex-wrap: wrap; }
.det-h b { font-size: .92rem; }
.det-body { font-size: .74rem; color: var(--c-muted); display: flex; align-items: center; gap: 4px; padding: 2px 4px; border-radius: 6px; }
.det-body .num { font-size: .95rem; color: var(--c-fg); font-weight: 600; }
.det-ex { display: flex; flex-direction: column; gap: 5px; }
.det-ex .n { font-size: .82rem; }
.pills { display: flex; flex-wrap: wrap; gap: 5px; }
.pills span { background: var(--c-raised); border-radius: 8px; padding: 3px 10px; font-weight: 600; font-size: 1.1rem; color: var(--c-fg); line-height: 1.3; }
.pills small { font-size: .72rem; color: var(--c-muted); margin-left: 1px; }

/* ボトムシート */
.sheet { padding: 16px 16px 20px; display: flex; flex-direction: column; gap: 14px; }
.sheet-h { display: flex; justify-content: space-between; align-items: baseline; }
.sheet-h b { font-size: 1rem; }
.sheet-row { display: flex; justify-content: space-between; align-items: center; }
.sheet-row label { font-size: .85rem; color: var(--c-muted); }
.stepper { display: flex; align-items: center; gap: 8px; }
.stepper button {
  width: 40px; height: 40px; border-radius: 12px; background: var(--c-raised);
  display: flex; align-items: center; justify-content: center;
}
.stepper input {
  width: 84px; text-align: center; background: transparent; border: 0; color: var(--c-fg);
  font-size: 2rem; font-weight: 600; line-height: 1; padding: 0;
  -moz-appearance: textfield; appearance: textfield;
}
.stepper input:focus { outline: none; border-bottom: 2px solid var(--c-primary); }
.stepper input::-webkit-outer-spin-button,
.stepper input::-webkit-inner-spin-button { -webkit-appearance: none; margin: 0; }
.sheet-btns { display: flex; justify-content: flex-end; gap: 8px; }
</style>
