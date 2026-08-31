<template>
  <v-container class="fill-height d-flex align-center justify-center" style="max-width: 400px;">
    <v-card rounded="lg" width="100%" class="pa-4">
      <v-card-title class="text-h5 text-center mb-4">
        筋トレ記録アプリ
      </v-card-title>

      <v-tabs v-model="tab" grow class="mb-4">
        <v-tab value="login">ログイン</v-tab>
        <v-tab value="signup">サインアップ</v-tab>
      </v-tabs>

      <v-window v-model="tab">
        <v-window-item value="login">
          <v-form @submit.prevent="handleLogin">
            <v-text-field
              v-model="email"
              label="メールアドレス"
              type="email"
              variant="outlined"
              class="mb-2"
              required
            />
            <v-text-field
              v-model="password"
              label="パスワード"
              type="password"
              variant="outlined"
              class="mb-3"
              required
            />
            <v-alert v-if="error" type="error" class="mb-3">{{ error }}</v-alert>
            <v-btn
              type="submit"
              color="primary"
              block
              size="large"
              :loading="isLoading"
            >
              ログイン
            </v-btn>
          </v-form>
        </v-window-item>

        <v-window-item value="signup">
          <v-form @submit.prevent="handleSignup">
            <v-text-field
              v-model="email"
              label="メールアドレス"
              type="email"
              variant="outlined"
              class="mb-2"
              required
            />
            <v-text-field
              v-model="password"
              label="パスワード（6文字以上）"
              type="password"
              variant="outlined"
              class="mb-2"
              required
            />
            <v-text-field
              v-model="confirmPassword"
              label="パスワード確認"
              type="password"
              variant="outlined"
              class="mb-3"
              required
            />
            <v-alert v-if="error" type="error" class="mb-3">{{ error }}</v-alert>
            <v-btn
              type="submit"
              color="primary"
              block
              size="large"
              :loading="isLoading"
            >
              サインアップ
            </v-btn>
          </v-form>
        </v-window-item>
      </v-window>
    </v-card>
  </v-container>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'

const router = useRouter()
const { signIn, signUp } = useAuth()

const tab = ref('login')
const email = ref('')
const password = ref('')
const confirmPassword = ref('')
const error = ref('')
const isLoading = ref(false)

async function handleLogin() {
  error.value = ''
  isLoading.value = true
  try {
    await signIn(email.value, password.value)
    router.push('/')
  } catch (e: any) {
    error.value = e.message || 'ログインに失敗しました'
  } finally {
    isLoading.value = false
  }
}

async function handleSignup() {
  error.value = ''
  if (password.value !== confirmPassword.value) {
    error.value = 'パスワードが一致しません'
    return
  }
  if (password.value.length < 6) {
    error.value = 'パスワードは6文字以上で入力してください'
    return
  }
  isLoading.value = true
  try {
    await signUp(email.value, password.value)
    router.push('/')
  } catch (e: any) {
    error.value = e.message || 'サインアップに失敗しました'
  } finally {
    isLoading.value = false
  }
}
</script>
