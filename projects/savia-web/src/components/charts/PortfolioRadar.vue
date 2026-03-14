<script setup lang="ts">
import { computed } from 'vue'
import VChart from 'vue-echarts'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { RadarChart } from 'echarts/charts'
import {
  TooltipComponent,
  LegendComponent,
} from 'echarts/components'

use([CanvasRenderer, RadarChart, TooltipComponent, LegendComponent])

interface ProjectHealth {
  name: string
  health: number
  velocity: number
  coverage: number
  debtCount: number
  sprintProgress: number
}

const props = defineProps<{ projects: ProjectHealth[] }>()

const colors = ['#6B4C9A', '#8E6FBF', '#A78BCA', '#CDB4DB', '#4A2D7A']

const indicators = [
  { name: 'Health', max: 100 },
  { name: 'Velocity', max: 50 },
  { name: 'Coverage', max: 100 },
  { name: 'Low Debt', max: 100 },
  { name: 'Progress', max: 100 },
]

const option = computed(() => ({
  tooltip: {},
  legend: {
    data: props.projects.map((p) => p.name),
    bottom: 0,
  },
  radar: { indicator: indicators, radius: '65%' },
  series: [
    {
      type: 'radar',
      data: props.projects.slice(0, 5).map((p, i) => ({
        name: p.name,
        value: [
          p.health,
          p.velocity,
          p.coverage,
          Math.max(0, 100 - p.debtCount * 5),
          p.sprintProgress * 100,
        ],
        lineStyle: { color: colors[i] },
        itemStyle: { color: colors[i] },
        areaStyle: { color: colors[i], opacity: 0.1 },
      })),
    },
  ],
}))
</script>

<template>
  <VChart :option="option" autoresize style="height: 350px" />
</template>
