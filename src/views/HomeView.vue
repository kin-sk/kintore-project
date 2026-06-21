<template>
  <v-container class="pa-2" style="max-width: 600px">
    <v-row class="mb-2" align="center">
      <v-col cols="auto">
        <v-btn
          icon="mdi-chevron-left"
          variant="text"
          size="small"
          @click="prevMonth"
        />
      </v-col>
      <v-col class="text-center">
        <h2 class="text-h6 font-weight-bold">
          {{ currentYear }}年{{ currentMonth }}月
        </h2>
      </v-col>
      <v-col cols="auto">
        <v-btn
          icon="mdi-chevron-right"
          variant="text"
          size="small"
          @click="nextMonth"
          :disabled="isCurrentMonth"
        />
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
          <v-col v-for="(day, di) in week" :key="di" class="text-center pa-1">
            <div
              v-if="day"
              class="calendar-day d-flex align-center justify-center mx-auto"
              :class="{
                today: isToday(day),
                'has-workout': hasWorkout(day),
              }"
              style="cursor: pointer"
              @click="handleDayClick(day)"
            >
              <span class="text-body-2">{{ day }}</span>
              <v-icon
                v-if="hasWorkout(day)"
                size="8"
                color="primary"
                class="workout-dot"
                >mdi-circle</v-icon
              >
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
            <div class="text-h5 font-weight-bold">
              {{ todayBody.weight }} <span class="text-body-2">kg</span>
            </div>
            <div class="text-caption text-medium-emphasis">体重</div>
          </v-col>
          <v-col cols="6" class="text-center">
            <div class="text-h5 font-weight-bold">
              {{ todayBody.body_fat_percentage ?? "-" }}
              <span class="text-body-2">%</span>
            </div>
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

    <!-- 日別記録ダイアログ -->
    <v-dialog v-model="dayDetailDialog" max-width="500" scrollable>
      <v-card rounded="lg">
        <v-card-title class="text-body-1 pt-4 pb-1">
          {{ currentYear }}年{{ currentMonth }}月{{ selectedDay }}日の記録
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-3">
          <v-progress-circular
            v-if="dayDetailLoading"
            indeterminate
            color="primary"
            class="d-block mx-auto my-4"
          />
          <template v-else>
            <!-- 体組成 -->
            <div v-if="selectedDayBody" class="mb-4">
              <div
                class="text-caption text-medium-emphasis font-weight-bold mb-2"
              >
                <v-icon size="14" class="mr-1">mdi-scale-bathroom</v-icon>体組成
              </div>
              <v-row dense>
                <v-col cols="6" class="text-center">
                  <div class="text-h6 font-weight-bold">
                    {{ selectedDayBody.weight }}
                    <span class="text-body-2">kg</span>
                  </div>
                  <div class="text-caption text-medium-emphasis">体重</div>
                </v-col>
                <v-col cols="6" class="text-center">
                  <div class="text-h6 font-weight-bold">
                    {{ selectedDayBody.body_fat_percentage ?? "-" }}
                    <span
                      class="text-body-2"
                      v-if="selectedDayBody.body_fat_percentage != null"
                      >%</span
                    >
                  </div>
                  <div class="text-caption text-medium-emphasis">体脂肪率</div>
                </v-col>
              </v-row>
            </div>

            <v-divider
              v-if="selectedDayBody && selectedDayWorkoutGroups.length > 0"
              class="mb-3"
            />

            <!-- トレーニング記録 -->
            <div v-if="selectedDayWorkoutGroups.length > 0">
              <div
                class="text-caption text-medium-emphasis font-weight-bold mb-2"
              >
                <v-icon size="14" class="mr-1">mdi-dumbbell</v-icon>トレーニング
              </div>
              <div
                v-for="group in selectedDayWorkoutGroups"
                :key="group.exerciseName"
                class="mb-3"
              >
                <div class="text-body-2 font-weight-bold mb-1">
                  {{ group.exerciseName }}
                </div>
                <v-table density="compact" class="rounded">
                  <thead>
                    <tr>
                      <th class="text-caption text-center" style="width: 33%">
                        セット
                      </th>
                      <th class="text-caption text-center" style="width: 33%">
                        重量
                      </th>
                      <th class="text-caption text-center" style="width: 33%">
                        回数
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="log in group.logs" :key="log.set_number">
                      <td class="text-caption text-center">
                        {{ log.set_number }}
                      </td>
                      <td class="text-caption text-center">
                        {{ log.weight }} kg
                      </td>
                      <td class="text-caption text-center">
                        {{ log.reps }} 回
                      </td>
                    </tr>
                  </tbody>
                </v-table>
              </div>
            </div>

            <!-- 記録なし -->
            <div
              v-if="!selectedDayBody && selectedDayWorkoutGroups.length === 0"
              class="text-center text-medium-emphasis py-6"
            >
              <v-icon size="32" class="mb-2 d-block mx-auto"
                >mdi-calendar-blank</v-icon
              >
              この日の記録はありません
            </div>
          </template>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dayDetailDialog = false">閉じる</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from "vue";
import { supabase } from "@/lib/supabase";
import type { BodyComposition, WorkoutLog } from "@/types";

const today = new Date();
// これをブラウザのJavaScriptで実行すると、UTC（協定世界時）の深夜0時として解釈されます。
// 日本（JST, UTC+9）のブラウザで実行すると、UTCの0時はJSTでは「6月21日 午前9時」になるので、
// 表示上は同じ日になるから問題なさそうに見えます。
// でも例えば、アメリカのユーザー（UTC - 5やUTC - 8）がこのアプリを使った場合、
// UTCの0時はその人のローカル時間では「6月20日の夜」になってしまい、getDate() で取得すると
// 1日前の日付として表示されてしまう、というズレが起きます。
// 「このアプリを使うユーザーが全員、日本（または同じくUTCより進んでいるタイムゾーン）のブラウザを
// 使う前提なら、今のところは問題が起きにくい」という状況です。
// 個人開発の筋トレアプリで、使うのは自分だけ・日本国内だけという前提なら、実害は出にくいと思います。
// もし不安なら
// 文字列をそのままパースする方法に変えると、タイムゾーンの解釈に依存しなくなります。
// "2026-06-21" → 21 を直接取り出す
// const day = Number(r.date.split('-')[2])
const currentYear = ref(today.getFullYear());
const currentMonth = ref(today.getMonth() + 1);

function prevMonth() {
  if (currentMonth.value === 1) {
    currentYear.value--;
    currentMonth.value = 12;
  } else {
    currentMonth.value--;
  }
}

function nextMonth() {
  if (currentMonth.value === 12) {
    currentYear.value++;
    currentMonth.value = 1;
  } else {
    currentMonth.value++;
  }
}

const isCurrentMonth = computed(
  () =>
    currentYear.value === today.getFullYear() &&
    currentMonth.value === today.getMonth() + 1,
);

const weekDays = ["日", "月", "火", "水", "木", "金", "土"];
const workoutDates = ref<Set<number>>(new Set());
const todayBody = ref<BodyComposition | null>(null);
const bodyDialog = ref(false);
const inputWeight = ref<number | null>(null);
const inputBodyFat = ref<number | null>(null);

const dayDetailDialog = ref(false);
const dayDetailLoading = ref(false);
const selectedDay = ref<number | null>(null);
const selectedDayBody = ref<BodyComposition | null>(null);
const selectedDayWorkouts = ref<WorkoutLog[]>([]);

const selectedDayWorkoutGroups = computed(() => {
  const map = new Map<string, WorkoutLog[]>();
  for (const log of selectedDayWorkouts.value) {
    const name = log.exercise?.name ?? log.exercise_id;
    if (!map.has(name)) map.set(name, []);
    map.get(name)!.push(log);
  }
  return Array.from(map.entries()).map(([exerciseName, logs]) => ({
    exerciseName,
    logs: logs.sort((a, b) => a.set_number - b.set_number),
  }));
});

const calendarWeeks = computed(() => {
  const firstDay = new Date(
    currentYear.value,
    currentMonth.value - 1,
    1,
  ).getDay();
  const daysInMonth = new Date(
    currentYear.value,
    currentMonth.value,
    0,
  ).getDate();
  const weeks: (number | null)[][] = [];
  let week: (number | null)[] = Array(firstDay).fill(null);

  for (let d = 1; d <= daysInMonth; d++) {
    week.push(d);
    if (week.length === 7) {
      weeks.push(week);
      week = [];
    }
  }
  if (week.length > 0) {
    while (week.length < 7) week.push(null);
    weeks.push(week);
  }
  return weeks;
});

function isToday(day: number) {
  return (
    day === today.getDate() &&
    currentMonth.value === today.getMonth() + 1 &&
    currentYear.value === today.getFullYear()
  );
}

function hasWorkout(day: number) {
  return workoutDates.value.has(day);
}

async function loadWorkoutDates() {
  const y = currentYear.value;
  const m = currentMonth.value;
  const lastDay = new Date(y, m, 0).getDate();
  const startDate = `${y}-${String(m).padStart(2, "0")}-01`;
  const endDate = `${y}-${String(m).padStart(2, "0")}-${String(lastDay).padStart(2, "0")}`;
  const { data } = await supabase
    .from("workout_logs")
    .select("date")
    .gte("date", startDate)
    .lte("date", endDate);
  if (data) {
    workoutDates.value = new Set(data.map((r) => new Date(r.date).getDate()));
  }
}

watch([currentYear, currentMonth], () => {
  workoutDates.value = new Set();
  loadWorkoutDates();
});

async function loadTodayBody() {
  const todayStr = today.toISOString().split("T")[0];
  const { data } = await supabase
    .from("body_compositions")
    .select("*")
    .eq("date", todayStr)
    .maybeSingle();
  todayBody.value = data;
}

async function handleDayClick(day: number) {
  selectedDay.value = day;
  dayDetailDialog.value = true;
  dayDetailLoading.value = true;
  const dateStr = `${currentYear.value}-${String(currentMonth.value).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
  const [workoutResult, bodyResult] = await Promise.all([
    supabase
      .from("workout_logs")
      .select("*, exercise:exercise_masters(*)")
      .eq("date", dateStr)
      .order("exercise_id")
      .order("set_number"),
    supabase
      .from("body_compositions")
      .select("*")
      .eq("date", dateStr)
      .maybeSingle(),
  ]);
  selectedDayWorkouts.value = (workoutResult.data ?? []) as WorkoutLog[];
  selectedDayBody.value = bodyResult.data;
  dayDetailLoading.value = false;
}

async function saveBodyComposition() {
  if (!inputWeight.value) return;
  const todayStr = today.toISOString().split("T")[0];
  await supabase.from("body_compositions").upsert(
    {
      date: todayStr,
      weight: inputWeight.value,
      body_fat_percentage: inputBodyFat.value ?? null,
    },
    { onConflict: "date" },
  );
  bodyDialog.value = false;
  await loadTodayBody();
}

onMounted(() => {
  loadWorkoutDates();
  loadTodayBody();
});
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
  border: 2px solid #1976d2;
}
.workout-dot {
  position: absolute;
  bottom: 2px;
}
</style>
