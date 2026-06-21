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

    <!-- 最新値サマリー -->
    <v-row v-if="latest">
      <v-col cols="6">
        <v-card rounded="lg" class="text-center pa-3">
          <div class="text-h5 font-weight-bold">{{ latest.weight }} <span class="text-body-2">kg</span></div>
          <div class="text-caption text-medium-emphasis">最新体重</div>
        </v-card>
      </v-col>
      <v-col cols="6">
        <v-card rounded="lg" class="text-center pa-3">
          <div class="text-h5 font-weight-bold">{{ latest.body_fat_percentage ?? '-' }} <span class="text-body-2">%</span></div>
          <div class="text-caption text-medium-emphasis">最新体脂肪率</div>
        </v-card>
      </v-col>
    </v-row>
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
import type { BodyComposition } from '@/types'

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Legend)

const period = ref('1M')
const records = ref<BodyComposition[]>([])

const latest = computed(() => records.value[records.value.length - 1] ?? null)

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
  if (period.value === '1W') { const d = new Date(now); d.setDate(d.getDate() - 7); from = d.toISOString().split('T')[0] }
  else if (period.value === '1M') { const d = new Date(now); d.setMonth(d.getMonth() - 1); from = d.toISOString().split('T')[0] }
  else if (period.value === '3M') { const d = new Date(now); d.setMonth(d.getMonth() - 3); from = d.toISOString().split('T')[0] }

  let q = supabase.from('body_compositions').select('*').order('date')
  if (from) q = q.gte('date', from)
  const { data } = await q
  records.value = (data as BodyComposition[]) ?? []
}

watch(period, loadData)
onMounted(loadData)
</script>
