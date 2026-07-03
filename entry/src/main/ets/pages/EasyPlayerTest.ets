/**
 * EasyPlayerTest.ets —— EasyPlayer 视频流测试页
 * 直连 192.168.2.57，不经过 stream-server
 */
import { router } from '@kit.ArkUI'
import { webview } from '@kit.ArkWeb'

const HTTP_BASE = 'http://172.21.128.1:8088'
const STREAM_BASE = HTTP_BASE

@Entry
@Component
struct EasyPlayerTest {
  private controller: webview.WebviewController = new webview.WebviewController()
  @State cam: number = 1
  @State ready: boolean = false

  onPageReady(): void {
    this.ready = true
    const url = STREAM_BASE + '/flv/cam' + this.cam + '.flv'
    this.controller.runJavaScript('startEasy("' + url + '")')
  }

  switchCam(i: number): void {
    this.cam = i
    const url = STREAM_BASE + '/flv/cam' + i + '.flv'
    this.controller.runJavaScript('startEasy("' + url + '")')
  }

  build() {
    Column() {
      Row() {
        Button('<-- 返回').fontSize(12).height(32).onClick(() => router.back())
        Text('EasyPlayer 测试').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#67C23A').margin({ left: 12 })
        Blank()
        Text(this.ready ? 'cam' + this.cam : '加载中...').fontSize(10).fontColor('#909399')
      }
      .width('100%').padding(16).backgroundColor(Color.White)

      Web({ src: HTTP_BASE + '/player-easy.html', controller: this.controller })
        .width('100%').layoutWeight(1)
        .backgroundColor(Color.Black)
        .javaScriptAccess(true)
        .onPageEnd(() => {
          this.onPageReady()
        })

      Row() {
        Button('1').fontSize(12).height(32)
          .backgroundColor(this.cam === 1 ? '#67C23A' : '#F0F2F5')
          .fontColor(this.cam === 1 ? Color.White : '#606266')
          .border({ width: 1, color: '#DCDFE6', radius: 3 }).margin({ left: 4, right: 4 })
          .enabled(this.ready)
          .onClick(() => { this.switchCam(1) })
        Button('2').fontSize(12).height(32)
          .backgroundColor(this.cam === 2 ? '#67C23A' : '#F0F2F5')
          .fontColor(this.cam === 2 ? Color.White : '#606266')
          .border({ width: 1, color: '#DCDFE6', radius: 3 }).margin({ left: 4, right: 4 })
          .enabled(this.ready)
          .onClick(() => { this.switchCam(2) })
        Button('3').fontSize(12).height(32)
          .backgroundColor(this.cam === 3 ? '#67C23A' : '#F0F2F5')
          .fontColor(this.cam === 3 ? Color.White : '#606266')
          .border({ width: 1, color: '#DCDFE6', radius: 3 }).margin({ left: 4, right: 4 })
          .enabled(this.ready)
          .onClick(() => { this.switchCam(3) })
        Button('4').fontSize(12).height(32)
          .backgroundColor(this.cam === 4 ? '#67C23A' : '#F0F2F5')
          .fontColor(this.cam === 4 ? Color.White : '#606266')
          .border({ width: 1, color: '#DCDFE6', radius: 3 }).margin({ left: 4, right: 4 })
          .enabled(this.ready)
          .onClick(() => { this.switchCam(4) })
      }
      .width('100%').justifyContent(FlexAlign.Center).padding(12)
    }
    .width('100%').height('100%').backgroundColor('#F0F2F5')
  }
}
