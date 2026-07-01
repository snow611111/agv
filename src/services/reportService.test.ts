import { describe, it, expect } from 'vitest'
import {
  buildReportRequest,
  extractReportContent,
  buildReportErrorMessage,
} from './reportService'

// ================================================================
// AI 巡检报告生成模块 — 单元测试
// 覆盖：请求体构造 / 报告内容解析 / 异常错误处理
// ================================================================

describe('AI巡检报告生成模块', () => {
  // ----------------------------------------------------------------
  // buildReportRequest
  // ----------------------------------------------------------------
  describe('buildReportRequest() - Dify 请求体构造', () => {
    it('正常任务和故障列表应构造正确的请求体', () => {
      const taskInfo = {
        taskCode: 'TASK002',
        taskName: '隧道重点巡检',
        taskTrip: 800,
        executor: '李四',
        execTime: '2026-06-24 09:00:00',
        endTime: '2026-06-24 10:30:00',
        taskStatus: '已完成',
      }

      const flawList = [
        {
          flawType: '结构缺陷',
          flawName: '隧道壁面裂缝',
          flawDistance: 120,
          confirmed: true,
        },
      ]

      const body = buildReportRequest(taskInfo, flawList)

      // 固定字段
      expect(body.response_mode).toBe('blocking')
      expect(body.user).toBe('agv-terminal')

      // task_info 经 JSON.stringify 后能正确反序列化
      const parsedTaskInfo = JSON.parse(body.inputs.task_info)
      expect(parsedTaskInfo.taskCode).toBe('TASK002')
      expect(parsedTaskInfo.taskName).toBe('隧道重点巡检')
      expect(parsedTaskInfo.taskTrip).toBe(800)
      expect(parsedTaskInfo.executor).toBe('李四')

      // flaw_list 经 JSON.stringify 后能正确反序列化
      const parsedFlawList = JSON.parse(body.inputs.flaw_list)
      expect(parsedFlawList).toHaveLength(1)
      expect(parsedFlawList[0].flawType).toBe('结构缺陷')
      expect(parsedFlawList[0].flawName).toBe('隧道壁面裂缝')
      expect(parsedFlawList[0].flawDistance).toBe(120)
      expect(parsedFlawList[0].confirmed).toBe(true)
    })

    it('故障列表为空时应正常构造请求体', () => {
      const taskInfo = {
        taskCode: 'TASK001',
        taskName: '隧道例行巡检',
      }

      const body = buildReportRequest(taskInfo, [])

      expect(JSON.parse(body.inputs.flaw_list)).toEqual([])
      expect(body.inputs.upload_info).toBe('')
    })

    it('upload_info 默认值应为空字符串', () => {
      const taskInfo = { taskCode: 'TASK003', taskName: '日常巡检' }

      const body = buildReportRequest(taskInfo, [])

      expect(body.inputs.upload_info).toBe('')
    })

    it('upload_info 传入时应正确赋值', () => {
      const taskInfo = { taskCode: 'TASK004', taskName: '设备巡检' }
      const uploadData = '{"images":["img001.jpg"]}'

      const body = buildReportRequest(taskInfo, [], uploadData)

      expect(body.inputs.upload_info).toBe(uploadData)
    })

    it('taskInfo 中缺少可选字段时不影响请求构造', () => {
      const taskInfo = {
        taskCode: 'TASK005',
        taskName: '快速巡检',
      }

      const body = buildReportRequest(taskInfo, [])

      const parsed = JSON.parse(body.inputs.task_info)
      expect(parsed.taskCode).toBe('TASK005')
      expect(parsed.execTime).toBeUndefined()
      expect(parsed.taskTrip).toBeUndefined()
    })

    it('多条故障记录应全部包含在请求体中', () => {
      const taskInfo = { taskCode: 'TASK006', taskName: '综合巡检' }
      const flawList = [
        { flawType: '结构缺陷', flawName: '裂缝A', flawDistance: 100, confirmed: true },
        { flawType: '渗漏问题', flawName: '渗水点B', flawDistance: 350, confirmed: false },
        { flawType: '设备故障', flawName: '传感器异常', confirmed: false },
      ]

      const body = buildReportRequest(taskInfo, flawList)
      const parsed = JSON.parse(body.inputs.flaw_list)

      expect(parsed).toHaveLength(3)
      expect(parsed[1].flawType).toBe('渗漏问题')
      expect(parsed[2].flawName).toBe('传感器异常')
    })
  })

  // ----------------------------------------------------------------
  // extractReportContent
  // ----------------------------------------------------------------
  describe('extractReportContent() - Dify 结果解析', () => {
    it('应正确解析 Dify 返回的巡检报告内容', () => {
      const response = {
        data: {
          outputs: {
            report_content: '一、任务基本信息\n任务编号：TASK002\n任务名称：隧道重点巡检',
          },
        },
      }

      const content = extractReportContent(response)

      expect(content).toContain('任务基本信息')
      expect(content).toContain('TASK002')
    })

    it('应返回完整的报告正文', () => {
      const reportText =
        '一、任务基本信息\n任务编号：TASK003\n' +
        '二、巡检执行情况\n开始时间：2026-06-24 09:00:00\n' +
        '三、故障统计\n故障总数：2\n' +
        '四、主要故障记录\n1. 裂缝A\n2. 渗水点B\n' +
        '五、处理建议\n对已确认故障进行后续处置\n' +
        '六、数据完整性\n故障信息基本完整\n' +
        '七、巡检结论\n本次巡检共发现2处故障'

      const response = {
        data: {
          outputs: {
            report_content: reportText,
          },
        },
      }

      const content = extractReportContent(response)

      expect(content).toBe(reportText)
      expect(content).toContain('七、巡检结论')
    })

    it('缺少 report_content 时应抛出异常', () => {
      const response = {
        data: {
          outputs: {},
        },
      }

      expect(() => extractReportContent(response)).toThrow('巡检报告生成结果为空')
    })

    it('outputs 为 null 时应抛出异常', () => {
      const response = {
        data: {
          outputs: null,
        },
      }

      expect(() => extractReportContent(response)).toThrow('巡检报告生成结果为空')
    })

    it('data 为 null 时应抛出异常', () => {
      const response = {
        data: null,
      }

      expect(() => extractReportContent(response)).toThrow('巡检报告生成结果为空')
    })

    it('空字符串 report_content 应视为无效', () => {
      const response = {
        data: {
          outputs: {
            report_content: '',
          },
        },
      }

      expect(() => extractReportContent(response)).toThrow('巡检报告生成结果为空')
    })

    it('response 为 null/undefined 时应抛出异常', () => {
      expect(() => extractReportContent(null)).toThrow('巡检报告生成结果为空')
      expect(() => extractReportContent(undefined)).toThrow('巡检报告生成结果为空')
    })
  })

  // ----------------------------------------------------------------
  // buildReportErrorMessage
  // ----------------------------------------------------------------
  describe('buildReportErrorMessage() - 异常错误处理', () => {
    it('应正确处理 401 认证失败', () => {
      const message = buildReportErrorMessage({ status: 401 })

      expect(message).toBe('AI报告接口认证失败')
    })

    it('应正确处理 404 地址或模型配置错误', () => {
      const message = buildReportErrorMessage({ status: 404 })

      expect(message).toBe('AI报告接口地址或模型配置错误')
    })

    it('应正确处理超时错误', () => {
      const message = buildReportErrorMessage({ message: 'request timeout' })

      expect(message).toBe('AI报告生成超时')
    })

    it('应正确处理 Dify 业务失败（status=failed）', () => {
      const error = {
        data: {
          status: 'failed',
          error: 'LLM generation timeout',
        },
      }

      const message = buildReportErrorMessage(error)

      expect(message).toContain('AI报告生成失败')
      expect(message).toContain('LLM generation timeout')
    })

    it('未知错误应返回默认错误信息', () => {
      const message = buildReportErrorMessage({ someUnknownField: '???' })

      expect(message).toBe('AI报告生成失败')
    })

    it('空对象应返回默认错误信息', () => {
      const message = buildReportErrorMessage({})

      expect(message).toBe('AI报告生成失败')
    })

    it('null/undefined 应返回默认错误信息', () => {
      expect(buildReportErrorMessage(null)).toBe('AI报告生成失败')
      expect(buildReportErrorMessage(undefined)).toBe('AI报告生成失败')
    })
  })
})
