/**
 * ネイティブ（Capacitor/Android）とブラウザの差を吸収する小さなラッパー。
 * - ネイティブ: 端末に通知を予約するので、画面OFF・アプリ終了中でも定刻に鳴る
 * - ブラウザ:   従来どおり Notification API + setTimeout（画面を開いている間だけ確実）
 */
import { Capacitor } from '@capacitor/core'
import { LocalNotifications } from '@capacitor/local-notifications'
import { Haptics, ImpactStyle } from '@capacitor/haptics'

export const isNative = Capacitor.isNativePlatform()

const REST_NOTIFICATION_ID = 1001
const REST_CHANNEL_ID = 'rest-timer'
const TITLE = '休憩終了！'
const BODY = '次のセットを始めましょう 💪'

let channelReady = false
let webTimeout: ReturnType<typeof setTimeout> | null = null

async function ensureNativeReady(): Promise<boolean> {
  let perm = await LocalNotifications.checkPermissions()
  if (perm.display === 'prompt' || perm.display === 'prompt-with-rationale') {
    perm = await LocalNotifications.requestPermissions()
  }
  if (perm.display !== 'granted') return false
  if (!channelReady) {
    // 重要度 5 = 画面上部にポップアップ + 音 + バイブ
    await LocalNotifications.createChannel({
      id: REST_CHANNEL_ID,
      name: '休憩タイマー',
      description: 'インターバル終了のお知らせ',
      importance: 5,
      visibility: 1,
      vibration: true,
    })
    channelReady = true
  }
  return true
}

/** 休憩終了の通知を endAt（epoch ms）に予約する。既存の予約は置き換える */
export async function scheduleRestEnd(endAt: number) {
  await cancelRestEnd()
  if (isNative) {
    try {
      if (!(await ensureNativeReady())) return
      await LocalNotifications.schedule({
        notifications: [{
          id: REST_NOTIFICATION_ID,
          title: TITLE,
          body: BODY,
          channelId: REST_CHANNEL_ID,
          schedule: { at: new Date(endAt), allowWhileIdle: true },
        }],
      })
    } catch (e) {
      console.error('[scheduleRestEnd] failed', e)
    }
    return
  }

  if (!('Notification' in window)) return
  if (Notification.permission === 'default') await Notification.requestPermission()
  if (Notification.permission !== 'granted') return
  webTimeout = setTimeout(() => {
    webTimeout = null
    new Notification(TITLE, { body: BODY, icon: '/pwa-192x192.png' })
  }, Math.max(0, endAt - Date.now()))
}

/** 予約済みの休憩終了通知を取り消す（一時停止・リセット・時間変更時） */
export async function cancelRestEnd() {
  if (webTimeout) { clearTimeout(webTimeout); webTimeout = null }
  if (!isNative) return
  try {
    await LocalNotifications.cancel({ notifications: [{ id: REST_NOTIFICATION_ID }] })
  } catch {
    // 予約がなければ何もしない
  }
}

/** 休憩終了時のバイブ（アプリを開いている時） */
export function vibrateRestEnd() {
  if (isNative) {
    // Haptics.vibrate は1回分なので、ブッ・ブッ・ブッと3回鳴らす
    [0, 450, 900].forEach((delay) => setTimeout(() => Haptics.vibrate({ duration: 300 }), delay))
    return
  }
  if (navigator.vibrate) navigator.vibrate([300, 100, 300, 100, 300])
}

/** セット記録などの軽い手応え */
export function tapFeedback() {
  if (isNative) Haptics.impact({ style: ImpactStyle.Medium }).catch(() => {})
}
