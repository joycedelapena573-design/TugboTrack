/** In-memory lock state: the app re-locks whenever it goes to the background. */
import { create } from 'zustand';

export const useAppLock = create<{ locked: boolean; setLocked: (v: boolean) => void }>((set) => ({
  locked: true,
  setLocked: (v) => set({ locked: v }),
}));
