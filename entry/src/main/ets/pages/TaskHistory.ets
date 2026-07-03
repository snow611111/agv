/**
 * TaskHistory.ets —— 巡检历史页，绿色主题
 */
import { router } from '@kit.ArkUI'
import http from '@ohos.net.http'

const BASE = 'http://192.168.2.57/prod-api'
const IMG_BASE = BASE + '/file'

@Entry
@Component
struct TaskHistory {
  @State taskId: number = 0
  @State taskCode: string = ''
  @State taskInfo: Record<string, Object> = {}
  @State flawList: Record<string, Object>[] = []
  @State selectedFlaw: Record<string, Object> | null = null
  @State reportLoading: boolean = false
  @State reportError: string = ''
  @State reportContent: string = ''

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>
    if (params) {
      this.taskId = (params['id'] as number) || 0
      this.taskCode = (params['taskCode'] as string) || ''
    }
    if (!this.taskId) {
      router.back()
      return
    }
    this.initPage()
  }

  async initPage(): Promise<void> {
    await this.loadTaskDetail()
    await this.fetchFlaws()
  }

  // ===== 工具 =====
  str(v: Object | undefined | null): string {
    if (v == null || v == undefined) return '--'
    return String(v)
  }

  statusColor(s: string): string {
    if (s === '待巡视') return '#D2991D'
    if (s === '巡视中') return '#409EFF'
    if (s === '待上传') return '#909399'
    if (s === '已完成') return '#67C23A'
    return '#909399'
  }

  // ===== HTTP =====
  async loadTaskDetail(): Promise<void> {
    const req = http.createHttp()
    try {
      const resp = await req.request(BASE + '/agv/task/' + this.taskId, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 120000,
      })
      req.destroy()
      const text = (resp.result as string) || '{}'
      const data = JSON.parse(text) as Record<string, Object>
      const src = data['data'] as Record<string, Object>
      if (src) {
        this.taskInfo = src
      }
    } catch (e) {
      req.destroy()
    }
  }

  async fetchFlaws(): Promise<void> {
    const req = http.createHttp()
    try {
      const resp = await req.request(
        BASE + '/agv/flaw/list?taskId=' + this.taskId + '&pageNum=1&pageSize=999', {
          method: http.RequestMethod.GET,
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 10000,
          readTimeout: 120000,
        })
      req.destroy()
      const text = (resp.result as string) || '{}'
      const data = JSON.parse(text) as Record<string, Object>
      const all = (data['rows'] as Object[] || []) as Record<string, Object>[]
      const filtered: Record<string, Object>[] = []
      for (let i = 0; i < all.length; i++) {
        if ((all[i]['taskId'] as number) === this.taskId) filtered.push(all[i])
      }
      this.flawList = filtered
      if (this.flawList.length > 0 && !this.selectedFlaw) {
        this.selectedFlaw = this.flawList[0]
      }
    } catch (e) {
      req.destroy()
    }
  }

  get selectedImageUrl(): string {
    if (!this.selectedFlaw) return ''
    const raw = this.str(this.selectedFlaw['flawImageUrl'])
    if (raw === '--' || raw === '') return ''
    if (raw.indexOf('http') === 0) return raw
    return IMG_BASE + raw
  }

  build() {
    Column() {
      // ===== 面包屑 =====
      Row() {
        Text('首页').fontSize(16).fontColor('#909399')
          .onClick(() => { router.pushUrl({ url: 'pages/SystemCheck' }) })
        Text(' / ').fontSize(16).fontColor('#C0C4CC')
        Text('任务列表').fontSize(16).fontColor('#909399')
          .onClick(() => { router.pushUrl({ url: 'pages/TaskList' }) })
        Text(' / ').fontSize(16).fontColor('#C0C4CC')
        Text('巡视历史').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#67C23A')
        Blank()
        Text(this.taskCode).fontSize(12).fontColor('#909399')
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(Color.White)

      Row() {
        // ===== 左侧图片 =====
        Column() {
          if (this.selectedImageUrl) {
            Image(this.selectedImageUrl)
              .width('100%').layoutWeight(1)
              .objectFit(ImageFit.Contain).backgroundColor('#1a1a2e').borderRadius(6)
          } else {
            Column() {
              Text('点击下方缺陷行查看现场照片').fontSize(14).fontColor('#555')
            }
            .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
            .backgroundColor('#1a1a2e').borderRadius(6)
          }
          if (this.selectedFlaw) {
            Text(this.str(this.selectedFlaw['flawName']) + ' | ' +
              this.str(this.selectedFlaw['flawDistance']) + 'm | ' +
              this.str(this.selectedFlaw['createTime']))
              .fontSize(10).fontColor('#ccc').padding(6).width('100%')
              .backgroundColor('rgba(0,0,0,0.7)')
          }
        }
        .layoutWeight(1).height('100%').padding(12)

        // ===== 右侧 =====
        Column() {
          // 任务信息卡片
          Column() {
            Row() {
              Text('任务信息').fontSize(15).fontWeight(FontWeight.Bold)
              Blank()
              Text(this.str(this.taskInfo['taskStatus']))
                .fontSize(11).fontColor(Color.White)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(4)
                .backgroundColor(this.statusColor(this.str(this.taskInfo['taskStatus'])))
            }.width('100%').margin({ bottom: 10 })

            Row() { Text('任务编号').fontSize(12).fontColor('#909399').width(70)
              Text(this.str(this.taskInfo['taskCode'])).fontSize(12).fontColor('#303133') }
            .margin({ bottom: 6 }).width('100%')

            Row() { Text('任务名称').fontSize(12).fontColor('#909399').width(70)
              Text(this.str(this.taskInfo['taskName'])).fontSize(12).fontColor('#303133') }
            .margin({ bottom: 6 }).width('100%')

            Row() { Text('起始地点').fontSize(12).fontColor('#909399').width(70)
              Text(this.str(this.taskInfo['startPos'])).fontSize(12).fontColor('#303133') }
            .margin({ bottom: 6 }).width('100%')

            Row() { Text('任务距离').fontSize(12).fontColor('#909399').width(70)
              Text(this.str(this.taskInfo['taskTrip']) !== '--' ?
                this.str(this.taskInfo['taskTrip']) + ' 米' : '--')
                .fontSize(12).fontColor('#303133') }
            .margin({ bottom: 6 }).width('100%')

            Row() { Text('创建人').fontSize(12).fontColor('#909399').width(70)
              Text(this.str(this.taskInfo['creator'])).fontSize(12).fontColor('#303133') }
            .margin({ bottom: 6 }).width('100%')

            Row() { Text('执行人').fontSize(12).fontColor('#909399').width(70)
              Text(this.str(this.taskInfo['executor'])).fontSize(12).fontColor('#303133') }
            .margin({ bottom: 6 }).width('100%')

            Row() { Text('执行时间').fontSize(12).fontColor('#909399').width(70)
              Text(this.str(this.taskInfo['execTime'])).fontSize(12).fontColor('#303133') }
            .margin({ bottom: 6 }).width('100%')

            Row() { Text('完成时间').fontSize(12).fontColor('#909399').width(70)
              Text(this.str(this.taskInfo['endTime'])).fontSize(12).fontColor('#303133') }
            .margin({ bottom: 6 }).width('100%')

            Row() { Text('巡视轮次').fontSize(12).fontColor('#909399').width(70)
              Text(this.str(this.taskInfo['round'])).fontSize(12).fontColor('#303133') }
            .margin({ bottom: 6 }).width('100%')

            Row() { Text('备注').fontSize(12).fontColor('#909399').width(70)
              Text(this.str(this.taskInfo['remark'])).fontSize(12).fontColor('#303133') }
            .margin({ bottom: 6 }).width('100%')
          }
          .width('100%').padding(14).backgroundColor(Color.White).borderRadius(8).margin({ bottom: 10 })

          // AI 报告
          Column() {
            Row() {
              Text('AI 巡检报告').fontSize(15).fontWeight(FontWeight.Bold)
              Blank()
              Button(this.reportLoading ? '生成中...' : '生成报告')
                .fontSize(11).height(28).type(ButtonType.Capsule)
                .fontColor(Color.White).backgroundColor('#67C23A')
                .enabled(!this.reportLoading)
            }.width('100%').margin({ bottom: 8 })

            if (this.reportError) {
              Text(this.reportError).fontSize(11).fontColor('#F56C6C').padding(8)
                .backgroundColor('#FEF0F0').borderRadius(4).width('100%')
            }
            if (this.reportContent) {
              Scroll() {
                Text(this.reportContent).fontSize(12).lineHeight(22).width('100%')
              }.layoutWeight(1).padding(10).backgroundColor('#FAFAFA').borderRadius(4)
            } else {
              Text('点击上方按钮生成 AI 巡检报告').fontSize(12).fontColor('#909399').padding(12)
            }
          }
          .width('100%').layoutWeight(1).padding(14).backgroundColor(Color.White).borderRadius(8)
        }
        .width(320).height('100%').padding({ left: 4, right: 12, top: 12, bottom: 12 })
      }
      .layoutWeight(1)

      // ===== 底部缺陷表 =====
      Column() {
        Text('缺陷记录（' + this.flawList.length + ' 条）')
          .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#303133')
          .width('100%').padding({ left: 16, top: 10, bottom: 10 })
          .backgroundColor(Color.White).borderRadius({ topLeft: 6, topRight: 6 })

        Row() {
          Text('序号').fontSize(11).fontColor('#909399').width(40).textAlign(TextAlign.Center)
          Text('缺陷名称').fontSize(11).fontColor('#909399').layoutWeight(2)
          Text('类型').fontSize(11).fontColor('#909399').width(70)
          Text('距离(m)').fontSize(11).fontColor('#909399').width(65).textAlign(TextAlign.End)
          Text('确认').fontSize(11).fontColor('#909399').width(55).textAlign(TextAlign.Center)
          Text('描述').fontSize(11).fontColor('#909399').layoutWeight(2)
          Text('发现时间').fontSize(11).fontColor('#909399').width(140)
        }
        .width('100%').padding({ left: 16, right: 16, top: 6, bottom: 6 })
        .backgroundColor('#FAFAFA')

        List() {
          ForEach(this.flawList, (f: Record<string, Object>, index: number) => {
            ListItem() {
              Row() {
                Text(String(index + 1)).fontSize(11).fontColor('#909399').width(40).textAlign(TextAlign.Center)
                Text(this.str(f['flawName'])).fontSize(11).fontColor('#303133').layoutWeight(2)
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.str(f['flawType'])).fontSize(11).fontColor('#909399').width(70)
                Text(this.str(f['flawDistance'])).fontSize(11).fontColor('#606266').width(65).textAlign(TextAlign.End)
                Text(f['confirmed'] === true ? '已确认' : '待确认')
                  .fontSize(10).fontColor(f['confirmed'] === true ? '#67C23A' : '#E6A23C').width(55).textAlign(TextAlign.Center)
                Text(this.str(f['flawDesc'])).fontSize(11).fontColor('#606266').layoutWeight(2)
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.str(f['createTime'])).fontSize(10).fontColor('#909399').width(140)
              }
              .width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .backgroundColor(this.selectedFlaw !== null &&
                this.selectedFlaw['id'] === f['id'] ? '#ECF5FF' : Color.White)
            }
            .onClick(() => { this.selectedFlaw = f })
            .border({ width: { bottom: 1 }, color: '#EBEEF5' })
          })
        }
        .width('100%').constraintSize({ minHeight: 120, maxHeight: 260 })
        .backgroundColor(Color.White).borderRadius({ bottomLeft: 6, bottomRight: 6 })
      }
      .width('100%').padding({ left: 12, right: 12, bottom: 12 })
    }
    .width('100%').height('100%').backgroundColor('#F0F2F5')
  }
}
