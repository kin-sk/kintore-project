import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import vuetify from './plugins/vuetify'
import { useAuth } from './composables/useAuth'

const app = createApp(App)

// 認証初期化
const { initialize } = useAuth()
initialize().then(() => {
  app.use(router).use(vuetify).mount('#app')
})
