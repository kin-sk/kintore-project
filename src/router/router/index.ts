import { createRouter, createWebHistory } from 'vue-router'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', name: 'home', component: () => import('@/views/HomeView.vue') },
    { path: '/workout', name: 'workout', component: () => import('@/views/WorkoutView.vue') },
    { path: '/analytics', name: 'analytics', component: () => import('@/views/AnalyticsView.vue') },
    { path: '/exercises', name: 'exercises', component: () => import('@/views/ExerciseMasterView.vue') },
  ],
})

export default router
