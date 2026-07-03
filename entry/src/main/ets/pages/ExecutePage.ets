/**
 * ExecutePage.ets —— 巡检执行页，FLV 视频
 */
import { router } from '@kit.ArkUI'
import { promptAction } from '@kit.ArkUI'
import { webview } from '@kit.ArkWeb'
import http from '@ohos.net.http'
import { FlawMarker } from '../common/models/TaskModels'

const BASE = 'http://192.168.2.57/prod-api'
const FLV_HOST = '172.21.128.1'
const FLV_PORT = '8088'

// ===== HTTP 帮助 =====
async function httpGet(url: string): Promise<string> {
  const req = http.createHttp()
  try {
    const resp = await req.request(url, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 5000,
      readTimeout: 5000,
    })
    req.destroy()
    return (resp.result as string) || '{}'
  } catch (e) {
    req.destroy()
    return '{}'
  }
}

async function httpPostNoBody(url: string): Promise<boolean> {
  const req = http.createHttp()
  try {
    const resp = await req.request(url, {
      method: http.RequestMethod.POST,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 5000,
      readTimeout: 5000,
      header: { 'Content-Type': 'application/json' },
    })
    req.destroy()
    return resp.responseCode === 200
  } catch (e) {
    req.destroy()
    return false
  }
}

async function httpPostWithBody(url: string, body: string): Promise<boolean> {
  const req = http.createHttp()
  try {
    const resp = await req.request(url, {
      method: http.RequestMethod.POST,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 5000,
      readTimeout: 5000,
      header: { 'Content-Type': 'application/json' },
      extraData: body,
    })
    req.destroy()
    return resp.responseCode === 200
  } catch (e) {
    req.destroy()
    return false
  }
}

@Entry
@Component
struct ExecutePage {
  // ===== 路由 =====
  @State taskId: number = 0
  @State taskCode: string = ''

  // ===== 视频 =====
  private webController: webview.WebviewController = new webview.WebviewController()
  @State cam: number = 1
  @State videoReady: boolean = false

  // ===== 车辆状态 =====
  @State sysTime: string = '--'
  @State distance: string = '0.00'
  @State progressPercent: number = 0
  @State totalDistance: number = 100
  @State moveDirection: string = 'stop'
  @State totalFlaws: number = 0
  @State confirmedFlaws: number = 0
  @State unconfirmedFlaws: number = 0

  // ===== 缺陷 =====
  @State flawList: Record<string, Object>[] = []
  @State currentFlaw: Record<string, Object> | null = null
  @State showFlawDialog: boolean = false
  @State flawConfirmed: boolean = false
  @State flawRemark: string = ''
  @State aiLoading: boolean = false
  @State aiResult: string = ''

  // ===== 内部 =====
  private timer: number = -1
  private pollCount: number = 0
  @State autoRefresh: boolean = true
  private stopDebounce: number = 0

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>
    if (params) {
      this.taskId = (params['id'] as number) || 0
      this.taskCode = (params['taskCode'] as string) || ''
    }
    if (!this.taskId) {
      promptAction.showToast({ message: '缺少任务ID' })
      router.back()
      return
    }
    this.initPage()
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) clearInterval(this.timer)
  }

  async initPage(): Promise<void> {
    await this.loadTaskDetail()
    await this.fetchHeartbeat()
    await this.fetchFlaws()

    this.timer = setInterval(() => {
      if (!this.autoRefresh) return
      this.pollCount++
      // 心跳每 2 秒刷新，缺陷列表每 5 次（10 秒）刷新减少渲染压力
      this.fetchHeartbeat()
      if (this.pollCount % 5 === 0) this.fetchFlaws()
    }, 2000)
  }

  async loadTaskDetail(): Promise<void> {
    try {
      const json = await httpGet(BASE + '/agv/task/' + this.taskId)
      const data = JSON.parse(json) as Record<string, Object>
      const t = (data['data'] as Record<string, Object>)
      if (t) {
        const trip = Number(t['taskTrip'] || 100)
        this.totalDistance = (Number.isFinite(trip) && trip > 0) ? trip : 100
      }
    } catch (e) { /* silent */ }
  }

  async fetchHeartbeat(): Promise<void> {
    try {
      const json = await httpGet(BASE + '/agv/movement/heartbeat')
      const data = JSON.parse(json) as Record<string, Object>
      const hb = data['data'] as Record<string, Object>
      if (hb) {
        this.sysTime = (hb['sysTime'] as string) || '--'
        this.distance = Number(hb['currentPosition'] || 0).toFixed(2)
        this.progressPercent = Math.max(0, Math.min(100,
          (Number(hb['currentPosition'] || 0) / (this.totalDistance || 1)) * 100))
      }
    } catch (e) { /* silent */ }
  }

  async fetchFlaws(): Promise<void> {
    try {
      const json = await httpGet(BASE + '/agv/flaw/list?taskId=' + this.taskId + '&pageNum=1&pageSize=999')
      const data = JSON.parse(json) as Record<string, Object>
      const all = (data['rows'] as Object[] || []) as Record<string, Object>[]
      const filtered: Record<string, Object>[] = []
      for (let i = 0; i < all.length; i++) {
        if ((all[i]['taskId'] as number) === this.taskId) filtered.push(all[i])
      }
      this.flawList = filtered
      this.totalFlaws = filtered.length
      let cf = 0
      for (let i = 0; i < filtered.length; i++) {
        if (filtered[i]['confirmed']) cf++
      }
      this.confirmedFlaws = cf
      this.unconfirmedFlaws = filtered.length - cf
    } catch (e) { /* silent */ }
  }

  // ===== 视频 =====
  onVideoReady(): void {
    this.videoReady = true
    this.startFlvStream()
  }

  startFlvStream(): void {
    const url = 'http://' + FLV_HOST + ':' + FLV_PORT + '/flv/cam' + this.cam
    this.webController.runJavaScript('startFlv("' + url + '")')
  }

  switchCam(i: number): void {
    this.cam = i
    if (this.videoReady) this.startFlvStream()
  }

  // ===== 车辆控制 =====
  onMoveChange(action: string): void {
    if (action !== 'stop' && this.stopDebounce > 0) {
      const elapsed = Date.now() - this.stopDebounce
      if (elapsed < 300) { setTimeout(() => this.onMoveChange(action), 300 - elapsed); return }
    }
    if (action === 'stop') this.stopDebounce = Date.now()
    else this.stopDebounce = 0
    this.moveDirection = action
    httpPostNoBody(BASE + '/agv/movement/' + action).catch(() => {})
  }

  async onComplete(): Promise<void> {
    const ok = await httpPostNoBody(BASE + '/agv/task/end/' + this.taskId + '?isAbort=false')
    if (ok) {
      promptAction.showToast({ message: '巡检已完成' })
      this.cleanup()
    } else promptAction.showToast({ message: '操作失败' })
  }

  async onAbort(): Promise<void> {
    const ok = await httpPostNoBody(BASE + '/agv/task/end/' + this.taskId + '?isAbort=true')
    if (ok) {
      promptAction.showToast({ message: '巡检已中止' })
      this.cleanup()
    } else promptAction.showToast({ message: '操作失败' })
  }

  cleanup(): void {
    if (this.timer >= 0) clearInterval(this.timer)
    router.back()
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

  getFlawMarkers(): FlawMarker[] {
    const distTotal = this.totalDistance > 0 ? this.totalDistance : 1
    const result: FlawMarker[] = []
    for (let i = 0; i < this.flawList.length; i++) {
      const f = this.flawList[i]
      const d = Number(f['flawDistance'] || 0)
      const marker: FlawMarker = {
        id: (f['id'] as number) || 0,
        left: Math.max(0, Math.min(100, d / distTotal * 100)),
        flawName: (f['flawName'] as string) || '缺陷',
        confirmed: !!(f['confirmed']),
      }
      result.push(marker)
    }
    return result
  }

  // ===== 缺陷详情 =====
  openFlawDetail(f: Record<string, Object>): void {
    this.currentFlaw = f
    this.flawConfirmed = !!(f['confirmed'])
    this.flawRemark = (f['remark'] as string) || ''
    this.aiResult = ''
    this.showFlawDialog = true
  }

  async saveFlaw(): Promise<void> {
    if (!this.currentFlaw) return
    try {
      const saveBody: Record<string, Object> = {}
      saveBody['id'] = this.currentFlaw['id']
      saveBody['confirmed'] = this.flawConfirmed
      saveBody['remark'] = this.flawRemark
      const body = JSON.stringify(saveBody)
      const ok = await httpPostWithBody(BASE + '/agv/flaw', body)
      if (ok) {
        promptAction.showToast({ message: '已保存' })
        this.showFlawDialog = false
        this.fetchFlaws()
      } else promptAction.showToast({ message: '保存失败' })
    } catch (e) {
      promptAction.showToast({ message: '网络错误' })
    }
  }

  async aiAnalyze(): Promise<void> {
    if (!this.currentFlaw) return
    this.aiLoading = true
    this.aiResult = ''
    try {
      const flaw = this.currentFlaw
      const aiInputs: Record<string, Object> = {}
      aiInputs['flawType'] = flaw['flawType'] || ''
      aiInputs['flawLevel'] = flaw['flawLevel'] || flaw['level'] || '未知'
      aiInputs['flawArea'] = Number(flaw['flawArea'] || 0)
      aiInputs['flawLength'] = Number(flaw['flawLength'] || 0)
      aiInputs['flawDistance'] = Number(flaw['flawDistance'] || 0)
      const aiBody: Record<string, Object> = {}
      aiBody['inputs'] = aiInputs
      aiBody['query'] = '请分析这条地铁隧道巡检缺陷数据。'
      aiBody['response_mode'] = 'blocking'
      aiBody['user'] = 'inspector-001'
      const body = JSON.stringify(aiBody)
      const req = http.createHttp()
      const resp = await req.request('http://192.168.2.53/v1/chat-messages', {
        method: http.RequestMethod.POST,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 120000,
        readTimeout: 120000,
        header: {
          'Authorization': 'Bearer app-ix0KtVqKKJIJ8Jk5t2bkotVa',
          'Content-Type': 'application/json',
        },
        extraData: body,
      })
      req.destroy()
      const data = JSON.parse(resp.result as string) as Record<string, Object>
      const answer = String(data['answer'] || '').replace(/<think>[\s\S]*?<\/think>/gi, '').trim()
      this.aiResult = answer || 'AI 未返回有效分析结果'
    } catch (e) {
      this.aiResult = 'AI 分析请求失败'
    } finally {
      this.aiLoading = false
    }
  }

  build() {
    Stack() {
      Column() {
        // ===== 标题 + 面包屑 =====
        Row() {
          Text('首页').fontSize(12).fontColor('#909399')
            .onClick(() => { router.pushUrl({ url: 'pages/SystemCheck' }) })
          Text(' / ').fontSize(12).fontColor('#C0C4CC')
          Text('任务列表').fontSize(12).fontColor('#909399')
            .onClick(() => { router.pushUrl({ url: 'pages/TaskList' }) })
          Text(' / ').fontSize(12).fontColor('#C0C4CC')
          Text('任务巡视').fontSize(12).fontWeight(FontWeight.Medium).fontColor('#303133')
          Blank()
          Text(this.taskCode).fontSize(11).fontColor('#909399')
        }
        .width('100%').padding({ left: 20, top: 12, bottom: 12 }).backgroundColor(Color.White)

        Row() {
          // ===== 左侧：视频 + 刻度条 =====
          Column() {
            Stack() {
              Web({ src: 'resource://rawfile/player.html', controller: this.webController })
                .width('100%').height('100%')
                .backgroundColor(Color.Black)
                .javaScriptAccess(true)
                .onPageEnd(() => { this.onVideoReady() })

              Text(this.videoReady ? 'cam' + this.cam : '加载中...')
                .fontSize(10).fontColor('#FFF')
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor('rgba(0,0,0,0.7)').borderRadius(4)
                .position({ x: 8, y: 8 })
            }
            .width('100%').height(0).layoutWeight(1).borderRadius(6).clip(true)

            // 摄像头切换
            Row() {
              ForEach([1, 2, 3, 4], (i: number) => {
                Button('摄像头' + i).fontSize(11).height(28)
                  .backgroundColor(this.cam === i ? '#67C23A' : '#FFFFFF')
                  .fontColor(this.cam === i ? Color.White : '#606266')
                  .border({ width: 1, color: this.cam === i ? '#67C23A' : '#DCDFE6', radius: 4 })
                  .margin({ right: 4 }).enabled(this.videoReady)
                  .onClick(() => { this.switchCam(i) })
              })
            }.width('100%').justifyContent(FlexAlign.Center).padding({ top: 8, bottom: 4 })

            // 刻度条
            Column() {
              Row() {
                Text('0m').fontSize(10).fontColor('#909399')
                Blank()
                Text(this.totalDistance + 'm').fontSize(10).fontColor('#909399')
              }.width('100%')

              Stack() {
                Row().width('100%').height(4).backgroundColor('#DCDFE6').borderRadius(2)
                Row().width(this.progressPercent + '%').height(4).backgroundColor('#67C23A').borderRadius(2)
                ForEach(this.getFlawMarkers(), (m: FlawMarker) => {
                  Text('*').fontSize(14)
                    .position({ x: m.left + '%', y: -10 })
                    .fontColor(m.confirmed ? '#F56C6C' : '#E6A23C')
                })
                Text('>').fontSize(14).fontColor('#67C23A')
                  .position({ x: this.progressPercent + '%', y: -12 })
              }.width('100%').height(30)
            }.width('100%').padding({ left: 24, right: 24, top: 12, bottom: 12 })
          }
          .layoutWeight(1).height('100%').padding(12)

          // ===== 右侧面板 =====
          Column() {
            // 控制台
            Column() {
              Text('控制台').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#303133')
                .padding({ top: 10, bottom: 10, left: 14, right: 14 })
                .width('100%').backgroundColor('#FAFAFA')
                .border({ width: { bottom: 1 }, color: '#EBEEF5' })

              Row() {
                Button('完成巡检').fontSize(11).height(28).padding({ left: 10, right: 10 })
                  .backgroundColor('#67C23A').fontColor('#FFFFFF')
                  .border({ width: 1, color: '#67C23A', radius: 4 })
                  .onClick(() => this.onComplete())
                Button('中止巡检').fontSize(11).height(28).padding({ left: 10, right: 10 })
                  .backgroundColor('#F56C6C').fontColor('#FFFFFF')
                  .border({ width: 1, color: '#F56C6C', radius: 4 }).margin({ left: 6 })
                  .onClick(() => this.onAbort())
              }.padding({ left: 14, top: 10, bottom: 10 })
            }
            .width('100%').backgroundColor('#FFFFFF').borderRadius(6)
            .border({ width: 1, color: '#EBEEF5' }).clip(true).margin({ bottom: 10 })

            // 车辆状态
            Column() {
              Row() {
                Text('车辆状态').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#303133')
                Blank()
                Button('后退').fontSize(10).height(28).padding({ left: 8, right: 8 })
                  .backgroundColor(this.moveDirection === 'backward' ? '#E6A23C' : '#FFFFFF')
                  .fontColor(this.moveDirection === 'backward' ? '#FFFFFF' : '#606266')
                  .border({ width: 1, color: '#DCDFE6', radius: 3 })
                  .onTouch((event: TouchEvent) => {
                    if (event.type === TouchType.Down) this.onMoveChange('backward')
                    else this.onMoveChange('stop')
                  })
                Button('停止').fontSize(10).height(28).padding({ left: 8, right: 8 })
                  .backgroundColor(this.moveDirection === 'stop' ? '#F56C6C' : '#FFFFFF')
                  .fontColor(this.moveDirection === 'stop' ? '#FFFFFF' : '#606266')
                  .border({ width: 1, color: '#DCDFE6', radius: 3 }).margin({ left: 3, right: 3 })
                  .onClick(() => this.onMoveChange('stop'))
                Button('前进').fontSize(10).height(28).padding({ left: 8, right: 8 })
                  .backgroundColor(this.moveDirection === 'forward' ? '#67C23A' : '#FFFFFF')
                  .fontColor(this.moveDirection === 'forward' ? '#FFFFFF' : '#606266')
                  .border({ width: 1, color: '#DCDFE6', radius: 3 })
                  .onTouch((event: TouchEvent) => {
                    if (event.type === TouchType.Down) this.onMoveChange('forward')
                    else this.onMoveChange('stop')
                  })
              }
              .width('100%').padding({ top: 10, bottom: 10, left: 14, right: 14 })
              .backgroundColor('#FAFAFA').border({ width: { bottom: 1 }, color: '#EBEEF5' })

              Column() {
                Row() { Text('任务编号').fontSize(11).fontColor('#909399').width(80)
                  Text(this.taskCode).fontSize(11).fontColor('#303133').fontWeight(FontWeight.Medium) }
                .width('100%').padding({ top: 3, bottom: 3 }).border({ width: { bottom: 1 }, color: 'rgba(0,0,0,0.03)' })

                Row() { Text('系统时间').fontSize(11).fontColor('#909399').width(80)
                  Text(this.sysTime).fontSize(11).fontColor('#303133').fontWeight(FontWeight.Medium) }
                .width('100%').padding({ top: 3, bottom: 3 }).border({ width: { bottom: 1 }, color: 'rgba(0,0,0,0.03)' })

                Row() { Text('已行驶距离').fontSize(11).fontColor('#909399').width(80)
                  Text(this.distance + ' 米').fontSize(11).fontColor('#303133').fontWeight(FontWeight.Medium) }
                .width('100%').padding({ top: 3, bottom: 3 }).border({ width: { bottom: 1 }, color: 'rgba(0,0,0,0.03)' })

                Row() { Text('故障总计').fontSize(11).fontColor('#909399').width(80)
                  Text(String(this.totalFlaws)).fontSize(11).fontColor('#303133').fontWeight(FontWeight.Medium) }
                .width('100%').padding({ top: 3, bottom: 3 }).border({ width: { bottom: 1 }, color: 'rgba(0,0,0,0.03)' })

                Row() { Text('已确定故障').fontSize(11).fontColor('#909399').width(80)
                  Text(String(this.confirmedFlaws)).fontSize(11).fontColor('#303133').fontWeight(FontWeight.Medium) }
                .width('100%').padding({ top: 3, bottom: 3 }).border({ width: { bottom: 1 }, color: 'rgba(0,0,0,0.03)' })

                Row() { Text('疑似故障').fontSize(11).fontColor('#909399').width(80)
                  Text(String(this.unconfirmedFlaws)).fontSize(11).fontColor('#303133').fontWeight(FontWeight.Medium) }
                .width('100%').padding({ top: 3, bottom: 3 }).border({ width: { bottom: 1 }, color: 'rgba(0,0,0,0.03)' })
              }.padding(12)
            }
            .width('100%').backgroundColor('#FFFFFF').borderRadius(6)
            .border({ width: 1, color: '#EBEEF5' }).clip(true).margin({ bottom: 10 })

            // 故障历史
            Column() {
              Text('故障历史').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#303133')
                .padding({ top: 10, bottom: 10, left: 14, right: 14 })
                .width('100%').backgroundColor('#FAFAFA')
                .border({ width: { bottom: 1 }, color: '#EBEEF5' })

              if (this.flawList.length === 0) {
                Text('暂无数据').fontSize(11).fontColor('#909399').padding(16)
                  .width('100%').textAlign(TextAlign.Center)
              } else {
                List() {
                  ForEach(this.flawList, (f: Record<string, Object>) => {
                    ListItem() {
                      Row() {
                        Text(this.str(f['flawName'])).fontSize(11).fontColor('#303133')
                          .width(80).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                        Text(this.str(f['flawType'])).fontSize(11).fontColor('#606266').width(60)
                        Text(Number(f['flawDistance'] || 0).toFixed(2) + 'm')
                          .fontSize(11).fontColor('#909399').width(55)
                      }
                      .width('100%').padding({ top: 5, bottom: 5, left: 14, right: 14 })
                    }
                    .onClick(() => { this.openFlawDetail(f) })
                    .border({ width: { bottom: 1 }, color: '#F5F5F5' })
                  })
                }
                .layoutWeight(1).scrollBar(BarState.Off)
              }
            }
            .width('100%').layoutWeight(1).backgroundColor('#FFFFFF').borderRadius(6)
            .border({ width: 1, color: '#EBEEF5' }).clip(true)
          }
          .width(300).height('100%').padding({ left: 4, right: 12, top: 12, bottom: 12 })
        }
        .layoutWeight(1)
      }
      .width('100%').height('100%').backgroundColor('#F0F2F5')

      // ===== 缺陷详情弹窗 =====
      if (this.showFlawDialog && this.currentFlaw) {
        Column() {
          Column() {
            Text('故障详情').fontSize(18).fontWeight(FontWeight.Bold).padding(20)
            Divider().color('#E4E7ED')

            Column() {
              // 图片
              if (this.str(this.currentFlaw['flawImageUrl']) !== '--' &&
                this.str(this.currentFlaw['flawImageUrl']) !== '') {
                Image('http://192.168.2.57/prod-api/file' +
                  (this.currentFlaw as Record<string, Object>)['flawImageUrl'])
                  .width('100%').height(240).objectFit(ImageFit.Contain)
                  .backgroundColor('#1a1a1a').borderRadius(8)
              } else {
                Text('暂无故障图片').fontSize(14).fontColor('#909399')
                  .width('100%').height(200).textAlign(TextAlign.Center)
                  .backgroundColor('#1a1a1a').borderRadius(8)
              }

              Column() {
                Row() { Text('名称').fontSize(12).fontColor('#909399').width(70)
                  Text(this.str(this.currentFlaw['flawName'])).fontSize(13).fontColor('#303133') }
                .margin({ bottom: 6 })
                Row() { Text('类型').fontSize(12).fontColor('#909399').width(70)
                  Text(this.str(this.currentFlaw['flawType'])).fontSize(13).fontColor('#303133') }
                .margin({ bottom: 6 })
                Row() { Text('描述').fontSize(12).fontColor('#909399').width(70)
                  Text(this.str(this.currentFlaw['flawDesc'])).fontSize(13).fontColor('#303133') }
                .margin({ bottom: 6 })
                Row() { Text('位置').fontSize(12).fontColor('#909399').width(70)
                  Text(this.str(this.currentFlaw['flawDistance']) + ' m').fontSize(13).fontColor('#303133') }
                .margin({ bottom: 6 })
                Row() { Text('等级').fontSize(12).fontColor('#909399').width(70)
                  Text(this.str(this.currentFlaw['flawLevel'] || this.currentFlaw['level'])).fontSize(13).fontColor('#303133') }
                .margin({ bottom: 6 })
                Row() { Text('发现时间').fontSize(12).fontColor('#909399').width(70)
                  Text(this.str(this.currentFlaw['createTime'])).fontSize(13).fontColor('#303133') }
                .margin({ bottom: 6 })
              }.width('100%').padding({ top: 12, bottom: 8 })

              // 是否属实
              Row() {
                Text('是否属实').fontSize(13).fontColor('#606266').margin({ right: 16 })
                Radio({ value: 'yes', group: 'flawConfirmed' }).checked(this.flawConfirmed)
                  .onChange((v: boolean) => { this.flawConfirmed = v })
                Text('是').fontSize(13).margin({ right: 16 })
                Radio({ value: 'no', group: 'flawConfirmed' }).checked(!this.flawConfirmed)
                  .onChange((v: boolean) => { this.flawConfirmed = v })
                Text('否').fontSize(13)
              }.width('100%').margin({ bottom: 12 })

              // 补充说明
              Text('补充说明').fontSize(12).fontColor('#909399').margin({ bottom: 6 })
              TextInput({ text: this.flawRemark })
                .height(60).fontSize(12)
                .onChange((v: string) => { this.flawRemark = v }).margin({ bottom: 8 })

              // AI 分析按钮
              Row() {
                Button(this.aiLoading ? 'AI 分析中...' : 'AI 分析')
                  .fontSize(12).height(32).padding({ left: 14, right: 14 })
                  .backgroundColor('#67C23A').fontColor(Color.White).borderRadius(4)
                  .enabled(!this.aiLoading)
                  .onClick(() => { this.aiAnalyze() })
              }.width('100%').margin({ bottom: 8 })

              // AI 结果
              if (this.aiResult) {
                Text(this.aiResult)
                  .fontSize(12).lineHeight(20).fontColor('#303133')
                  .padding(12).backgroundColor('#F9FAFC').borderRadius(6)
                  .border({ width: 1, color: '#E4E7ED' })
                  .width('100%')
              }
            }.padding(20)

            Divider().color('#E4E7ED')
            Row() {
              Button('取消').fontSize(13).backgroundColor('#FFFFFF')
                .border({ width: 1, color: '#DCDFE6', radius: 4 })
                .padding({ left: 20, right: 20, top: 8, bottom: 8 }).fontColor('#606266')
                .onClick(() => { this.showFlawDialog = false })
              Button('保存').fontSize(13).backgroundColor('#67C23A').borderRadius(4)
                .padding({ left: 20, right: 20, top: 8, bottom: 8 }).fontColor('#FFFFFF')
                .margin({ left: 12 })
                .onClick(() => { this.saveFlaw() })
            }.padding(16).justifyContent(FlexAlign.Center)
          }
          .width('90%').backgroundColor('#FFFFFF').borderRadius(12)
        }
        .width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .backgroundColor('rgba(0,0,0,0.5)')
        .position({ x: 0, y: 0 })
        .onClick(() => { this.showFlawDialog = false })
      }
    }
    .width('100%').height('100%')
  }
}
