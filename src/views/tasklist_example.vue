<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'

const router = useRouter()
import { Search, Refresh, Upload, Setting } from '@element-plus/icons-vue'

const API = 'http://192.168.2.57/prod-api'

// ===== 搜索表单 =====
const searchForm = reactive({
  taskCode: '',
  creator: '',
  executor: '',
  taskStatus: '',
  dateFrom: '',
  dateTo: '',
})

const statusOptions = [
  { label: '待巡视', value: '待巡视' },
  { label: '巡视中', value: '巡视中' },
  { label: '待上传', value: '待上传' },
  { label: '已完成', value: '已完成' },
]

// ===== 表格 =====
const tableData = ref([])
const loading = ref(false)
const allRows = ref([])             // 日期筛选时缓存全部数据
const dateFilterActive = ref(false) // 是否处于日期筛选模式
const statsText = ref('--')
const pagination = reactive({
  currentPage: 1,
  pageSize: 20,
  total: 0,
})

// ===== 弹窗控制 =====
const dialogVisible = ref(false)
const uploadDialogVisible = ref(false)
const settingsDialogVisible = ref(false)
const currentTask = ref(null)
const editDialogVisible = ref(false)
const settingsLoading = ref(false)
const settingsSaving = ref(false)

// ===== 设置表单 =====
const settingsForm = reactive({
  id: null,
  host: '',
  drivePort: null,
  analysisPort: null,
  cloudUrl: '',
  cam1: '',
  cam2: '',
  cam3: '',
  cam4: '',
  username1: '',
  username2: '',
  username3: '',
  username4: '',
  password1: '',
  password2: '',
  password3: '',
  password4: '',
})

const cameraLabels = ['前方主视角', '左侧视角', '右侧视角', '后方视角']

// ===== 上传表单 =====
const uploadForm = reactive({
  taskCode: '',
  file: null,
})

// ===== 新增任务 =====
const createDialogVisible = ref(false)
const createForm = reactive({
  taskName: '',
  taskCode: '',
  startPos: '',
  taskTrip: '',
  creator: '',
  executor: '',
  remark: '',
})
const editForm = reactive({
  id: '',
  taskName: '',
  taskCode: '',
  startPos: '',
  taskTrip: '',
  creator: '',
  executor: '',
  remark: '',
  taskStatus: '',
})
function openCreateDialog() {
  Object.assign(createForm, { taskName: '', taskCode: '', startPos: '', taskTrip: '', creator: '', executor: '', remark: '' })
  createDialogVisible.value = true
}

async function createTask(andStart) {
  if (!createForm.taskName) { ElMessage.warning('请输入任务名称'); return }
  if (!createForm.startPos) { ElMessage.warning('请输入起始地点'); return }
  if (!createForm.taskTrip) { ElMessage.warning('请输入任务距离'); return }
  if (!createForm.creator) { ElMessage.warning('请输入创建人'); return }
  if (!createForm.executor) { ElMessage.warning('请输入执行人'); return }

  createDialogVisible.value = false

  try {
    const body = {
      taskName: createForm.taskName.trim(),
      taskCode: createForm.taskCode.trim(),
      startPos: createForm.startPos.trim(),
      taskTrip: createForm.taskTrip.trim(),
      creator: createForm.creator.trim(),
      executor: createForm.executor.trim(),
      remark: createForm.remark.trim(),
    }
    const res = await fetch(API + '/agv/task', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    })
    const data = await res.json()
    if (data.code === 200 || data.code === 0) {
      let foundId = null
      let foundTaskCode = body.taskCode

      if (andStart) {
        ElMessage.success('任务创建成功，正在查找...')
        // 回查任务列表，按 taskName + creator 匹配
        try {
          const lookup = await fetch(API + '/agv/task/list?pageNum=1&pageSize=999')
          const lookupData = await lookup.json()
          if (lookupData.code === 200 || lookupData.code === 0) {
            const rows = lookupData.rows || []
            const matches = rows.filter(r => {
              const sameName = r.taskName === body.taskName
              const sameCreator = r.creator === body.creator
              const sameCode = body.taskCode ? r.taskCode === body.taskCode : true
              return sameName && sameCreator && sameCode
            })
            if (matches.length === 1) {
              foundId = matches[0].id
              foundTaskCode = matches[0].taskCode || foundTaskCode
            } else if (matches.length > 1) {
              // 重名：取 id 最大（最新创建）
              const latest = matches.reduce((max, r) => r.id > max.id ? r : max, matches[0])
              foundId = latest.id
              foundTaskCode = latest.taskCode || foundTaskCode
            }
          }
        } catch (e) { /* 回查失败继续 */ }

        if (foundId) {
          const r2 = await fetch(API + '/agv/task/start/' + foundId, { method: 'POST' })
          const d2 = await r2.json()
          if (d2.code === 200 || d2.code === 0) {
            ElMessage.success('任务已启动 (ID: ' + foundId + ')')
            router.push({ path: '/execute_example', query: { id: foundId, taskCode: foundTaskCode || body.taskCode } })
            return
          } else {
            ElMessage.error('启动失败: ' + (d2.msg || ''))
          }
        } else {
          ElMessage.warning('任务已创建但未找到ID，请手动启动')
        }
      } else {
        ElMessage.success('任务创建成功')
      }
      fetchTaskList()
    } else {
      ElMessage.error('创建失败: ' + (data.msg || ''))
    }
  } catch (e) {
    ElMessage.error('网络异常: ' + e.message)
  }
}

// ===== 日期过滤（本地） =====
function filterByDate(rows) {
  const from = searchForm.dateFrom
  const to = searchForm.dateTo
  if (!from && !to) return rows
  return rows.filter(function (t) {
    const dateStr = t.execTime || t.createTime || t.endTime || ''
    if (!dateStr) return false
    const datePart = String(dateStr).substring(0, 10)
    if (from && datePart < from) return false
    if (to && datePart > to) return false
    return true
  })
}

// ===== 查询 =====
async function fetchTaskList() {
  loading.value = true
  try {
    const hasDateFilter = !!(searchForm.dateFrom || searchForm.dateTo)
    const isFirstPage = pagination.currentPage === 1

    // 日期筛选模式：全量拉取不分页
    if (hasDateFilter) {
      dateFilterActive.value = true
      const params = new URLSearchParams({ pageNum: '1', pageSize: '500' })
      if (searchForm.taskCode) params.append('taskCode', searchForm.taskCode)
      if (searchForm.creator) params.append('creator', searchForm.creator)
      if (searchForm.executor) params.append('executor', searchForm.executor)
      if (searchForm.taskStatus) params.append('taskStatus', searchForm.taskStatus)

      const res = await fetch(API + '/agv/task/list?' + params.toString())
      const data = await res.json()
      if (data.code === 200 || data.code === 0) {
        const rows = data.rows || []
        pagination.total = data.total || 0
        allRows.value = rows
        const filtered = filterByDate(rows)
        tableData.value = filtered
        statsText.value = '共 ' + (data.total || 0) + ' 条 | 日期筛选: ' + filtered.length + ' 条（已加载全部）'
      } else {
        ElMessage.error(data.msg || '查询失败')
      }
      loading.value = false
      return
    }

    // 非日期模式
    dateFilterActive.value = false
    allRows.value = []

    // 构造当前页请求参数
    const params = new URLSearchParams({
      pageNum: String(pagination.currentPage),
      pageSize: String(pagination.pageSize),
    })
    if (searchForm.taskCode) params.append('taskCode', searchForm.taskCode)
    if (searchForm.creator) params.append('creator', searchForm.creator)
    if (searchForm.executor) params.append('executor', searchForm.executor)
    if (searchForm.taskStatus) params.append('taskStatus', searchForm.taskStatus)

    // ★ 第 1 页：并行拉取巡视中任务 + 当前页数据
    if (isFirstPage) {
      const [resPatrol, resNormal] = await Promise.all([
        fetch(API + '/agv/task/list?pageNum=1&pageSize=100&taskStatus=巡视中'),
        fetch(API + '/agv/task/list?' + params.toString()),
      ])
      const [dataA, dataB] = await Promise.all([resPatrol.json(), resNormal.json()])

      if (dataB.code === 200 || dataB.code === 0) {
        const patrolRows = (dataA.code === 200 || dataA.code === 0) ? (dataA.rows || []) : []
        const normalRows = dataB.rows || []

        // 去重：从 B 中排除已在 A 中的 id
        const patrolIds = new Set(patrolRows.map(r => r.id))
        const filteredB = normalRows.filter(r => !patrolIds.has(r.id))

        tableData.value = [...patrolRows, ...filteredB]
        pagination.total = dataB.total || 0
        statsText.value = '共 ' + (dataB.total || 0) + ' 条 | 第 ' + pagination.currentPage + ' 页 | 巡视中置顶'
      } else {
        ElMessage.error(dataB.msg || '查询失败')
      }
    } else {
      // 第 2 页以后：正常请求
      const res = await fetch(API + '/agv/task/list?' + params.toString())
      const data = await res.json()
      if (data.code === 200 || data.code === 0) {
        tableData.value = data.rows || []
        pagination.total = data.total || 0
        statsText.value = '共 ' + (data.total || 0) + ' 条 | 第 ' + pagination.currentPage + ' 页'
      } else {
        ElMessage.error(data.msg || '查询失败')
      }
    }
  } catch (e) {
    console.error('查询任务列表失败:', e)
    if (!tableData.value.length) {
      tableData.value = getMockData()
      pagination.total = tableData.value.length
    }
  } finally {
    loading.value = false
  }
}

function getMockData() {
  return [
    { id: 1, taskCode: 'TASK-20260624-001', taskName: '随便逛逛', startPos: 'K3+300 米', taskTrip: '1200', creator: 'admin', executor: 'user', execTime: '', taskStatus: '待巡视' },
    { id: 2, taskCode: 'TASK-20260624-002', taskName: '2026.6.24task1', startPos: '0 米', taskTrip: '1', creator: 'ywq', executor: 'xwy', execTime: '', taskStatus: '待巡视' },
    { id: 3, taskCode: 'TASK-20260624-003', taskName: '隧道巡检-北段', startPos: 'K1+200 米', taskTrip: '800', creator: 'admin', executor: 'zhangsan', execTime: '2026-06-25 08:30', taskStatus: '已完成' },
    { id: 4, taskCode: 'TASK-20260624-004', taskName: '隧道巡检-南段', startPos: 'K2+000 米', taskTrip: '1500', creator: 'admin', executor: 'lisi', execTime: '2026-06-25 09:00', taskStatus: '巡视中' },
    { id: 5, taskCode: 'TASK-20260624-005', taskName: '紧急排查', startPos: 'K4+100 米', taskTrip: '500', creator: 'manager', executor: '', execTime: '', taskStatus: '待巡视' },
  ]
}

function onSearch() {
  pagination.currentPage = 1
  fetchTaskList()
}

function onReset() {
  searchForm.taskCode = ''
  searchForm.creator = ''
  searchForm.executor = ''
  searchForm.taskStatus = ''
  searchForm.dateFrom = ''
  searchForm.dateTo = ''
  dateFilterActive.value = false
  allRows.value = []
  pagination.currentPage = 1
  fetchTaskList()
}

function onPageChange(page) {
  if (dateFilterActive.value) return  // 日期筛选模式不分页
  pagination.currentPage = page
  fetchTaskList()
}

function onSizeChange(size) {
  pagination.pageSize = size
  pagination.currentPage = 1
  fetchTaskList()
}

// ===== 状态样式 =====
function getStatusType(taskStatus) {
  const map = { '待巡视': 'info', '巡视中': 'warning', '待上传': '', '已完成': 'success' }
  return map[taskStatus] || 'info'
}

function getStatusLabel(taskStatus) {
  return taskStatus || '--'
}

// ===== 操作按钮 =====
function onView(row) {
  currentTask.value = row
  dialogVisible.value = true
}

// 待巡视 → 启动任务
async function onStartTask(row) {
  try {
    await ElMessageBox.confirm('确认启动任务【' + row.taskName + '】？', '提示', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning',
    })
  } catch { return }

  try {
    const res = await fetch(API + '/agv/task/start/' + row.id, { method: 'POST' })
    const data = await res.json()
    if (data.code === 200 || data.code === 0) {
      ElMessage.success('任务【' + row.taskName + '】已启动')
      dialogVisible.value = false
      router.push({ path: '/execute_example', query: { id: row.id, taskCode: row.taskCode } })
    } else {
      ElMessage.error(data.msg || '启动失败')
    }
  } catch (e) {
    ElMessage.error('网络错误，启动失败')
  }
}

// 巡视中 → 完成任务
async function onCompleteTask(row) {
  try {
    await ElMessageBox.confirm('确认完成任务【' + row.taskName + '】？', '提示', {
      confirmButtonText: '确定完成',
      cancelButtonText: '取消',
      type: 'warning',
    })
  } catch { return }

  try {
    const res = await fetch(API + '/agv/task/end/' + row.id + '?isAbort=false', { method: 'POST' })
    const data = await res.json()
    if (data.code === 200 || data.code === 0) {
      ElMessage.success('任务【' + row.taskName + '】已完成')
      fetchTaskList()
    } else {
      ElMessage.error(data.msg || '操作失败')
    }
  } catch (e) {
    ElMessage.error('网络错误，操作失败')
  }
}

// 巡视中 → 中止（退出巡视状态，不结束任务）
async function onAbortTask(row) {
  try {
    await ElMessageBox.confirm('确认中止任务【' + row.taskName + '】？任务将退出巡视状态，不会标记为完成。', '提示', {
      confirmButtonText: '确定中止',
      cancelButtonText: '取消',
      type: 'warning',
    })
  } catch { return }

  try {
    const res = await fetch(API + '/agv/task/end/' + row.id + '?isAbort=true', { method: 'POST' })
    const data = await res.json()
    if (data.code === 200 || data.code === 0) {
      ElMessage.success('任务【' + row.taskName + '】已中止，回到待巡视状态')
      fetchTaskList()
    } else {
      ElMessage.error(data.msg || '操作失败')
    }
  } catch (e) {
    ElMessage.error('网络错误，操作失败')
  }
}

// 待上传 → 上传数据
async function onUploadTask(row) {
  try {
    await ElMessageBox.confirm('确认上传任务【' + row.taskName + '】的数据？', '提示', {
      confirmButtonText: '确定上传',
      cancelButtonText: '取消',
      type: 'warning',
    })
  } catch { return }

  try {
    const res = await fetch(API + '/agv/task/upload/' + row.id, { method: 'POST' })
    const data = await res.json()
    if (data.code === 200 || data.code === 0) {
      ElMessage.success('任务【' + row.taskName + '】数据上传成功')
      fetchTaskList()
    } else {
      ElMessage.error(data.msg || '上传失败')
    }
  } catch (e) {
    ElMessage.error('网络错误，上传失败')
  }
}

function onEdit(row) {
  Object.assign(editForm, {
    id: row.id || '',
    taskName: row.taskName || '',
    taskCode: row.taskCode || '',
    startPos: row.startPos || '',
    taskTrip: row.taskTrip || '',
    creator: row.creator || '',
    executor: row.executor || '',
    remark: row.remark || '',
    taskStatus: row.taskStatus || '',
  })
  editDialogVisible.value = true
}

async function submitEdit() {
  if (!editForm.id) { ElMessage.warning('缺少任务ID'); return }
  if (!editForm.taskName) { ElMessage.warning('请输入任务名称'); return }
  if (!editForm.startPos) { ElMessage.warning('请输入起始地点'); return }
  if (!editForm.taskTrip) { ElMessage.warning('请输入任务距离'); return }
  if (!editForm.creator) { ElMessage.warning('请输入创建人'); return }
  if (!editForm.executor) { ElMessage.warning('请输入执行人'); return }

  try {
    const body = {
      id: editForm.id,
      taskName: editForm.taskName.trim(),
      taskCode: editForm.taskCode.trim(),
      startPos: editForm.startPos.trim(),
      taskTrip: editForm.taskTrip.trim(),
      creator: editForm.creator.trim(),
      executor: editForm.executor.trim(),
      remark: editForm.remark.trim(),
      taskStatus: editForm.taskStatus,
    }
    const res = await fetch(API + '/agv/task', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    })
    const data = await res.json()
    if (data.code === 200 || data.code === 0) {
      ElMessage.success('任务修改成功')
      editDialogVisible.value = false
      fetchTaskList()
    } else {
      ElMessage.error(data.msg || '修改失败')
    }
  } catch (e) {
    ElMessage.error('网络异常: ' + e.message)
  }
}

function onDelete(row) {
  ElMessageBox.confirm('确认删除任务【' + row.taskName + '】？此操作不可恢复。', '警告', {
    confirmButtonText: '确定删除',
    cancelButtonText: '取消',
    type: 'error',
  }).then(async () => {
    try {
      const res = await fetch(API + '/agv/task/' + row.id, { method: 'DELETE' })
      const data = await res.json()
      if (data.code === 200 || data.code === 0) {
        ElMessage.success('删除成功')
        fetchTaskList()
      } else {
        ElMessage.error(data.msg || '删除失败')
      }
    } catch (e) {
      ElMessage.error('网络错误，删除失败')
    }
  }).catch(() => {})
}

// ===== 上传 =====
function onUpload() {
  uploadForm.taskCode = ''
  uploadForm.file = null
  uploadDialogVisible.value = true
}

function handleUploadFile(file) {
  uploadForm.file = file
}

function submitUpload() {
  if (!uploadForm.taskCode) {
    ElMessage.warning('请输入任务编号')
    return
  }
  ElMessage.success('任务数据上传成功（模拟）')
  uploadDialogVisible.value = false
}

function resetSettingsForm() {
  Object.assign(settingsForm, {
    id: null,
    host: '',
    drivePort: null,
    analysisPort: null,
    cloudUrl: '',
    cam1: '',
    cam2: '',
    cam3: '',
    cam4: '',
    username1: '',
    username2: '',
    username3: '',
    username4: '',
    password1: '',
    password2: '',
    password3: '',
    password4: '',
  })
}

async function openSettingsDialog() {
  settingsDialogVisible.value = true
  await loadSettings()
}

async function loadSettings() {
  settingsLoading.value = true
  try {
    const res = await fetch(API + '/agv/config')
    const data = await res.json()
    if (data.code === 200 || data.code === 0) {
      const config = data.data || {}
      resetSettingsForm()
      Object.assign(settingsForm, {
        id: config.id ?? null,
        host: config.host || '',
        drivePort: config.drivePort ?? null,
        analysisPort: config.analysisPort ?? null,
        cloudUrl: config.cloudUrl || '',
        cam1: config.cam1 || '',
        cam2: config.cam2 || '',
        cam3: config.cam3 || '',
        cam4: config.cam4 || '',
        username1: config.username1 || '',
        username2: config.username2 || '',
        username3: config.username3 || '',
        username4: config.username4 || '',
        password1: config.password1 || '',
        password2: config.password2 || '',
        password3: config.password3 || '',
        password4: config.password4 || '',
      })
    } else {
      ElMessage.error(data.msg || '加载系统设置失败')
    }
  } catch (e) {
    ElMessage.error('加载系统设置失败: ' + e.message)
  } finally {
    settingsLoading.value = false
  }
}

function validateSettingsForm() {
  const ipRe = /^(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$/
  const urlRe = /^https?:\/\/.+/i

  if (!settingsForm.host.trim()) {
    ElMessage.warning('请输入车辆 IP 地址')
    return false
  }
  if (!ipRe.test(settingsForm.host.trim())) {
    ElMessage.warning('车辆 IP 地址格式不正确')
    return false
  }

  const portFields = [
    ['drivePort', '车辆控制端口'],
    ['analysisPort', '分析程序端口'],
  ]
  for (const [field, label] of portFields) {
    const value = Number(settingsForm[field])
    if (!value || Number.isNaN(value) || value < 1 || value > 65535) {
      ElMessage.warning(label + '需填写 1-65535 之间的端口号')
      return false
    }
  }

  if (settingsForm.cloudUrl && !urlRe.test(settingsForm.cloudUrl.trim())) {
    ElMessage.warning('云端地址需以 http:// 或 https:// 开头')
    return false
  }

  return true
}

async function saveSettings() {
  if (!validateSettingsForm()) return

  settingsSaving.value = true
  try {
    const body = {
      id: settingsForm.id,
      host: settingsForm.host.trim(),
      drivePort: Number(settingsForm.drivePort),
      analysisPort: Number(settingsForm.analysisPort),
      cloudUrl: settingsForm.cloudUrl.trim(),
      cam1: settingsForm.cam1.trim(),
      cam2: settingsForm.cam2.trim(),
      cam3: settingsForm.cam3.trim(),
      cam4: settingsForm.cam4.trim(),
      username1: settingsForm.username1.trim(),
      username2: settingsForm.username2.trim(),
      username3: settingsForm.username3.trim(),
      username4: settingsForm.username4.trim(),
      password1: settingsForm.password1.trim(),
      password2: settingsForm.password2.trim(),
      password3: settingsForm.password3.trim(),
      password4: settingsForm.password4.trim(),
    }

    const res = await fetch(API + '/agv/config', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    })
    const data = await res.json()

    if (data.code === 200 || data.code === 0) {
      settingsDialogVisible.value = false
      ElMessage.success('系统设置已保存')
      try {
        await ElMessageBox.confirm('设置已保存，是否立即返回系统自检页面重新检测连接？', '提示', {
          confirmButtonText: '去自检',
          cancelButtonText: '稍后再说',
          type: 'success',
        })
        router.push('/')
      } catch {
        // 用户选择稍后处理
      }
    } else {
      ElMessage.error(data.msg || '保存系统设置失败')
    }
  } catch (e) {
    ElMessage.error('保存系统设置失败: ' + e.message)
  } finally {
    settingsSaving.value = false
  }
}

// ===== 初始化 =====
onMounted(() => {
  fetchTaskList()
})
</script>

<template>
  <div class="app-container">
    <!-- ========== 面包屑 ========== -->
    <el-breadcrumb separator="/" class="breadcrumb">
      <el-breadcrumb-item :to="{ path: '/' }">地铁隧道巡线车智能巡检系统</el-breadcrumb-item>
      <el-breadcrumb-item>任务列表</el-breadcrumb-item>
    </el-breadcrumb>

    <!-- 设置按钮 -->
    <el-button class="settings-btn" :icon="Setting" circle @click="openSettingsDialog" />

    <!-- ========== 搜索表单 ========== -->
    <el-form :model="searchForm" inline class="search-form">
      <el-form-item label="任务编号">
        <el-input v-model="searchForm.taskCode" placeholder="请输入任务编号" clearable style="width:180px" />
      </el-form-item>
      <el-form-item label="创建人">
        <el-input v-model="searchForm.creator" placeholder="请输入创建人" clearable style="width:150px" />
      </el-form-item>
      <el-form-item label="执行人">
        <el-input v-model="searchForm.executor" placeholder="请输入执行人" clearable style="width:150px" />
      </el-form-item>
      <el-form-item label="状态">
        <el-select v-model="searchForm.taskStatus" placeholder="请选择" clearable style="width:130px">
          <el-option v-for="opt in statusOptions" :key="opt.value" :label="opt.label" :value="opt.value" />
        </el-select>
      </el-form-item>
      <el-form-item label="执行时间">
        <el-date-picker v-model="searchForm.dateFrom" type="date" placeholder="开始日期" value-format="YYYY-MM-DD" style="width:130px" />
        <span style="margin:0 8px;color:#909399">至</span>
        <el-date-picker v-model="searchForm.dateTo" type="date" placeholder="结束日期" value-format="YYYY-MM-DD" style="width:130px" />
      </el-form-item>
      <el-form-item>
        <el-button type="primary" :icon="Search" @click="onSearch">查询</el-button>
        <el-button :icon="Refresh" @click="onReset">重置</el-button>
      </el-form-item>
    </el-form>

    <!-- 统计 -->
    <div class="stats">{{ statsText }}</div>

    <!-- 操作栏 -->
    <div class="toolbar">
      <el-button type="primary" :icon="Upload" plain @click="onUpload">任务数据上传</el-button>
      <el-button type="success" plain @click="openCreateDialog">新增任务</el-button>
    </div>

    <!-- ========== 任务表格 ========== -->
    <el-table :data="tableData" v-loading="loading" border stripe style="width:100%">
      <el-table-column prop="id" label="序号" width="70" align="center" />
      <el-table-column prop="taskCode" label="任务编号" width="180" show-overflow-tooltip />
      <el-table-column prop="taskName" label="任务名称" min-width="150" show-overflow-tooltip />
      <el-table-column prop="startPos" label="起始地点" width="130" />
      <el-table-column prop="taskTrip" label="任务距离" width="100" align="right">
        <template #default="{ row }">{{ row.taskTrip }} 米</template>
      </el-table-column>
      <el-table-column prop="creator" label="创建人" width="100" />
      <el-table-column prop="executor" label="执行人" width="100">
        <template #default="{ row }">{{ row.executor || '--' }}</template>
      </el-table-column>
      <el-table-column prop="execTime" label="执行时间" width="160">
        <template #default="{ row }">{{ row.execTime || '--' }}</template>
      </el-table-column>
      <el-table-column prop="finishTime" label="完成时间" width="160">
        <template #default="{ row }">{{ row.finishTime || '--' }}</template>
      </el-table-column>
      <el-table-column prop="taskStatus" label="状态" width="100" align="center">
        <template #default="{ row }">
          <el-tag :type="getStatusType(row.taskStatus)">{{ getStatusLabel(row.taskStatus) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" width="260" fixed="right">
        <template #default="{ row }">

          <!-- 待巡视：详情 编辑 启动 删除 -->
          <template v-if="row.taskStatus === '待巡视'">
            <el-button size="small" link @click="onView(row)">详情</el-button>
            <el-button size="small" link @click="onEdit(row)">编辑</el-button>
            <el-button size="small" type="success" link @click="onStartTask(row)">启动</el-button>
            <el-button size="small" type="danger" link @click="onDelete(row)">删除</el-button>
          </template>

          <!-- 巡视中：详情 完成 中止 -->
          <template v-else-if="row.taskStatus === '巡视中'">
            <el-button size="small" link @click="onView(row)">详情</el-button>
            <el-button size="small" type="success" link @click="onCompleteTask(row)">完成</el-button>
            <el-button size="small" type="warning" link @click="onAbortTask(row)">中止</el-button>
          </template>

          <!-- 待上传：详情 上传 删除 -->
          <template v-else-if="row.taskStatus === '待上传'">
            <el-button size="small" link @click="onView(row)">详情</el-button>
            <el-button size="small" type="primary" link @click="onUploadTask(row)">上传</el-button>
            <el-button size="small" type="danger" link @click="onDelete(row)">删除</el-button>
          </template>

          <!-- 已完成：仅详情 -->
          <template v-else-if="row.taskStatus === '已完成'">
            <el-button size="small" link @click="onView(row)">详情</el-button>
          </template>

        </template>
      </el-table-column>
    </el-table>

    <!-- ========== 分页 ========== -->
    <div class="pagination-wrap">
      <template v-if="dateFilterActive">
        <span style="color:#909399;font-size:12px">已加载全部 {{ allRows.length }} 条，筛选出 {{ tableData.length }} 条</span>
      </template>
      <el-pagination
        v-else
        v-model:current-page="pagination.currentPage"
        v-model:page-size="pagination.pageSize"
        :page-sizes="[10, 20, 50, 100]"
        :total="pagination.total"
        layout="total, sizes, prev, pager, next, jumper"
        @size-change="onSizeChange"
        @current-change="onPageChange"
      />
    </div>

    <!-- ========== 任务详情弹窗 ========== -->
    <el-dialog v-model="dialogVisible" title="任务详情" width="80%" top="15vh">
      <template v-if="currentTask">
        <el-descriptions :column="2" border>
          <el-descriptions-item label="任务编号">{{ currentTask.taskCode }}</el-descriptions-item>
          <el-descriptions-item label="任务名称">{{ currentTask.taskName }}</el-descriptions-item>
          <el-descriptions-item label="起始地点">{{ currentTask.startPos }}</el-descriptions-item>
          <el-descriptions-item label="任务距离">{{ currentTask.taskTrip }} 米</el-descriptions-item>
          <el-descriptions-item label="创建人">{{ currentTask.creator }}</el-descriptions-item>
          <el-descriptions-item label="执行人">{{ currentTask.executor || '未分配' }}</el-descriptions-item>
          <el-descriptions-item label="执行时间">{{ currentTask.execTime || '--' }}</el-descriptions-item>
          <el-descriptions-item label="完成时间">{{ currentTask.finishTime || '--' }}</el-descriptions-item>
          <el-descriptions-item label="状态">
            <el-tag :type="getStatusType(currentTask.taskStatus)">{{ getStatusLabel(currentTask.taskStatus) }}</el-tag>
          </el-descriptions-item>
        </el-descriptions>
      </template>
      <template #footer>
        <el-button @click="dialogVisible = false">关闭</el-button>
        <el-button
          v-if="currentTask && currentTask.taskStatus === '待巡视'"
          type="success"
          @click="dialogVisible = false; onStartTask(currentTask)"
        >启动</el-button>
        <el-button
          v-if="currentTask && currentTask.taskStatus === '巡视中'"
          type="primary"
          @click="dialogVisible = false; router.push({ path: '/execute_example', query: { id: currentTask.id, taskCode: currentTask.taskCode } })"
        >进入详情页</el-button>
        <el-button
          v-if="currentTask && currentTask.taskStatus === '已完成'"
          type="primary"
          @click="dialogVisible = false; router.push({ path: '/task-history', query: { id: currentTask.id, taskCode: currentTask.taskCode } })"
        >查看历史</el-button>
        <el-button
          v-if="currentTask && currentTask.taskStatus === '待上传'"
          type="primary"
          @click="dialogVisible = false; router.push({ path: '/task-history', query: { id: currentTask.id, taskCode: currentTask.taskCode } })"
        >查看历史</el-button>
      </template>
    </el-dialog>

    <!-- ========== 任务数据上传弹窗 ========== -->
    <el-dialog v-model="uploadDialogVisible" title="任务数据上传" width="800px" top="15vh">
      <el-form :model="uploadForm" label-width="100px">
        <el-form-item label="任务编号" required>
          <el-input v-model="uploadForm.taskCode" placeholder="请输入任务编号" />
        </el-form-item>
        <el-form-item label="数据文件">
          <el-upload
            :auto-upload="false"
            :on-change="handleUploadFile"
            :limit="1"
            drag
          >
            <el-icon class="el-icon--upload"><Upload /></el-icon>
            <div class="el-upload__text">拖拽文件到此处或<em>点击上传</em></div>
          </el-upload>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="uploadDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="submitUpload">确认上传</el-button>
      </template>
    </el-dialog>

    <!-- ========== 新增任务弹窗 ========== -->
    <el-dialog v-model="createDialogVisible" title="新增任务" width="500px" top="10vh">
      <el-form :model="createForm" label-width="80px" size="small">
        <el-row :gutter="12">
          <el-col :span="12">
            <el-form-item label="任务名称" required>
              <el-input v-model="createForm.taskName" maxlength="50" placeholder="例如：隧道例行巡检" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="任务编号">
              <el-input v-model="createForm.taskCode" maxlength="20" placeholder="留空自动生成" />
            </el-form-item>
          </el-col>
        </el-row>
        <el-row :gutter="12">
          <el-col :span="12">
            <el-form-item label="起始地点" required>
              <el-input v-model="createForm.startPos" placeholder="例如：100" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="任务距离" required>
              <el-input v-model="createForm.taskTrip" placeholder="例如：500">
                <template #append>m</template>
              </el-input>
            </el-form-item>
          </el-col>
        </el-row>
        <el-row :gutter="12">
          <el-col :span="12">
            <el-form-item label="创建人" required>
              <el-input v-model="createForm.creator" maxlength="10" placeholder="你的名字" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="执行人" required>
              <el-input v-model="createForm.executor" maxlength="10" placeholder="执行人" />
            </el-form-item>
          </el-col>
        </el-row>
        <el-form-item label="备注">
          <el-input v-model="createForm.remark" type="textarea" maxlength="250" placeholder="可选备注" :rows="2" />
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="createDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="createTask(false)">保存任务</el-button>
        <el-button type="success" @click="createTask(true)">保存并启动</el-button>
      </template>
    </el-dialog>

    <!-- ========== 编辑任务弹窗 ========== -->
    <el-dialog v-model="editDialogVisible" title="编辑任务" width="500px" top="10vh">
      <el-form :model="editForm" label-width="80px" size="small">
        <el-row :gutter="12">
          <el-col :span="12">
            <el-form-item label="任务名称" required>
              <el-input v-model="editForm.taskName" maxlength="50" placeholder="例如：隧道例行巡检" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="任务编号">
              <el-input v-model="editForm.taskCode" maxlength="20" placeholder="请输入任务编号" />
            </el-form-item>
          </el-col>
        </el-row>
        <el-row :gutter="12">
          <el-col :span="12">
            <el-form-item label="起始地点" required>
              <el-input v-model="editForm.startPos" placeholder="例如：100" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="任务距离" required>
              <el-input v-model="editForm.taskTrip" placeholder="例如：500">
                <template #append>m</template>
              </el-input>
            </el-form-item>
          </el-col>
        </el-row>
        <el-row :gutter="12">
          <el-col :span="12">
            <el-form-item label="创建人" required>
              <el-input v-model="editForm.creator" maxlength="10" placeholder="创建人" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="执行人" required>
              <el-input v-model="editForm.executor" maxlength="10" placeholder="执行人" />
            </el-form-item>
          </el-col>
        </el-row>
        <el-form-item label="备注">
          <el-input v-model="editForm.remark" type="textarea" maxlength="250" placeholder="可选备注" :rows="2" />
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="editDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="submitEdit">保存修改</el-button>
      </template>
    </el-dialog>

    <!-- ========== 设置弹窗 ========== -->
    <el-dialog v-model="settingsDialogVisible" title="系统设置" width="860px" top="8vh">
      <el-form v-loading="settingsLoading" :model="settingsForm" label-width="120px" class="settings-form">
        <div class="settings-section">
          <div class="settings-section-title">车辆控制设置</div>
          <el-row :gutter="16">
            <el-col :span="12">
              <el-form-item label="车辆IP地址" required>
                <el-input v-model="settingsForm.host" placeholder="如 192.168.1.100" />
              </el-form-item>
            </el-col>
            <el-col :span="6">
              <el-form-item label="控制端口" required>
                <el-input-number v-model="settingsForm.drivePort" :min="1" :max="65535" :controls="false" style="width:100%" />
              </el-form-item>
            </el-col>
            <el-col :span="6">
              <el-form-item label="分析端口" required>
                <el-input-number v-model="settingsForm.analysisPort" :min="1" :max="65535" :controls="false" style="width:100%" />
              </el-form-item>
            </el-col>
          </el-row>
        </div>

        <div class="settings-section">
          <div class="settings-section-title">云端平台设置</div>
          <el-form-item label="云端地址">
            <el-input v-model="settingsForm.cloudUrl" placeholder="如 https://api.example.com" />
          </el-form-item>
        </div>

        <div class="settings-section">
          <div class="settings-section-title">摄像头设置</div>
          <div v-for="index in 4" :key="index" class="camera-card">
            <div class="camera-card-title">摄像头{{ index }} - {{ cameraLabels[index - 1] }}</div>
            <el-row :gutter="16">
              <el-col :span="24">
                <el-form-item :label="'摄像头地址'">
                  <el-input v-model="settingsForm['cam' + index]" placeholder="如 rtsp://..." />
                </el-form-item>
              </el-col>
              <el-col :span="12">
                <el-form-item label="账号">
                  <el-input v-model="settingsForm['username' + index]" placeholder="请输入账号" />
                </el-form-item>
              </el-col>
              <el-col :span="12">
                <el-form-item label="密码">
                  <el-input v-model="settingsForm['password' + index]" type="password" show-password placeholder="请输入密码" />
                </el-form-item>
              </el-col>
            </el-row>
          </div>
        </div>
      </el-form>
      <template #footer>
        <el-button @click="settingsDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="settingsSaving" @click="saveSettings">保存设置</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.app-container {
  height: 100vh;
  display: flex;
  flex-direction: column;
  background: #f0f2f5;
  overflow: hidden;
  position: relative;
}

.breadcrumb {
  padding: 12px 20px;
  background: #fff;
  flex-shrink: 0;
}

.settings-btn {
  position: absolute;
  top: 8px;
  right: 20px;
  z-index: 10;
}

.settings-form {
  max-height: 70vh;
  overflow-y: auto;
  padding-right: 8px;
}

.settings-section {
  margin-bottom: 18px;
  padding: 16px;
  border: 1px solid #ebeef5;
  border-radius: 10px;
  background: #fafcff;
}

.settings-section-title {
  margin-bottom: 16px;
  font-size: 15px;
  font-weight: 600;
  color: #303133;
}

.camera-card {
  padding: 14px;
  margin-bottom: 14px;
  border-radius: 8px;
  background: #fff;
  border: 1px solid #edf2f7;
}

.camera-card:last-child {
  margin-bottom: 0;
}

.camera-card-title {
  margin-bottom: 12px;
  font-size: 14px;
  font-weight: 600;
  color: #409eff;
}

.search-form {
  padding: 16px 20px 0;
  background: #fff;
  flex-shrink: 0;
}

.stats {
  text-align: center;
  font-size: 12px;
  color: #909399;
  padding: 6px 20px;
  background: #fff;
  flex-shrink: 0;
}

.toolbar {
  padding: 8px 20px;
  background: #fff;
  flex-shrink: 0;
}

.el-table {
  flex: 1;
  margin: 0 20px;
  width: calc(100% - 40px) !important;
}

.pagination-wrap {
  display: flex;
  justify-content: flex-end;
  padding: 12px 20px;
  background: #fff;
  flex-shrink: 0;
}

.create-result {
  margin-top: 12px;
  padding: 10px 14px;
  border-radius: 4px;
  font-size: 12px;
}
.create-result.ok {
  background: rgba(103, 194, 58, 0.1);
  border: 1px solid rgba(103, 194, 58, 0.3);
  color: #67c23a;
}
.create-result.err {
  background: rgba(245, 108, 108, 0.1);
  border: 1px solid rgba(245, 108, 108, 0.3);
  color: #f56c6c;
}
</style>
