<script setup>
import { ref, reactive, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { ArrowLeft } from '@element-plus/icons-vue'

const route = useRoute()
const router = useRouter()
const API = import.meta.env.VITE_API_BASE || '/prod-api'
const IMG_BASE = import.meta.env.VITE_IMG_BASE || (API + '/file')
const REPORT_AI_CONFIG = {
  apiUrl: import.meta.env.VITE_REPORT_AI_API_URL || '',
  apiKey: import.meta.env.VITE_REPORT_AI_API_KEY || '',
  user: import.meta.env.VITE_REPORT_AI_USER || 'agv-terminal',
  timeoutMs: Number(import.meta.env.VITE_REPORT_AI_TIMEOUT_MS || 300000),
}

function getReportAiHostLabel() {
  try {
    const url = new URL(REPORT_AI_CONFIG.apiUrl)
    return url.host || REPORT_AI_CONFIG.apiUrl
  } catch {
    return REPORT_AI_CONFIG.apiUrl || '未配置地址'
  }
}

const taskId = ref(route.query.id || '')
const taskCode = ref(route.query.taskCode || '')

// ===== 任务详情 =====
const taskInfo = reactive({
  taskCode: '--',
  taskName: '--',
  startPos: '--',
  taskTrip: '--',
  creator: '--',
  executor: '--',
  execTime: '--',
  endTime: '--',
  taskStatus: '--',
  round: '--',
  remark: '--',
})

// ===== 缺陷列表 =====
const flawList = ref([])
const flawLoading = ref(false)
const selectedFlaw = ref(null)
const reportLoading = ref(false)
const reportError = ref('')
const reportContent = ref('')

// 当前选中缺陷的图片 URL
const currentImageUrl = computed(() => {
  if (selectedFlaw.value && selectedFlaw.value.flawImageUrl) {
    return IMG_BASE + selectedFlaw.value.flawImageUrl
  }
  return ''
})

// 选中缺陷的行 class
function tableRowClassName({ row }) {
  if (selectedFlaw.value && row.id === selectedFlaw.value.id) return 'selected-row'
  return ''
}

function onFlawRowClick(row) {
  selectedFlaw.value = row
}

async function loadTaskDetail() {
  try {
    const res = await fetch(API + '/agv/task/' + taskId.value)
    const data = await res.json()
    if (data.code === 200 || data.code === 0) {
      Object.assign(taskInfo, data.data || data)
    }
  } catch (e) {
    console.error('加载任务详情失败:', e)
  }
}

async function loadFlawList() {
  flawLoading.value = true
  try {
    const res = await fetch(API + '/agv/flaw/list?taskId=' + taskId.value + '&pageNum=1&pageSize=999')
    const data = await res.json()
    if (data.code === 200 || data.code === 0) {
      // 服务端不支持 taskId 过滤，客户端自行过滤
      flawList.value = (data.rows || []).filter(f => f.taskId === Number(taskId.value))
      // 默认选中第一条
      if (flawList.value.length && !selectedFlaw.value) {
        selectedFlaw.value = flawList.value[0]
      }
    }
  } catch (e) {
    console.error('加载缺陷列表失败:', e)
  } finally {
    flawLoading.value = false
  }
}

// ===== 状态 =====
function getStatusType(s) {
  const map = { '待巡视': 'info', '巡视中': 'warning', '待上传': '', '已完成': 'success' }
  return map[s] || 'info'
}

function goBack() {
  router.push('/taskList')
}

function resetReportState() {
  reportLoading.value = false
  reportError.value = ''
  reportContent.value = ''
}

function buildReportTaskInfo() {
  return {
    taskCode: taskInfo.taskCode || '',
    taskName: taskInfo.taskName || '',
    taskTrip: taskInfo.taskTrip ? Number(taskInfo.taskTrip) : '',
    executor: taskInfo.executor || '',
    execTime: taskInfo.execTime || '',
    endTime: taskInfo.endTime || '',
    taskStatus: taskInfo.taskStatus || '',
  }
}

function buildReportFlawList() {
  return flawList.value.map(item => ({
    flawName: item.flawName || '',
    flawType: item.flawType || '',
    flawDesc: item.flawDesc || '',
    flawDistance: item.flawDistance ?? '',
    confirmed: !!item.confirmed,
  }))
}

async function generateAiReport() {
  if (!REPORT_AI_CONFIG.apiUrl || !REPORT_AI_CONFIG.apiKey) {
    reportError.value = 'AI 巡检报告接口未配置，请先在 .env 中填写 VITE_REPORT_AI_API_URL 和 VITE_REPORT_AI_API_KEY。'
    return
  }

  reportLoading.value = true
  reportError.value = ''
  reportContent.value = ''

  const controller = typeof AbortController !== 'undefined' ? new AbortController() : null
  const timerId = controller ? setTimeout(() => controller.abort(), REPORT_AI_CONFIG.timeoutMs) : null

  try {
    const body = {
      inputs: {
        task_info: JSON.stringify(buildReportTaskInfo()),
        flaw_list: JSON.stringify(buildReportFlawList()),
        upload_info: '',
      },
      response_mode: 'blocking',
      user: REPORT_AI_CONFIG.user,
    }

    const res = await fetch(REPORT_AI_CONFIG.apiUrl, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer ' + REPORT_AI_CONFIG.apiKey,
        'Content-Type': 'application/json',
      },
      signal: controller?.signal,
      body: JSON.stringify(body),
    })

    if (timerId) clearTimeout(timerId)
    if (!res.ok) throw new Error('HTTP ' + res.status + ' ' + res.statusText)

    const data = await res.json()
    const content = data?.data?.outputs?.report_content
    if (!content) {
      throw new Error(data?.data?.error || '未返回报告内容')
    }
    reportContent.value = content
  } catch (err) {
    if (timerId) clearTimeout(timerId)
    if (err?.name === 'AbortError') {
      reportError.value = '生成超时：AI 报告服务 ' + getReportAiHostLabel() + ' 在 ' + Math.round(REPORT_AI_CONFIG.timeoutMs / 1000) + ' 秒内未返回。'
    } else if (String(err?.message || '').includes('Failed to fetch')) {
      reportError.value = '生成失败：无法连接 AI 报告服务 ' + getReportAiHostLabel() + '，请检查服务地址、网络连通性或服务是否启动。'
    } else {
      reportError.value = '生成失败：' + (err?.message || String(err))
    }
  } finally {
    reportLoading.value = false
  }
}

// ===== 比例尺（只读）=====
const totalDistance = ref(100)
const progressPercent = ref(0)

onMounted(() => {
  if (!taskId.value) {
    ElMessage.warning('缺少任务ID')
    router.push('/taskList')
    return
  }
  loadTaskDetail()
  loadFlawList()
})
</script>

<template>
  <div class="app-container">
    <!-- ========== 面包屑 ========== -->
    <el-breadcrumb separator="/" class="breadcrumb">
      <el-breadcrumb-item :to="{ path: '/' }">地铁隧道巡线车智能巡检系统</el-breadcrumb-item>
      <el-breadcrumb-item :to="{ path: '/taskList' }">任务列表</el-breadcrumb-item>
      <el-breadcrumb-item>巡视历史</el-breadcrumb-item>
    </el-breadcrumb>

    <!-- ========== 主布局：图片区 + 侧边栏 ========== -->
    <el-container class="task-body">
      <!-- 左侧：图片 + 底部比例尺 -->
      <el-container class="task-main-vertical">
        <el-main class="task-main">
          <!-- 缺陷现场照片 -->
          <div class="image-area">
            <img
              v-if="currentImageUrl"
              :src="currentImageUrl"
              style="width:100%;height:100%;object-fit:contain"
              alt="缺陷现场照片"
            />
            <div v-else class="image-placeholder">
              <span class="placeholder-icon">📷</span>
              <span>点击下方缺陷行查看现场照片</span>
            </div>
            <!-- 照片信息叠加层 -->
            <div v-if="selectedFlaw" class="image-info">
              {{ selectedFlaw.flawName }} | {{ selectedFlaw.flawDistance }}m | {{ selectedFlaw.createTime }}
            </div>
          </div>
        </el-main>

        <!-- 底部里程比例尺 -->
        <el-footer class="task-footer" height="60px">
          <div class="scale-bar-wrapper">
            <div class="scale-bar"></div>
            <span class="scale-bar-text">0m</span>
            <span class="scale-bar-text end">{{ totalDistance }}m</span>
            <div class="scale-bar-progress" :style="{ width: progressPercent + '%' }"></div>
            <div class="scale-bar-agv" :style="{ left: 'calc(' + progressPercent + '% - 12px)' }">
              🚛
            </div>
          </div>
        </el-footer>
      </el-container>

      <!-- 右侧面板 -->
      <el-aside width="300px" class="task-aside">
        <!-- 任务信息 -->
        <el-card class="mb10" shadow="never">
          <template #header>
            <div class="card-header-row">
              <span>任务信息</span>
              <el-tag :type="getStatusType(taskInfo.taskStatus)" size="small">{{ taskInfo.taskStatus }}</el-tag>
            </div>
          </template>
          <el-descriptions :column="1" border size="small">
            <el-descriptions-item label="任务编号">{{ taskInfo.taskCode || '--' }}</el-descriptions-item>
            <el-descriptions-item label="任务名称">{{ taskInfo.taskName || '--' }}</el-descriptions-item>
            <el-descriptions-item label="起始地点">{{ taskInfo.startPos || '--' }}</el-descriptions-item>
            <el-descriptions-item label="任务距离">{{ taskInfo.taskTrip ? taskInfo.taskTrip + ' 米' : '--' }}</el-descriptions-item>
            <el-descriptions-item label="创建人">{{ taskInfo.creator || '--' }}</el-descriptions-item>
            <el-descriptions-item label="执行人">{{ taskInfo.executor || '--' }}</el-descriptions-item>
            <el-descriptions-item label="执行时间">{{ taskInfo.execTime || '--' }}</el-descriptions-item>
            <el-descriptions-item label="完成时间">{{ taskInfo.endTime || '--' }}</el-descriptions-item>
            <el-descriptions-item label="巡视轮次">{{ taskInfo.round || '--' }}</el-descriptions-item>
            <el-descriptions-item label="备注">{{ taskInfo.remark || '--' }}</el-descriptions-item>
          </el-descriptions>
        </el-card>

        <!-- 返回 -->
        <el-button style="width:100%" :icon="ArrowLeft" @click="goBack">返回任务列表</el-button>

        <el-card class="mb10" shadow="never" style="margin-top:10px">
          <template #header>
            <div class="card-header-row">
              <span>AI 巡检报告</span>
              <el-button type="primary" size="small" :loading="reportLoading" @click="generateAiReport">
                {{ reportLoading ? '生成中...' : (reportContent ? '重新生成' : '生成AI巡检报告') }}
              </el-button>
            </div>
          </template>

          <el-alert
            v-if="reportError"
            :title="reportError"
            type="error"
            :closable="false"
            show-icon
            style="margin-bottom:12px"
          />

          <div v-if="reportContent" class="report-content">{{ reportContent }}</div>
          <div v-else-if="reportLoading" class="report-placeholder">AI 正在生成巡检报告，请稍候...</div>
          <div v-else class="report-placeholder">点击上方按钮生成当前任务的 AI 巡检报告</div>

          <div class="report-disclaimer">本报告由 AI 生成，仅供辅助参考，最终以人工复核为准。</div>
        </el-card>

      </el-aside>
    </el-container>

    <!-- ========== 缺陷记录（全宽详细表格）========== -->
    <div class="flaw-section">
      <div class="flaw-header">
        <span>缺陷记录（{{ flawList.length }} 条）</span>
        <span class="flaw-hint">※ 点击行查看现场照片 | 等级/长度/面积/数量暂不返回</span>
      </div>
      <div class="flaw-table-wrap">
        <el-table
          :data="flawList"
          v-loading="flawLoading"
          border stripe size="small"
          style="width:100%"
          highlight-current-row
          :row-class-name="tableRowClassName"
          @row-click="onFlawRowClick"
        >
          <el-table-column type="index" label="序号" width="55" />
          <el-table-column prop="flawName" label="缺陷名称" min-width="120" show-overflow-tooltip />
          <el-table-column prop="flawType" label="缺陷类型" width="120" />
          <el-table-column prop="level" label="等级" width="80" align="center">
            <template #default="{ row }">
              <el-tag v-if="row.level" :type="row.level === '严重' ? 'danger' : row.level === '一般' ? 'warning' : 'info'" size="small">{{ row.level }}</el-tag>
              <span v-else>--</span>
            </template>
          </el-table-column>
          <el-table-column prop="flawDistance" label="距离(m)" width="90" align="right">
            <template #default="{ row }">{{ row.flawDistance != null ? row.flawDistance : '--' }}</template>
          </el-table-column>
          <el-table-column prop="flawLength" label="长度(m)" width="90" align="right">
            <template #default="{ row }">{{ row.flawLength != null ? row.flawLength : '--' }}</template>
          </el-table-column>
          <el-table-column prop="flawArea" label="面积(m²)" width="90" align="right">
            <template #default="{ row }">{{ row.flawArea != null ? row.flawArea : '--' }}</template>
          </el-table-column>
          <el-table-column prop="countNum" label="数量" width="60" align="center" />
          <el-table-column prop="confirmed" label="确认状态" width="100" align="center">
            <template #default="{ row }">
              <el-tag :type="row.confirmed ? 'success' : 'warning'" size="small">{{ row.confirmed ? '已确认' : '待确认' }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="uploaded" label="上传" width="80" align="center">
            <template #default="{ row }">
              <el-tag :type="row.uploaded ? 'success' : 'info'" size="small">{{ row.uploaded ? '已上传' : '未上传' }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="flawDesc" label="描述" min-width="150" show-overflow-tooltip>
            <template #default="{ row }">{{ row.flawDesc || '--' }}</template>
          </el-table-column>
          <el-table-column prop="createTime" label="发现时间" width="160" />
          <template #empty>
            <span style="color: #909399">暂无数据</span>
          </template>
        </el-table>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* ========== 整体布局 ========== */
.app-container {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  background: #f0f2f5;
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

/* ========== 左侧：图片区 ========== */
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

.image-area {
  flex: 1;
  background: #1a1a2e;
  border-radius: 6px;
  min-height: 400px;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.image-placeholder {
  text-align: center;
  color: #555;
  font-size: 14px;
}

.image-placeholder .placeholder-icon {
  font-size: 48px;
  display: block;
  margin-bottom: 10px;
}

.image-info {
  position: absolute;
  bottom: 8px;
  left: 8px;
  background: rgba(0, 0, 0, 0.7);
  color: #ccc;
  padding: 3px 8px;
  border-radius: 4px;
  font-size: 10px;
  font-family: Consolas, monospace;
  pointer-events: none;
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

.flaw-hint {
  font-size: 11px;
  color: #909399;
  font-weight: normal;
  margin-left: 16px;
}

.report-placeholder {
  color: #909399;
  font-size: 13px;
  line-height: 1.8;
}

.report-content {
  white-space: pre-wrap;
  line-height: 1.9;
  font-size: 13px;
  color: #303133;
  background: #fafafa;
  border: 1px solid #ebeef5;
  border-radius: 6px;
  padding: 12px;
}

.report-disclaimer {
  margin-top: 12px;
  color: #909399;
  font-size: 12px;
  line-height: 1.6;
}

/* ========== 底部缺陷区域（全宽）========== */
.flaw-section {
  padding: 0 12px 12px;
  margin-top: 5px;
}

.flaw-header {
  padding: 8px 16px;
  background: #fff;
  border-radius: 6px 6px 0 0;
  border-bottom: 1px solid #e4e7ed;
  font-size: 14px;
  font-weight: 600;
  color: #303133;
}

.flaw-table-wrap {
  background: #fff;
  border-radius: 0 0 6px 6px;
  padding: 0;
}

/* ========== 表格选中行 ========== */
:deep(.selected-row) {
  background-color: #ecf5ff !important;
}
</style>
