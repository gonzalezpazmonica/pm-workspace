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
  states: { name: string; value: number }[]
}>()

const colors = ['#CDB4DB', '#A78BCA', '#8E6FBF', '#6B4C9A', '#4A2D7A']

const option = computed(() => ({
  tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
  legend: { data: props.states.map((s) => s.name) },
  grid: { left: 20, right: 20, bottom: 20, top: 40 },
  xAxis: { type: 'value' },
  yAxis: { type: 'category', data: ['Sprint'] },
  series: props.states.map((s, i) => ({
    name: s.name,
    type: 'bar',
    stack: 'total',
    data: [s.value],
    itemStyle: { color: colors[i % colors.length] },
  })),
}))
</script>

<template>
  <VChart :option="option" autoresize style="height: 120px" />
</template>
