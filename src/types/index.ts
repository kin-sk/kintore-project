export interface ExerciseMaster {
  id: string
  name: string
  part: string
  equipment: string
  created_at: string
}

export interface WorkoutLog {
  id: number
  date: string
  exercise_id: string
  exercise?: ExerciseMaster
  weight: number
  reps: number
  set_number: number
  created_at: string
}

export interface BodyComposition {
  id: number
  date: string
  weight: number
  body_fat_percentage: number | null
  created_at: string
}

export const PARTS: string[] = ['胸', '背中', '脚', '肩', '腕', '腹', '全身']
export const EQUIPMENTS: string[] = ['バーベル', 'ダンベル', 'マシン', 'ケーブル', '自重']
