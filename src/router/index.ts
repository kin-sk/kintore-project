import { createRouter, createWebHistory } from 'vue-router'
import { watch } from 'vue'
import { useAuth } from '@/composables/useAuth'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/auth',
      name: 'auth',
      component: () => import('@/views/AuthView.vue'),
      meta: { requiresAuth: false }
    },
    {
      path: '/',
      name: 'home',
      component: () => import('@/views/HomeView.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/workout',
      name: 'workout',
      component: () => import('@/views/WorkoutView.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/analytics',
      name: 'analytics',
      component: () => import('@/views/AnalyticsView.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/exercises',
      name: 'exercises',
      component: () => import('@/views/ExerciseMasterView.vue'),
      meta: { requiresAuth: true }
    },
  ],
})

router.beforeEach((to, _from, next) => {
  const { isAuthenticated, loading } = useAuth()

  // ローディング中は待機
  if (loading.value) {
    const unwatch = watch(loading, (newLoading) => {
      if (!newLoading) {
        unwatch()
        checkAuth()
      }
    })
    return
  }

  checkAuth()

  function checkAuth() {
    const requiresAuth = to.meta.requiresAuth !== false

    if (requiresAuth && !isAuthenticated.value) {
      next('/auth')
    } else if (to.path === '/auth' && isAuthenticated.value) {
      next('/')
    } else {
      next()
    }
  }
})

export default router
