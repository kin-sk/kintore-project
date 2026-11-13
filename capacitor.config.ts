import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'jp.kintore.app',
  appName: 'KINTORE',
  webDir: 'dist',
  backgroundColor: '#13161b',
  android: {
    // Android 15 以降でステータスバー/ナビゲーションバーに画面が潜り込まないようにする
    adjustMarginsForEdgeToEdge: 'auto',
  },
  plugins: {
    LocalNotifications: {
      iconColor: '#4C8DFF',
    },
  },
}

export default config
