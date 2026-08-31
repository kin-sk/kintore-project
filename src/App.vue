<template>
  <v-app>
    <v-app-bar v-if="isAuthenticated" color="primary" dark>
      <v-toolbar-title>筋トレ記録</v-toolbar-title>
      <v-spacer />
      <v-btn icon @click="handleLogout">
        <v-icon>mdi-logout</v-icon>
      </v-btn>
    </v-app-bar>

    <v-main>
      <router-view />
    </v-main>

    <v-bottom-navigation v-if="isAuthenticated" :elevation="8" grow color="primary">
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
