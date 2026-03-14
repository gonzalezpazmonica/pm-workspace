<script setup lang="ts">
import { computed } from 'vue'
import VChart from 'vue-echarts'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { BarChart } from 'echarts/charts'
import {
  GridComponent,
  TooltipComponent,
  LegendComponent,
} from 'echarts/components'

use([CanvasRenderer, BarChart, GridComponent, TooltipComponent, LegendComponent])

const props = defineProps<{
  sprints: { name: string; planned: number; completed: number }[]
}>()

const option = computed(() => ({
  tooltip: { trigger: 'axis' },
  legend: { data: ['Planned', 'Completed'] },
  grid: { left: 40, right: 20, bottom: 40, top: 40 },
  xAxis: {
    type: 'category',
    data: props.sprints.map((s) => s.name),
    axisLabel: { rotate: 20, fontSize: 11 },
  },
  yAxis: { type: 'value', name: 'SP' },
  series: [
    {
      name: 'Planned',
      type: 'bar',
      data: props.sprints.map((s) => s.planned),
      itemStyle: { color: '#CDB4DB' },
    },
    {
      name: 'Completed',
      type: 'bar',
      data: props.sprints.map((s) => s.completed),
      itemStyle: { color: '#6B4C9A' },
    },
  ],
}))
</script>

<template>
  <VChart :option="option" autoresize style="height: 300px" />
</template>
