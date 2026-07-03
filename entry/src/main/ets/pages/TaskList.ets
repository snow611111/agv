/**
 * TaskList.ets —— 任务列表页，绿色主题
 */
import { router } from '@kit.ArkUI'
import { promptAction } from '@kit.ArkUI'
import { http } from '@kit.NetworkKit'

const BASE = 'http://192.168.2.57/prod-api'

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
    return resp.result as string
  } catch (e) {
    req.destroy()
    return '{}'
  }
}

async function httpPost(url: string, body: string): Promise<boolean> {
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

async function httpDelete(url: string): Promise<boolean> {
  const req = http.createHttp()
  try {
    const resp = await req.request(url, {
      method: http.RequestMethod.DELETE,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 5000,
      readTimeout: 5000,
    })
    req.destroy()
    return resp.responseCode === 200
  } catch (e) {
    req.destroy()
    return false
  }
}

class ExecParams {
  id: number = 0
  taskCode: string = ''

  constructor(id: number, taskCode: string) {
    this.id = id
    this.taskCode = taskCode
  }
}

@Entry
@Component
struct TaskList {
  @State sCode: string = ''
  @State sCreator: string = ''
  @State sExecutor: string = ''
  @State sStatus: string = ''
  @State tasks: Record<string, Object>[] = []
  @State page: number = 1
  @State pageSize: number = 20
  @State pageSizeIndex: number = 2   // 0=10, 1=15, 2=20, 3=50, 4=100
  @State jumpPage: string = ''
  @State total: number = 0

  @State detailVisible: boolean = false
  @State createVisible: boolean = false
  @State cur: Record<string, Object> = {}

  @State cfName: string = ''
  @State cfCode: string = ''
  @State cfStartPos: string = ''
  @State cfTrip: string = ''
  @State cfCreator: string = ''
  @State cfExecutor: string = ''
  @State cfMsg: string = ''

  aboutToAppear(): void {
    this.loadData()
  }

  statusColor(s: string): string {
    if (s === '待巡视') return '#D2991D'
    if (s === '巡视中') return '#409EFF'
    if (s === '待上传') return '#909399'
    if (s === '已完成') return '#67C23A'
    return '#909399'
  }

  actionList(s: string): string[] {
    if (s === '待巡视') return ['detail', 'start', 'delete']
    if (s === '巡视中') return ['detail', 'complete', 'abort']
    if (s === '待上传') return ['detail', 'upload', 'delete']
    if (s === '已完成') return ['detail']
    return ['detail']
  }

  actionLabel(a: string): string {
    switch (a) {
      case 'detail': return '详情'
      case 'start': return '启动'
      case 'delete': return '删除'
      case 'complete': return '完成'
      case 'abort': return '中止'
      case 'upload': return '上传'
      default: return a
    }
  }

  field(t: Record<string, Object>, key: string): string {
    const v = t[key]
    if (v == null || v == undefined) return '--'
    return String(v)
  }

  // ===== 加载 =====
  async loadData(): Promise<void> {
    let url = BASE + '/agv/task/list?pageNum=' + this.page + '&pageSize=' + this.pageSize
    if (this.sCode.trim()) url += '&taskCode=' + encodeURIComponent(this.sCode.trim())
    if (this.sCreator.trim()) url += '&creator=' + encodeURIComponent(this.sCreator.trim())
    if (this.sExecutor.trim()) url += '&executor=' + encodeURIComponent(this.sExecutor.trim())
    if (this.sStatus) url += '&taskStatus=' + encodeURIComponent(this.sStatus)

    if (this.page === 1) {
      const patrolUrl = BASE + '/agv/task/list?pageNum=1&pageSize=100&taskStatus=' + encodeURIComponent('巡视中')
      const results = await Promise.all([httpGet(patrolUrl), httpGet(url)])
      const pBody = JSON.parse(results[0]) as Record<string, Object>
      const nBody = JSON.parse(results[1]) as Record<string, Object>
      const pRows = (pBody['rows'] as Object[] || []) as Record<string, Object>[]
      const nRows = (nBody['rows'] as Object[] || []) as Record<string, Object>[]
      const pIds: number[] = []
      for (let i = 0; i < pRows.length; i++) { pIds.push((pRows[i]['id'] as number) || 0) }
      const filtered: Record<string, Object>[] = []
      for (let i = 0; i < nRows.length; i++) {
        if (pIds.indexOf((nRows[i]['id'] as number) || 0) === -1) filtered.push(nRows[i])
      }
      this.tasks = pRows.concat(filtered)
      this.total = (nBody['total'] as number) || 0
    } else {
      const json = await httpGet(url)
      const body = JSON.parse(json) as Record<string, Object>
      this.tasks = (body['rows'] as Object[] || []) as Record<string, Object>[]
      this.total = (body['total'] as number) || 0
    }
  }

  onSearch(): void { this.page = 1; this.loadData() }
  onReset(): void {
    this.sCode = ''; this.sCreator = ''; this.sExecutor = ''; this.sStatus = ''
    this.page = 1; this.loadData()
  }
  goPage(n: number): void {
    const tp = Math.ceil(this.total / this.pageSize) || 1
    if (n < 1 || n > tp) return
    this.page = n; this.loadData()
  }

  // ===== 操作 =====
  async doAction(action: string, t: Record<string, Object>): Promise<void> {
    const id = (t['id'] as number) || 0
    const code = (t['taskCode'] as string) || ''
    if (action === 'detail') { this.cur = t; this.detailVisible = true; return }

    let ok = false
    if (action === 'start') {
      ok = await httpPost(BASE + '/agv/task/start/' + id, '')
      if (ok) { router.pushUrl({ url: 'pages/ExecutePage', params: new ExecParams(id, code) }); return }
    } else if (action === 'complete') ok = await httpPost(BASE + '/agv/task/end/' + id + '?isAbort=false', '')
    else if (action === 'abort') ok = await httpPost(BASE + '/agv/task/end/' + id + '?isAbort=true', '')
    else if (action === 'upload') ok = await httpPost(BASE + '/agv/task/upload/' + id, '')
    else if (action === 'delete') ok = await httpDelete(BASE + '/agv/task/' + id)

    promptAction.showToast({ message: this.actionLabel(action) + (ok ? '成功' : '失败'), duration: 1500 })
    if (ok) this.loadData()
  }

  // ===== 创建 =====
  openCreate(): void {
    this.cfName = ''; this.cfCode = ''; this.cfStartPos = ''
    this.cfTrip = ''; this.cfCreator = ''; this.cfExecutor = ''; this.cfMsg = ''
    this.createVisible = true
  }

  async doCreate(andStart: boolean): Promise<void> {
    if (!this.cfName) { this.cfMsg = '请输入任务名称'; return }
    if (!this.cfTrip) { this.cfMsg = '请输入任务距离'; return }
    if (!this.cfCreator) { this.cfMsg = '请输入创建人'; return }
    if (!this.cfExecutor) { this.cfMsg = '请输入执行人'; return }

    const body: Record<string, string> = {}
    body['taskName'] = this.cfName.trim()
    body['taskCode'] = this.cfCode.trim()
    body['startPos'] = this.cfStartPos.trim()
    body['taskTrip'] = this.cfTrip.trim()
    body['creator'] = this.cfCreator.trim()
    body['executor'] = this.cfExecutor.trim()

    const ok = await httpPost(BASE + '/agv/task', JSON.stringify(body))
    if (!ok) { this.cfMsg = '创建失败'; return }
    this.createVisible = false
    promptAction.showToast({ message: '任务创建成功', duration: 1500 })

    if (andStart) {
      let findUrl = BASE + '/agv/task/list?pageNum=1&pageSize=999'
      if (body['taskName']) findUrl += '&taskName=' + encodeURIComponent(body['taskName'])
      const json = await httpGet(findUrl)
      const res = JSON.parse(json) as Record<string, Object>
      const rows = (res['rows'] as Object[] || []) as Record<string, Object>[]
      let newId = 0; let newCode = ''
      for (let i = 0; i < rows.length; i++) {
        if ((rows[i]['taskName'] as string) === body['taskName'] &&
          (rows[i]['creator'] as string) === body['creator']) {
          newId = (rows[i]['id'] as number) || 0
          newCode = (rows[i]['taskCode'] as string) || ''
        }
      }
      if (newId > 0) {
        await httpPost(BASE + '/agv/task/start/' + newId, '')
        router.pushUrl({ url: 'pages/ExecutePage', params: new ExecParams(newId, newCode) })
      }
    }
    this.loadData()
  }

  build() {
    Stack() {
      Column() {
        // ===== 面包屑 + 标题栏 =====
        Row() {
          Text('首页').fontSize(16).fontColor('#909399')
            .onClick(() => { router.pushUrl({ url: 'pages/SystemCheck' }) })
          Text(' / ').fontSize(16).fontColor('#C0C4CC')
          Text('任务列表').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#67C23A')
          Blank()
          Button('新建任务')
            .fontSize(12).height(32).type(ButtonType.Capsule)
            .fontColor(Color.White).backgroundColor('#67C23A')
            .onClick(() => { this.openCreate() })
        }
        .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor(Color.White)

        // ===== 搜索栏 =====
        Row() {
          TextInput({ placeholder: '任务编号' })
            .width('22%').height(32).fontSize(12)
            .onChange((v: string) => this.sCode = v)
          TextInput({ placeholder: '创建人' })
            .width('18%').height(32).fontSize(12)
            .onChange((v: string) => this.sCreator = v).margin({ left: 8 })
          TextInput({ placeholder: '执行人' })
            .width('18%').height(32).fontSize(12)
            .onChange((v: string) => this.sExecutor = v).margin({ left: 8 })
          Select([
            { value: '全部状态' }, { value: '待巡视' }, { value: '巡视中' },
            { value: '待上传' }, { value: '已完成' }
          ])
            .width('16%').height(32)
            .selected(this.sStatus === '待巡视' ? 1 : this.sStatus === '巡视中' ? 2 :
              this.sStatus === '待上传' ? 3 : this.sStatus === '已完成' ? 4 : 0)
            .onSelect((index: number) => {
              const vals = ['', '待巡视', '巡视中', '待上传', '已完成']
              this.sStatus = vals[index]
            }).margin({ left: 8 })
          Button('搜索').fontSize(11).height(32)
            .backgroundColor('#67C23A').fontColor(Color.White)
            .borderRadius(4)
            .onClick(() => this.onSearch()).margin({ left: 8 })
          Button('重置').fontSize(11).height(32)
            .backgroundColor('#67C23A').fontColor(Color.White)
            .borderRadius(4)
            .onClick(() => { this.onReset() }).margin({ left: 4 })
        }
        .width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor('#FAFAFA').border({ width: { bottom: 1 }, color: '#E4E7ED' })

        // ===== 统计 =====
        if (this.page === 1) {
          Text('巡视中任务置顶显示')
            .fontSize(11).fontColor('#909399')
            .width('100%').padding({ left: 16, top: 8, bottom: 8 })
            .backgroundColor(Color.White)
        }

        // ===== 表头 =====
        Row() {
          Text('任务编号').fontSize(12).fontColor('#909399').width('16%')
          Text('任务名称').fontSize(12).fontColor('#909399').width('14%')
          Text('创建人').fontSize(12).fontColor('#909399').width('8%')
          Text('执行人').fontSize(12).fontColor('#909399').width('8%')
          Text('状态').fontSize(12).fontColor('#909399').width('10%')
          Text('执行时间').fontSize(12).fontColor('#909399').width('18%')
          Text('操作').fontSize(12).fontColor('#909399').width('26%')
        }
        .width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor('#F5F7FA').border({ width: { bottom: 1 }, color: '#E4E7ED' })

        // ===== 列表 =====
        List() {
          ForEach(this.tasks, (t: Record<string, Object>) => {
            ListItem() {
              Row() {
                Text(this.field(t, 'taskCode')).fontSize(12).width('16%')
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.field(t, 'taskName')).fontSize(12).width('14%')
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.field(t, 'creator')).fontSize(12).width('8%')
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.field(t, 'executor')).fontSize(12).width('8%')
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.field(t, 'taskStatus'))
                  .fontSize(11).fontColor(Color.White)
                  .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                  .borderRadius(4)
                  .backgroundColor(this.statusColor(this.field(t, 'taskStatus')))
                  .maxLines(1)
                Text(this.field(t, 'execTime')).fontSize(11).width('18%').fontColor('#909399')
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Row() {
                  ForEach(this.actionList(this.field(t, 'taskStatus')), (a: string) => {
                    Button(this.actionLabel(a))
                      .fontSize(10).height(24).padding({ left: 5, right: 5 })
                      .backgroundColor(Color.Transparent)
                      .fontColor(a === 'delete' ? '#F56C6C' : a === 'abort' ? '#E6A23C' : '#67C23A')
                      .borderRadius(3)
                      .onClick(() => { this.doAction(a, t) })
                  })
                }.width('26%')
              }
              .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .alignItems(VerticalAlign.Center)
            }
            .border({ width: { bottom: 1 }, color: '#EBEEF5' })
          })
        }
        .layoutWeight(1).width('100%').backgroundColor(Color.White)

        // ===== 分页 =====
        Row() {
          // 总数
          Text('共 ' + this.total + ' 条').fontSize(13).fontColor('#606266')

          // 每页条数
          Text('每页').fontSize(13).fontColor('#606266').margin({ left: 20 })
          Select([
            { value: '10 条/页' }, { value: '15 条/页' }, { value: '20 条/页' },
            { value: '50 条/页' }, { value: '100 条/页' }
          ])
            .width(90).height(28)
            .selected(this.pageSizeIndex)
            .onSelect((index: number) => {
              const sizes = [10, 15, 20, 50, 100]
              this.pageSizeIndex = index
              this.pageSize = sizes[index]
              this.page = 1
              this.loadData()
            })

          Blank()

          // 上一页按钮
          Button('上一页')
            .fontSize(12).height(28).padding({ left: 10, right: 10 })
            .backgroundColor(Color.White)
            .border({ width: 1, color: '#DCDFE6', radius: 4 })
            .fontColor(this.page > 1 ? '#303133' : '#C0C4CC')
            .enabled(this.page > 1)
            .onClick(() => { this.goPage(this.page - 1) })

          // 页码 如 "1 / 24"
          Text(this.page + ' / ' + Math.ceil(this.total / this.pageSize))
            .fontSize(13).fontWeight(FontWeight.Bold).fontColor('#303133')
            .margin({ left: 12, right: 12 })

          // 下一页按钮
          Button('下一页')
            .fontSize(12).height(28).padding({ left: 10, right: 10 })
            .backgroundColor(Color.White)
            .border({ width: 1, color: '#DCDFE6', radius: 4 })
            .fontColor(this.page * this.pageSize < this.total ? '#303133' : '#C0C4CC')
            .enabled(this.page * this.pageSize < this.total)
            .onClick(() => { this.goPage(this.page + 1) })

          // 跳转
          Text('前往').fontSize(13).fontColor('#606266').margin({ left: 20 })
          TextInput({ placeholder: '', text: this.jumpPage })
            .width(48).height(28).fontSize(12).type(InputType.Number)
            .borderRadius(3).border({ width: 1, color: '#DCDFE6' })
            .onChange((v: string) => { this.jumpPage = v })
          Text('页').fontSize(13).fontColor('#606266').margin({ left: 4 })
          Button('GO')
            .fontSize(11).height(28).padding({ left: 8, right: 8 })
            .backgroundColor('#67C23A').fontColor(Color.White)
            .borderRadius(3).margin({ left: 6 })
            .onClick(() => {
              const n = parseInt(this.jumpPage)
              if (n >= 1 && n <= Math.ceil(this.total / this.pageSize)) {
                this.page = n; this.loadData()
              }
              this.jumpPage = ''
            })
        }
        .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor(Color.White)
      }
      .width('100%').height('100%').backgroundColor('#F0F2F5')

      // ===== 详情弹窗 =====
      if (this.detailVisible) {
        Column() {
          Column() {
            Text('任务详情').fontSize(16).fontWeight(FontWeight.Bold).padding(16)
            Divider().color('#E4E7ED')
            Column() {
              this.infoRow('任务编号', this.field(this.cur, 'taskCode'))
              this.infoRow('任务名称', this.field(this.cur, 'taskName'))
              this.infoRow('起始地点', this.field(this.cur, 'startPos'))
              this.infoRow('任务距离', this.field(this.cur, 'taskTrip') + ' 米')
              this.infoRow('创建人', this.field(this.cur, 'creator'))
              this.infoRow('执行人', this.field(this.cur, 'executor') !== '--' ? this.field(this.cur, 'executor') : '未分配')
              this.infoRow('执行时间', this.field(this.cur, 'execTime'))
              this.infoRow('结束时间', this.field(this.cur, 'endTime'))
              Row() {
                Text('状态').fontSize(12).fontColor('#909399').width(80)
                Text(this.field(this.cur, 'taskStatus'))
                  .fontSize(12).fontColor(this.statusColor(this.field(this.cur, 'taskStatus')))
              }.margin({ bottom: 8 })
            }.padding(16)
            Divider().color('#E4E7ED')
            Row() {
              Button('关闭').fontSize(12).backgroundColor('#FFFFFF')
                .border({ width: 1, color: '#DCDFE6', radius: 4 })
                .padding({ left: 20, right: 20 }).fontColor('#606266')
                .onClick(() => { this.detailVisible = false })
              if (this.field(this.cur, 'taskStatus') === '待巡视') {
                Button('启动').fontSize(12).backgroundColor('#67C23A').borderRadius(4)
                  .padding({ left: 20, right: 20 }).fontColor('#FFFFFF').margin({ left: 8 })
                  .onClick(() => { this.detailVisible = false; this.doAction('start', this.cur) })
              }
              if (this.field(this.cur, 'taskStatus') === '巡视中') {
                Button('进入巡视').fontSize(12).backgroundColor('#67C23A').borderRadius(4)
                  .padding({ left: 20, right: 20 }).fontColor('#FFFFFF').margin({ left: 8 })
                  .onClick(() => {
                    this.detailVisible = false
                    router.pushUrl({
                      url: 'pages/ExecutePage',
                      params: new ExecParams((this.cur['id'] as number) || 0, (this.cur['taskCode'] as string) || '')
                    })
                  })
              }
              if (this.field(this.cur, 'taskStatus') === '已完成' || this.field(this.cur, 'taskStatus') === '待上传') {
                Button('查看历史').fontSize(12).backgroundColor('#67C23A').borderRadius(4)
                  .padding({ left: 20, right: 20 }).fontColor('#FFFFFF').margin({ left: 8 })
                  .onClick(() => {
                    this.detailVisible = false
                    router.pushUrl({
                      url: 'pages/TaskHistory',
                      params: new ExecParams((this.cur['id'] as number) || 0, (this.cur['taskCode'] as string) || '')
                    })
                  })
              }
            }.padding(16).justifyContent(FlexAlign.Center)
          }
          .width('85%').backgroundColor('#FFFFFF').borderRadius(12).clip(true)
        }
        .width('100%').height('100%').backgroundColor('rgba(0,0,0,0.5)')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .onClick(() => { this.detailVisible = false })
      }

      // ===== 创建弹窗 =====
      if (this.createVisible) {
        Column() {
          Column() {
            Text('新增任务').fontSize(18).fontWeight(FontWeight.Bold).padding(20)
            Divider().color('#E4E7ED')

            // 表单区
            Column() {
              // 任务名称 | 任务编号
              Row() {
                Text('任务名称*').fontSize(13).fontColor('#606266').width(100)
                TextInput({ text: this.cfName }).fontSize(14).height(40).layoutWeight(1)
                  .onChange((v: string) => { this.cfName = v })
                  .border({ width: 1, color: '#DCDFE6', radius: 4 })
                Text('任务编号').fontSize(13).fontColor('#606266').width(100).margin({ left: 20 })
                TextInput({ placeholder: '留空自动生成', text: this.cfCode }).fontSize(14).height(40).layoutWeight(1)
                  .placeholderColor('#C0C4CC')
                  .onChange((v: string) => { this.cfCode = v })
                  .border({ width: 1, color: '#DCDFE6', radius: 4 })
              }.width('100%').margin({ bottom: 16 })

              // 起始地点 | 任务距离
              Row() {
                Text('起始地点').fontSize(13).fontColor('#606266').width(100)
                TextInput({ text: this.cfStartPos }).fontSize(14).height(40).layoutWeight(1)
                  .onChange((v: string) => { this.cfStartPos = v })
                  .border({ width: 1, color: '#DCDFE6', radius: 4 })
                Text('任务距离(m)*').fontSize(13).fontColor('#606266').width(100).margin({ left: 20 })
                TextInput({ text: this.cfTrip }).fontSize(14).height(40).layoutWeight(1)
                  .onChange((v: string) => { this.cfTrip = v })
                  .border({ width: 1, color: '#DCDFE6', radius: 4 })
              }.width('100%').margin({ bottom: 16 })

              // 创建人 | 执行人
              Row() {
                Text('创建人*').fontSize(13).fontColor('#606266').width(100)
                TextInput({ text: this.cfCreator }).fontSize(14).height(40).layoutWeight(1)
                  .onChange((v: string) => { this.cfCreator = v })
                  .border({ width: 1, color: '#DCDFE6', radius: 4 })
                Text('执行人*').fontSize(13).fontColor('#606266').width(100).margin({ left: 20 })
                TextInput({ text: this.cfExecutor }).fontSize(14).height(40).layoutWeight(1)
                  .onChange((v: string) => { this.cfExecutor = v })
                  .border({ width: 1, color: '#DCDFE6', radius: 4 })
              }.width('100%').margin({ bottom: 8 })
            }.padding(20)

            if (this.cfMsg) {
              Text(this.cfMsg).fontSize(12).fontColor('#F56C6C')
                .padding({ left: 20, right: 20, bottom: 12 })
            }

            Divider().color('#E4E7ED')
            Row() {
              Button('取消').fontSize(13).backgroundColor('#FFFFFF')
                .border({ width: 1, color: '#DCDFE6', radius: 4 })
                .padding({ left: 24, right: 24, top: 8, bottom: 8 }).fontColor('#606266')
                .onClick(() => { this.createVisible = false })
              Button('保存任务').fontSize(13).backgroundColor('#67C23A').borderRadius(4)
                .padding({ left: 24, right: 24, top: 8, bottom: 8 }).fontColor('#FFFFFF').margin({ left: 12 })
                .onClick(() => { this.doCreate(false) })
              Button('保存并启动').fontSize(13).backgroundColor('#67C23A').borderRadius(4)
                .padding({ left: 24, right: 24, top: 8, bottom: 8 }).fontColor('#FFFFFF').margin({ left: 12 })
                .onClick(() => { this.doCreate(true) })
            }.padding({ left: 20, right: 20, top: 16, bottom: 16 }).justifyContent(FlexAlign.Center)
          }
          .width('80%').backgroundColor('#FFFFFF').borderRadius(12).clip(true)
        }
        .width('100%').height('100%').backgroundColor('rgba(0,0,0,0.5)')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .onClick(() => { this.createVisible = false })
      }
    }
    .width('100%').height('100%')
  }

  @Builder infoRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor('#909399').width(80)
      Text(value).fontSize(12)
    }.margin({ bottom: 8 })
  }
}
