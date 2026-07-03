/**
 * API 服务层 —— 封装所有后端 HTTP 请求
 * 对应 web 版各 .vue 中的 fetch() 调用
 */
import { http } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { AppConfig } from '../utils/AppConfig'
import { ApiResponse, TaskInfo, HeartbeatData, FlawInfo, SystemConfig, CameraDevice, TaskQuery } from '../models/TaskModels'

const BASE = AppConfig.API_BASE

/** 简单对象转查询字符串（ArkTS 无 URLSearchParams） */
function buildQuery(params: Record<string, string>): string {
  const parts: string[] = []
  const keys = Object.keys(params)
  for (let i = 0; i < keys.length; i++) {
    const k = keys[i]
    if (params[k] && params[k].length > 0) {
      parts.push(k + '=' + encodeURIComponent(params[k]))
    }
  }
  return parts.join('&')
}

/** 通用 GET 请求 */
async function apiGet<T>(url: string, timeout: number = 5000): Promise<ApiResponse<T>> {
  const req = http.createHttp()
  try {
    const resp = await req.request(url, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: timeout,
      readTimeout: timeout,
    })
    req.destroy()
    if (resp.responseCode === 200) {
      const result: ApiResponse<T> = JSON.parse(resp.result as string) as ApiResponse<T>
      return result
    }
    return { code: -1, msg: 'HTTP ' + resp.responseCode } as ApiResponse<T>
  } catch (e) {
    req.destroy()
    return { code: -1, msg: 'Network error' } as ApiResponse<T>
  }
}

/** 通用 POST 请求 */
async function apiPost<T>(url: string, body: Object | null, headers: Record<string, string> | null, timeout: number = 5000): Promise<ApiResponse<T>> {
  const req = http.createHttp()
  const reqHeaders: Record<string, string> = { 'Content-Type': 'application/json' }
  if (headers) {
    const hKeys = Object.keys(headers)
    for (let i = 0; i < hKeys.length; i++) {
      reqHeaders[hKeys[i]] = headers[hKeys[i]]
    }
  }
  try {
    const resp = await req.request(url, {
      method: http.RequestMethod.POST,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: timeout,
      readTimeout: timeout,
      header: reqHeaders,
      extraData: body ? JSON.stringify(body) : undefined,
    })
    req.destroy()
    if (resp.responseCode === 200) {
      const result: ApiResponse<T> = JSON.parse(resp.result as string) as ApiResponse<T>
      return result
    }
    return { code: -1, msg: 'HTTP ' + resp.responseCode } as ApiResponse<T>
  } catch (e) {
    req.destroy()
    return { code: -1, msg: 'Network error' } as ApiResponse<T>
  }
}

/** 通用 PUT 请求 */
async function apiPut<T>(url: string, body: Object | null, headers: Record<string, string> | null, timeout: number = 5000): Promise<ApiResponse<T>> {
  const req = http.createHttp()
  const reqHeaders: Record<string, string> = { 'Content-Type': 'application/json' }
  if (headers) {
    const hKeys = Object.keys(headers)
    for (let i = 0; i < hKeys.length; i++) {
      reqHeaders[hKeys[i]] = headers[hKeys[i]]
    }
  }
  try {
    const resp = await req.request(url, {
      method: http.RequestMethod.PUT,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: timeout,
      readTimeout: timeout,
      header: reqHeaders,
      extraData: body ? JSON.stringify(body) : undefined,
    })
    req.destroy()
    if (resp.responseCode === 200) {
      const result: ApiResponse<T> = JSON.parse(resp.result as string) as ApiResponse<T>
      return result
    }
    return { code: -1, msg: 'HTTP ' + resp.responseCode } as ApiResponse<T>
  } catch (e) {
    req.destroy()
    return { code: -1, msg: 'Network error' } as ApiResponse<T>
  }
}

/** 通用 DELETE 请求 */
async function apiDelete<T>(url: string): Promise<ApiResponse<T>> {
  const req = http.createHttp()
  try {
    const resp = await req.request(url, {
      method: http.RequestMethod.DELETE,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 5000,
      readTimeout: 5000,
    })
    req.destroy()
    if (resp.responseCode === 200) {
      const result: ApiResponse<T> = JSON.parse(resp.result as string) as ApiResponse<T>
      return result
    }
    return { code: -1, msg: 'HTTP ' + resp.responseCode } as ApiResponse<T>
  } catch (e) {
    req.destroy()
    return { code: -1, msg: 'Network error' } as ApiResponse<T>
  }
}

export class ApiService {
  // ==================== 系统自检 ====================

  static checkFs(): Promise<ApiResponse<Object>> {
    return apiGet(BASE + '/system/check/fs')
  }

  static checkDb(): Promise<ApiResponse<Object>> {
    return apiGet(BASE + '/system/check/db')
  }

  static checkAgv(): Promise<ApiResponse<Object>> {
    return apiGet(BASE + '/system/check/agv')
  }

  static checkCam(): Promise<ApiResponse<Object>> {
    return apiGet(BASE + '/system/check/cam')
  }

  // ==================== 系统配置 ====================

  static getConfig(): Promise<ApiResponse<SystemConfig>> {
    return apiGet(BASE + '/agv/config')
  }

  static saveConfig(config: SystemConfig): Promise<ApiResponse<Object>> {
    return apiPut(BASE + '/agv/config', config, null)
  }

  // ==================== 任务 CRUD ====================

  static getTaskList(query: TaskQuery): Promise<ApiResponse<TaskInfo>> {
    const params: Record<string, string> = {
      'pageNum': String(query.pageNum),
      'pageSize': String(query.pageSize),
      'taskCode': query.taskCode,
      'creator': query.creator,
      'executor': query.executor,
      'taskStatus': query.taskStatus,
    }
    const qs = buildQuery(params)
    return apiGet(BASE + '/agv/task/list?' + qs)
  }

  static getTaskDetail(id: number): Promise<ApiResponse<TaskInfo>> {
    return apiGet(BASE + '/agv/task/' + id)
  }

  static createTask(task: SystemConfig): Promise<ApiResponse<Object>> {
    return apiPost(BASE + '/agv/task', task, null)
  }

  static updateTask(task: SystemConfig): Promise<ApiResponse<Object>> {
    return apiPut(BASE + '/agv/task', task, null)
  }

  static deleteTask(id: number): Promise<ApiResponse<Object>> {
    return apiDelete(BASE + '/agv/task/' + id)
  }

  // ==================== 任务生命周期 ====================

  static startTask(id: number): Promise<ApiResponse<Object>> {
    return apiPost(BASE + '/agv/task/start/' + id, null, null)
  }

  static endTask(id: number, isAbort: boolean): Promise<ApiResponse<Object>> {
    return apiPost(BASE + '/agv/task/end/' + id + '?isAbort=' + String(isAbort), null, null)
  }

  static uploadTask(id: number): Promise<ApiResponse<Object>> {
    return apiPost(BASE + '/agv/task/upload/' + id, null, null)
  }

  // ==================== 车辆控制 ====================

  static moveForward(): Promise<ApiResponse<Object>> {
    return apiPost(BASE + '/agv/movement/forward', null, null)
  }

  static moveBackward(): Promise<ApiResponse<Object>> {
    return apiPost(BASE + '/agv/movement/backward', null, null)
  }

  static moveStop(): Promise<ApiResponse<Object>> {
    return apiPost(BASE + '/agv/movement/stop', null, null)
  }

  static getHeartbeat(): Promise<ApiResponse<HeartbeatData>> {
    return apiGet(BASE + '/agv/movement/heartbeat')
  }

  // ==================== 缺陷管理 ====================

  static getFlawList(taskId: number): Promise<ApiResponse<FlawInfo>> {
    return apiGet(BASE + '/agv/flaw/list?taskId=' + taskId + '&pageNum=1&pageSize=999')
  }

  static getLiveFlaw(taskId: number): Promise<ApiResponse<FlawInfo>> {
    return apiGet(BASE + '/agv/flaw/live/' + taskId)
  }

  static updateFlaw(flaw: SystemConfig): Promise<ApiResponse<Object>> {
    return apiPut(BASE + '/agv/flaw', flaw, null)
  }

  // ==================== 摄像头 ====================

  static async getCameraDevices(): Promise<ApiResponse<CameraDevice>> {
    const req = http.createHttp()
    try {
      const resp = await req.request(AppConfig.EASY_API_BASE + '/devices?page=1&size=999&status=&id&name', {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 5000,
        readTimeout: 5000,
        header: { 'Authorization': AppConfig.EASY_AUTH },
      })
      req.destroy()
      if (resp.responseCode === 200) {
        const result: ApiResponse<CameraDevice> = JSON.parse(resp.result as string) as ApiResponse<CameraDevice>
        return result
      }
      return { code: -1, msg: 'HTTP ' + resp.responseCode } as ApiResponse<CameraDevice>
    } catch (e) {
      req.destroy()
      return { code: -1, msg: 'Network error' } as ApiResponse<CameraDevice>
    }
  }

  // ==================== Dify AI 缺陷分析 ====================

  static async analyzeFlawWithDify(flaw: SystemConfig): Promise<string> {
    const body: Record<string, Object> = {
      'inputs': {
        'flawType': '',
        'flawLevel': '未知',
        'flawArea': 0,
        'flawLength': 0,
        'flawDistance': 0,
      } as Record<string, Object>,
      'query': '请分析这条地铁隧道巡检缺陷数据。',
      'response_mode': 'blocking',
      'conversation_id': '',
      'user': AppConfig.DIFY_USER,
    }

    const req = http.createHttp()
    try {
      const resp = await req.request(AppConfig.DIFY_API_URL, {
        method: http.RequestMethod.POST,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: AppConfig.DIFY_TIMEOUT_MS,
        readTimeout: AppConfig.DIFY_TIMEOUT_MS,
        header: {
          'Authorization': 'Bearer ' + AppConfig.DIFY_API_KEY,
          'Content-Type': 'application/json; charset=utf-8',
        },
        extraData: JSON.stringify(body),
      })
      req.destroy()
      return resp.result as string
    } catch (e) {
      req.destroy()
      return '{}'
    }
  }

  // ==================== AI 巡检报告 ====================

  static async generateAiReport(taskInfo: SystemConfig, flawList: SystemConfig[]): Promise<string> {
    const body: Record<string, Object> = {
      'task_info': JSON.stringify({
        'taskCode': '',
        'taskName': '',
        'execTime': '',
        'totalFlaws': flawList.length,
        'confirmedFlaws': 0,
      } as Record<string, Object>),
      'flaw_list': JSON.stringify(flawList),
      'query': '请生成巡检报告',
      'response_mode': 'blocking',
      'user': AppConfig.REPORT_AI_USER,
    }

    const req = http.createHttp()
    const headers: Record<string, string> = {
      'Authorization': 'Bearer ' + AppConfig.REPORT_AI_API_KEY,
      'Content-Type': 'application/json; charset=utf-8',
    }
    try {
      const resp = await req.request(AppConfig.REPORT_AI_API_URL, {
        method: http.RequestMethod.POST,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: AppConfig.REPORT_AI_TIMEOUT_MS,
        readTimeout: AppConfig.REPORT_AI_TIMEOUT_MS,
        header: headers,
        extraData: JSON.stringify(body),
      })
      req.destroy()
      return resp.result as string
    } catch (e) {
      req.destroy()
      return '{}'
    }
  }
}
