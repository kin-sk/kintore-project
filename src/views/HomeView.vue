<template>
  <v-container class="pa-2" style="max-width: 600px;">
    <v-row class="mb-2">
      <v-col>
        <h2 class="text-h6 font-weight-bold">
          {{ currentYear }}年{{ currentMonth }}月
        </h2>
      </v-col>
    </v-row>

    <!-- カレンダー -->
    <v-card class="mb-4" rounded="lg">
      <v-card-text class="pa-2">
        <!-- 曜日ヘッダー -->
        <v-row dense class="mb-1">
          <v-col v-for="day in weekDays" :key="day" class="text-center pa-0">
            <span class="text-caption text-medium-emphasis">{{ day }}</span>
          </v-col>
        </v-row>

        <!-- 日付グリッド -->
        <v-row v-for="(week, wi) in calendarWeeks" :key="wi" dense>
          <v-col
            v-for="(day, di) in week"
            :key="di"
            class="text-center pa-1"
          >
            <div
              v-if="day"
              class="calendar-day d-flex align-center justify-center mx-auto"
              :class="{
                'today': isToday(day),
                'has-workout': hasWorkout(day),
              }"
            >
              <span class="text-body-2">{{ day }}</span>
              <v-icon
                v-if="hasWorkout(day)"
                size="8"
                color="primary"
                class="workout-dot"
              >mdi-circle</v-icon>
            </div>
          </v-col>
        </v-row>
      </v-card-text>
    </v-card>

    <!-- 体組成入力ボタン -->
    <v-btn
      block
      variant="outlined"
      color="secondary"
      class="mb-3"
      prepend-icon="mdi-scale-bathroom"
      @click="bodyDialog = true"
    >
      今日の体重・体脂肪を入力
    </v-btn>

    <!-- 筋トレ開始ボタン -->
    <v-btn
      block
      size="x-large"
      color="primary"
      class="mb-4"
      prepend-icon="mdi-dumbbell"
      to="/workout"
    >
      今日の筋トレを開始！
    </v-btn>

    <!-- 今日の体組成表示 -->
    <v-card v-if="todayBody" rounded="lg" class="mb-4">
      <v-card-title class="text-body-1">今日の記録</v-card-title>
      <v-card-text>
        <v-row>
          <v-col cols="6" class="text-center">
            <div class="text-h5 font-weight-bold">{{ todayBody.weight }} <span class="text-body-2">kg</span></div>
            <div class="text-caption text-medium-emphasis">体重</div>
          </v-col>
          <v-col cols="6" class="text-center">
            <div class="text-h5 font-weight-bold">{{ todayBody.body_fat_percentage ?? '-' }} <span class="text-body-2">%</span></div>
            <div class="text-caption text-medium-emphasis">体脂肪率</div>
          </v-col>
        </v-row>
      </v-card-text>
    </v-card>

    <!-- 体組成入力ダイアログ -->
    <v-dialog v-model="bodyDialog" max-width="400">
      <v-card rounded="lg">
        <v-card-title>体組成を記録</v-card-title>
        <v-card-text>
          <v-text-field
            v-model.number="inputWeight"
            label="体重 (kg)"
            type="number"
            step="0.1"
            variant="outlined"
            class="mb-2"
          />
          <v-text-field
            v-model.number="inputBodyFat"
            label="体脂肪率 (%)"
            type="number"
            step="0.1"
            variant="outlined"
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="bodyDialog = false">キャンセル</v-btn>
          <v-btn color="primary" @click="saveBodyComposition">保存</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import type { BodyComposition } from '@/types'

const today = new Date()
const currentYear = today.getFullYear()
const currentMonth = today.getMonth() + 1

const weekDays = ['日', '月', '火', '水', '木', '金', '土']
const workoutDates = ref<Set<number>>(new Set())
const todayBody = ref<BodyComposition | null>(null)
const bodyDialog = ref(false)
const inputWeight = ref<number | null>(null)
const inputBodyFat = ref<number | null>(null)

const calendarWeeks = computed(() => {
  const firstDay = new Date(currentYear, currentMonth - 1, 1).getDay()
  const daysInMonth = new Date(currentYear, currentMonth, 0).getDate()
  const weeks: (number | null)[][] = []
  let week: (number | null)[] = Array(firstDay).fill(null)

  for (let d = 1; d <= daysInMonth; d++) {
    week.push(d)
    if (week.length === 7) { weeks.push(week); week = [] }
  }
  if (week.length > 0) {
    while (week.length < 7) week.push(null)
    weeks.push(week)
  }
  return weeks
})

function isToday(day: number) {
  return day === today.getDate() && currentMonth === today.getMonth() + 1 && currentYear === today.getFullYear()
}

function hasWorkout(day: number) {
  return workoutDates.value.has(day)
}

async function loadWorkoutDates() {
  const startDate = `${currentYear}-${String(currentMonth).padStart(2, '0')}-01`
  const endDate = `${currentYear}-${String(currentMonth).padStart(2, '0')}-31`
  const { data } = await supabase
    .from('workout_logs')
    .select('date')
    .gte('date', startDate)
    .lte('date', endDate)
  if (data) {
    workoutDates.value = new Set(data.map((r) => new Date(r.date).getDate()))
  }
}

async function loadTodayBody() {
  const todayStr = today.toISOString().split('T')[0]
  const { data } = await supabase
    .from('body_compositions')
    .select('*')
    .eq('date', todayStr)
    .maybeSingle()
  todayBody.value = data
}

async function saveBodyComposition() {
  if (!inputWeight.value) return
  const todayStr = today.toISOString().split('T')[0]
  await supabase.from('body_compositions').upsert({
    date: todayStr,
    weight: inputWeight.value,
    body_fat_percentage: inputBodyFat.value ?? null,
  }, { onConflict: 'date' })
  bodyDialog.value = false
  await loadTodayBody()
}

onMounted(() => {
  loadWorkoutDates()
  loadTodayBody()
})
</script>

<style scoped>
.calendar-day {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  position: relative;
  flex-direction: column;
}
.today {
  background-color: rgba(25, 118, 210, 0.2);
  border: 2px solid #1976D2;
}
.workout-dot {
  position: absolute;
  bottom: 2px;
}
</style>
