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
  days: { date: string; ideal: number; actual: number }[]
}>()

const option = computed(() => ({
  tooltip: { trigger: 'axis' },
  legend: { data: ['Ideal', 'Actual'] },
  grid: { left: 40, right: 20, bottom: 30, top: 40 },
  xAxis: {
    type: 'category',
    data: props.days.map((d) => d.date.slice(5)),
  },
  yAxis: { type: 'value', name: 'SP' },
  series: [
    {
      name: 'Ideal',
      type: 'line',
      data: props.days.map((d) => d.ideal),
      lineStyle: { type: 'dashed', color: '#999' },
      itemStyle: { color: '#999' },
    },
    {
      name: 'Actual',
      type: 'line',
      data: props.days.map((d) => d.actual),
      lineStyle: { color: '#6B4C9A' },
      itemStyle: { color: '#6B4C9A' },
      areaStyle: { color: 'rgba(107,76,154,0.1)' },
    },
  ],
}))
</script>

<template>
  <VChart :option="option" autoresize style="height: 300px" />
</template>
