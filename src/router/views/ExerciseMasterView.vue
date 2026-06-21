<template>
  <v-container class="pa-2" style="max-width: 600px;">
    <v-row align="center" class="mb-2">
      <v-col>
        <h2 class="text-h6 font-weight-bold">種目管理</h2>
      </v-col>
      <v-col cols="auto">
        <v-btn color="primary" prepend-icon="mdi-plus" @click="openAddDialog">追加</v-btn>
      </v-col>
    </v-row>

    <!-- フィルター -->
    <v-row dense class="mb-3">
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

    <!-- 種目一覧 -->
    <v-card rounded="lg">
      <v-list>
        <v-list-item
          v-for="ex in filteredExercises"
          :key="ex.id"
        >
          <template #title>{{ ex.name }}</template>
          <template #subtitle>{{ ex.part }} / {{ ex.equipment }}</template>
          <template #append>
            <v-btn icon="mdi-pencil-outline" size="small" variant="text" @click="openEditDialog(ex)" />
            <v-btn icon="mdi-delete-outline" size="small" variant="text" color="error" @click="deleteExercise(ex.id)" />
          </template>
        </v-list-item>
        <v-list-item v-if="filteredExercises.length === 0">
          <v-list-item-title class="text-medium-emphasis text-center py-4">種目がありません</v-list-item-title>
        </v-list-item>
      </v-list>
    </v-card>

    <!-- 追加/編集ダイアログ -->
    <v-dialog v-model="dialog" max-width="400">
      <v-card rounded="lg">
        <v-card-title>{{ editingId ? '種目を編集' : '種目を追加' }}</v-card-title>
        <v-card-text>
          <v-text-field
            v-model="form.name"
            label="種目名"
            variant="outlined"
            class="mb-2"
          />
          <v-select
            v-model="form.part"
            :items="[...PARTS]"
            label="部位"
            variant="outlined"
            class="mb-2"
          />
          <v-select
            v-model="form.equipment"
            :items="[...EQUIPMENTS]"
            label="器具"
            variant="outlined"
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="dialog = false">キャンセル</v-btn>
          <v-btn color="primary" :disabled="!form.name || !form.part || !form.equipment" @click="saveExercise">
            {{ editingId ? '更新' : '追加' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import type { ExerciseMaster } from '@/types'
import { PARTS, EQUIPMENTS } from '@/types'

const exercises = ref<ExerciseMaster[]>([])
const filterPart = ref('すべて')
const filterEquipment = ref('すべて')
const dialog = ref(false)
const editingId = ref<string | null>(null)
const form = ref<{ name: string; part: string; equipment: string }>({ name: '', part: '', equipment: '' })

const filteredExercises = computed(() =>
  exercises.value.filter((e) => {
    if (filterPart.value !== 'すべて' && e.part !== filterPart.value) return false
    if (filterEquipment.value !== 'すべて' && e.equipment !== filterEquipment.value) return false
    return true
  })
)

function openAddDialog() {
  editingId.value = null
  form.value = { name: '', part: '', equipment: '' }
  dialog.value = true
}

function openEditDialog(ex: ExerciseMaster) {
  editingId.value = ex.id
  form.value = { name: ex.name, part: ex.part, equipment: ex.equipment }
  dialog.value = true
}

async function loadExercises() {
  const { data } = await supabase.from('exercise_masters').select('*').order('part').order('name')
  exercises.value = (data as ExerciseMaster[]) ?? []
}

async function saveExercise() {
  if (editingId.value) {
    await supabase.from('exercise_masters').update(form.value).eq('id', editingId.value)
  } else {
    await supabase.from('exercise_masters').insert(form.value)
  }
  dialog.value = false
  await loadExercises()
}

async function deleteExercise(id: string) {
  await supabase.from('exercise_masters').delete().eq('id', id)
  await loadExercises()
}

onMounted(loadExercises)
</script>
