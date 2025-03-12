// Entry point for just the AI Chat component
import { createApp } from 'vue'
import AIChat from './components/AIChat.vue'

// Mount the AI Chat component on non-dashboard pages
document.addEventListener('DOMContentLoaded', () => {
  const aiChatContainer = document.getElementById('ai-chat-app')
  
  if (aiChatContainer) {
    console.log('Mounting standalone AI chat component');
    const app = createApp({
      components: {
        'ai-chat': AIChat
      },
      data() {
        return {
          expanded: false
        }
      },
      methods: {
        updateExpanded(value) {
          console.log('Standalone chat expanded state updated:', value);
          this.expanded = value;
        }
      },
      template: '<ai-chat :is-sidebar-integrated="false" :force-expanded="expanded" @update:expanded="updateExpanded" />'
    })
    
    app.mount('#ai-chat-app')
  }
})