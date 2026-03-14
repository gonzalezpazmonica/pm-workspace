<script setup lang="ts">
import { computed } from 'vue'
import VChart from 'vue-echarts'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { LineChart } from 'echarts/charts'
import {
  GridComponent,
  TooltipComponent,
  MarkLineComponent,
} from 'echarts/components'

use([
  CanvasRenderer,
  LineChart,
  GridComponent,
  TooltipComponent,
  MarkLineComponent,
])

const props = defineProps<{
  trend: { date: string; count: number }[]
}>()

const option = computed(() => ({
  tooltip: { trigger: 'axis' },
  grid: { left: 40, right: 20, bottom: 30, top: 20 },
  xAxis: {
    type: 'category',
    data: props.trend.map((t) => t.date),
  },
  yAxis: { type: 'value', name: 'Items' },
  series: [
    {
      type: 'line',
      data: props.trend.map((t) => t.count),
      smooth: true,
      itemStyle: { color: '#BA1A1A' },
      areaStyle: { color: 'rgba(186,26,26,0.08)' },
      markLine: {
        silent: true,
        data: [
          {
            type: 'average',
            label: { formatter: 'Avg: {c}' },
          },
        ],
      },
    },
  ],
}))
</script>

<template>
  <VChart :option="option" autoresize style="height: 250px" />
</template>
