import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/authStore'
import AppShell from '../components/AppShell.vue'
import AuthView from '../views/AuthView.vue'
import CalendarView from '../views/CalendarView.vue'
import DashboardView from '../views/DashboardView.vue'
import EditProfileView from '../views/EditProfileView.vue'
import ExerciseDetailView from '../views/ExerciseDetailView.vue'
import ExercisesView from '../views/ExercisesView.vue'
import LiveWorkoutView from '../views/LiveWorkoutView.vue'
import PersonalRecordsView from '../views/PersonalRecordsView.vue'
import PrivacyPolicyView from '../views/PrivacyPolicyView.vue'
import RegisterView from '../views/RegisterView.vue'
import RoutineDetailView from '../views/RoutineDetailView.vue'
import RoutineFormView from '../views/RoutineFormView.vue'
import RoutinesView from '../views/RoutinesView.vue'
import SaveWorkoutView from '../views/SaveWorkoutView.vue'
import StatsView from '../views/StatsView.vue'
import WorkoutDetailView from '../views/WorkoutDetailView.vue'

declare module 'vue-router' {
  interface RouteMeta {
    requiresAuth?: boolean
    guestOnly?: boolean
    hideNav?: boolean
  }
}

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', name: 'login', component: AuthView, meta: { guestOnly: true } },
    { path: '/register', name: 'register', component: RegisterView, meta: { guestOnly: true } },
    { path: '/privacy', name: 'privacy', component: PrivacyPolicyView },
    {
      path: '/',
      component: AppShell,
      meta: { requiresAuth: true },
      children: [
        { path: '', name: 'dashboard', component: DashboardView },
        { path: 'workout', name: 'workout', component: RoutinesView },
        { path: 'workout/routines/new', name: 'routine-new', component: RoutineFormView },
        { path: 'workout/routines/:id', name: 'routine', component: RoutineDetailView },
        { path: 'workout/routines/:id/edit', name: 'routine-edit', component: RoutineFormView },
        { path: 'exercises', name: 'exercises', component: ExercisesView },
        { path: 'exercises/:id', name: 'exercise', component: ExerciseDetailView },
        { path: 'stats', name: 'stats', component: StatsView },
        { path: 'stats/records', name: 'records', component: PersonalRecordsView },
        { path: 'stats/prs', redirect: { name: 'records' } },
        { path: 'calendar', name: 'calendar', component: CalendarView },
        { path: 'profile', redirect: { name: 'profile-edit' } },
        { path: 'profile/edit', name: 'profile-edit', component: EditProfileView },
        { path: 'workouts/:id', name: 'workout-detail', component: WorkoutDetailView },
        { path: 'live', name: 'live', component: LiveWorkoutView, meta: { hideNav: true } },
        { path: 'live/save', name: 'save', component: SaveWorkoutView, meta: { hideNav: true } },
      ],
    },
  ],
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  await auth.initialize()
  if (to.meta.requiresAuth && !auth.session) return { name: 'login' }
  if (to.meta.guestOnly && auth.session) return { name: 'dashboard' }
  return true
})

export default router
