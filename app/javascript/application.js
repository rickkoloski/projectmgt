// Entry point for the Vue application
import { createApp } from 'vue'
import App from './App.vue'

// Mount the Vue application
document.addEventListener('DOMContentLoaded', () => {
  const app = createApp(App)
  app.mount('#app')
})
