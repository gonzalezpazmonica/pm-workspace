import { createRouter, createWebHistory } from 'vue-router'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: () => import('../pages/HomePage.vue') },
    { path: '/chat', component: () => import('../pages/ChatPage.vue') },
    { path: '/commands', component: () => import('../pages/CommandsPage.vue') },
    { path: '/kanban', component: () => import('../pages/KanbanPage.vue') },
    { path: '/approvals', component: () => import('../pages/ApprovalsPage.vue') },
    { path: '/timelog', component: () => import('../pages/TimeLogPage.vue') },
    { path: '/files', component: () => import('../pages/FileBrowserPage.vue') },
    { path: '/profile', component: () => import('../pages/ProfilePage.vue') },
    { path: '/settings', component: () => import('../pages/SettingsPage.vue') },
    {
      path: '/reports',
      component: () => import('../pages/reports/ReportsLayout.vue'),
      redirect: '/reports/sprint',
      children: [
        { path: 'sprint', component: () => import('../pages/reports/SprintReportPage.vue') },
        { path: 'board-flow', component: () => import('../pages/reports/BoardFlowPage.vue') },
        { path: 'team-workload', component: () => import('../pages/reports/TeamWorkloadPage.vue') },
        { path: 'portfolio', component: () => import('../pages/reports/PortfolioPage.vue') },
        { path: 'dora', component: () => import('../pages/reports/DoraMetricsPage.vue') },
        { path: 'quality', component: () => import('../pages/reports/QualityPage.vue') },
        { path: 'debt', component: () => import('../pages/reports/DebtPage.vue') },
      ]
    },
  ]
})

export default router
