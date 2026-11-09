<template>
  <v-container class="graph pa-4" style="max-width: 600px;">

    <div class="tabs" role="tablist">
      <button
        v-for="t in TABS"
        :key="t.key"
        role="tab"
        :aria-selected="tab === t.key"
        :class="{ on: tab === t.key }"
        @click="tab = t.key"
      >{{ t.label }}</button>
    </div>

    <!-- ========== 体重 / 体脂肪 ========== -->
    <template v-if="tab !== 'train'">
      <template v-if="bodyLatest">
        <div class="hero">
          <div>
            <span class="lbl">最新（{{ formatMd(bodyLatest.date) }}）</span>
            <div class="num">{{ fmt1(bodyLatest.value) }}<small>{{ bodyUnit }}</small></div>
          </div>
          <div class="hero-d">
            {{ PERIOD_LABEL[period] }}で<br>
            <b v-if="bodyPeriodChange != null" class="num" :class="diffClass(bodyPeriodChange)">
              {{ formatDiff(bodyPeriodChange) }}{{ bodyUnit }}
            </b>
            <b v-else class="num">—</b>
          </div>
        </div>

        <div class="chips">
          <button
            v-for="p in PERIODS"
            :key="p"
            class="num"
            :class="{ on: period === p }"
            @click="period = p"
          >{{ p }}</button>
        </div>

        <section class="card">
          <div class="chart-box">
            <Line v-if="bodySeries.length" :data="bodyChartData" :options="lineOptions" />
            <div v-else class="empty">この期間の記録はありません</div>
          </div>
        </section>

        <section class="card">
          <div class="lbl mb-1">週ごとの平均</div>
          <table class="tbl">
            <thead><tr><th>週</th><th>平均</th><th>前週比</th></tr></thead>
            <tbody>
              <tr v-for="(w, i) in weeklyAvg" :key="w.label">
                <td>{{ w.label }}</td>
                <td>{{ w.avg != null ? fmt1(w.avg) : '—' }}</td>
                <td :class="weekDiff(i) != null ? diffClass(weekDiff(i)!) : ''">
                  {{ weekDiff(i) != null ? formatDiff(weekDiff(i)!) : '—' }}
                </td>
              </tr>
            </tbody>
          </table>
        </section>
      </template>
      <div v-else-if="!bodyLoading" class="card empty">
        <v-icon size="40">mdi-chart-line</v-icon>
        <p>{{ tab === 'weight' ? '体重' : '体脂肪率' }}の記録がまだありません。ホームの「体重」から記録できます</p>
      </div>
    </template>

    <!-- ========== 筋トレ ========== -->
    <template v-else>
      <template v-if="trainExercises.length">
        <div class="exsel">
          <button
            v-for="ex in trainExercises"
            :key="ex.id"
            :class="{ on: selectedExId === ex.id }"
            @click="selectedExId = ex.id"
          >{{ ex.name }}</button>
        </div>

        <div class="two">
          <div class="stat">
            <span class="lbl">ベスト（3か月）</span>
            <div class="num big" v-if="bestSet">{{ fmtW(bestSet.weight) }}<small>kg × {{ bestSet.reps }}</small></div>
            <span class="sub" v-if="bestSet">{{ formatMd(bestSet.date) }}</span>
          </div>
          <div class="stat">
            <span class="lbl">推定1RM（最新）</span>
            <div class="num big" v-if="sessions.length">{{ fmtW(sessions[sessions.length - 1].e1rm) }}<small>kg</small></div>
            <span v-if="e1rmChange != null" class="sub" :class="e1rmChange > 0 ? 'down' : e1rmChange < 0 ? 'up' : ''">
              3か月で {{ formatDiff(e1rmChange) }}
            </span>
          </div>
        </div>

        <section class="card">
          <span class="lbl">各回の最高重量</span>
          <div class="chart-box">
            <Line :data="trainChartData" :options="trainLineOptions" />
          </div>
          <div class="legend">
            <span><i class="solid" />最高重量</span>
            <span><i class="dash" />推定1RM</span>
          </div>
        </section>

        <section class="card">
          <div class="row-between"><span class="lbl">週の総挙上量</span><span class="lbl">全種目・kg</span></div>
          <div class="chart-box short">
            <Bar :data="volumeChartData" :options="barOptions" />
          </div>
        </section>
      </template>
      <div v-else-if="!trainLoading" class="card empty">
        <v-icon size="40">mdi-dumbbell</v-icon>
        <p>直近3か月の筋トレ記録がまだありません</p>
      </div>
    </template>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { Line, Bar } from 'vue-chartjs'
import {
  Chart as ChartJS, CategoryScale, LinearScale, PointElement,
  LineElement, BarElement, Filler, Tooltip,
} from 'chart.js'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/composables/useAuth'
import { toLocalDateStr } from '@/lib/date'
import type { BodyComposition } from '@/types'

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, BarElement, Filler, Tooltip)

const { user } = useAuth()

type TabKey = 'weight' | 'fat' | 'train'
type Period = '1W' | '1M' | '3M' | 'ALL'
const TABS: { key: TabKey; label: string }[] = [
  { key: 'weight', label: '体重' },
  { key: 'fat', label: '体脂肪' },
  { key: 'train', label: '筋トレ' },
]
const PERIODS: Period[] = ['1W', '1M', '3M', 'ALL']
const PERIOD_LABEL: Record<Period, string> = { '1W': '1週間', '1M': '1か月', '3M': '3か月', ALL: '全期間' }

const COLOR = { primary: '#4C8DFF', primaryLight: '#8FB8FF', fat: '#FF8A65', grid: '#262B33', tick: '#7D8794' }

const tab = ref<TabKey>('weight')
const period = ref<Period>('1M')

// ---------- 表示ヘルパー ----------
function fmt1(n: number) { return (Math.round(n * 10) / 10).toFixed(1) }
function fmtW(w: number) { return Number.isInteger(w) ? String(w) : String(Math.round(w * 10) / 10) }
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
function daysAgo(n: number) {
  const d = new Date()
  d.setDate(d.getDate() - n)
  return toLocalDateStr(d)
}

// ---------- 体組成 ----------
const bodyRecords = ref<BodyComposition[]>([])
const bodyLoading = ref(true)
const bodyUnit = computed(() => (tab.value === 'weight' ? 'kg' : '%'))

/** 選択中タブの値を持つ記録だけ（体脂肪率は未入力の日がある） */
const bodyValues = computed(() =>
  bodyRecords.value
    .map((r) => ({ date: r.date, value: tab.value === 'weight' ? r.weight : r.body_fat_percentage }))
    .filter((r): r is { date: string; value: number } => r.value != null),
)
const bodyLatest = computed(() => bodyValues.value[bodyValues.value.length - 1] ?? null)

const bodySeries = computed(() => {
  if (period.value === 'ALL') return bodyValues.value
  const days = { '1W': 6, '1M': 30, '3M': 90 }[period.value]
  const from = daysAgo(days)
  return bodyValues.value.filter((r) => r.date >= from)
})

const bodyPeriodChange = computed(() => {
  const s = bodySeries.value
  return s.length >= 2 ? s[s.length - 1].value - s[0].value : null
})

// 直近4週（今日を含む7日ごと）の平均
const weeklyAvg = computed(() =>
  [0, 1, 2, 3].map((i) => {
    const to = daysAgo(i * 7)
    const from = daysAgo(i * 7 + 6)
    const xs = bodyValues.value.filter((r) => r.date >= from && r.date <= to)
    return {
      label: `${formatMd(from)}〜${formatMd(to)}`,
      avg: xs.length ? xs.reduce((s, r) => s + r.value, 0) / xs.length : null,
    }
  }),
)
function weekDiff(i: number) {
  const a = weeklyAvg.value[i]?.avg
  const b = weeklyAvg.value[i + 1]?.avg
  return a != null && b != null ? a - b : null
}

async function loadBody() {
  const { data } = await supabase
    .from('body_compositions')
    .select('*')
    .eq('user_id', user.value!.id)
    .order('date')
  bodyRecords.value = (data as BodyComposition[]) ?? []
  bodyLoading.value = false
}

// ---------- 筋トレ ----------
interface TrainLog { date: string; weight: number; reps: number; exercise_id: string; exercise: { name: string } | null }
interface Session { date: string; weight: number; reps: number; e1rm: number }

const trainLogs = ref<TrainLog[]>([])
const trainLoading = ref(true)
const selectedExId = ref<string | null>(null)

/** Epley 式の推定1RM（0.5kg 単位に丸める） */
function e1rmOf(w: number, r: number) {
  return Math.round(w * (1 + r / 30) * 2) / 2
}

// 記録回数（日数）が多い順に並べる
const trainExercises = computed(() => {
  const map = new Map<string, { id: string; name: string; days: Set<string> }>()
  for (const l of trainLogs.value) {
    let e = map.get(l.exercise_id)
    if (!e) { e = { id: l.exercise_id, name: l.exercise?.name ?? '不明な種目', days: new Set() }; map.set(l.exercise_id, e) }
    e.days.add(l.date)
  }
  return [...map.values()].sort((a, b) => b.days.size - a.days.size)
})

// 選択種目の「日ごとのトップセット」（重量が最大、同重量なら回数が多いセット）
const sessions = computed<Session[]>(() => {
  const byDate = new Map<string, TrainLog>()
  for (const l of trainLogs.value) {
    if (l.exercise_id !== selectedExId.value) continue
    const cur = byDate.get(l.date)
    if (!cur || l.weight > cur.weight || (l.weight === cur.weight && l.reps > cur.reps)) byDate.set(l.date, l)
  }
  return [...byDate.values()]
    .sort((a, b) => a.date.localeCompare(b.date))
    .map((l) => ({ date: l.date, weight: l.weight, reps: l.reps, e1rm: e1rmOf(l.weight, l.reps) }))
})

const bestSet = computed(() =>
  sessions.value.reduce<Session | null>(
    (best, s) => (!best || s.weight > best.weight || (s.weight === best.weight && s.reps > best.reps) ? s : best),
    null,
  ),
)
const e1rmChange = computed(() => {
  const s = sessions.value
  return s.length >= 2 ? s[s.length - 1].e1rm - s[0].e1rm : null
})

// 直近8週（月曜はじまり）の総挙上量
const weeklyVolume = computed(() => {
  const now = new Date()
  const monday = new Date(now)
  monday.setDate(now.getDate() - ((now.getDay() + 6) % 7))
  return [7, 6, 5, 4, 3, 2, 1, 0].map((i) => {
    const start = new Date(monday)
    start.setDate(monday.getDate() - i * 7)
    const end = new Date(start)
    end.setDate(start.getDate() + 6)
    const from = toLocalDateStr(start)
    const to = toLocalDateStr(end)
    const vol = trainLogs.value
      .filter((l) => l.date >= from && l.date <= to)
      .reduce((s, l) => s + l.weight * l.reps, 0)
    return { label: formatMd(from), vol: Math.round(vol) }
  })
})

async function loadTraining() {
  const { data } = await supabase
    .from('workout_logs')
    .select('date, weight, reps, exercise_id, exercise:exercise_masters(name)')
    .eq('user_id', user.value!.id)
    .gte('date', daysAgo(90))
    .order('date')
  trainLogs.value = (data as unknown as TrainLog[]) ?? []
  selectedExId.value = trainExercises.value[0]?.id ?? null
  trainLoading.value = false
}

// ---------- チャート ----------
function gradientFill(hex: string) {
  return (ctx: any) => {
    const { chart } = ctx
    const area = chart.chartArea
    if (!area) return 'transparent'
    const g = chart.ctx.createLinearGradient(0, area.top, 0, area.bottom)
    g.addColorStop(0, `${hex}47`)
    g.addColorStop(1, `${hex}00`)
    return g
  }
}
function lastPointOnly(len: () => number, r = 4) {
  return (ctx: any) => (ctx.dataIndex === len() - 1 ? r : 0)
}

const axisFont = { family: "'Barlow Condensed', 'Arial Narrow', sans-serif", size: 11 }
const baseScales = {
  x: { grid: { display: false }, ticks: { color: COLOR.tick, font: axisFont, maxTicksLimit: 5, maxRotation: 0 } },
  y: { grid: { color: COLOR.grid }, border: { display: false }, ticks: { color: COLOR.tick, font: axisFont, maxTicksLimit: 4 } },
}

const bodyChartData = computed(() => {
  const color = tab.value === 'weight' ? COLOR.primary : COLOR.fat
  const s = bodySeries.value
  return {
    labels: s.map((r) => formatMd(r.date)),
    datasets: [{
      data: s.map((r) => r.value),
      borderColor: color,
      backgroundColor: gradientFill(color),
      fill: 'start',
      tension: 0.3,
      borderWidth: 2,
      pointRadius: lastPointOnly(() => s.length),
      pointBackgroundColor: color,
      pointBorderColor: '#1C2027',
      pointBorderWidth: 2,
    }],
  }
})

const lineOptions: any = {
  responsive: true,
  maintainAspectRatio: false,
  interaction: { mode: 'index', intersect: false },
  plugins: { legend: { display: false } },
  scales: baseScales,
}

const trainChartData = computed(() => {
  const s = sessions.value
  return {
    labels: s.map((x) => formatMd(x.date)),
    datasets: [
      {
        label: '最高重量',
        data: s.map((x) => x.weight),
        borderColor: COLOR.primary,
        backgroundColor: gradientFill(COLOR.primary),
        fill: 'start',
        tension: 0.25,
        borderWidth: 2,
        pointRadius: lastPointOnly(() => s.length),
        pointBackgroundColor: COLOR.primary,
        pointBorderColor: '#1C2027',
        pointBorderWidth: 2,
      },
      {
        label: '推定1RM',
        data: s.map((x) => x.e1rm),
        borderColor: COLOR.primaryLight,
        borderDash: [4, 3],
        borderWidth: 1.6,
        tension: 0.25,
        pointRadius: 0,
        fill: false,
      },
    ],
  }
})

const trainLineOptions: any = {
  ...lineOptions,
  plugins: {
    legend: { display: false },
    tooltip: {
      callbacks: {
        afterBody: (items: any[]) => {
          const s = sessions.value[items[0]?.dataIndex]
          return s ? `${fmtW(s.weight)}kg × ${s.reps}回` : ''
        },
      },
    },
  },
}

const volumeChartData = computed(() => {
  const w = weeklyVolume.value
  return {
    labels: w.map((x) => x.label),
    datasets: [{
      data: w.map((x) => x.vol),
      // 今週だけ濃く、ほかは薄く
      backgroundColor: w.map((_, i) => (i === w.length - 1 ? COLOR.primary : `${COLOR.primary}73`)),
      borderRadius: 4,
      maxBarThickness: 22,
    }],
  }
})

const barOptions: any = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: false },
    tooltip: { callbacks: { label: (c: any) => `${c.parsed.y.toLocaleString()} kg` } },
  },
  scales: {
    x: baseScales.x,
    y: {
      ...baseScales.y,
      ticks: { ...baseScales.y.ticks, callback: (v: number) => (v >= 1000 ? `${v / 1000}t` : v) },
    },
  },
}

onMounted(() => {
  loadBody()
  loadTraining()
})
</script>

<style scoped>
.graph {
  --c-surface: rgb(var(--v-theme-surface));
  --c-raised: rgb(var(--v-theme-surface-variant));
  --c-primary: rgb(var(--v-theme-primary));
  --c-fg: rgb(var(--v-theme-on-background));
  --c-muted: #8b95a3;
  --c-line: #2a303a;
  --c-ok: #4fd19b;
  --c-up: #ff8a65;
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.num { font-family: 'Barlow Condensed', 'Arial Narrow', sans-serif; font-variant-numeric: tabular-nums; }
button {
  font: inherit; color: inherit; border: 0; background: none; cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
button:focus-visible { outline: 2px solid rgb(var(--v-theme-warning)); outline-offset: 2px; }
.lbl { font-size: .72rem; color: var(--c-muted); letter-spacing: .04em; }
.down { color: var(--c-ok); }
.up { color: var(--c-up); }
.card { background: var(--c-surface); border-radius: 18px; padding: 12px; }
.row-between { display: flex; justify-content: space-between; align-items: baseline; }

/* タブ */
.tabs { display: grid; grid-template-columns: repeat(3, 1fr); background: var(--c-surface); border-radius: 12px; padding: 3px; }
.tabs button { padding: 8px 0; border-radius: 9px; font-size: .85rem; color: var(--c-muted); font-weight: 700; }
.tabs button.on { background: var(--c-raised); color: var(--c-fg); }

/* 最新値 */
.hero { display: flex; justify-content: space-between; align-items: flex-end; }
.hero .num { font-size: 3rem; font-weight: 700; line-height: 1; }
.hero .num small { font-size: 1rem; color: var(--c-muted); margin-left: 3px; font-weight: 600; }
.hero-d { text-align: right; font-size: .76rem; color: var(--c-muted); line-height: 1.4; }
.hero-d b { font-size: 1.15rem; }

/* 期間チップ */
.chips { display: flex; gap: 6px; }
.chips button {
  padding: 4px 14px; border-radius: 999px; border: 1px solid var(--c-line);
  font-size: .85rem; font-weight: 600; letter-spacing: .04em; color: #b9c2ce;
}
.chips button.on { background: var(--c-fg); color: rgb(var(--v-theme-background)); border-color: var(--c-fg); }

/* チャート */
.chart-box { position: relative; height: 190px; margin-top: 4px; }
.chart-box.short { height: 140px; }
.legend { display: flex; gap: 14px; font-size: .7rem; color: var(--c-muted); margin-top: 6px; }
.legend span { display: flex; align-items: center; gap: 6px; }
.legend i { width: 16px; height: 0; border-top: 2px solid #4c8dff; display: block; }
.legend i.dash { border-top: 2px dashed #8fb8ff; }

/* 表 */
.tbl { width: 100%; border-collapse: collapse; }
.tbl th { font-size: .66rem; font-weight: 500; color: var(--c-muted); text-align: right; padding: 0 4px 4px; }
.tbl td {
  padding: 7px 4px; border-top: 1px solid var(--c-line); text-align: right;
  font-family: 'Barlow Condensed', 'Arial Narrow', sans-serif; font-variant-numeric: tabular-nums;
  font-weight: 600; font-size: 1rem;
}
.tbl th:first-child, .tbl td:first-child { text-align: left; }

/* 筋トレ */
.exsel { display: flex; gap: 6px; overflow-x: auto; scrollbar-width: none; margin: 0 -16px; padding: 0 16px; }
.exsel button {
  flex: none; padding: 6px 13px; border-radius: 10px; background: var(--c-surface);
  font-size: .8rem; color: #b9c2ce; border: 1.5px solid transparent;
}
.exsel button.on { border-color: var(--c-primary); color: var(--c-fg); background: #1a2433; }
.two { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.stat { background: var(--c-surface); border-radius: 16px; padding: 10px 12px; display: flex; flex-direction: column; min-width: 0; }
.stat .big { font-size: 2rem; font-weight: 600; line-height: 1.05; }
.stat .big small { font-size: .9rem; color: var(--c-muted); margin-left: 2px; }
.stat .sub { font-size: .74rem; color: var(--c-muted); }
.stat .sub.down { color: var(--c-ok); }
.stat .sub.up { color: var(--c-up); }

.empty { text-align: center; color: var(--c-muted); padding: 32px 16px; font-size: .85rem; }
.empty p { margin: 8px 0 0; }
</style>
