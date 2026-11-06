<template>
  <v-container class="pa-2" style="max-width: 600px;">
    <h2 class="text-h6 font-weight-bold mb-3">体組成グラフ</h2>

    <!-- 期間切り替え -->
    <v-btn-toggle v-model="period" mandatory color="primary" class="mb-4" density="compact">
      <v-btn value="1W">1W</v-btn>
      <v-btn value="1M">1M</v-btn>
      <v-btn value="3M">3M</v-btn>
      <v-btn value="ALL">ALL</v-btn>
    </v-btn-toggle>

    <!-- グラフ -->
    <v-card rounded="lg" class="mb-4">
      <v-card-text>
        <Line v-if="chartData.labels?.length" :data="chartData" :options="chartOptions" style="max-height: 300px;" />
        <div v-else class="text-center text-medium-emphasis py-8">
          <v-icon size="48">mdi-chart-line</v-icon>
          <p class="mt-2">データがありません</p>
        </div>
      </v-card-text>
    </v-card>

    <!-- 最新値 -->
    <v-row v-if="latest" dense class="mb-2">
      <v-col cols="6">
        <v-card rounded="lg" class="text-center pa-3">
          <div class="text-caption text-medium-emphasis">最新体重（{{ formatMd(latest.date) }}）</div>
          <div class="text-h5 font-weight-bold">{{ latest.weight }} <span class="text-body-2">kg</span></div>
          <div v-if="weightDiff != null" class="text-caption">前回比 {{ formatDiff(weightDiff) }} kg</div>
        </v-card>
      </v-col>
      <v-col cols="6">
        <v-card rounded="lg" class="text-center pa-3">
          <div class="text-caption text-medium-emphasis">最新体脂肪率</div>
          <div class="text-h5 font-weight-bold">
            {{ latest.body_fat_percentage ?? '-' }}
            <span v-if="latest.body_fat_percentage != null" class="text-body-2">%</span>
          </div>
          <div v-if="fatDiff != null" class="text-caption">前回比 {{ formatDiff(fatDiff) }} %</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- 直近1週間 -->
    <v-card rounded="lg" class="mb-4">
      <v-card-title class="text-body-1">直近1週間</v-card-title>
      <v-card-text class="pt-0">
        <template v-if="weekRows.length">
          <v-row dense class="mb-2 text-center">
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">平均体重</div>
              <div class="text-h6 font-weight-bold">{{ weekAvgWeight }} <span class="text-body-2">kg</span></div>
            </v-col>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">週の変化</div>
              <div class="text-h6 font-weight-bold">
                {{ weekChange != null ? formatDiff(weekChange) : '-' }} <span class="text-body-2">kg</span>
              </div>
            </v-col>
          </v-row>
          <v-table density="compact">
            <thead>
              <tr>
                <th class="text-caption text-center">日付</th>
                <th class="text-caption text-center">体重</th>
                <th class="text-caption text-center">前回比</th>
                <th class="text-caption text-center">体脂肪</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="r in weekRows" :key="r.date">
                <td class="text-caption text-center">{{ formatMd(r.date) }}</td>
                <td class="text-caption text-center">{{ r.weight }} kg</td>
                <td class="text-caption text-center">{{ r.diff != null ? formatDiff(r.diff) : '-' }}</td>
                <td class="text-caption text-center">{{ r.body_fat_percentage != null ? `${r.body_fat_percentage} %` : '-' }}</td>
              </tr>
            </tbody>
          </v-table>
        </template>
        <div v-else class="text-caption text-medium-emphasis text-center py-2">記録がありません</div>
      </v-card-text>
    </v-card>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { Line } from 'vue-chartjs'
import {
  Chart as ChartJS, CategoryScale, LinearScale, PointElement,
  LineElement, Title, Tooltip, Legend,
} from 'chart.js'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/composables/useAuth'
import { toLocalDateStr } from '@/lib/date'
import type { BodyComposition } from '@/types'

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Legend)

const { user } = useAuth()

const period = ref('1M')
const records = ref<BodyComposition[]>([])

const latestTwo = ref<BodyComposition[]>([])
const weekRecords = ref<BodyComposition[]>([])
const weekFrom = ref('')

const latest = computed(() => latestTwo.value[0] ?? null)
const previous = computed(() => latestTwo.value[1] ?? null)

const weightDiff = computed(() =>
  latest.value && previous.value ? latest.value.weight - previous.value.weight : null
)
const fatDiff = computed(() => {
  const a = latest.value?.body_fat_percentage
  const b = previous.value?.body_fat_percentage
  return a != null && b != null ? a - b : null
})

// 直近7日（新しい順）。前回比は1つ前の記録との差
const weekRows = computed(() =>
  weekRecords.value
    .map((r, i) => {
      const prev = weekRecords.value[i - 1]
      return { ...r, diff: prev ? r.weight - prev.weight : null }
    })
    .filter((r) => r.date >= weekFrom.value)
    .reverse()
)

const weekAvgWeight = computed(() => {
  if (!weekRows.value.length) return '-'
  const sum = weekRows.value.reduce((s, r) => s + r.weight, 0)
  return (sum / weekRows.value.length).toFixed(1)
})

const weekChange = computed(() => {
  const rows = weekRows.value
  return rows.length >= 2 ? rows[0].weight - rows[rows.length - 1].weight : null
})

function formatDiff(n: number) {
  const v = Math.round(n * 10) / 10
  if (v > 0) return `▲${v.toFixed(1)}`
  if (v < 0) return `▼${Math.abs(v).toFixed(1)}`
  return '±0.0'
}

function formatMd(date: string) {
  const [, m, d] = date.split('-')
  return `${Number(m)}/${Number(d)}`
}

const chartData = computed(() => ({
  labels: records.value.map((r) => r.date.slice(5)),
  datasets: [
    {
      label: '体重 (kg)',
      data: records.value.map((r) => r.weight),
      borderColor: '#1976D2',
      backgroundColor: 'rgba(25, 118, 210, 0.1)',
      yAxisID: 'y',
      tension: 0.3,
      pointRadius: 3,
    },
    {
      label: '体脂肪率 (%)',
      data: records.value.map((r) => r.body_fat_percentage),
      borderColor: '#FF7043',
      backgroundColor: 'rgba(255, 112, 67, 0.1)',
      yAxisID: 'y1',
      tension: 0.3,
      pointRadius: 3,
    },
  ],
}))

const chartOptions = {
  responsive: true,
  interaction: { mode: 'index' as const, intersect: false },
  plugins: { legend: { position: 'bottom' as const } },
  scales: {
    y: { type: 'linear' as const, display: true, position: 'left' as const, title: { display: true, text: 'kg' } },
    y1: { type: 'linear' as const, display: true, position: 'right' as const, title: { display: true, text: '%' }, grid: { drawOnChartArea: false } },
  },
}

async function loadData() {
  let from: string | null = null
  const now = new Date()
  if (period.value === '1W') { const d = new Date(now); d.setDate(d.getDate() - 7); from = toLocalDateStr(d) }
  else if (period.value === '1M') { const d = new Date(now); d.setMonth(d.getMonth() - 1); from = toLocalDateStr(d) }
  else if (period.value === '3M') { const d = new Date(now); d.setMonth(d.getMonth() - 3); from = toLocalDateStr(d) }

  let q = supabase
    .from('body_compositions')
    .select('*')
    .eq('user_id', user.value!.id)
    .order('date')
  if (from) q = q.gte('date', from)
  const { data } = await q
  records.value = (data as BodyComposition[]) ?? []
}

async function loadSummary() {
  const today = new Date()
  const from6 = new Date(today); from6.setDate(today.getDate() - 6) // 表示する7日間の初日
  const from7 = new Date(today); from7.setDate(today.getDate() - 7) // 初日の前回比計算用に1日多く取得
  weekFrom.value = toLocalDateStr(from6)

  const [latestRes, weekRes] = await Promise.all([
    supabase
      .from('body_compositions')
      .select('*')
      .eq('user_id', user.value!.id)
      .order('date', { ascending: false })
      .limit(2),
    supabase
      .from('body_compositions')
      .select('*')
      .eq('user_id', user.value!.id)
      .gte('date', toLocalDateStr(from7))
      .order('date'),
  ])
  latestTwo.value = (latestRes.data as BodyComposition[]) ?? []
  weekRecords.value = (weekRes.data as BodyComposition[]) ?? []
}

watch(period, loadData)
onMounted(() => {
  loadData()
  loadSummary()
})
</script>
