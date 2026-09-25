<script setup lang="ts">
import { useNav } from '@slidev/client'

const { currentLayout } = useNav()
</script>

<template>
  <div
    v-if="!['cover', 'section', 'end', 'image'].includes(currentLayout)"
    class="slide-footer"
  >
    <img src="/logos/membrane-full-on-light.svg" alt="Membrane" />
    <span>Multimedia with Membrane 101 · Goatmire 2026 · <SlideCurrentNo /> / <SlidesTotal /></span>
  </div>
</template>
