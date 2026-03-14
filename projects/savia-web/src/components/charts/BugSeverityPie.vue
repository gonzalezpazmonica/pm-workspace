<script setup lang="ts">
import { computed } from 'vue'
import VChart from 'vue-echarts'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { PieChart } from 'echarts/charts'
import {
  TooltipComponent,
  LegendComponent,
} from 'echarts/components'

use([CanvasRenderer, PieChart, TooltipComponent, LegendComponent])

const props = defineProps<{
  bugs: { critical: number; high: number; medium: number; low: number }
}>()

const option = computed(() => ({
  tooltip: { trigger: 'item' },
  legend: { bottom: 0 },
  series: [
    {
      type: 'pie',
      radius: ['45%', '70%'],
      center: ['50%', '45%'],
      label: { show: true, formatter: '{b}: {c}' },
      data: [
        {
          value: props.bugs.critical,
          name: 'Critical',
          itemStyle: { color: '#BA1A1A' },
        },
        {
          value: props.bugs.high,
          name: 'High',
          itemStyle: { color: '#E6A817' },
        },
        {
          value: props.bugs.medium,
          name: 'Medium',
          itemStyle: { color: '#8E6FBF' },
        },
        {
          value: props.bugs.low,
          name: 'Low',
          itemStyle: { color: '#CDB4DB' },
        },
      ],
    },
  ],
}))
</script>

<template>
  <VChart :option="option" autoresize style="height: 300px" />
</template>
