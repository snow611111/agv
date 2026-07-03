/**
 * CameraTest.ets —— 摄像头调试页
 * 对应 web 版: camer_test_vue_version.vue
 */
import { router } from '@kit.ArkUI'
import { webview } from '@kit.ArkWeb'
import { AppConfig } from '../common/utils/AppConfig'

@Entry
@Component
struct CameraTest {
  @State currentMode: string = 'flv'
  private controllers: webview.WebviewController[] = [
    new webview.WebviewController(),
    new webview.WebviewController(),
    new webview.WebviewController(),
    new webview.WebviewController(),
  ]

  aboutToAppear(): void {
    this.loadAllCameras()
  }

  buildCamUrl(index: number): string {
    const cam = index + 1
    if (this.currentMode === 'flv') {
      return AppConfig.LOCAL_STREAM_ORIGIN + '/flv/cam' + cam
    }
    return AppConfig.LOCAL_STREAM_ORIGIN + '/hls_output/cam' + cam + '/index.m3u8'
  }

  loadAllCameras(): void {
    for (let i = 0; i < 4; i++) {
      const url = 'resource://rawfile/player.html?mode=' + this.currentMode +
        '&url=' + encodeURIComponent(this.buildCamUrl(i)) + '&cam=' + (i + 1)
      this.controllers[i].loadUrl(url)
    }
  }

  switchMode(mode: string): void {
    this.currentMode = mode
    this.loadAllCameras()
  }

  build() {
    Column() {
      Row() {
        Button('<-- 返回').fontSize(12).height(32).onClick(() => router.back())
        Text('摄像头调试').fontSize(18).fontWeight(FontWeight.Bold).margin({ left: 12 })
        Blank()
        Button('FLV').fontSize(11).height(28)
          .type(this.currentMode === 'flv' ? ButtonType.Capsule : ButtonType.Normal)
          .fontColor(this.currentMode === 'flv' ? Color.White : '#606266')
          .backgroundColor(this.currentMode === 'flv' ? '#409eff' : '#f0f2f5')
          .onClick(() => this.switchMode('flv'))
        Button('HLS').fontSize(11).height(28)
          .type(this.currentMode === 'hls' ? ButtonType.Capsule : ButtonType.Normal)
          .fontColor(this.currentMode === 'hls' ? Color.White : '#606266')
          .backgroundColor(this.currentMode === 'hls' ? '#409eff' : '#f0f2f5')
          .onClick(() => this.switchMode('hls')).margin({ left: 4 })
      }
      .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .backgroundColor('#1a1a2e')

      Grid() {
        ForEach([0, 1, 2, 3], (i: number) => {
          GridItem() {
            Stack() {
              Web({ src: '', controller: this.controllers[i] })
                .width('100%').height('100%')
                .backgroundColor(Color.Black).javaScriptAccess(true)

              Text(AppConfig.CAMERAS[i].name)
                .fontSize(11).fontColor('#fff')
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor('rgba(0,0,0,0.7)').borderRadius(4)
                .position({ x: 6, y: 6 })
            }
          }
          .border({ width: 1, color: '#333' })
        })
      }
      .columnsTemplate('1fr 1fr').rowsTemplate('1fr 1fr')
      .width('100%').layoutWeight(1).padding(8)
      .backgroundColor('#0f3460')
    }
    .width('100%').height('100%')
  }
}
