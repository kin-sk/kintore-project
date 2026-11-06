<template>
  <v-app>
    <v-main>
      <router-view />
    </v-main>

    <v-bottom-navigation :elevation="8" grow color="primary" :height="64" class="safe-bottom">
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
</script>
<style>
.safe-bottom.v-bottom-navigation {
  height: calc(64px + env(safe-area-inset-bottom)) !important;
  padding-bottom: env(safe-area-inset-bottom);
}
.v-main {
  padding-bottom: calc(64px + env(safe-area-inset-bottom)) !important;
}
</style>
