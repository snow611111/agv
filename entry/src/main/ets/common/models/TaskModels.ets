/**
 * 数据模型 —— 对应后端 JSON 返回结构
 */

// ========== 响应包裹 ==========
export interface ApiResponse<T> {
  code: number
  msg: string
  data: T
  rows: T[]
  total: number
}

// ========== 任务 ==========
export interface TaskInfo {
  id: number
  taskCode: string
  taskName: string
  creator: string
  executor: string
  taskStatus: string
  taskTrip: string
  startPos: string
  taskRound: string
  execTime: string
  endTime: string
  remark: string
}

// ========== 车辆心跳 ==========
export interface HeartbeatData {
  isRunning: boolean
  currentPosition: number
  sysTime: string
}

// ========== 缺陷 ==========
export interface FlawInfo {
  id: number
  taskId: number
  flawName: string
  flawType: string
  flawDesc: string
  flawLevel: string
  flawDistance: number
  flawArea: number
  flawLength: number
  flawImageUrl: string
  flawImage: string
  countNum: number
  confirmed: boolean
  remark: string
  shown: boolean
  createTime: string
}

// ========== 系统检查 ==========
export interface CheckItem {
  key: string
  label: string
  status: string
  solution: string
  expanded: boolean
}

// ========== 系统配置 ==========
export class SystemConfig {
  vehicleIp: string = ''
  vehiclePort: string = ''
  cloudUrl: string = ''

  constructor() {}
}

// ========== 摄像头设备 ==========
export interface CameraDevice {
  id: string
  name: string
  status: string
}

// ========== AI 分析结果 ==========
export interface AiResult {
  isPlainAnswer: boolean
  severity: string
  severity_label: string
  cause_analysis: string
  risk_assessment: string
  repair_suggestion: string
  reference_standards: string
  answer: string
  conversation_id: string
}

// ========== 任务列表查询参数 ==========
export class TaskQuery {
  pageNum: number = 1
  pageSize: number = 10
  taskCode: string = ''
  creator: string = ''
  executor: string = ''
  taskStatus: string = ''

  constructor() {}
}

// ========== 刻度条缺陷标记 ==========
export interface FlawMarker {
  id: number
  left: number
  flawName: string
  confirmed: boolean
}

// ========== HTTP 请求选项 ==========
export class HttpReqOptions {
  method?: string
  header?: Record<string, string>
  extraData?: string
  connectTimeout?: number
  readTimeout?: number

  constructor() {}
}
