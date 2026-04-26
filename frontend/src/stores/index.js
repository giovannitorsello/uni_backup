import { store } from 'quasar/wrappers'
import { createPinia } from 'pinia'

export default store((/* { ssrContext } */) => {
  const pinia = createPinia()
  // Qui puoi aggiungere eventuali plugin di Pinia
  return pinia
})