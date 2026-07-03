/**
 * Index.ets —— 启动页，自动跳转到系统自检页
 */
import { router } from '@kit.ArkUI'

@Entry
@Component
struct Index {
  aboutToAppear(): void {
    setTimeout(() => {
      router.pushUrl({ url: 'pages/SystemCheck' })
    }, 300)
  }

  build() {
    Column() {
      Text('地铁巡线车').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#303133')
      Text('智能巡检系统').fontSize(18).fontColor('#909399').margin({ top: 8 })
      LoadingProgress().width(36).height(36).margin({ top: 32 }).color('#409eff')
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor('#f0f2f5')
  }
}
