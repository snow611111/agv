/**
 * TaskInfoTest.ets —— 任务详情 API 调试页
 */
import { router } from '@kit.ArkUI'
import http from '@ohos.net.http'

const BASE = 'http://192.168.2.57/prod-api'

@Entry
@Component
struct TaskInfoTest {
  @State taskId: string = '1'
  @State rawJson: string = '点击按钮发起请求'
  @State code: string = '--'
  @State keys: string = '--'
  @State loading: boolean = false

  async doFetch(): Promise<void> {
    this.loading = true
    this.rawJson = '请求中...'
    const url = BASE + '/agv/task/' + this.taskId
    const req = http.createHttp()
    try {
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 120000,
      })
      req.destroy()
      const text = (resp.result as string) || '(empty)'
      this.rawJson = text
      try {
        const data = JSON.parse(text) as Record<string, Object>
        this.code = String(data['code'] ?? 'undefined')
        const src = data['data'] as Record<string, Object>
        if (src) {
          this.keys = Object.keys(src).join(', ')
        } else {
          this.keys = 'data 字段为空，尝试把整个响应当数据'
          // fallback: show all top-level keys
          this.keys = 'top keys: ' + Object.keys(data).join(', ')
        }
      } catch (e) {
        this.code = 'JSON parse error'
        this.keys = String(e)
      }
    } catch (e) {
      req.destroy()
      this.rawJson = '网络错误: ' + JSON.stringify(e)
      this.code = 'error'
      this.keys = 'error'
    }
    this.loading = false
  }

  build() {
    Column() {
      Row() {
        Button('<-- 返回').fontSize(12).height(32)
          .onClick(() => router.back())
        Text('任务详情 API 测试').fontSize(18).fontWeight(FontWeight.Bold)
          .fontColor('#67C23A').margin({ left: 12 })
      }
      .width('100%').padding(16).backgroundColor(Color.White)

      Row() {
        Text('Task ID:').fontSize(14).width(80)
        TextInput({ text: this.taskId })
          .fontSize(14).height(40).layoutWeight(1)
          .type(InputType.Number)
          .onChange((v: string) => { this.taskId = v })
        Button('请求').fontSize(14).height(40).margin({ left: 12 })
          .backgroundColor('#67C23A').fontColor(Color.White).borderRadius(8)
          .enabled(!this.loading)
          .onClick(() => { this.doFetch() })
      }
      .width('100%').padding(16)

      Text('响应 code: ' + this.code)
        .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#409EFF')
        .width('100%').padding({ left: 16, right: 16, top: 8 })

      Text('data 字段 keys: ' + this.keys)
        .fontSize(12).fontColor('#909399')
        .width('100%').padding({ left: 16, right: 16, bottom: 8 })

      Text('原始 JSON 响应:')
        .fontSize(14).fontWeight(FontWeight.Bold)
        .width('100%').padding({ left: 16, top: 12 })

      Scroll() {
        Text(this.rawJson)
          .fontSize(11).fontColor('#606266').lineHeight(18)
          .width('100%').padding(16)
          .fontFamily('monospace')
      }
      .layoutWeight(1).width('100%')
      .backgroundColor('#F8FAFC').borderRadius(8).margin({ left: 16, right: 16, bottom: 16 })
    }
    .width('100%').height('100%').backgroundColor('#F0F2F5')
  }
}
