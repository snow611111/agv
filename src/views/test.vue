<script setup>
import { ref, reactive, onMounted, onUnmounted, nextTick } from 'vue'

const cameras = reactive([
  { id: 'PbemokuspQHD5', name: '摄像头1', ok: false, err: false, tag: '等待', tagColor: '#909399', started: false, foot: '--' },
  { id: 'Psh0GyTpkiSdC', name: '摄像头2', ok: false, err: false, tag: '等待', tagColor: '#909399', started: false, foot: '--' },
  { id: 'Pk8FmQHNeOqSx', name: '摄像头3', ok: false, err: false, tag: '等待', tagColor: '#909399', started: false, foot: '--' },
  { id: 'PaKHUtvPpcrZq', name: '摄像头4', ok: false, err: false, tag: '等待', tagColor: '#909399', started: false, foot: '--' },
])

const players = ref([])
const timers = ref([])

function loadScript(src) {
  return new Promise((resolve, reject) => {
    const s = document.createElement('script')
    s.src = src
    s.onload = resolve
    s.onerror = reject
    document.head.appendChild(s)
  })
}

onMounted(async () => {
  await nextTick()

  // 1. 加载 EasyPlayer（通过 vite proxy → 192.168.2.57）
  if (!window.EasyPlayerPro && !window['EasyPlayer-pro']) {
    try {
      console.log('加载 EasyPlayer...')
      await loadScript('http://192.168.2.57/easyplayer/EasyPlayer-lib.js')
      console.log('EasyPlayer 加载完成')
    } catch (e) {
      console.error('EasyPlayer 加载失败:', e)
      cameras.forEach(c => { c.tag = '库加载失败'; c.tagColor = '#f56c6c'; c.err = true })
      return
    }
  }

  const EasyPlayer = window.EasyPlayerPro || window['EasyPlayer-pro']
  if (!EasyPlayer) {
    console.error('EasyPlayer 未找到! 全局 key:', Object.keys(window).filter(k => k.toLowerCase().includes('easy')))
    cameras.forEach(c => { c.tag = '未找到'; c.tagColor = '#f56c6c'; c.err = true })
    return
  }
  console.log('EasyPlayer OK, version:', EasyPlayer.version || '?')

  // 2. 按原版方式初始化：构造时不传 url，之后 .play(url)
  cameras.forEach((cam, i) => {
    const t0 = Date.now()
    const url = 'http://192.168.2.57/webrtc-api/live/' + cam.id + '_01.flv'
    cam.foot = cam.id + '_01.flv'

    try {
      const container = document.getElementById('ep' + i)
      if (!container) { console.error('容器未找到: ep' + i); return }

      const player = new EasyPlayer(container, {
        isLive: true,
        bufferTime: 0.2,
        stretch: true,
        MSE: false,
        WCS: false,
        hasAudio: true,
      })

      player.play(url).then(() => {
        console.log('player ' + i + ' play() OK')
      }).catch(err => {
        console.error('player ' + i + ' play() 失败:', err)
        cam.err = true
        cam.tag = '播放失败'; cam.tagColor = '#f85149'
      })

      players.value[i] = player

      // 轮询检测视频渲染
      let count = 0
      timers.value[i] = setInterval(() => {
        count++
        const el = document.getElementById('ep' + i)
        const video = el ? el.querySelector('video') : null
        if (video && video.videoWidth > 0) {
          clearInterval(timers.value[i])
          const elap = ((Date.now() - t0) / 1000).toFixed(1)
          cam.ok = true; cam.started = true
          cam.tag = 'OK ' + elap + 's'; cam.tagColor = '#67c23a'
          cam.foot = video.videoWidth + 'x' + video.videoHeight + ' | ' + elap + 's'
        } else if (count > 60) {
          clearInterval(timers.value[i])
          cam.err = true
          cam.tag = '超时'; cam.tagColor = '#f85149'
        }
      }, 500)
    } catch (e) {
      console.error('Player ' + i + ' 异常:', e)
      cam.err = true
      cam.tag = '异常'; cam.tagColor = '#f85149'
    }
  })
})

onUnmounted(() => {
  players.value.forEach(p => { try { p && p.destroy() } catch (e) {} })
  timers.value.forEach(t => clearInterval(t))
})
</script>

<template>
  <div class="page">
    <h1>视频流测试 — 模仿原版 EasyPlayer 6.2.0 / HTTP-FLV</h1>
    <div class="grid">
      <div v-for="(cam, i) in cameras" :key="i" :class="['panel', { ok: cam.ok, err: cam.err }]">
        <div class="ph">
          <b>{{ cam.name }}</b>
          <span :style="{ fontSize: '11px', color: cam.tagColor }">{{ cam.tag }}</span>
        </div>
        <div class="vbox">
          <div :id="'ep' + i" style="width:100%;height:100%;min-height:280px"></div>
          <div v-if="!cam.started" class="msg">
            <span style="font-size:36px;display:block;margin-bottom:6px">🎥</span>连接中...
          </div>
        </div>
        <div class="foot">
          <span>HTTP-FLV</span><span>{{ cam.foot }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.page{background:#0d1117;color:#e0e0e0;min-height:100vh;padding:12px}
h1{text-align:center;font-size:16px;padding:6px 0;color:#fff}
.grid{display:grid;grid-template-columns:repeat(2,1fr);gap:10px}
.panel{background:#16213e;border:2px solid #0f3460;border-radius:8px;overflow:hidden}
.panel.ok{border-color:#67c23a}.panel.err{border-color:#f56c6c}
.ph{padding:8px 12px;font-size:13px;background:rgba(255,255,255,.03);display:flex;justify-content:space-between}
.vbox{background:#000;min-height:280px;position:relative}
.msg{text-align:center;color:#666;font-size:13px;position:absolute;top:50%;left:50%;transform:translate(-50%,-50%)}
.foot{padding:6px 12px;font-size:11px;color:#888;background:rgba(0,0,0,.2);display:flex;justify-content:space-between}
</style>
