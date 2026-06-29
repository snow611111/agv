<template>
  <div class="app-container no-scroll-container">
    <!-- ========== 顶部面包屑 ========== -->
    <el-breadcrumb separator="/" class="breadcrumb">
      <el-breadcrumb-item :to="{ path: '/' }">地铁隧道巡线车智能巡检系统</el-breadcrumb-item>
      <el-breadcrumb-item :to="{ path: '/taskList' }">任务列表</el-breadcrumb-item>
      <el-breadcrumb-item>任务巡视</el-breadcrumb-item>
    </el-breadcrumb>

    <!-- ========== 主布局：视频区 + 侧边栏 ========== -->
    <el-container class="task-body">
      <!-- 左侧：视频 + 底部比例尺 -->
      <el-container class="task-main-vertical">
        <el-main class="task-main">
          <!-- 视频播放器 -->
          <div class="video-stream">
            <!-- FLV (mpegts) 模式 -->
            <video v-if="playerType === 'flv'" ref="videoRef" autoplay muted playsinline style="width:100%;height:100%;object-fit:contain"></video>
            <!-- EasyPlayer 模式（key 确保切摄像头时重建 DOM） -->
            <div v-else ref="easyPlayerContainer" :key="'ep-' + currentCamera" style="width:100%;height:100%"></div>
            <div class="video-overlay" v-if="videoOverlay !== '--'">{{ videoOverlay }}</div>
          </div>


          <!-- 摄像头切换快捷按钮 -->
          <div class="camera-switch-bar">
            <el-radio-group v-model="currentCamera" @change="onCameraChange">
              <el-radio-button value="1">摄像头1</el-radio-button>
              <el-radio-button value="2">摄像头2</el-radio-button>
              <el-radio-button value="3">摄像头3</el-radio-button>
              <el-radio-button value="4">摄像头4</el-radio-button>
            </el-radio-group>
          </div>
        </el-main>

        <!-- 底部里程比例尺 -->
        <el-footer class="task-footer" height="60px">
          <div class="scale-bar-wrapper">
            <div class="scale-bar"></div>
            <span class="scale-bar-text">0m</span>
            <span class="scale-bar-text end">{{ totalDistance }}m</span>
            <div class="scale-bar-progress" :style="{ width: progressPercent + '%' }"></div>
            <div class="scale-bar-agv scale-bar-flaw" :style="{ left: 'calc(' + progressPercent + '% - 12px)' }">
              🚛
            </div>
          </div>
        </el-footer>
      </el-container>

      <!-- 右侧面板 -->
      <el-aside width="300px" class="task-aside">
        <!-- 控制台卡片 -->
        <el-card class="mb10" shadow="never">
          <template #header>
            <span>控制台</span>
          </template>
          <div class="control-btns">
            <div style="width:100%;text-align:center">
              <el-radio-group v-model="playerType" @change="onPlayerTypeChange" size="small">
                <el-radio-button value="flv">FLV (mpegts)</el-radio-button>
                <el-radio-button value="easyplayer">EasyPlayer</el-radio-button>
              </el-radio-group>
            </div>
            <el-select
              v-model="currentCamera"
              placeholder="请选择摄像头"
              style="width: 120px"
              @change="onCameraChange"
            >
              <el-option label="摄像头1" value="1" />
              <el-option label="摄像头2" value="2" />
              <el-option label="摄像头3" value="3" />
              <el-option label="摄像头4" value="4" />
            </el-select>
            <el-button type="success" @click="onComplete">完成巡检</el-button>
            <el-button type="danger" @click="onAbort">终止巡检</el-button>
          </div>
        </el-card>

        <!-- 车辆状态卡片 -->
        <el-card class="task-aside-card mb10" shadow="never">
          <template #header>
            <div class="card-header-row">
              <span>车辆状态</span>
              <el-button-group>
                <el-button
                  :type="moveDirection === 'backward' ? 'warning' : 'default'"
                  @mousedown="onMoveChange('backward')"
                  @mouseup="onMoveChange('stop')"
                  @mouseleave="onMoveChange('stop')"
                  size="small"
                >后退</el-button>

                <el-button
                  :type="moveDirection === 'stop' ? 'danger' : 'default'"
                  @click="onMoveChange('stop')"
                  size="small"
                >停止</el-button>

                <el-button
                  :type="moveDirection === 'forward' ? 'success' : 'default'"
                  @mousedown="onMoveChange('forward')"
                  @mouseup="onMoveChange('stop')"
                  @mouseleave="onMoveChange('stop')"
                  size="small"
                >前进</el-button>
              </el-button-group>
            </div>
          </template>
          <el-descriptions :column="1" border>
            <el-descriptions-item>
              <template #label><el-icon><Document /></el-icon> 巡视任务编号</template>
              {{ taskInfo.taskCode }}
            </el-descriptions-item>
            <el-descriptions-item>
              <template #label><el-icon><Clock /></el-icon> 车辆系统时间</template>
              {{ taskInfo.systemTime }}
            </el-descriptions-item>
            <el-descriptions-item>
              <template #label><el-icon><LocationFilled /></el-icon> 已行驶距离</template>
              <span>{{ taskInfo.distance }}</span> 米
            </el-descriptions-item>
            <el-descriptions-item>
              <template #label><el-icon><WarningFilled /></el-icon> 故障总计</template>
              {{ taskInfo.totalFlaws }}
            </el-descriptions-item>
            <el-descriptions-item>
              <template #label><el-icon><SuccessFilled /></el-icon> 已确定故障</template>
              <span class="confirmed-flaw">{{ taskInfo.confirmedFlaws }}</span>
            </el-descriptions-item>
            <el-descriptions-item>
              <template #label><el-icon><QuestionFilled /></el-icon> 疑似故障</template>
              <span class="unconfirmed-flaw">{{ taskInfo.unconfirmedFlaws }}</span>
            </el-descriptions-item>
          </el-descriptions>
        </el-card>

        <!-- 故障历史卡片 -->
        <el-card class="task-aside-card mb10" shadow="never">
          <template #header>
            <span>故障历史</span>
          </template>
          <el-table :data="flawList" border style="width: 100%">
            <el-table-column prop="flawName" label="故障名称" width="120" />
            <el-table-column prop="flawType" label="故障类型" width="100" />
            <el-table-column prop="flawDistance" label="距离(m)" width="90" />
            <template #empty>
              <span style="color: #909399">暂无数据</span>
            </template>
          </el-table>
        </el-card>
      </el-aside>
    </el-container>

    <!-- ========== 故障详情弹窗 ========== -->
    <el-dialog v-model="flawDialogVisible" title="故障详情" width="1150px" top="15vh">
      <div class="flaw-detail-content">
        <p>故障详情内容待填充……</p>
      </div>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="flawDialogVisible = false">取 消</el-button>
          <el-button type="primary" @click="flawDialogVisible = false">确 定</el-button>
        </span>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, onUnmounted, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  Document,
  Clock,
  LocationFilled,
  WarningFilled,
  SuccessFilled,
  QuestionFilled,
} from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'

// -------------------- 路由参数 --------------------
const route = useRoute()
const router = useRouter()
const taskId = ref(route.query.id || '')
const taskCode = ref(route.query.taskCode || '')

// -------------------- 视频播放器 --------------------

// ---- 变量 ----
const videoRef = ref(null)        // 替代 playerRef
const currentCamera = ref('1')
const playerType = ref('flv')      // ★ 'flv' | 'easyplayer'
let flvPlayer = null              // 替代 playerInstance
const videoOverlay = ref('--')    // 新增：显示速率/分辨率

// ---- 摄像头 FLV 地址（直连巡检车） ----
const camUrls = {
  '1': 'http://192.168.2.57/webrtc-api/live/PbemokuspQHD5_01.flv',
  '2': 'http://192.168.2.57/webrtc-api/live/Psh0GyTpkiSdC_01.flv',
  '3': 'http://192.168.2.57/webrtc-api/live/Pk8FmQHNeOqSx_01.flv',
  '4': 'http://192.168.2.57/webrtc-api/live/PaKHUtvPpcrZq_01.flv',
}

// ---- EasyPlayer 相关 ----
const easyPlayerContainer = ref(null)   // EasyPlayer 容器
let easyPlayerInstance = null           // EasyPlayer 实例

// EasyPlayer 摄像头 ID（巡检车服务器设备 ID）
const easyCamIds = {
  '1': 'PbemokuspQHD5',
  '2': 'Psh0GyTpkiSdC',
  '3': 'Pk8FmQHNeOqSx',
  '4': 'PaKHUtvPpcrZq',
}

// ---- 连接函数（替代 initPlayer）----
function connectFlv(url) {
  // 1. 销毁旧实例
  if (flvPlayer) { try { flvPlayer.destroy() } catch(e) {} flvPlayer = null }

  const video = videoRef.value
  if (!video) return

  // 2. 检查 MSE 支持
  if (typeof mpegts === 'undefined' || !mpegts.isSupported()) {
    console.error('MSE 不支持')
    return
  }

  // 3. 创建 mpegts 播放器
  const t0 = Date.now()
  flvPlayer = mpegts.createPlayer({
    type: 'flv', isLive: true, url,
    hasAudio: false, hasVideo: true,
    enableStashBuffer: false
  })

  // 4. 事件：连接成功
  flvPlayer.on(mpegts.Events.MEDIA_INFO, () => {
    console.log('FLV 已连接 (' + ((Date.now()-t0)/1000).toFixed(1) + 's)')
  })

  // 5. 事件：实时速率（叠加到视频左上角）
  flvPlayer.on(mpegts.Events.STATISTICS_INFO, (s) => {
    const spd = (s.speed||0) >= 1000
      ? ((s.speed||0)/1000).toFixed(1) + 'MB/s'
      : (s.speed||0).toFixed(0) + 'KB/s'
    videoOverlay.value = spd + ' | ' + (video.videoWidth||0) + 'x' + (video.videoHeight||0)
  })

  // 6. 事件：错误
  flvPlayer.on(mpegts.Events.ERROR, (type, info) => {
    console.error('FLV 错误:', type, info)
  })

  // 7. 挂载并加载
  flvPlayer.attachMediaElement(video)
  flvPlayer.load()
}

// ---- EasyPlayer 连接函数（新技术） ----
async function connectEasyPlayer(camNum) {
  // 1. 销毁旧实例
  if (easyPlayerInstance) { try { easyPlayerInstance.destroy() } catch(e) {} easyPlayerInstance = null }

  // 2. 等 Vue DOM 更新（:key 切换会重建容器）
  await nextTick()

  const container = easyPlayerContainer.value
  if (!container) { console.error('EasyPlayer 容器未找到'); return }

  // 3. 确保 EasyPlayer 全局可用
  const EasyPlayer = window.EasyPlayerPro || window['EasyPlayer-pro']
  if (!EasyPlayer) {
    console.error('EasyPlayer 未加载')
    videoOverlay.value = 'EasyPlayer 未加载'
    return
  }

  // 4. 构造播放器（原版方式：不传 url）
  const player = new EasyPlayer(container, {
    isLive: true,
    bufferTime: 0.2,
    stretch: true,
    MSE: false,
    WCS: false,
    hasAudio: true,
  })
  easyPlayerInstance = player

  // 5. 播放
  const deviceId = easyCamIds[camNum]
  const url = 'http://192.168.2.57/webrtc-api/live/' + deviceId + '_01.flv'

  try {
    await player.play(url)
    console.log('EasyPlayer 已连接 cam' + camNum)
  } catch (err) {
    console.error('EasyPlayer play 失败:', err)
    videoOverlay.value = 'EasyPlayer 播放失败'
  }
}

async function onPlayerTypeChange() {
  // 销毁旧播放器
  if (flvPlayer) { try { flvPlayer.destroy() } catch(e) {} flvPlayer = null }
  if (easyPlayerInstance) { try { easyPlayerInstance.destroy() } catch(e) {} easyPlayerInstance = null }
  videoOverlay.value = '--'
  // 短暂延迟确保 DOM 更新
  await nextTick()
  // 用新模式重连当前摄像头
  onCameraChange(currentCamera.value)
}

function onCameraChange(val) {
  if (playerType.value === 'easyplayer') {
    connectEasyPlayer(val)
  } else {
    const url = camUrls[val]
    if (url) connectFlv(url)
  }
}

// -------------------- 车辆状态 --------------------
const moveDirection = ref('stop')  // 'backward' | 'stop' | 'forward'

const taskInfo = reactive({
  taskCode: '---',
  systemTime: '---',
  distance: '0.00',
  totalFlaws: 0,
  confirmedFlaws: 0,
  unconfirmedFlaws: 0,
})

const totalDistance = ref(100)
const progressPercent = ref(0)

// -------------------- 故障历史 --------------------
const flawList = ref([])
const flawDialogVisible = ref(false)

// -------------------- 按钮操作 --------------------
async function onComplete() {
  try {
    await ElMessageBox.confirm('确认完成本次巡检？巡检数据将被保存。', '提示', {
      confirmButtonText: '确定完成',
      cancelButtonText: '取消',
      type: 'warning',
    })
  } catch { return }

  try {
    const res = await fetch(API + '/agv/task/end/' + taskId.value + '?isAbort=false', { method: 'POST' })
    const data = await res.json()
    if (data.code === 200 || data.code === 0) {
      ElMessage.success('巡检已完成')
      cleanupAndLeave()
    } else {
      ElMessage.error(data.msg || '操作失败')
    }
  } catch (e) {
    ElMessage.error('网络错误，操作失败')
  }
}

async function onAbort() {
  try {
    await ElMessageBox.confirm('确认中止本次巡检？任务将退出巡视状态，不会标记为完成。', '提示', {
      confirmButtonText: '确定中止',
      cancelButtonText: '取消',
      type: 'warning',
    })
  } catch { return }

  try {
    const res = await fetch(API + '/agv/task/end/' + taskId.value + '?isAbort=true', { method: 'POST' })
    const data = await res.json()
    if (data.code === 200 || data.code === 0) {
      ElMessage.success('巡检已中止')
      cleanupAndLeave()
    } else {
      ElMessage.error(data.msg || '操作失败')
    }
  } catch (e) {
    ElMessage.error('网络错误，操作失败')
  }
}

function cleanupAndLeave() {
  if (timer) clearInterval(timer)
  if (flvPlayer) { try { flvPlayer.destroy() } catch(e) {} flvPlayer = null }
  if (easyPlayerInstance) { try { easyPlayerInstance.destroy() } catch(e) {} easyPlayerInstance = null }
  router.push('/taskList')
}

const API = 'http://192.168.2.57/prod-api'
let stopDebounce = 0
function onMoveChange(action) {
  // 方向反转防抖：停止后等 300ms 才能切方向
  if (action !== 'stop' && stopDebounce > 0) {
    const elapsed = Date.now() - stopDebounce
    if (elapsed < 300) {
      setTimeout(() => onMoveChange(action), 300 - elapsed)
      return
    }
  }

  if (action === 'stop') {
    stopDebounce = Date.now()
  } else {
    stopDebounce = 0
  }

  moveDirection.value = action

  const endpoint = action === 'forward' ? '/agv/movement/forward'
    : action === 'backward' ? '/agv/movement/backward'
    : '/agv/movement/stop'

  fetch(API + endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json' } })
    .then(res => res.json())
    .then(data => {
      if (data.code === 200 || data.code === 0) {
        console.log('指令成功:', action)
      } else {
        console.error('指令失败:', data.msg)
      }
    })
    .catch(e => console.error('网络错误:', e))
}

// -------------------- 定时刷新数据 --------------------
let timer = null

async function fetchTaskData() {
  try {
    const res = await fetch(API + '/agv/movement/heartbeat')
    const data = await res.json()
    if (data.code === 200 || data.code === 0) {
      const s = data.data || {}
      taskInfo.systemTime = s.sysTime || '--'
      taskInfo.distance = (s.currentPosition || 0).toFixed(2)
      progressPercent.value = (s.currentPosition || 0) / totalDistance.value * 100
    }
  } catch (e) {
    console.error('获取状态失败:', e)
  }
}

async function fetchFlawStats() {
  if (!taskId.value) return
  try {
    const res = await fetch(API + '/agv/flaw/list?taskId=' + taskId.value + '&pageNum=1&pageSize=999')
    const data = await res.json()
    if (data.code === 200 || data.code === 0) {
      // 服务端不支持 taskId 过滤，客户端自行过滤
      const rows = (data.rows || []).filter(f => f.taskId === Number(taskId.value))
      flawList.value = rows
      taskInfo.totalFlaws = rows.length
      taskInfo.confirmedFlaws = rows.filter(f => f.confirmed).length
      taskInfo.unconfirmedFlaws = rows.filter(f => !f.confirmed).length
    }
  } catch (e) {
    console.error('获取缺陷统计失败:', e)
  }
}

// -------------------- 生命周期 --------------------
onMounted(() => {
  taskInfo.taskCode = taskCode.value || '---'
  fetchTaskData()
  fetchFlawStats()
  onCameraChange('1')
  // 每2秒刷新车辆状态 + 缺陷统计
  timer = setInterval(() => { fetchTaskData(); fetchFlawStats() }, 2000)
})

onUnmounted(() => {
  if (timer) clearInterval(timer)
  if (flvPlayer) { try { flvPlayer.destroy() } catch (e) { /* ignore */ } }
  if (easyPlayerInstance) { try { easyPlayerInstance.destroy() } catch (e) { /* ignore */ } }
})
</script>

<style scoped>
/* ========== 整体布局 ========== */
.app-container {
  height: 100vh;
  display: flex;
  flex-direction: column;
  background: #f0f2f5;
  overflow: hidden;
}

.breadcrumb {
  padding: 12px 20px;
  background: #fff;
  flex-shrink: 0;
}

.task-body {
  flex: 1;
  overflow: hidden;
}

/* ========== 左侧：视频区 ========== */
.task-main-vertical {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.task-main {
  flex: 1;
  padding: 12px;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.video-stream {
  flex: 1;
  background: #000;
  border-radius: 6px;
  min-height: 400px;
  position: relative;
}

.video-overlay {
  position: absolute;
  top: 8px;
  left: 8px;
  background: rgba(0, 0, 0, 0.7);
  color: #58a6ff;
  padding: 3px 8px;
  border-radius: 4px;
  font-size: 10px;
  font-family: Consolas, monospace;
  pointer-events: none;
}

.camera-switch-bar {
  display: flex;
  justify-content: center;
  padding: 10px 0 4px;
}

/* ========== 底部比例尺 ========== */
.task-footer {
  display: flex;
  align-items: center;
  padding: 0 30px;
  background: #fff;
  border-top: 1px solid #e4e7ed;
}

.scale-bar-wrapper {
  position: relative;
  width: 100%;
  height: 20px;
}

.scale-bar {
  width: 100%;
  height: 4px;
  background: #dcdfe6;
  border-radius: 2px;
  position: absolute;
  top: 8px;
}

.scale-bar-progress {
  height: 4px;
  background: #409eff;
  border-radius: 2px;
  position: absolute;
  top: 8px;
  left: 0;
  transition: width 0.3s ease;
}

.scale-bar-text {
  position: absolute;
  top: -12px;
  font-size: 11px;
  color: #909399;
}

.scale-bar-text.end {
  right: 0;
}

.scale-bar-agv {
  position: absolute;
  top: 0;
  font-size: 20px;
  transition: left 0.3s ease;
}

/* ========== 右侧面板 ========== */
.task-aside {
  background: #f0f2f5;
  padding: 12px;
  overflow-y: auto;
}

.mb10 {
  margin-bottom: 10px;
}

.card-header-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.control-btns {
  display: flex;
  justify-content: center;
  gap: 8px;
  flex-wrap: wrap;
}

.confirmed-flaw {
  color: #f56c6c;
  font-weight: bold;
}

.unconfirmed-flaw {
  color: #e6a23c;
  font-weight: bold;
}
</style>
