<template>
  <div class="app-container">
    <el-breadcrumb separator="/" class="breadcrumb">
      <el-breadcrumb-item :to="{ path: '/' }">地铁隧道巡线车智能巡检系统</el-breadcrumb-item>
      <el-breadcrumb-item :to="{ path: '/taskList' }">任务列表</el-breadcrumb-item>
      <el-breadcrumb-item>任务巡视</el-breadcrumb-item>
    </el-breadcrumb>

    <el-container class="task-body">
      <el-container class="task-main-vertical">
        <el-main class="task-main">
          <div class="video-stream">
            <video
              v-if="playerType === 'flv'"
              ref="videoRef"
              autoplay
              playsinline
              :muted="muted"
              style="width:100%;height:100%;object-fit:contain"
            ></video>
            <div
              v-else
              ref="easyPlayerContainer"
              :key="'ep-' + currentCamera"
              style="width:100%;height:100%"
            ></div>

            <div v-if="videoOverlay !== '--'" class="video-overlay">{{ videoOverlay }}</div>

            <div class="audio-bar">
              <el-button size="small" circle @click="toggleMute">{{ muted ? '🔇' : '🔊' }}</el-button>
              <el-slider
                v-model="volume"
                :min="0"
                :max="100"
                size="small"
                style="width: 140px"
                @input="applyVolume"
              />
            </div>
          </div>

          <div class="camera-switch-bar">
            <el-radio-group v-model="currentCamera" @change="onCameraChange">
              <el-radio-button value="1">摄像头1</el-radio-button>
              <el-radio-button value="2">摄像头2</el-radio-button>
              <el-radio-button value="3">摄像头3</el-radio-button>
              <el-radio-button value="4">摄像头4</el-radio-button>
            </el-radio-group>
          </div>
        </el-main>

        <el-footer class="task-footer" height="90px">
          <div class="scale-bar-wrapper">
            <span class="scale-bar-text start">0m</span>
            <span class="scale-bar-text end">{{ totalDistance }}m</span>

            <div class="scale-bar">
              <div class="scale-bar-progress" :style="{ width: progressPercent + '%' }"></div>
            </div>

            <div
              v-for="flaw in flawMarkers"
              :key="flaw.id"
              :class="['scale-bar-item', flaw.confirmed ? 'scale-bar-flaw' : 'scale-bar-flaw unconfirmed']"
              :style="{ left: flaw.left + '%' }"
              :title="flaw.flawName || '缺陷'"
              @click="openFlawDetail(flaw)"
            >
              📍
            </div>

            <div class="scale-bar-item scale-bar-agv" :style="{ left: progressPercent + '%' }" title="当前位置">
              🚛
            </div>
          </div>
        </el-footer>
      </el-container>

      <el-aside width="360px" class="task-aside">
        <el-card class="mb10" shadow="never">
          <template #header>
            <div class="card-header-row">
              <span>控制台</span>
              <el-switch v-model="autoRefresh" />
            </div>
          </template>

          <div class="control-btns">
            <el-button @click="refreshMonitor">刷新监控</el-button>

            <el-radio-group v-model="playerType" @change="onPlayerTypeChange" size="small">
              <el-radio-button value="flv">FLV</el-radio-button>
              <el-radio-button value="easyplayer">EasyPlayer</el-radio-button>
            </el-radio-group>

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

        <el-card class="mb10" shadow="never">
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
              {{ taskInfo.distance }} 米
            </el-descriptions-item>
            <el-descriptions-item>
              <template #label><el-icon><WarningFilled /></el-icon> 故障总计</template>
              {{ taskInfo.totalFlaws }}
            </el-descriptions-item>
            <el-descriptions-item>
              <template #label><el-icon><SuccessFilled /></el-icon> 已确认故障</template>
              <span class="confirmed-flaw">{{ taskInfo.confirmedFlaws }}</span>
            </el-descriptions-item>
            <el-descriptions-item>
              <template #label><el-icon><QuestionFilled /></el-icon> 疑似故障</template>
              <span class="unconfirmed-flaw">{{ taskInfo.unconfirmedFlaws }}</span>
            </el-descriptions-item>
          </el-descriptions>
        </el-card>

        <el-card class="mb10" shadow="never">
          <template #header>
            <span>故障历史</span>
          </template>

          <el-table :data="flawList" border style="width: 100%" @row-click="openFlawDetail">
            <el-table-column prop="flawName" label="故障名称" min-width="120" show-overflow-tooltip />
            <el-table-column prop="flawType" label="故障类型" width="100" show-overflow-tooltip />
            <el-table-column prop="flawDistance" label="距离(m)" width="90" />
            <template #empty>
              <span style="color: #909399">暂无数据</span>
            </template>
          </el-table>
        </el-card>
      </el-aside>
    </el-container>

    <el-dialog v-model="flawDialogVisible" title="故障详情" width="1150px" top="8vh">
      <div v-if="currentFlaw" class="flaw-detail-layout">
        <div class="flaw-image-panel">
          <img
            v-if="currentFlawImageUrl"
            :src="currentFlawImageUrl"
            class="flaw-image"
            alt="故障现场照片"
          />
          <div v-else class="flaw-image-placeholder">暂无故障图片</div>
        </div>

        <div class="flaw-info-panel">
          <el-descriptions :column="1" border size="small">
            <el-descriptions-item label="名称">{{ currentFlaw.flawName || '--' }}</el-descriptions-item>
            <el-descriptions-item label="类型">{{ currentFlaw.flawType || '--' }}</el-descriptions-item>
            <el-descriptions-item label="描述">{{ currentFlaw.flawDesc || '--' }}</el-descriptions-item>
            <el-descriptions-item label="位置">{{ formatDistance(currentFlaw.flawDistance) }}</el-descriptions-item>
            <el-descriptions-item label="等级">{{ currentFlaw.level || '--' }}</el-descriptions-item>
            <el-descriptions-item label="长度">{{ formatMeasure(currentFlaw.flawLength, 'm') }}</el-descriptions-item>
            <el-descriptions-item label="面积">{{ formatMeasure(currentFlaw.flawArea, 'm²') }}</el-descriptions-item>
            <el-descriptions-item label="数量">{{ currentFlaw.countNum ?? '--' }}</el-descriptions-item>
            <el-descriptions-item label="发现时间">{{ currentFlaw.createTime || '--' }}</el-descriptions-item>
          </el-descriptions>

          <div class="flaw-form-block">
            <div class="flaw-form-label">是否属实</div>
            <el-radio-group v-model="flawForm.confirmed">
              <el-radio :value="true">是</el-radio>
              <el-radio :value="false">否</el-radio>
            </el-radio-group>
          </div>

          <div class="flaw-form-block">
            <div class="flaw-form-label">补充说明</div>
            <el-input
              v-model="flawForm.remark"
              type="textarea"
              :rows="4"
              maxlength="500"
              show-word-limit
              placeholder="请输入补充说明"
            />
          </div>

          <div class="flaw-form-block">
            <div class="ai-action-row">
              <el-button type="primary" :loading="aiLoading" @click="analyzeFlawWithDify">
                {{ aiLoading ? 'AI 分析中...' : 'AI 分析' }}
              </el-button>
              <span class="ai-action-tip">基于 Dify 对当前缺陷做辅助分析</span>
            </div>
          </div>

          <div v-if="aiError" class="flaw-form-block">
            <el-alert :title="aiError" type="error" :closable="false" show-icon />
          </div>

          <div v-if="aiResult" class="ai-analysis-section">
            <div class="ai-analysis-header">
              <span class="ai-icon">🤖</span>
              <span>AI 智能分析结果</span>
            </div>

            <template v-if="aiResult.isPlainAnswer">
              <div class="ai-field">
                <div class="ai-field-label">AI 分析回答</div>
                <div class="ai-field-value answer-text">{{ aiResult.answer || '--' }}</div>
              </div>
            </template>

            <template v-else>
              <div class="ai-field">
                <div class="ai-field-label">严重程度</div>
                <div class="ai-field-value">
                  <span :class="severityClass(aiResult.severity)">
                    {{ aiResult.severity || '--' }}{{ aiResult.severity_label ? '（' + aiResult.severity_label + '）' : '' }}
                  </span>
                </div>
              </div>

              <div v-if="aiResult.cause_analysis" class="ai-field">
                <div class="ai-field-label">成因分析</div>
                <div class="ai-field-value answer-text">{{ aiResult.cause_analysis }}</div>
              </div>

              <div v-if="aiResult.risk_assessment" class="ai-field">
                <div class="ai-field-label">风险评估</div>
                <div class="ai-field-value answer-text">{{ aiResult.risk_assessment }}</div>
              </div>

              <div v-if="aiResult.repair_suggestion" class="ai-field">
                <div class="ai-field-label">维修建议</div>
                <div class="ai-field-value answer-text">{{ aiResult.repair_suggestion }}</div>
              </div>

              <div v-if="aiResult.reference_standards" class="ai-field">
                <div class="ai-field-label">参考标准</div>
                <div class="ai-field-value answer-text">{{ aiResult.reference_standards }}</div>
              </div>
            </template>

            <div class="ai-field meta">
              <div class="ai-field-label">Dify 应用</div>
              <div class="ai-field-value meta-text">故障解读助手 (App: {{ DIFY_CONFIG.appId }})</div>
            </div>

            <div v-if="aiResult.conversation_id" class="ai-field meta">
              <div class="ai-field-label">会话 ID</div>
              <div class="ai-field-value meta-text">{{ aiResult.conversation_id }}</div>
            </div>
          </div>
        </div>
      </div>

      <template #footer>
        <el-button @click="flawDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="saveFlawDetail">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { computed, nextTick, onMounted, onUnmounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  Clock,
  Document,
  LocationFilled,
  QuestionFilled,
  SuccessFilled,
  WarningFilled,
} from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'

const route = useRoute()
const router = useRouter()

const BACKEND_ORIGIN = 'http://192.168.2.57'
const LOCAL_STREAM_ORIGIN = 'http://127.0.0.1:8088'

function resolveServiceUrl(base, fallbackPath) {
  const raw = base || fallbackPath
  if (/^https?:\/\//i.test(raw)) return raw
  return BACKEND_ORIGIN + raw
}

const API = resolveServiceUrl(import.meta.env.VITE_API_BASE, '/prod-api')
const IMG_BASE = resolveServiceUrl(import.meta.env.VITE_IMG_BASE, '/prod-api/file')
const RTC_BASE = resolveServiceUrl(import.meta.env.VITE_RTC_BASE, '/webrtc-api')
const EASY_API = resolveServiceUrl(import.meta.env.VITE_EASY_API_BASE, '/easy-api')
const EASY_AUTH = import.meta.env.VITE_EASY_AUTH || 'Basic YWRtaW4xMjM6QWRtaW5AMTIz'
const EASY_PLAYER_LIB_URL = BACKEND_ORIGIN + '/easyplayer/EasyPlayer-lib.js'

const taskId = ref(route.query.id || '')
const taskCode = ref(route.query.taskCode || '')

const videoRef = ref(null)
const easyPlayerContainer = ref(null)
const currentCamera = ref('1')
const playerType = ref('flv')
const videoOverlay = ref('--')
const muted = ref(true)
const volume = ref(0)
const autoRefresh = ref(true)
const moveDirection = ref('stop')

const taskInfo = reactive({
  id: '',
  taskCode: '---',
  taskName: '---',
  taskTrip: '100',
  systemTime: '---',
  distance: '0.00',
  totalFlaws: 0,
  confirmedFlaws: 0,
  unconfirmedFlaws: 0,
})

const totalDistance = ref(100)
const progressPercent = ref(0)

const flawList = ref([])
const currentFlaw = ref(null)
const flawDialogVisible = ref(false)
const flawForm = reactive({
  confirmed: false,
  remark: '',
})
const aiLoading = ref(false)
const aiError = ref('')
const aiResult = ref(null)

const cameraDevices = ref([])
const agvConfig = ref({})

let flvPlayer = null
let easyPlayerInstance = null
let timer = null
let liveFlawPolling = false
let stopDebounce = 0
let easyPlayerLoadPromise = null

const DIFY_CONFIG = {
  appId: import.meta.env.VITE_DIFY_APP_ID || 'ab90ca0c-95b9-4cbb-9f24-97166e6c5032',
  apiKey: import.meta.env.VITE_DIFY_API_KEY || 'app-ix0KtVqKKJIJ8Jk5t2bkotVa',
  apiUrl: import.meta.env.VITE_DIFY_API_URL || 'http://192.168.2.53/v1/chat-messages',
  user: import.meta.env.VITE_DIFY_USER || 'inspector-001',
  timeoutMs: Number(import.meta.env.VITE_DIFY_TIMEOUT_MS || 120000),
  useMockOnFailure: String(import.meta.env.VITE_DIFY_USE_MOCK || 'false') === 'true',
}

const flawMarkers = computed(() => {
  const distanceTotal = totalDistance.value > 0 ? totalDistance.value : 1
  return flawList.value
    .filter(item => item && item.flawDistance != null)
    .map(item => {
      const left = Math.max(0, Math.min(100, (Number(item.flawDistance || 0) / distanceTotal) * 100))
      return { ...item, left }
    })
})

const currentFlawImageUrl = computed(() => {
  if (!currentFlaw.value) return ''
  return normalizeImageUrl(currentFlaw.value)
})

function normalizeImageUrl(flaw) {
  const raw = flaw?.flawImageUrl || flaw?.flawImage || ''
  if (!raw) return ''
  if (/^https?:\/\//i.test(raw)) return raw
  return IMG_BASE + raw
}

function formatDistance(value) {
  if (value == null || value === '') return '--'
  return value + ' m'
}

function formatMeasure(value, unit) {
  if (value == null || value === '') return '--'
  return value + ' ' + unit
}

function severityClass(severity) {
  if (severity === '高') return 'ai-severity-high'
  if (severity === '中') return 'ai-severity-medium'
  return 'ai-severity-low'
}

function resetAiAnalysis() {
  aiLoading.value = false
  aiError.value = ''
  aiResult.value = null
}

function normalizeFlawForDify(flaw) {
  return {
    flawType: flaw?.flawType || flaw?.type || '',
    flawLevel: flaw?.flawLevel || flaw?.level || '未知',
    flawArea: Number(flaw?.flawArea || flaw?.area || 0),
    flawLength: Number(flaw?.flawLength || flaw?.length || 0),
    flawDistance: Number(flaw?.flawDistance || 0),
  }
}

function cleanDifyAnswer(answer) {
  return String(answer || '').replace(/<think>[\s\S]*?<\/think>/gi, '').trim()
}

function tryParseJSON(text) {
  if (!text) return null
  try {
    return JSON.parse(text)
  } catch {
    const match = text.match(/```(?:json)?\s*\n?([\s\S]*?)\n?```/)
    if (!match) return null
    try {
      return JSON.parse(match[1])
    } catch {
      return null
    }
  }
}

function parseDifyChatResponse(data, flaw) {
  const answerText = cleanDifyAnswer(data?.answer || '')
  const parsed = tryParseJSON(answerText)

  if (parsed) {
    return {
      isReal: true,
      severity: parsed.severity || parsed['严重程度'] || (flaw?.confirmed ? '高' : '中'),
      severity_label: parsed.severity_label || parsed['严重等级'] || (flaw?.confirmed ? '严重' : '需关注'),
      cause_analysis: parsed.cause_analysis || parsed['成因分析'] || '',
      risk_assessment: parsed.risk_assessment || parsed['风险评估'] || '',
      repair_suggestion: parsed.repair_suggestion || parsed['维修建议'] || '',
      reference_standards: parsed.reference_standards || parsed['参考标准'] || '',
      conversation_id: data?.conversation_id || '',
    }
  }

  return {
    isReal: true,
    isPlainAnswer: true,
    severity: flaw?.confirmed ? '高' : '中',
    severity_label: flaw?.confirmed ? '严重' : '需关注',
    answer: answerText,
    conversation_id: data?.conversation_id || '',
  }
}

function generateMockDifyResponse(flaw) {
  if (flaw?.flawName?.includes('裂缝')) {
    return {
      severity: '高',
      severity_label: '严重',
      cause_analysis: '该缺陷更像结构性裂缝，可能与混凝土收缩、围岩压力变化或施工缝处理有关。',
      risk_assessment: '若持续发展，可能带来结构完整性下降、渗漏加重和后续剥落风险。',
      repair_suggestion: '建议尽快安排人工复核，并结合注浆封闭、裂缝监测和局部加固方案处理。',
      reference_standards: '《铁路隧道养护技术规范》\n《混凝土结构加固设计规范》',
    }
  }

  return {
    severity: '中',
    severity_label: '需关注',
    cause_analysis: '该缺陷可能与局部渗漏、防水层破损或接缝密封失效相关。',
    risk_assessment: '短期风险中等，但长期可能导致腐蚀、冻胀或附属设备受潮。',
    repair_suggestion: '建议核查水源路径，必要时采用封堵或注浆方案，并记录复检结果。',
    reference_standards: '《地下工程防水技术规范》\n《铁路隧道养护技术规范》',
  }
}

async function analyzeFlawWithDify() {
  if (!currentFlaw.value) return

  aiLoading.value = true
  aiError.value = ''
  aiResult.value = null

  const controller = typeof AbortController !== 'undefined' ? new AbortController() : null
  const timerId = controller ? setTimeout(() => controller.abort(), DIFY_CONFIG.timeoutMs) : null

  try {
    const body = {
      inputs: normalizeFlawForDify(currentFlaw.value),
      query: '请分析这条地铁隧道巡检缺陷数据。',
      response_mode: 'blocking',
      conversation_id: '',
      user: DIFY_CONFIG.user,
    }

    const res = await fetch(DIFY_CONFIG.apiUrl, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer ' + DIFY_CONFIG.apiKey,
        'Content-Type': 'application/json; charset=utf-8',
      },
      signal: controller?.signal,
      body: JSON.stringify(body),
    })

    if (timerId) clearTimeout(timerId)
    if (!res.ok) throw new Error('HTTP ' + res.status + ' ' + res.statusText)

    const data = await res.json()
    aiResult.value = parseDifyChatResponse(data, currentFlaw.value)
  } catch (err) {
    if (timerId) clearTimeout(timerId)
    if (DIFY_CONFIG.useMockOnFailure) {
      aiResult.value = generateMockDifyResponse(currentFlaw.value)
    } else {
      aiError.value = err?.name === 'AbortError'
        ? '请求超时：Dify/本地模型超过 ' + Math.round(DIFY_CONFIG.timeoutMs / 1000) + ' 秒未返回。'
        : 'AI 分析失败：' + (err?.message || String(err))
    }
  } finally {
    aiLoading.value = false
  }
}

async function loadTaskDetail() {
  try {
    const res = await fetch(API + '/agv/task/' + taskId.value)
    const data = await res.json()
    if (data.code === 200 || data.code === 0) {
      const task = data.data || data
      taskInfo.id = task.id || ''
      taskInfo.taskCode = task.taskCode || taskCode.value || '---'
      taskInfo.taskName = task.taskName || '---'
      taskInfo.taskTrip = task.taskTrip || '100'
      const trip = Number(task.taskTrip || 100)
      totalDistance.value = Number.isFinite(trip) && trip > 0 ? trip : 100
    }
  } catch (e) {
    console.error('加载任务详情失败:', e)
  }
}

async function loadConfig() {
  try {
    const res = await fetch(API + '/agv/config')
    const data = await res.json()
    if (data.code === 200 || data.code === 0) {
      agvConfig.value = data.data || {}
    }
  } catch (e) {
    console.warn('加载系统配置失败:', e)
  }
}

async function loadCameraDevices() {
  try {
    const res = await fetch(EASY_API + '/devices?page=1&size=999&status=&id&name', {
      headers: {
        Authorization: EASY_AUTH,
      },
    })
    const data = await res.json()
    cameraDevices.value = data.items || data.list || data.data?.items || data.data?.list || data.data || []
  } catch (e) {
    console.warn('加载摄像头列表失败:', e)
  }
}

function buildFlvUrl(cameraNo) {
  const index = Number(cameraNo) - 1
  const device = cameraDevices.value[index]
  if (device?.id) {
    return RTC_BASE + '/live/' + device.id + '_01.flv'
  }

  const configUrl = agvConfig.value['cam' + cameraNo]
  if (configUrl) return configUrl

  return RTC_BASE + '/live/cam' + cameraNo + '_01.flv'
}

function buildRelayFlvUrl(cameraNo) {
  return LOCAL_STREAM_ORIGIN + '/flv/cam' + cameraNo
}

function loadScript(src) {
  return new Promise((resolve, reject) => {
    const script = document.createElement('script')
    script.src = src
    script.onload = resolve
    script.onerror = reject
    document.head.appendChild(script)
  })
}

async function ensureEasyPlayerLoaded() {
  if (window.EasyPlayerPro || window['EasyPlayer-pro']) return
  if (!easyPlayerLoadPromise) {
    easyPlayerLoadPromise = loadScript(EASY_PLAYER_LIB_URL)
  }
  await easyPlayerLoadPromise
}

function destroyPlayers() {
  if (flvPlayer) {
    try { flvPlayer.destroy() } catch (e) { /* ignore */ }
    flvPlayer = null
  }
  if (easyPlayerInstance) {
    try { easyPlayerInstance.destroy() } catch (e) { /* ignore */ }
    easyPlayerInstance = null
  }
}

function applyVolume() {
  const video = videoRef.value
  if (video) {
    video.volume = volume.value / 100
    video.muted = muted.value
  }
  if (easyPlayerInstance) {
    try {
      easyPlayerInstance.volume(volume.value / 100)
      easyPlayerInstance.muted(muted.value)
    } catch (e) {
      console.warn('设置音量失败:', e)
    }
  }
}

function toggleMute() {
  muted.value = !muted.value
  applyVolume()
}

function connectFlv(cameraNo) {
  destroyPlayers()

  const video = videoRef.value
  if (!video || typeof mpegts === 'undefined' || !mpegts.isSupported()) return
  const url = buildRelayFlvUrl(cameraNo)

  flvPlayer = mpegts.createPlayer({
    type: 'flv',
    isLive: true,
    url,
    hasAudio: false,
    hasVideo: true,
    enableStashBuffer: false,
    stashInitialSize: 128,
    lazyLoad: false,
  })

  flvPlayer.on(mpegts.Events.STATISTICS_INFO, stats => {
    const speed = Number(stats.speed || 0)
    const text = speed >= 1000 ? (speed / 1000).toFixed(1) + 'MB/s' : speed.toFixed(0) + 'KB/s'
    videoOverlay.value = text + ' | ' + (video.videoWidth || 0) + 'x' + (video.videoHeight || 0)
  })

  flvPlayer.on(mpegts.Events.MEDIA_INFO, () => {
    video.play().catch(err => {
      console.warn('video.play() 失败:', err)
    })
  })

  flvPlayer.on(mpegts.Events.ERROR, (type, info) => {
    console.error('FLV 错误:', type, info)
    videoOverlay.value = 'FLV 错误: ' + type
  })

  flvPlayer.attachMediaElement(video)
  flvPlayer.load()
  applyVolume()
}

async function connectEasyPlayer(cameraNo) {
  destroyPlayers()
  await nextTick()
  await ensureEasyPlayerLoaded()

  const container = easyPlayerContainer.value
  const EasyPlayer = window.EasyPlayerPro || window['EasyPlayer-pro']
  if (!container || !EasyPlayer) {
    videoOverlay.value = 'EasyPlayer 未加载'
    return
  }

  const url = buildFlvUrl(cameraNo)
  const player = new EasyPlayer({
    container,
    lang: 'zh',
  })
  easyPlayerInstance = player

  try {
    await player.play(url)
    videoOverlay.value = 'EasyPlayer'
    applyVolume()
  } catch (e) {
    console.error('EasyPlayer 播放失败:', e)
    videoOverlay.value = 'EasyPlayer 播放失败'
  }
}

async function onCameraChange(val) {
  if (playerType.value === 'easyplayer') {
    await connectEasyPlayer(val)
  } else {
    connectFlv(val)
  }
}

async function onPlayerTypeChange() {
  videoOverlay.value = '--'
  await nextTick()
  await onCameraChange(currentCamera.value)
}

function refreshMonitor() {
  onCameraChange(currentCamera.value)
}

async function onComplete() {
  try {
    await ElMessageBox.confirm('确认完成本次巡检？巡检数据将被保存。', '提示', {
      confirmButtonText: '确定完成',
      cancelButtonText: '取消',
      type: 'warning',
    })
  } catch {
    return
  }

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
  } catch {
    return
  }

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
  destroyPlayers()
  router.push('/taskList')
}

function onMoveChange(action) {
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

  const endpoint = action === 'forward'
    ? '/agv/movement/forward'
    : action === 'backward'
      ? '/agv/movement/backward'
      : '/agv/movement/stop'

  fetch(API + endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json' } })
    .then(res => res.json())
    .then(data => {
      if (!(data.code === 200 || data.code === 0)) {
        console.error('指令失败:', data.msg)
      }
    })
    .catch(e => console.error('网络错误:', e))
}

async function fetchTaskData() {
  try {
    const res = await fetch(API + '/agv/movement/heartbeat')
    const data = await res.json()
    if (data.code === 200 || data.code === 0) {
      const status = data.data || {}
      taskInfo.systemTime = status.sysTime || '--'
      taskInfo.distance = Number(status.currentPosition || 0).toFixed(2)
      progressPercent.value = Math.max(
        0,
        Math.min(100, (Number(status.currentPosition || 0) / (totalDistance.value || 1)) * 100),
      )
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
      const rows = (data.rows || []).filter(item => item.taskId === Number(taskId.value))
      flawList.value = rows
      taskInfo.totalFlaws = rows.length
      taskInfo.confirmedFlaws = rows.filter(item => item.confirmed).length
      taskInfo.unconfirmedFlaws = rows.filter(item => !item.confirmed).length

      if (currentFlaw.value) {
        const next = rows.find(item => item.id === currentFlaw.value.id)
        if (next) {
          currentFlaw.value = next
          flawForm.confirmed = !!next.confirmed
          flawForm.remark = next.remark || ''
        }
      }
    }
  } catch (e) {
    console.error('获取缺陷统计失败:', e)
  }
}

async function pollLiveFlaw() {
  if (!taskId.value || liveFlawPolling) return
  liveFlawPolling = true
  try {
    const res = await fetch(API + '/agv/flaw/live/' + taskId.value)
    const data = await res.json()
    if (data.code === 200 || data.code === 0 && data.data) {
      const liveFlaw = data.data
      if (liveFlaw && liveFlaw.id) {
        await fetchFlawStats()
        const latest = flawList.value.find(item => item.id === liveFlaw.id) || liveFlaw
        if (!latest.shown) {
          openFlawDetail(latest)
          try {
            await fetch(API + '/agv/flaw', {
              method: 'PUT',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ ...latest, shown: true }),
            })
          } catch (e) {
            console.warn('更新缺陷 shown 失败:', e)
          }
        }
      }
    }
  } catch (e) {
    console.warn('轮询实时缺陷失败:', e)
  } finally {
    liveFlawPolling = false
  }
}

function openFlawDetail(flaw) {
  if (!flaw) return
  currentFlaw.value = { ...flaw }
  flawForm.confirmed = !!flaw.confirmed
  flawForm.remark = flaw.remark || ''
  resetAiAnalysis()
  flawDialogVisible.value = true
}

async function saveFlawDetail() {
  if (!currentFlaw.value) return
  try {
    const payload = {
      ...currentFlaw.value,
      confirmed: flawForm.confirmed,
      remark: flawForm.remark,
    }
    const res = await fetch(API + '/agv/flaw', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    })
    const data = await res.json()
    if (data.code === 200 || data.code === 0) {
      ElMessage.success('故障状态已更新')
      flawDialogVisible.value = false
      await fetchFlawStats()
    } else {
      ElMessage.error(data.msg || '保存失败')
    }
  } catch (e) {
    ElMessage.error('网络错误，保存失败')
  }
}

onMounted(async () => {
  if (!taskId.value) {
    ElMessage.warning('缺少任务ID')
    router.push('/taskList')
    return
  }

  taskInfo.taskCode = taskCode.value || '---'
  await Promise.all([loadTaskDetail(), loadConfig(), loadCameraDevices()])
  await Promise.all([fetchTaskData(), fetchFlawStats()])
  await onCameraChange(currentCamera.value)

  timer = setInterval(async () => {
    if (!autoRefresh.value) return
    await fetchTaskData()
    await fetchFlawStats()
    await pollLiveFlaw()
  }, 2000)
})

onUnmounted(() => {
  if (timer) clearInterval(timer)
  destroyPlayers()
})
</script>

<style scoped>
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
  min-height: 420px;
  position: relative;
  overflow: hidden;
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
  z-index: 3;
}

.audio-bar {
  position: absolute;
  right: 12px;
  bottom: 12px;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  border-radius: 20px;
  background: rgba(0, 0, 0, 0.55);
  z-index: 3;
}

.camera-switch-bar {
  display: flex;
  justify-content: center;
  padding: 10px 0 4px;
}

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
  height: 60px;
}

.scale-bar {
  width: 100%;
  height: 8px;
  background: #dcdfe6;
  border-radius: 4px;
  position: absolute;
  top: 28px;
}

.scale-bar-progress {
  position: absolute;
  top: 28px;
  left: 0;
  height: 8px;
  background: #409eff;
  border-radius: 4px;
  transition: width 0.3s ease;
}

.scale-bar-text {
  position: absolute;
  top: 0;
  font-size: 12px;
  color: #666;
}

.scale-bar-text.start {
  left: 0;
}

.scale-bar-text.end {
  right: 0;
}

.scale-bar-item {
  position: absolute;
  top: 18px;
  width: 24px;
  height: 24px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  cursor: pointer;
  transform: translateX(-50%);
}

.scale-bar-flaw {
  background: #f56c6c;
  color: #fff;
}

.scale-bar-flaw.unconfirmed {
  background: #e6a23c;
}

.scale-bar-agv {
  background: #67c23a;
  color: #fff;
  font-size: 14px;
  animation: pulse 2s infinite;
}

@keyframes pulse {
  0% { transform: translateX(-50%) scale(1); }
  50% { transform: translateX(-50%) scale(1.1); }
  100% { transform: translateX(-50%) scale(1); }
}

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

.flaw-detail-layout {
  display: flex;
  gap: 20px;
}

.flaw-image-panel {
  width: 760px;
  height: 560px;
  background: #000;
  border-radius: 8px;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
}

.flaw-image {
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.flaw-image-placeholder {
  color: #fff;
  font-size: 16px;
}

.flaw-info-panel {
  flex: 1;
  min-width: 0;
}

.flaw-form-block {
  margin-top: 16px;
}

.flaw-form-label {
  margin-bottom: 8px;
  color: #606266;
  font-size: 13px;
  font-weight: 600;
}

.ai-action-row {
  display: flex;
  align-items: center;
  gap: 12px;
}

.ai-action-tip {
  font-size: 12px;
  color: #909399;
}

.ai-analysis-section {
  margin-top: 16px;
  padding: 15px;
  border: 1px solid #e4e7ed;
  border-radius: 8px;
  background: #f9fafc;
}

.ai-analysis-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 12px;
  font-size: 16px;
  font-weight: 700;
  color: #303133;
}

.ai-field {
  margin-bottom: 12px;
}

.ai-field.meta {
  margin-bottom: 8px;
}

.ai-field-label {
  margin-bottom: 4px;
  font-size: 13px;
  font-weight: 700;
  color: #606266;
}

.ai-field-value {
  padding: 8px 12px;
  background: #fff;
  border: 1px solid #ebeef5;
  border-radius: 4px;
  color: #303133;
}

.answer-text {
  white-space: pre-wrap;
  line-height: 1.8;
}

.meta-text {
  font-size: 12px;
  color: #909399;
  font-family: Consolas, monospace;
}

.ai-severity-high {
  color: #f56c6c;
  font-weight: 700;
}

.ai-severity-medium {
  color: #e6a23c;
  font-weight: 700;
}

.ai-severity-low {
  color: #67c23a;
  font-weight: 700;
}
</style>
