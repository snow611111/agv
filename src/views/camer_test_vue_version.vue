<script setup>
import { ref, reactive, onMounted, onUnmounted, nextTick } from 'vue'

// ===== 摄像头配置 =====
const cameras = [
  { name: '摄像头1', hls: '/hls_output/cam1/index.m3u8', flv: '/flv/cam1' },
  { name: '摄像头2', hls: '/hls_output/cam2/index.m3u8', flv: '/flv/cam2' },
  { name: '摄像头3', hls: '/hls_output/cam3/index.m3u8', flv: '/flv/cam3' },
  { name: '摄像头4', hls: '/hls_output/cam4/index.m3u8', flv: '/flv/cam4' },
]

// ===== 响应式状态 =====
const urlParams = new URLSearchParams(window.location.search)
const currentMode = ref(urlParams.get('mode') === 'hls' ? 'hls' : 'flv')
const players = ref({})
const speedEnabled = ref(true)
const camEnabled = reactive([true, true, true, true])
const logModeLabel = ref('当前: 低延迟 FLV')

// 每个摄像头的 UI 状态（用 reactive 数组，模板中直接 camState[i].xxx 访问）
const camState = reactive([
  { tag: '等待', tagColor: '#909399', panelClass: '', videoShow: false, msgShow: true, msgIcon: '🎥', msgText: '加载中...', speedHtml: '<span style="color:#888">⏳</span> 等待...', latencyVal: '--', latencyColor: '#67c23a', latencyBarW: '0%', footL: '--', footR: '' },
  { tag: '等待', tagColor: '#909399', panelClass: '', videoShow: false, msgShow: true, msgIcon: '🎥', msgText: '加载中...', speedHtml: '<span style="color:#888">⏳</span> 等待...', latencyVal: '--', latencyColor: '#67c23a', latencyBarW: '0%', footL: '--', footR: '' },
  { tag: '等待', tagColor: '#909399', panelClass: '', videoShow: false, msgShow: true, msgIcon: '🎥', msgText: '加载中...', speedHtml: '<span style="color:#888">⏳</span> 等待...', latencyVal: '--', latencyColor: '#67c23a', latencyBarW: '0%', footL: '--', footR: '' },
  { tag: '等待', tagColor: '#909399', panelClass: '', videoShow: false, msgShow: true, msgIcon: '🎥', msgText: '加载中...', speedHtml: '<span style="color:#888">⏳</span> 等待...', latencyVal: '--', latencyColor: '#67c23a', latencyBarW: '0%', footL: '--', footR: '' },
])

// 视频元素 refs
const videoRefs = ref([])
function setVideoRef(i, el) { if (el) videoRefs.value[i] = el }

// 日志
const logs = ref([])
const logContainerRef = ref(null)

// ===== 日志函数 =====
function log(msg, cls) {
  const now = new Date()
  const ts = ('0' + now.getHours()).slice(-2) + ':' +
             ('0' + now.getMinutes()).slice(-2) + ':' +
             ('0' + now.getSeconds()).slice(-2)
  const colorMap = { ok: '#67c23a', err: '#f56c6c', info: '#409eff' }
  logs.value.push({ ts, msg, color: colorMap[cls] || '#ccc' })
  nextTick(() => {
    const el = logContainerRef.value
    if (el) el.scrollTop = el.scrollHeight
  })
  console.log(ts + ' ' + msg)
}

// ===== 开关摄像头 =====
function toggleCam(i) {
  camEnabled[i] = !camEnabled[i]
  if (camEnabled[i]) {
    log('cam' + (i + 1) + ' 启用', 'info')
    startCamera(i)
  } else {
    stopCamera(i)
    camState[i].tag = '⏸ 已禁用'
    camState[i].tagColor = '#909399'
    camState[i].panelClass = ''
    camState[i].msgIcon = '⏸'
    camState[i].msgText = '已禁用'
    camState[i].msgShow = true
    camState[i].videoShow = false
    log('cam' + (i + 1) + ' 禁用', 'info')
  }
}

// ===== 测速开关 =====
function toggleSpeed() {
  speedEnabled.value = !speedEnabled.value
}

// ===== 更新测速信息 =====
function updateSpeed(i, kbPerSec, fpsVal, resW, resH, videoEl) {
  if (!speedEnabled.value) return
  // 速度 + 分辨率
  const s = kbPerSec >= 1000 ? (kbPerSec / 1000).toFixed(1) + ' MB/s' : kbPerSec.toFixed(0) + ' KB/s'
  const r = resW > 0 ? '<span style="color:#67c23a">' + resW + 'x' + resH + '</span>' : '--'
  const speedColor = kbPerSec > 10 ? '#67c23a' : (kbPerSec > 0 ? '#e6a23c' : '#fff')
  camState[i].speedHtml = '📥 ' + (kbPerSec > 10 ? '<span style="color:#67c23a">' + s + '</span>' : (kbPerSec > 0 ? '<span style="color:#e6a23c">' + s + '</span>' : s)) + ' &nbsp;📐 ' + r

  // 延迟估算
  if (videoEl) {
    const v = videoEl
    let latSec = 0
    if (v.buffered && v.buffered.length > 0) {
      latSec = Math.max(0, v.buffered.end(v.buffered.length - 1) - v.currentTime)
    }
    if (latSec > 0) {
      camState[i].latencyVal = latSec.toFixed(1) + 's'
      camState[i].latencyColor = latSec < 2 ? '#67c23a' : (latSec < 5 ? '#e6a23c' : '#f56c6c')
    } else {
      camState[i].latencyVal = '--'
      camState[i].latencyColor = '#67c23a'
    }
    camState[i].latencyBarW = Math.min(latSec / 5 * 100, 100) + '%'
  }
}

// ===== 模式切换 =====
function switchMode(mode) {
  if (currentMode.value === mode) return
  currentMode.value = mode
  logModeLabel.value = mode === 'hls' ? '高延迟 HLS' : '低延迟 FLV'
  log('=== 切换到 ' + logModeLabel.value + ' ===', 'info')
  cameras.forEach((c, i) => {
    if (camEnabled[i]) startCamera(i)
  })
}

// ===== 启动单个摄像头 =====
function startCamera(i) {
  stopCamera(i)
  const c = cameras[i]

  camState[i].msgShow = true
  camState[i].msgIcon = '🎥'
  camState[i].msgText = '连接中...'
  camState[i].videoShow = false
  camState[i].tag = '⏳'
  camState[i].tagColor = '#e6a23c'
  camState[i].panelClass = ''

  const video = videoRefs.value[i]
  if (!video) return

  if (currentMode.value === 'hls') {
    startHls(i, c, video)
  } else {
    startFlv(i, c, video)
  }
}

// ===== HLS 模式 =====
function startHls(i, c, video) {
  camState[i].footL = 'HLS | ' + c.hls
  log('cam' + (i + 1) + ' HLS 连接: ' + c.hls, 'info')

  if (typeof Hls !== 'undefined' && Hls.isSupported()) {
    const hls = new Hls({ liveDurationInfinity: true, maxBufferLength: 30 })
    players.value[i] = { type: 'hls', instance: hls }

    let hlsSpeedData = { lastSegTime: Date.now(), segBytes: 0 }
    hls.on(Hls.Events.FRAG_LOADED, function (ev, data) {
      const now = Date.now()
      const loadTime = (now - hlsSpeedData.lastSegTime) / 1000
      if (loadTime > 0.1 && data.frag && data.frag.loader) {
        const bytes = data.frag.stats ? data.frag.stats.total : (data.frag.loader._bytesLoaded || 0)
        const kbSec = (bytes / 1024) / loadTime
        updateSpeed(i, kbSec, 0, video.videoWidth, video.videoHeight, video)
        hlsSpeedData = { lastSegTime: now, segBytes: bytes }
      }
    })

    hls.on(Hls.Events.MANIFEST_PARSED, function () {
      video.play()
      camState[i].tag = '✅ HLS'
      camState[i].tagColor = '#67c23a'
      camState[i].panelClass = 'ok'
      camState[i].msgShow = false
      camState[i].videoShow = true
      camState[i].footR = 'OK'
      log('cam' + (i + 1) + ' ✅ HLS MANIFEST_PARSED', 'ok')
    })

    hls.on(Hls.Events.ERROR, function (ev, data) {
      log('cam' + (i + 1) + ' HLS err: ' + data.type + '/' + data.details, 'err')
      if (data.fatal) {
        camState[i].tag = '❌'
        camState[i].tagColor = '#f56c6c'
        camState[i].panelClass = 'err'
        camState[i].footR = 'ERR: ' + data.details
        camState[i].msgIcon = '❌'
        camState[i].msgText = data.details
        camState[i].msgShow = true
      }
    })

    hls.loadSource(c.hls)
    hls.attachMedia(video)
  } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
    // Safari 原生 HLS
    video.src = c.hls
    players.value[i] = { type: 'hls_native', instance: null }
  } else {
    camState[i].tag = '❌'
    camState[i].tagColor = '#f56c6c'
    camState[i].footR = '不支持HLS'
    camState[i].msgIcon = '❌'
    camState[i].msgText = '浏览器不支持HLS'
    camState[i].msgShow = true
  }

  video.addEventListener('playing', function () {
    camState[i].msgShow = false
    camState[i].videoShow = true
    camState[i].tag = '✅ HLS'
    camState[i].tagColor = '#67c23a'
    camState[i].panelClass = 'ok'
  })
}

// ===== FLV 模式（低延迟）=====
function startFlv(i, c, video) {
  camState[i].footL = 'FLV | ' + c.flv
  log('cam' + (i + 1) + ' FLV 连接: ' + c.flv, 'info')

  if (typeof mpegts === 'undefined' || !mpegts.isSupported()) {
    camState[i].tag = '❌'
    camState[i].tagColor = '#f56c6c'
    camState[i].footR = '不支持FLV/MSE'
    camState[i].msgIcon = '❌'
    camState[i].msgText = '浏览器不支持MSE'
    camState[i].msgShow = true
    return
  }

  try {
    const player = mpegts.createPlayer({
      type: 'flv',
      isLive: true,
      url: c.flv,
      hasAudio: false,
      hasVideo: true,
      enableStashBuffer: false,
      stashInitialSize: 128,
      lazyLoad: false
    })
    players.value[i] = { type: 'flv', instance: player }

    const t0 = Date.now()
    player.on(mpegts.Events.STATISTICS_INFO, function (s) {
      const el = ((Date.now() - t0) / 1000).toFixed(0)
      camState[i].footR = '📥' + (s.speed || 0).toFixed(0) + 'KB/s | ⏱' + el + 's'
      updateSpeed(i, s.speed || 0, s.decodeFps || 0, video.videoWidth, video.videoHeight, video)
    })

    player.on(mpegts.Events.MEDIA_INFO, function (info) {
      const el = ((Date.now() - t0) / 1000).toFixed(1)
      log('cam' + (i + 1) + ' ✅ FLV MEDIA_INFO (' + el + 's)', 'ok')
      camState[i].tag = '✅ FLV'
      camState[i].tagColor = '#67c23a'
      camState[i].panelClass = 'ok'
      camState[i].msgShow = false
      camState[i].videoShow = true
      camState[i].footR = 'OK (' + el + 's)'
    })

    player.on(mpegts.Events.ERROR, function (type, info) {
      log('cam' + (i + 1) + ' ❌ FLV ' + type + ': ' + JSON.stringify(info), 'err')
      camState[i].tag = '❌'
      camState[i].tagColor = '#f56c6c'
      camState[i].panelClass = 'err'
      camState[i].footR = 'ERR: ' + type
      camState[i].msgIcon = '❌'
      camState[i].msgText = type
      camState[i].msgShow = true
    })

    player.attachMediaElement(video)
    player.load()

  } catch (e) {
    camState[i].tag = '❌'
    camState[i].tagColor = '#f56c6c'
    camState[i].footR = 'ERR: ' + e.message
  }
}

// ===== 停止摄像头 =====
function stopCamera(i) {
  const p = players.value[i]
  if (p) {
    if (p.type === 'hls' && p.instance) { p.instance.destroy() }
    if (p.type === 'flv' && p.instance) { p.instance.destroy() }
    players.value[i] = null
  }
  const video = videoRefs.value[i]
  if (video) { video.pause(); video.src = ''; video.srcObject = null }
}

// ===== 初始化 =====
onMounted(() => {
  if (currentMode.value === 'hls') {
    logModeLabel.value = '高延迟 HLS'
  }
  cameras.forEach((c, i) => {
    if (camEnabled[i]) {
      startCamera(i)
    } else {
      camState[i].tag = '⏸ 已禁用'
      camState[i].tagColor = '#909399'
      camState[i].msgIcon = '⏸'
      camState[i].msgText = '已禁用'
    }
  })
})

// ===== 清理 =====
onUnmounted(() => {
  cameras.forEach((_, i) => stopCamera(i))
})
</script>

<template>
  <h1>📹 摄像头实时测试</h1>

  <!-- 模式切换栏 -->
  <div class="mode-bar">
    <span style="font-size:13px;color:#909399">延迟模式:</span>
    <button :class="['mode-btn', { active: currentMode === 'flv' }]" @click="switchMode('flv')">🚀 低延迟 (FLV)</button>
    <button :class="['mode-btn', { active: currentMode === 'hls' }]" @click="switchMode('hls')">🐢 高延迟 (HLS)</button>
    <button
      :class="['toggle-btn', { on: speedEnabled }]"
      @click="toggleSpeed()"
    >📊 实时测速: {{ speedEnabled ? '开' : '关' }}</button>
  </div>

  <!-- 摄像头开关栏 -->
  <div class="mode-bar">
    <span style="font-size:11px;color:#888">摄像头:</span>
    <button
      v-for="(cam, i) in cameras"
      :key="i"
      :class="['toggle-btn', { on: camEnabled[i] }]"
      style="font-size:11px"
      @click="toggleCam(i)"
    >📷 {{ cam.name }}: {{ camEnabled[i] ? '开' : '关' }}</button>
  </div>

  <!-- HLS 说明卡片 -->
  <div class="annotation" v-show="currentMode === 'hls'">
    <h3>🐢 高延迟模式 — HLS</h3>
    <table>
      <tr><td>原理</td><td>ffmpeg 将 RTSP 流切成 2 秒一段的 .ts 文件 → Python HTTP 服务 → 浏览器 hls.js 播放</td></tr>
      <tr><td>延迟</td><td><span class="tag yellow">5 ~ 15 秒</span>（视频攒够一个分段 + 网络传输 + 浏览器缓冲）</td></tr>
      <tr><td>优点</td><td>稳定性高、有缓冲抗抖动、兼容所有浏览器、数据量小</td></tr>
      <tr><td>适用</td><td>网络不稳定时、不需要实时操作的场景（如任务复盘查看）</td></tr>
      <tr><td>数据流</td><td style="font-family:Consolas;font-size:10px">RTSP → ffmpeg → .ts 文件 → HTTP GET → hls.js → &lt;video&gt;</td></tr>
    </table>
  </div>

  <!-- FLV 说明卡片 -->
  <div class="annotation" v-show="currentMode === 'flv'">
    <h3>🚀 低延迟模式 — HTTP-FLV</h3>
    <table>
      <tr><td>原理</td><td>ffmpeg 持续输出 FLV 流 → 浏览器 mpegts.js 通过 MSE 实时解码到 &lt;video&gt;</td></tr>
      <tr><td>延迟</td><td><span class="tag green">1 ~ 3 秒</span>（仅网络传输 + 少量缓冲）</td></tr>
      <tr><td>优点</td><td>延迟低、实时性好、画面即时反馈</td></tr>
      <tr><td>缺点</td><td>网络波动可能导致画面卡顿或花屏、数据量稍大</td></tr>
      <tr><td>适用</td><td>需要实时监控、操控车辆时使用</td></tr>
      <tr><td>数据流</td><td style="font-family:Consolas;font-size:10px">RTSP → ffmpeg → FLV → HTTP 长连接 → mpegts.js → MSE → &lt;video&gt;</td></tr>
    </table>
  </div>

  <!-- 摄像头网格 -->
  <div class="grid">
    <div v-for="(cam, i) in cameras" :key="i" :class="['panel', camState[i].panelClass]">
      <!-- 面板头 -->
      <div class="ph">
        <b>📷 {{ cam.name }}</b>
        <span style="font-size:11px" :style="{ color: camState[i].tagColor }">{{ camState[i].tag }}</span>
      </div>

      <!-- 视频框 -->
      <div class="vbox">
        <video
          :ref="el => setVideoRef(i, el)"
          autoplay muted playsinline
          :style="{ display: camState[i].videoShow ? '' : 'none' }"
        ></video>

        <!-- 测速覆盖层 -->
        <div
          v-show="speedEnabled"
          class="speed-ov"
          style="position:absolute;top:6px;left:6px;background:rgba(0,0,0,.7);color:#fff;padding:4px 8px;border-radius:4px;font-size:10px;font-family:Consolas,monospace;pointer-events:none;z-index:3;line-height:1.5"
          v-html="camState[i].speedHtml"
        ></div>

        <!-- 延迟指示器 -->
        <div
          v-show="speedEnabled"
          class="fps-gauge"
          style="position:absolute;top:6px;right:6px;background:rgba(0,0,0,.7);color:#fff;padding:4px 8px;border-radius:4px;font-size:10px;font-family:Consolas,monospace;pointer-events:none;z-index:3"
        >
          延迟
          <span class="val" :style="{ color: camState[i].latencyColor }">{{ camState[i].latencyVal }}</span>
          <span style="display:inline-block;width:40px;height:6px;background:#333;border-radius:3px;vertical-align:middle;margin-left:4px;overflow:hidden">
            <span :style="{ display:'block', height:'100%', background: camState[i].latencyColor, borderRadius:'3px', width: camState[i].latencyBarW }"></span>
          </span>
        </div>

        <!-- 状态消息 -->
        <div v-show="camState[i].msgShow" class="msg" style="text-align:center;color:#666;font-size:13px;position:absolute">
          <span class="icon" style="font-size:40px;display:block;margin-bottom:6px">{{ camState[i].msgIcon }}</span>{{ camState[i].msgText }}
        </div>
      </div>

      <!-- 底部栏 -->
      <div class="foot">
        <span>{{ camState[i].footL }}</span>
        <span>{{ camState[i].footR }}</span>
      </div>
    </div>
  </div>

  <!-- 日志面板 -->
  <div id="logWrap" style="max-width:100%;background:#0f3460;border-radius:6px;overflow:hidden;margin-top:8px">
    <div style="padding:6px 12px;background:rgba(0,0,0,.2);font-size:12px;display:flex;justify-content:space-between">
      <b>📋 日志</b>
      <span style="font-size:10px;color:#666">当前: {{ logModeLabel }}</span>
    </div>
    <div
      id="log"
      ref="logContainerRef"
      style="height:160px;overflow-y:auto;padding:8px 12px;font-size:10px;line-height:1.6;font-family:Consolas,monospace;white-space:pre-wrap;word-break:break-all;color:#ccc"
    >
      <div v-for="(entry, idx) in logs" :key="idx" style="margin:0" :style="{ color: entry.color }">
        <span style="color:#666">{{ entry.ts }}</span> {{ entry.msg }}
      </div>
    </div>
  </div>
</template>

<style scoped>
* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}
body {
  background: #1a1a2e;
  color: #e0e0e0;
  font-family: 'Microsoft YaHei', Arial, sans-serif;
  min-height: 100vh;
  padding: 12px;
}
h1 {
  text-align: center;
  font-size: 18px;
  padding: 8px 0;
  color: #fff;
}

/* Mode selector */
.mode-bar {
  display: flex;
  gap: 12px;
  justify-content: center;
  align-items: center;
  margin: 0 0 8px;
}
.mode-btn {
  padding: 6px 20px;
  border: 1px solid #409eff;
  border-radius: 4px;
  background: transparent;
  color: #409eff;
  cursor: pointer;
  font-size: 13px;
  transition: all 0.2s;
}
.mode-btn.active {
  background: #409eff;
  color: #fff;
}
.mode-btn:hover {
  opacity: 0.85;
}

/* Toggle button */
.toggle-btn {
  padding: 5px 14px;
  border: 1px solid #409eff;
  border-radius: 14px;
  background: transparent;
  color: #409eff;
  cursor: pointer;
  font-size: 12px;
  margin-left: 12px;
  transition: all 0.2s;
}
.toggle-btn.on {
  background: #409eff;
  color: #fff;
}

/* Annotation card */
.annotation {
  max-width: 960px;
  margin: 0 auto 10px;
  background: #0f3460;
  border-radius: 6px;
  padding: 12px 16px;
  font-size: 12px;
  line-height: 1.7;
}
.annotation h3 {
  font-size: 14px;
  margin-bottom: 4px;
}
.annotation .tag {
  display: inline-block;
  padding: 1px 8px;
  border-radius: 3px;
  font-size: 10px;
  margin-right: 4px;
}
.annotation .tag.green {
  background: rgba(103, 194, 58, 0.2);
  color: #67c23a;
}
.annotation .tag.yellow {
  background: rgba(230, 162, 60, 0.2);
  color: #e6a23c;
}
.annotation table {
  width: 100%;
  border-collapse: collapse;
  margin-top: 6px;
}
.annotation td {
  padding: 3px 8px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  font-size: 11px;
}
.annotation td:first-child {
  color: #888;
  width: 90px;
}

/* Grid */
.grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(460px, 1fr));
  gap: 10px;
}
.panel {
  background: #16213e;
  border: 2px solid #0f3460;
  border-radius: 8px;
  overflow: hidden;
}
.panel.ok {
  border-color: #67c23a;
}
.panel.err {
  border-color: #f56c6c;
}
.ph {
  padding: 8px 12px;
  font-size: 13px;
  background: rgba(255, 255, 255, 0.03);
  display: flex;
  justify-content: space-between;
}
.vbox {
  background: #000;
  min-height: 300px;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
}
.vbox video {
  width: 100%;
  height: 100%;
  object-fit: contain;
}
.foot {
  padding: 6px 12px;
  font-size: 11px;
  color: #888;
  background: rgba(0, 0, 0, 0.2);
  display: flex;
  justify-content: space-between;
}
.g {
  color: #67c23a;
}
.r {
  color: #f56c6c;
}
.y {
  color: #e6a23c;
}
</style>
