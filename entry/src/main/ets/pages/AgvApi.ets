/**
 * SystemCheck 专用 API —— 从 old_hm 直接复制
 */
import { http } from '@kit.NetworkKit';

export const BASE_URL = 'http://192.168.2.57/prod-api';

export class CheckResult {
  key: string = '';
  label: string = '';
  solution: string = '';
  status: number = 0; // 0=loading, 1=success, 2=error
  expanded: boolean = false;
}

export function getCheckItems(): CheckResult[] {
  return [
    { key: 'fs', label: '正在检查系统文件完整性', solution: '解决方案：请重新安装本系统。', status: 0, expanded: false },
    { key: 'db', label: '正在检测数据库系统连接', solution: '解决方案：请检查数据库连接设置是否正确。', status: 0, expanded: false },
    { key: 'agv', label: '正在与车辆控制系统通信', solution: '解决方案：请检查巡检车IP与端口配置是否正确。', status: 0, expanded: false },
    { key: 'cam', label: '正在检测摄像头通道状态', solution: '解决方案：请检查摄像头IP及账号密码是否正确。', status: 0, expanded: false },
  ];
}

export async function runSystemCheck(items: CheckResult[]): Promise<boolean> {
  const endpoints = ['/system/check/fs', '/system/check/db', '/system/check/agv', '/system/check/cam'];

  for (let i = 0; i < items.length; i++) {
    items[i].status = 0;
    items[i].expanded = false;
  }

  for (let i = 0; i < items.length; i++) {
    try {
      const req = http.createHttp();
      const resp = await req.request(BASE_URL + endpoints[i], {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 5000,
        readTimeout: 5000
      });
      req.destroy();

      if (resp.responseCode === 200) {
        const text = resp.result as string;
        const data = JSON.parse(text) as Record<string, Object>;
        const ok = data['code'] === 200 || data['code'] === 0;
        items[i].status = ok ? 1 : 2;
      } else {
        items[i].status = 2;
      }
    } catch (e) {
      items[i].status = 2;
    }
    if (items[i].status === 2) {
      items[i].expanded = true;
    }
  }

  return items.every((c: CheckResult) => c.status === 1);
}
