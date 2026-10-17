import {
  BarElement,
  CategoryScale,
  Chart as ChartJS,
  Filler,
  Legend,
  LinearScale,
  LineElement,
  PointElement,
  Tooltip,
  type ChartOptions,
} from 'chart.js'

ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  PointElement,
  LineElement,
  Filler,
  Tooltip,
  Legend,
)

const tick = '#a1a1aa'
const grid = '#27272a'

export function barOptions(): ChartOptions<'bar'> {
  return {
    responsive: true,
    maintainAspectRatio: false,
    plugins: { legend: { display: false } },
    scales: {
      x: { ticks: { color: tick, maxRotation: 0 }, grid: { display: false } },
      y: { beginAtZero: true, ticks: { color: tick, precision: 0 }, grid: { color: grid } },
    },
  }
}

export function lineOptions(): ChartOptions<'line'> {
  return {
    responsive: true,
    maintainAspectRatio: false,
    plugins: { legend: { display: false } },
    scales: {
      x: { ticks: { color: tick, maxRotation: 0 }, grid: { display: false } },
      y: { beginAtZero: true, ticks: { color: tick }, grid: { color: grid } },
    },
  }
}

