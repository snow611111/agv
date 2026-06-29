<script setup>
import { ref, reactive, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { ArrowLeft } from '@element-plus/icons-vue'

const route = useRoute()
const router = useRouter()
const API = 'http://192.168.2.57/prod-api'
const IMG_BASE = 'http://192.168.2.57/prod-api/file'

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
