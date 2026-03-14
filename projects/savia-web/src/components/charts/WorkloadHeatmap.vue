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
  members: { name: string; capacity: number; assigned: number }[]
}>()

const option = computed(() => ({
  tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
  legend: { data: ['Capacity', 'Assigned'] },
  grid: { left: 100, right: 20, bottom: 20, top: 40 },
  xAxis: { type: 'value', name: 'Hours' },
  yAxis: { type: 'category', data: props.members.map((m) => m.name) },
  series: [
    {
      name: 'Capacity',
      type: 'bar',
      data: props.members.map((m) => m.capacity),
      itemStyle: { color: '#EDE7F3' },
    },
    {
      name: 'Assigned',
      type: 'bar',
      data: props.members.map((m) => m.assigned),
      itemStyle: {
        color: (p: { value: number; dataIndex: number }) =>
          p.value > (props.members[p.dataIndex]?.capacity ?? 0)
            ? '#BA1A1A'
            : '#6B4C9A',
      },
    },
  ],
}))
</script>

<template>
  <VChart :option="option" autoresize style="height: 300px" />
</template>
