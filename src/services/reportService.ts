// ============================================================
// AI 巡检报告生成模块 — 请求构造 / 结果解析 / 错误处理
// 对接 Dify Workflow API: POST /v1/workflows/run
// ============================================================

/** 任务基本信息 */
export interface ReportTaskInfo {
  taskCode?: string
  taskName?: string
  /** 巡检里程（米） */
  taskTrip?: number
  executor?: string
  /** 巡检开始时间 */
  execTime?: string
  /** 巡检结束时间 */
  endTime?: string
  /** 任务状态 */
  taskStatus?: string
}

/** 故障记录 */
export interface ReportFlawInfo {
  /** 故障类型（结构缺陷/渗漏问题/设备故障等） */
  flawType?: string
  /** 故障名称 */
  flawName?: string
  /** 故障描述 */
  flawDesc?: string
  /** 故障位置距离（米） */
  flawDistance?: number
  /** 是否已确认 */
  confirmed?: boolean
}

/**
 * 将 taskInfo、flawList、uploadInfo 转成 Dify 工作流请求体
 *
 * @param taskInfo  任务基本信息
 * @param flawList  故障列表
 * @param uploadInfo 上传检查结果 JSON 字符串（可选）
 * @returns Dify Workflow 请求体
 */
export function buildReportRequest(
  taskInfo: ReportTaskInfo,
  flawList: ReportFlawInfo[],
  uploadInfo: string = '',
) {
  return {
    inputs: {
      task_info: JSON.stringify(taskInfo),
      flaw_list: JSON.stringify(flawList),
      upload_info: uploadInfo,
    },
    response_mode: 'blocking',
    user: 'agv-terminal',
  }
}

/**
 * 从 Dify 返回结果中取出 report_content
 *
 * @param response Dify Workflow 阻塞模式返回的完整响应体
 * @returns 巡检报告正文（Markdown 字符串）
 * @throws 当 data.outputs.report_content 不存在或为空时
 */
export function extractReportContent(response: any): string {
  const content = response?.data?.outputs?.report_content

  if (!content) {
    throw new Error('巡检报告生成结果为空')
  }

  return content
}

/**
 * 将 Dify 调用异常转成前端可展示的中文错误信息
 *
 * @param error Dify 返回的错误对象或 axios/网络异常
 * @returns 面向用户的中文错误提示
 */
export function buildReportErrorMessage(error: any): string {
  // HTTP 401
  if (error?.status === 401) {
    return 'AI报告接口认证失败'
  }

  // HTTP 404
  if (error?.status === 404) {
    return 'AI报告接口地址或模型配置错误'
  }

  // 超时
  if (error?.message?.includes('timeout')) {
    return 'AI报告生成超时'
  }

  // 服务端返回的业务错误
  if (error?.data?.status === 'failed') {
    return `AI报告生成失败：${error.data.error || '未知错误'}`
  }

  // 默认兜底
  return 'AI报告生成失败'
}
