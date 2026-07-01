import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    // 项目内所有测试文件（AI 巡检报告模块）
    include: ['src/**/*.test.{ts,tsx}'],
    // 不使用 globals 以避免污染
    globals: false,
  },
})
