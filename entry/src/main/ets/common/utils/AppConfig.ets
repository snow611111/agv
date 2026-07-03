/**
 * 应用配置 —— 替代 web 版 .env 文件
 * 修改这里的值即可切换后端地址 / AI Key 等
 */

export interface CameraConfig {
  name: string
  rtsp: string
}

export class AppConfig {
  // ========== 后端服务地址 ==========
  static readonly BACKEND_ORIGIN: string = 'http://192.168.2.57'
  static readonly API_BASE: string = AppConfig.BACKEND_ORIGIN + '/prod-api'
  static readonly IMG_BASE: string = AppConfig.API_BASE + '/file'
  static readonly RTC_BASE: string = AppConfig.BACKEND_ORIGIN + '/webrtc-api'
  static readonly EASY_API_BASE: string = AppConfig.BACKEND_ORIGIN + '/easy-api'
  static readonly EASY_AUTH: string = 'Basic YWRtaW4xMjM6QWRtaW5AMTIz'
  static readonly EASY_PLAYER_LIB_URL: string = AppConfig.BACKEND_ORIGIN + '/easyplayer/EasyPlayer-lib.js'
  static readonly LOCAL_STREAM_ORIGIN: string = 'http://127.0.0.1:8088'

  // ========== Dify AI (单条缺陷分析) ==========
  static readonly DIFY_APP_ID: string = 'ab90ca0c-95b9-4cbb-9f24-97166e6c5032'
  static readonly DIFY_API_KEY: string = 'app-ix0KtVqKKJIJ8Jk5t2bkotVa'
  static readonly DIFY_API_URL: string = 'http://192.168.2.53/v1/chat-messages'
  static readonly DIFY_USER: string = 'inspector-001'
  static readonly DIFY_TIMEOUT_MS: number = 120000
  static readonly DIFY_USE_MOCK: boolean = false

  // ========== AI 巡检报告 ==========
  static readonly REPORT_AI_API_URL: string = ''
  static readonly REPORT_AI_API_KEY: string = ''
  static readonly REPORT_AI_USER: string = 'agv-terminal'
  static readonly REPORT_AI_TIMEOUT_MS: number = 300000

  // ========== 摄像头 RTSP 地址（4路） ==========
  static readonly CAMERAS: CameraConfig[] = [
    { name: '摄像头1', rtsp: 'rtsp://admin:Admin123@192.168.2.14:554' } as CameraConfig,
    { name: '摄像头2', rtsp: 'rtsp://admin:Admin123@192.168.2.13:554' } as CameraConfig,
    { name: '摄像头3', rtsp: 'rtsp://admin:Admin123@192.168.2.12:554' } as CameraConfig,
    { name: '摄像头4', rtsp: 'rtsp://admin:Admin123@192.168.2.11:554' } as CameraConfig,
  ]
}
