export interface Project {
  id: string
  name: string
  team: string
  currentSprint: string
  health: string
}

export interface SprintSummary {
  name: string
  progress: number
  completedPoints: number
  totalPoints: number
  blockedItems: number
  daysRemaining: number
  velocity: number
}

export interface BoardItem {
  id: string
  title: string
  state: string
  type: string
  assignedTo: string
  priority: number
}

export interface BoardColumn {
  name: string
  items: BoardItem[]
}

export interface DashboardData {
  greeting: string
  projects: Project[]
  selectedProjectId: string | null
  sprint: SprintSummary | null
  myTasks: BoardItem[]
  recentActivity: string[]
  blockedItems: number
  hoursToday: number
}

export interface UserProfile {
  name: string
  email: string
  role: string
  organization: string
  stats: UserStats
}

export interface UserStats {
  sprintsCompleted: number
  pbisDelivered: number
  hoursLogged: number
}

export interface TimeEntry {
  id: string
  taskId: string
  taskTitle: string
  hours: number
  date: string
  note: string
}

export interface ApprovalRequest {
  id: string
  title: string
  type: string
  requestedBy: string
  createdAt: string
  status: string
  description: string
}

export interface CommandFamily {
  name: string
  description: string
  icon: string
  commands: SlashCommand[]
}

export interface SlashCommand {
  name: string
  description: string
  usage: string
}

export interface CompanyProfile {
  status: string
  identity?: CompanySection
  structure?: CompanySection
  strategy?: CompanySection
  policies?: CompanySection
  technology?: CompanySection
  vertical?: CompanySection
}

export interface CompanySection {
  fields: Record<string, string>
  content: string
}

export interface FileEntry {
  name: string
  type: 'file' | 'directory'
  size?: number
  modified?: string
}

export interface BridgeResponse<T> {
  data?: T
  error?: string
}

export interface TeamMember {
  slug: string
  name?: string
  role?: string
  email?: string
  company?: string
  [key: string]: string | boolean | undefined
}

export interface TeamResponse {
  status: string
  members: TeamMember[]
  count: number
}
