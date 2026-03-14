<script setup lang="ts">
import { computed } from 'vue'
import VChart from 'vue-echarts'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { GaugeChart } from 'echarts/charts'

use([CanvasRenderer, GaugeChart])

const props = defineProps<{ coverage: number; target: number }>()

const color = computed(() =>
  props.coverage >= props.target ? '#6B4C9A' : '#BA1A1A',
)

const option = computed(() => ({
  series: [
    {
      type: 'gauge',
      startAngle: 200,
      endAngle: -20,
      min: 0,
      max: 100,
      pointer: { show: false },
      progress: {
        show: true,
        width: 18,
        itemStyle: { color: color.value },
      },
      axisLine: {
        lineStyle: { width: 18, color: [[1, '#EDE7F3']] },
      },
      axisTick: { show: false },
      splitLine: { show: false },
      axisLabel: { show: false },
      title: {
        show: true,
        offsetCenter: [0, '65%'],
        fontSize: 13,
        color: '#49454F',
      },
      detail: {
        valueAnimation: true,
        offsetCenter: [0, '20%'],
        fontSize: 28,
        fontWeight: 700,
        color: color.value,
        formatter: '{value}%',
      },
      data: [
        {
          value: props.coverage,
          name: `Target: ${props.target}%`,
        },
      ],
    },
  ],
}))
</script>

<template>
  <VChart :option="option" autoresize style="height: 250px" />
</template>
