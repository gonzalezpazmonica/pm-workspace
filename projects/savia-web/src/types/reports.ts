export interface ReportResponse<T> {
  project: string
  generated_at: string
  data: T
}

export interface VelocityData {
  sprints: { name: string; planned: number; completed: number }[]
}

export interface BurndownData {
  sprintName: string
  days: { date: string; ideal: number; actual: number }[]
}

export interface DoraData {
  deployFrequency: { value: number; unit: string; trend: string }
  leadTime: { value: number; unit: string; trend: string }
  changeFailureRate: { value: number; unit: string; trend: string }
  mttr: { value: number; unit: string; trend: string }
}

export interface TeamWorkloadData {
  members: { name: string; capacity: number; assigned: number }[]
}

export interface QualityData {
  coverage: number
  coverageTarget: number
  bugs: { severity: string; count: number }[]
  escapeRate: number
}

export interface DebtData {
  trend: { date: string; count: number }[]
  topItems: { title: string; age: number; severity: string; effort: string }[]
}

export interface CycleTimeData {
  sprints: { name: string; cycleTime: number; leadTime: number }[]
}

export interface PortfolioData {
  projects: {
    name: string; health: string; velocity: number
    coverage: number; debt: number; satisfaction: number
  }[]
}

export interface SpDistributionData {
  states: { state: string; points: number }[]
}
