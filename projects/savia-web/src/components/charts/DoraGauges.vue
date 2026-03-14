<script setup lang="ts">
import { computed } from 'vue'
import VChart from 'vue-echarts'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { GaugeChart } from 'echarts/charts'
import { TooltipComponent } from 'echarts/components'

use([CanvasRenderer, GaugeChart, TooltipComponent])

const props = defineProps<{
  deployFreq: { value: number; unit: string }
  leadTime: { value: number; unit: string }
  cfr: { value: number }
  mttr: { value: number; unit: string }
}>()

function gaugeOption(
  title: string,
  value: number,
  max: number,
  color: string,
) {
  return {
    series: [
      {
        type: 'gauge',
        startAngle: 200,
        endAngle: -20,
        min: 0,
        max,
        pointer: { show: false },
        progress: { show: true, width: 14, itemStyle: { color } },
        axisLine: { lineStyle: { width: 14, color: [[1, '#EDE7F3']] } },
        axisTick: { show: false },
        splitLine: { show: false },
        axisLabel: { show: false },
        title: {
          show: true,
          offsetCenter: [0, '60%'],
          fontSize: 12,
          color: '#49454F',
        },
        detail: {
          valueAnimation: true,
          offsetCenter: [0, '20%'],
          fontSize: 22,
          fontWeight: 700,
          color,
        },
        data: [{ value: Math.round(value * 10) / 10, name: title }],
      },
    ],
  }
}

const opts = computed(() => [
  gaugeOption('Deploy Freq', props.deployFreq.value, 10, '#6B4C9A'),
  gaugeOption('Lead Time', props.leadTime.value, 30, '#8E6FBF'),
  gaugeOption(
    'CFR %',
    props.cfr.value,
    50,
    props.cfr.value > 15 ? '#BA1A1A' : '#6B4C9A',
  ),
  gaugeOption('MTTR', props.mttr.value, 24, '#A78BCA'),
])
</script>

<template>
  <div class="dora-grid">
    <VChart
      v-for="(opt, i) in opts"
      :key="i"
      :option="opt"
      autoresize
      style="height: 200px"
    />
  </div>
</template>

<style scoped>
.dora-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
}
@media (max-width: 600px) {
  .dora-grid {
    grid-template-columns: 1fr;
  }
}
</style>
