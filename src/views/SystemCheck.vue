<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'

const router = useRouter()
const API = 'http://192.168.2.57/prod-api'

const checks = reactive([
  {
    key: 'fs',
    label: '正在检查系统文件完整性',
    solution: '解决方案：请重新安装本系统。',
    status: 'loading', // 'loading' | 'success' | 'error'
    expanded: false,
  },
  {
    key: 'db',
    label: '正在检测数据库系统连接',
    solution: '解决方案：请检查数据库连接设置是否正确。',
    status: 'loading',
    expanded: false,
  },
  {
    key: 'agv',
    label: '正在与车辆控制系统通信',
    solution: '解决方案：请检查巡检车IP与端口配置是否正确。',
    status: 'loading',
    expanded: false,
  },
  {
    key: 'cam',
    label: '正在检测摄像头通道状态',
    solution: '解决方案：请检查摄像头IP及账号密码是否正确。',
    status: 'loading',
    expanded: false,
  },
])

const allPassed = ref(false)
const checking = ref(false)

const endpoints = ['/system/check/fs', '/system/check/db', '/system/check/agv', '/system/check/cam']

async function runChecks() {
  checking.value = true
  allPassed.value = false

  // Reset
  checks.forEach(c => {
    c.status = 'loading'
    c.expanded = false
  })

  for (let i = 0; i < checks.length; i++) {
    try {
      const res = await fetch(API + endpoints[i])
      const data = await res.json()
      const ok = data.code === 200 || data.code === 0
      checks[i].status = ok ? 'success' : 'error'
      if (!ok) checks[i].expanded = true
    } catch (e) {
      checks[i].status = 'error'
      checks[i].expanded = true
    }
  }

  checking.value = false
  allPassed.value = checks.every(c => c.status === 'success')

  if (allPassed.value) {
    ElMessage.success('所有系统检查已通过！')
  } else {
    const failed = checks.filter(c => c.status !== 'success').length
    ElMessage.warning(failed + ' 项检查未通过，请检查配置或重新检测')
  }
}

function toggleExpand(item) {
  item.expanded = !item.expanded
}

function enterSystem() {
  router.push('/taskList')
}

onMounted(() => {
  runChecks()
})
</script>

<template>
  <div class="init-wrap">
    <div class="init-card">
      <h1>系统自检</h1>

      <div class="check-list">
        <div
          v-for="c in checks"
          :key="c.key"
          :class="['check-item', { expanded: c.expanded }]"
        >
          <div class="check-header" @click="toggleExpand(c)">
            <div :class="['check-status', c.status]">
              <span v-if="c.status === 'loading'" class="spinner"></span>
              <span v-else-if="c.status === 'success'">&#10003;</span>
              <span v-else>&#10005;</span>
            </div>
            <span>{{ c.label }}</span>
          </div>
          <div class="check-content">{{ c.solution }}</div>
        </div>
      </div>

      <div class="init-btns">
        <button class="btn" :disabled="checking" @click="runChecks">重新检测</button>
        <button class="btn btn-enter" :disabled="!allPassed" @click="enterSystem">进入系统</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.init-wrap {
  flex: 1;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 20px;
  min-height: 100vh;
  background: #f0f2f5;
}

.init-card {
  width: 440px;
  background: #fff;
  padding: 30px 32px;
  border-radius: 12px;
  box-shadow: 0 2px 16px rgba(0, 0, 0, 0.08);
}

.init-card h1 {
  text-align: center;
  font-size: 22px;
  margin-bottom: 36px;
  color: #303133;
}

.check-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-bottom: 36px;
}

.check-item {
  border: 1px solid #e4e7ed;
  border-radius: 6px;
  overflow: hidden;
  transition: all 0.3s;
}

.check-item.expanded {
  border-color: #c0c4cc;
}

.check-header {
  padding: 10px 14px;
  background: #fafafa;
  display: flex;
  align-items: center;
  cursor: pointer;
  gap: 10px;
  font-size: 14px;
}

.check-header:hover {
  background: #f0f2f5;
}

.check-status {
  width: 22px;
  height: 22px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  flex-shrink: 0;
  border: 2px solid #dcdfe6;
  color: #909399;
}

.check-status.loading {
  border-color: #409eff;
  border-top-color: transparent;
  animation: spin 0.8s linear infinite;
}

.check-status.success {
  background: #67c23a;
  border-color: #67c23a;
  color: #fff;
}

.check-status.error {
  background: #f56c6c;
  border-color: #f56c6c;
  color: #fff;
}

.check-status .spinner {
  display: block;
  width: 12px;
  height: 12px;
  border: 2px solid #e4e7ed;
  border-top-color: #409eff;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.check-content {
  display: none;
  padding: 10px 14px;
  background: #fff;
  font-size: 12px;
  color: #909399;
  line-height: 1.6;
  border-top: 1px solid #ebeef5;
}

.check-item.expanded .check-content {
  display: block;
}

.init-btns {
  display: flex;
  justify-content: center;
  gap: 12px;
}

.btn {
  padding: 8px 18px;
  border: 1px solid #dcdfe6;
  border-radius: 4px;
  background: #fff;
  cursor: pointer;
  font-size: 13px;
  transition: all 0.2s;
  white-space: nowrap;
}

.btn:hover {
  opacity: 0.85;
}

.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-enter {
  background: #67c23a;
  border-color: #67c23a;
  color: #fff;
}

.btn-enter:disabled {
  background: #a0cfff;
  border-color: #a0cfff;
}
</style>
