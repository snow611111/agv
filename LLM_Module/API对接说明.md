# 巡检报告生成 API 对接说明

## 接口信息

| 项目 | 值 |
|------|-----|
| 请求方式 | POST |
| 接口地址 | `http://<服务器IP>/v1/workflows/run` |
| 认证方式 | Bearer Token |
| Content-Type | application/json |
| 超时建议 | 5 分钟（生成耗时约 2-4 分钟） |
| 响应模式 | blocking（等待完整生成） |

> API Key 由项目成员本地配置，不在文档中公开。

---

## 输入参数

### 请求体结构

```json
{
  "inputs": {
    "task_info": "<String，必填>",
    "flaw_list": "<String，必填>",
    "upload_info": "<String，可选>"
  },
  "response_mode": "blocking",
  "user": "<终端标识>"
}
```

### 参数说明

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|:--:|------|
| task_info | String | ✅ | 任务详情 JSON 字符串。先 JSON.stringify() 再放入 |
| flaw_list | String | ✅ | 故障列表 JSON 字符串。先 JSON.stringify() 再放入 |
| upload_info | String | | 上传检查结果 JSON 字符串，无数据时传空字符串 `""` |
| response_mode | String | ✅ | 固定 `"blocking"` |
| user | String | ✅ | 终端标识，如 `"agv-terminal"` |

### task_info 字段说明

```json
{
  "taskCode": "任务编号",
  "taskName": "任务名称",
  "taskTrip": 巡检里程（数字，单位：米）,
  "executor": "执行人",
  "execTime": "巡检开始时间（如 2026-06-24 09:00:00）",
  "endTime": "巡检结束时间（如 2026-06-24 10:30:00）",
  "taskStatus": "任务状态（待巡视/巡视中/待上传/已完成/执行中）"
}
```

> execTime、endTime、taskTrip 为可选字段，缺失时报告显示"数据未提供"。

### flaw_list 字段说明

```json
[
  {
    "flawName": "故障名称",
    "flawType": "故障类型（结构缺陷/渗漏问题/设备故障等）",
    "flawDesc": "故障描述（可选）",
    "flawDistance": 故障位置距离（数字）,
    "confirmed": 是否已确认（true/false）
  }
]
```

> flawDesc、flawDistance 为可选字段。

---

## 输出格式

### 成功响应

```json
{
  "task_id": "...",
  "workflow_run_id": "...",
  "data": {
    "id": "...",
    "workflow_id": "...",
    "status": "succeeded",
    "outputs": {
      "report_content": "完整的巡检报告正文（Markdown 格式）"
    },
    "error": null,
    "elapsed_time": 263.4,
    "total_tokens": 1861
  }
}
```

取 `data.outputs.report_content` 即为报告正文。

### 失败响应

```json
{
  "data": {
    "status": "failed",
    "error": "错误信息"
  }
}
```

---

## 完整调用示例

```http
POST http://172.18.241.21/v1/workflows/run
Authorization: Bearer app-xxxxx
Content-Type: application/json

{
  "inputs": {
    "task_info": "{\"taskCode\":\"TASK002\",\"taskName\":\"隧道重点巡检\",\"taskTrip\":800,\"executor\":\"李四\",\"execTime\":\"2026-06-24 09:00:00\",\"endTime\":\"2026-06-24 10:30:00\",\"taskStatus\":\"已完成\"}",
    "flaw_list": "[{\"flawType\":\"结构缺陷\",\"flawName\":\"隧道壁面裂缝\",\"flawDistance\":120,\"confirmed\":true},{\"flawType\":\"渗漏问题\",\"flawName\":\"疑似渗水点\",\"flawDistance\":350,\"confirmed\":false}]"
  },
  "response_mode": "blocking",
  "user": "agv-terminal"
}
```

---

## 鸿蒙端调用流程

```
任务详情页
  → 点击「生成AI巡检报告」按钮
  → 按钮变灰，显示「生成中...」
  → GET /agv/task/{id} 获取任务详情 → JSON.stringify → task_info
  → GET /agv/flaw/list?taskId={id} 获取故障列表 → JSON.stringify → flaw_list
  → POST /v1/workflows/run
  → 展示 data.outputs.report_content
  → 恢复按钮，支持「重新生成」
```

## 页面 UI 要求

- 「生成AI巡检报告」按钮
- 生成中状态指示（约 2-4 分钟）
- 报告展示区域（支持 Markdown 渲染）
- 失败提示 + 「重新生成」按钮
- 免责声明：「本报告由AI生成，仅供辅助参考，最终以人工复核为准」

## 网络说明

Dify 运行在局域网某台电脑的 Docker 中，鸿蒙端需与该电脑在同一局域网内。不可使用 `localhost`，需使用电脑的局域网 IP。

测试前先确认：
1. 电脑端 `docker ps` 确认 Dify 容器在运行
2. 鸿蒙端 ping 电脑 IP 能通
3. 浏览器访问 `http://<电脑IP>` 能看到 Dify 登录页
