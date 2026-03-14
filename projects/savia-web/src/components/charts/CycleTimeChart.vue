<script setup lang="ts">
import { computed } from 'vue'
import VChart from 'vue-echarts'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { LineChart } from 'echarts/charts'
import {
  GridComponent,
  TooltipComponent,
  LegendComponent,
} from 'echarts/components'

use([CanvasRenderer, LineChart, GridComponent, TooltipComponent, LegendComponent])

const props = defineProps<{
  sprints: { name: string; cycleTime: number; leadTime: number }[]
}>()

const option = computed(() => ({
  tooltip: { trigger: 'axis' },
  legend: { data: ['Cycle Time', 'Lead Time'] },
  grid: { left: 40, right: 20, bottom: 40, top: 40 },
  xAxis: {
    type: 'category',
    data: props.sprints.map((s) => s.name),
    axisLabel: { rotate: 20, fontSize: 11 },
  },
  yAxis: { type: 'value', name: 'Days' },
  series: [
    {
      name: 'Cycle Time',
      type: 'line',
      data: props.sprints.map((s) => s.cycleTime),
      smooth: true,
      itemStyle: { color: '#6B4C9A' },
      areaStyle: { color: 'rgba(107,76,154,0.1)' },
    },
    {
      name: 'Lead Time',
      type: 'line',
      data: props.sprints.map((s) => s.leadTime),
      smooth: true,
      itemStyle: { color: '#A78BCA' },
      areaStyle: { color: 'rgba(167,139,202,0.08)' },
    },
  ],
}))
</script>

<template>
  <VChart :option="option" autoresize style="height: 300px" />
</template>
