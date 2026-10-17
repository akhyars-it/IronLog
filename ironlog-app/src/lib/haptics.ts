import { Haptics, ImpactStyle } from '@capacitor/haptics'

/** Heavy impact on device. Falls back to a short vibration, then does nothing. */
export async function impactHeavy(): Promise<void> {
  try {
    await Haptics.impact({ style: ImpactStyle.Heavy })
  } catch {
    try {
      navigator.vibrate?.(40)
    } catch {
      // Browsers without a vibration API, or a blocked gesture, stay silent.
    }
  }
}
