<template>
  <v-container class="pa-2" style="max-width: 600px;">

    <!-- インターバルタイマー -->
    <v-card class="mb-3 timer-card" :class="{ 'flash': isFlashing }" rounded="lg">
      <v-card-text class="pa-3">
        <v-row align="center">
          <v-col>
            <div class="text-h4 font-weight-bold text-center" :class="timerColor">
              {{ formattedTime }}
            </div>
            <div class="text-caption text-center text-medium-emphasis">インターバル</div>
          </v-col>
          <v-col cols="auto">
            <v-btn-group density="compact" variant="outlined">
              <v-btn size="small" @click="setTimer(90)">90s</v-btn>
              <v-btn size="small" @click="setTimer(180)">3m</v-btn>
            </v-btn-group>
          </v-col>
          <v-col cols="auto">
            <v-btn
              :icon="timerRunning ? 'mdi-pause' : 'mdi-play'"
              :color="timerRunning ? 'warning' : 'primary'"
              variant="flat"
              size="small"
              @click="toggleTimer"
            />
            <v-btn icon="mdi-stop" variant="text" size="small" @click="resetTimer" class="ml-1" />
          </v-col>
        </v-row>
      </v-card-text>
    </v-card>

    <!-- 種目選択 -->
    <v-card class="mb-3" rounded="lg">
      <v-card-text>
        <v-row dense>
          <v-col cols="6">
            <v-select
              v-model="filterPart"
              :items="['すべて', ...PARTS]"
              label="部位"
              density="compact"
              variant="outlined"
              hide-details
            />
          </v-col>
          <v-col cols="6">
            <v-select
              v-model="filterEquipment"
              :items="['すべて', ...EQUIPMENTS]"
              label="器具"
              density="compact"
              variant="outlined"
              hide-details
            />
          </v-col>
        </v-row>
        <v-autocomplete
          v-model="selectedExercise"
          :items="filteredExercises"
          item-title="name"
          item-value="id"
          label="種目を選択"
          variant="outlined"
          density="compact"
          class="mt-2"
          hide-details
          return-object
        />
      </v-card-text>
    </v-card>

    <!-- 重量・回数入力 -->
    <v-card class="mb-3" rounded="lg">
      <v-card-text>
        <v-row dense>
          <v-col cols="6">
            <v-text-field
              v-model.number="inputWeight"
              label="重量 (kg)"
              type="number"
              step="2.5"
              variant="outlined"
              density="compact"
              :placeholder="lastRecord ? String(lastRecord.weight) : ''"
              :hint="lastRecord ? `前回: ${lastRecord.weight}kg` : ''"
              persistent-hint
            />
          </v-col>
          <v-col cols="6">
            <v-text-field
              v-model.number="inputReps"
              label="回数 (reps)"
              type="number"
              variant="outlined"
              density="compact"
              :placeholder="lastRecord ? String(lastRecord.reps) : ''"
              :hint="lastRecord ? `前回: ${lastRecord.reps}reps` : ''"
              persistent-hint
            />
          </v-col>
        </v-row>
        <v-btn
          block
          color="primary"
          class="mt-3"
          :disabled="!selectedExercise || !inputWeight || !inputReps"
          @click="addSet"
        >
          <v-icon start>mdi-plus</v-icon>
          セット追加
        </v-btn>
      </v-card-text>
    </v-card>

    <!-- 今日の記録一覧 -->
    <v-card v-if="todaySets.length > 0" rounded="lg">
      <v-card-title class="text-body-1">本日の記録</v-card-title>
      <v-list density="compact">
        <v-list-item
          v-for="(log, i) in todaySets"
          :key="log.id"
          :subtitle="`${log.weight}kg × ${log.reps}reps`"
        >
          <template #title>
            <span class="text-body-2 font-weight-medium">
              Set {{ log.set_number }} — {{ log.exercise?.name }}
            </span>
          </template>
          <template #append>
            <v-btn icon="mdi-delete-outline" size="small" variant="text" color="error" @click="deleteSet(log.id, i)" />
          </template>
        </v-list-item>
      </v-list>
    </v-card>

    <v-snackbar v-model="snackbar" timeout="2000" color="success">セットを記録しました</v-snackbar>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { supabase } from '@/lib/supabase'
import type { ExerciseMaster, WorkoutLog } from '@/types'
import { PARTS, EQUIPMENTS } from '@/types'

const exercises = ref<ExerciseMaster[]>([])
const selectedExercise = ref<ExerciseMaster | null>(null)
const filterPart = ref('すべて')
const filterEquipment = ref('すべて')
const inputWeight = ref<number | null>(null)
const inputReps = ref<number | null>(null)
const todaySets = ref<WorkoutLog[]>([])
const lastRecord = ref<WorkoutLog | null>(null)
const snackbar = ref(false)

const filteredExercises = computed(() =>
  exercises.value.filter((e) => {
    if (filterPart.value !== 'すべて' && e.part !== filterPart.value) return false
    if (filterEquipment.value !== 'すべて' && e.equipment !== filterEquipment.value) return false
    return true
  })
)

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

const timerColor = computed(() => {
  if (timerRemaining.value <= 10 && timerRunning.value) return 'text-error'
  return ''
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

// 種目が変わったら前回値を取得
watch(selectedExercise, async (ex) => {
  if (!ex) { lastRecord.value = null; return }
  const today = new Date().toISOString().split('T')[0]
  const { data } = await supabase
    .from('workout_logs')
    .select('*')
    .eq('exercise_id', ex.id)
    .lt('date', today)
    .order('date', { ascending: false })
    .order('set_number', { ascending: false })
    .limit(1)
    .maybeSingle()
  lastRecord.value = data
})

async function loadExercises() {
  const { data } = await supabase.from('exercise_masters').select('*').order('name')
  exercises.value = data ?? []
}

async function loadTodaySets() {
  const today = new Date().toISOString().split('T')[0]
  const { data } = await supabase
    .from('workout_logs')
    .select('*, exercise:exercise_masters(name)')
    .eq('date', today)
    .order('set_number')
  todaySets.value = (data as WorkoutLog[]) ?? []
}

async function addSet() {
  if (!selectedExercise.value || !inputWeight.value || !inputReps.value) return
  const today = new Date().toISOString().split('T')[0]
  const nextSet = todaySets.value.filter((s) => s.exercise_id === selectedExercise.value!.id).length + 1
  await supabase.from('workout_logs').insert({
    date: today,
    exercise_id: selectedExercise.value.id,
    weight: inputWeight.value,
    reps: inputReps.value,
    set_number: nextSet,
  })
  snackbar.value = true
  await loadTodaySets()
  // タイマー自動スタート
  if (!timerRunning.value) {
    timerRemaining.value = timerSeconds.value
    startTimer()
  }
}

async function deleteSet(id: number, index: number) {
  await supabase.from('workout_logs').delete().eq('id', id)
  todaySets.value.splice(index, 1)
}

onMounted(() => {
  loadExercises()
  loadTodaySets()
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
.timer-card {
  transition: background-color 0.1s;
}
.flash {
  background-color: #1976D2 !important;
}
</style>
