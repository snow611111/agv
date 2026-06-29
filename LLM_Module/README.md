# 巡检报告生成模块（基于大模型）

## 模块概述

本模块基于 Dify + Ollama + qwen3:8b 实现轨道交通巡检报告的自动生成。巡线车手持终端获取任务和故障数据后，调用本模块生成正式巡检报告。

## 技术栈

| 组件 | 说明 |
|------|------|
| Dify | AI 应用平台，管理工作流和 API |
| Ollama | 本地大模型运行引擎 |
| qwen3:8b | 使用的 LLM 模型（5.2 GB） |
| Docker | 容器化部署 Dify |

## 文件说明

```
LLM_Module/
├── README.md              # 本文件
├── 模块说明文档.md          # 详细模块说明
├── API对接说明.md           # 供前端/鸿蒙端使用
├── 测试结果.md              # 三组测试用例及结果
├── sync_payload.json       # Dify 工作流完整定义
└── prompt.txt              # 提示词模板
```

## 调用方式

```
POST http://<服务器IP>/v1/workflows/run
Authorization: Bearer <API_Key>
Content-Type: application/json

{
  "inputs": {
    "task_info": "<任务对象JSON字符串>",
    "flaw_list": "<故障数组JSON字符串>",
    "upload_info": "<上传信息JSON字符串，可选>"
  },
  "response_mode": "blocking",
  "user": "终端标识"
}
```

返回：`data.outputs.report_content`

## 免责声明

> 本报告由 AI 生成，仅供辅助参考，最终以人工复核为准。
