<template>
  <v-app>
    <v-app-bar v-if="isAuthenticated" color="background" flat border="b">
      <router-link to="/" class="app-logo ml-4" aria-label="KINTORE ホーム">
        <span class="app-logo-mark"><v-icon size="16">mdi-dumbbell</v-icon></span>
        KINTORE
      </router-link>
      <v-spacer />
      <v-btn icon variant="text" color="medium-emphasis" aria-label="ログアウト" @click="handleLogout">
        <v-icon>mdi-logout</v-icon>
      </v-btn>
    </v-app-bar>

    <v-main>
      <router-view />
    </v-main>

    <v-bottom-navigation v-if="isAuthenticated" :elevation="0" border="t" bg-color="background" grow color="primary" :height="64">
      <v-btn to="/" value="home">
        <v-icon>mdi-calendar</v-icon>
        <span>ホーム</span>
      </v-btn>
      <v-btn to="/workout" value="workout">
        <v-icon>mdi-dumbbell</v-icon>
        <span>記録</span>
      </v-btn>
      <v-btn to="/analytics" value="analytics">
        <v-icon>mdi-chart-line</v-icon>
        <span>グラフ</span>
      </v-btn>
      <v-btn to="/exercises" value="exercises">
        <v-icon>mdi-format-list-bulleted</v-icon>
        <span>種目</span>
      </v-btn>
    </v-bottom-navigation>
  </v-app>
</template>

<script setup lang="ts">
import { useAuth } from '@/composables/useAuth'
import { useRouter } from 'vue-router'

const { isAuthenticated, signOut } = useAuth()
const router = useRouter()

async function handleLogout() {
  await signOut()
  router.push('/auth')
}
</script>

<style scoped>
.app-logo {
  display: flex;
  align-items: center;
  gap: 8px;
  font-family: 'Barlow Condensed', 'Arial Narrow', sans-serif;
  font-weight: 700;
  font-style: italic;
  font-size: 1.4rem;
  letter-spacing: .06em;
  color: var(--k-fg);
  text-decoration: none;
}
.app-logo-mark {
  width: 24px;
  height: 24px;
  border-radius: 7px;
  background: var(--k-primary);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-style: normal;
}
</style>
