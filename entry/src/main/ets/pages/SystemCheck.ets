/**
 * SystemCheck.ets —— 从 old_hm 直接复制
 */
import { router } from '@kit.ArkUI';
import { getCheckItems, runSystemCheck, CheckResult } from './AgvApi';
import { promptAction } from '@kit.ArkUI';

@Entry
@Component
struct SystemCheckPage {
  @State checks: CheckResult[] = getCheckItems();
  @State allPassed: boolean = false;
  @State checking: boolean = false;

  aboutToAppear(): void {
    this.doCheck();
  }

  async doCheck(): Promise<void> {
    this.checking = true;
    this.checks = getCheckItems();
    const passed = await runSystemCheck(this.checks);
    this.allPassed = passed;
    this.checking = false;
    this.checks = [...this.checks];
    if (passed) {
      promptAction.showToast({ message: '所有系统检查已通过！', duration: 2000 });
    } else {
      const failed = this.checks.filter((c: CheckResult) => c.status !== 1).length;
      promptAction.showToast({ message: failed + ' 项检查未通过，请检查配置或重新检测', duration: 2000 });
    }
  }

  toggleExpand(index: number): void {
    this.checks[index].expanded = !this.checks[index].expanded;
    this.checks = [...this.checks];
  }

  getStatusIcon(item: CheckResult): string {
    if (item.status === 0) return '-';
    if (item.status === 1) return '✓';
    return '✕';
  }

  getStatusColor(item: CheckResult): string {
    if (item.status === 0) return '#909399';
    if (item.status === 1) return '#67C23A';
    return '#F56C6C';
  }

  getStatusBg(item: CheckResult): string {
    if (item.status === 0) return 'transparent';
    if (item.status === 1) return '#67C23A';
    return '#F56C6C';
  }

  build() {
    Column() {
      Text('系统自检')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#303133')
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ bottom: 36 })

      Column() {
        ForEach(this.checks, (item: CheckResult, index: number) => {
          Column() {
            Row() {
              if (item.status === 0) {
                Text('-')
                  .fontSize(11)
                  .fontColor('#909399')
                  .width(22).height(22)
                  .borderRadius(11)
                  .border({ width: 2, color: '#409EFF' })
                  .textAlign(TextAlign.Center)
              } else {
                Text(this.getStatusIcon(item))
                  .fontSize(11)
                  .fontColor('#FFFFFF')
                  .width(22).height(22)
                  .borderRadius(11)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(this.getStatusBg(item))
              }

              Text(item.label)
                .fontSize(14)
                .fontColor('#303133')
                .margin({ left: 10 })

              Blank()
            }
            .width('100%')
            .padding({ top: 10, bottom: 10, left: 14, right: 14 })
            .backgroundColor('#FAFAFA')
            .onClick(() => { this.toggleExpand(index); })

            if (item.expanded) {
              Text(item.solution)
                .fontSize(12)
                .fontColor('#909399')
                .padding({ top: 10, bottom: 10, left: 14, right: 14 })
                .width('100%')
                .backgroundColor('#FFFFFF')
                .border({ width: { top: 1 }, color: '#EBEEF5' })
            }
          }
          .width('100%')
          .border({ width: 1, color: item.expanded ? '#C0C4CC' : '#E4E7ED', radius: 6 })
          .clip(true)
          .margin({ bottom: 8 })
        })
      }
      .width('100%')
      .margin({ bottom: 36 })

      Row() {
        Button('重新检测')
          .fontSize(13)
          .padding({ left: 18, right: 18, top: 8, bottom: 8 })
          .backgroundColor('#FFFFFF')
          .border({ width: 1, color: '#DCDFE6', radius: 4 })
          .fontColor('#606266')
          .enabled(!this.checking)
          .onClick(() => { this.doCheck(); })
          .margin({ right: 12 })

        Button('进入系统')
          .fontSize(13)
          .padding({ left: 18, right: 18, top: 8, bottom: 8 })
          .backgroundColor(this.allPassed ? '#67C23A' : '#A0CFFF')
          .border({ width: 1, color: this.allPassed ? '#67C23A' : '#A0CFFF', radius: 4 })
          .fontColor('#FFFFFF')
          .enabled(this.allPassed)
          .onClick(() => { router.pushUrl({ url: 'pages/TaskList' }); })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      Text('跳过自检')
        .fontSize(12).fontColor('#C0C4CC')
        .margin({ top: 24 })
        .onClick(() => { router.pushUrl({ url: 'pages/TaskList' }); })

      Text('API 调试')
        .fontSize(12).fontColor('#C0C4CC')
        .margin({ top: 8 })
        .onClick(() => { router.pushUrl({ url: 'pages/TaskInfoTest' }); })

      Text('FLV 测试')
        .fontSize(12).fontColor('#C0C4CC')
        .margin({ top: 4 })
        .onClick(() => { router.pushUrl({ url: 'pages/FlvTest' }); })

      Text('EasyPlayer 测试')
        .fontSize(12).fontColor('#C0C4CC')
        .margin({ top: 4 })
        .onClick(() => { router.pushUrl({ url: 'pages/EasyPlayerTest' }); })
    }
    .width('100%').height('100%')
    .padding(20)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F0F2F5')
  }
}
