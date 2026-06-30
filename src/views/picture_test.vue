<template>
  <div class="picture-test-container">
    <h2>缺陷图片预览</h2>
    <div class="image-wrapper">
      <img
        :src="imageSrc"
        alt="缺陷图片"
        class="flaw-image"
        @load="onImageLoad"
        @error="onImageError"
      />
    </div>
    <p class="image-info">{{ imageInfo }}</p>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import flawImage from '../assets/flaw-img/20260623222923432.jpg'

const imageSrc = flawImage
const imageInfo = ref('加载中...')

function onImageLoad() {
  imageInfo.value = '图片加载成功 — 20260623222923432.jpg'
}

function onImageError() {
  imageInfo.value = '图片加载失败'
}
</script>

<style scoped>
.picture-test-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 20px;
}

h2 {
  margin-bottom: 16px;
  color: #303133;
}

.image-wrapper {
  max-width: 900px;
  width: 100%;
  border: 1px solid #dcdfe6;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.1);
}

.flaw-image {
  width: 100%;
  height: auto;
  display: block;
}

.image-info {
  margin-top: 12px;
  color: #909399;
  font-size: 14px;
}
</style>
