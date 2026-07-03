/**
 * 格式化工具函数 —— 对应 web 版各 .vue 中的格式化方法
 */

export class Formatters {
  /** 格式化距离 */
  static formatDistance(value: number | null | undefined): string {
    if (value == null || value === undefined) return '--'
    return value + ' m'
  }

  /** 格式化带单位的度量值 */
  static formatMeasure(value: number | null | undefined, unit: string): string {
    if (value == null || value === undefined) return '--'
    return value + ' ' + unit
  }

  /** 严重程度对应 CSS 颜色类名 */
  static severityColor(severity: string): string {
    if (severity === '高') return '#f56c6c'
    if (severity === '中') return '#e6a23c'
    return '#67c23a'
  }

  /** 任务状态对应颜色 */
  static taskStatusColor(status: string): string {
    switch (status) {
      case '巡视中': return '#409eff'
      case '已完成': return '#67c23a'
      case '待巡视': return '#e6a23c'
      case '待上传': return '#909399'
      default: return '#909399'
    }
  }

  /** 格式化速度 */
  static formatSpeed(speed: number): string {
    return speed >= 1000
      ? (speed / 1000).toFixed(1) + 'MB/s'
      : speed.toFixed(0) + 'KB/s'
  }
}
