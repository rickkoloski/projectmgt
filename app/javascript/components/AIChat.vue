<template>
  <div>
    <!-- Collapsed Chat Button (only shown in standalone mode) -->
    <div 
      v-if="!isSidebarIntegrated && !isExpanded" 
      class="ai-chat-container collapsed standalone-mode"
      @click="toggleChat"
    >
      <div class="ai-chat-toggle">
        <div class="ai-icon">
          <svg 
            xmlns="http://www.w3.org/2000/svg" 
            width="24" 
            height="24" 
            viewBox="0 0 24 24" 
            fill="none" 
            stroke="currentColor" 
            stroke-width="2" 
            stroke-linecap="round" 
            stroke-linejoin="round"
          >
            <path d="M12 2a8 8 0 0 1 8 8v12l-4-4H4a2 2 0 0 1-2-2V10a8 8 0 0 1 8-8h0z"></path>
            <path d="M14 9.5a6 6 0 0 0-6 0"></path>
            <path d="M12 13a1 1 0 1 0 0-2 1 1 0 0 0 0 2Z"></path>
          </svg>
          <span class="ai-label">AI Assistant</span>
        </div>
      </div>
    </div>
    
    <!-- Expanded Chat Panel -->
    <div 
      v-if="isExpanded"
      class="ai-chat-container expanded"
      :class="{ 'standalone-mode': !isSidebarIntegrated }"
    >
      <!-- Chat Panel Content -->
      <div class="ai-chat-header">
        <div class="ai-chat-title">
          <div class="ai-icon">
            <svg 
              xmlns="http://www.w3.org/2000/svg" 
              width="20" 
              height="20" 
              viewBox="0 0 24 24" 
              fill="none" 
              stroke="currentColor" 
              stroke-width="2" 
              stroke-linecap="round" 
              stroke-linejoin="round"
            >
              <path d="M12 2a8 8 0 0 1 8 8v12l-4-4H4a2 2 0 0 1-2-2V10a8 8 0 0 1 8-8h0z"></path>
              <path d="M14 9.5a6 6 0 0 0-6 0"></path>
              <path d="M12 13a1 1 0 1 0 0-2 1 1 0 0 0 0 2Z"></path>
            </svg>
          </div>
          <span style="color: red; font-weight: bold;">AI CHAT PANEL IS VISIBLE</span>
        </div>
        <div class="ai-chat-controls">
          <button class="ai-chat-settings">
            <svg 
              xmlns="http://www.w3.org/2000/svg" 
              width="18" 
              height="18" 
              viewBox="0 0 24 24" 
              fill="none" 
              stroke="currentColor" 
              stroke-width="2" 
              stroke-linecap="round" 
              stroke-linejoin="round"
            >
              <circle cx="12" cy="12" r="3"></circle>
              <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path>
            </svg>
          </button>
          <button class="ai-chat-close" @click="toggleChat">
            <svg 
              xmlns="http://www.w3.org/2000/svg" 
              width="18" 
              height="18" 
              viewBox="0 0 24 24" 
              fill="none" 
              stroke="currentColor" 
              stroke-width="2" 
              stroke-linecap="round" 
              stroke-linejoin="round"
            >
              <line x1="18" y1="6" x2="6" y2="18"></line>
              <line x1="6" y1="6" x2="18" y2="18"></line>
            </svg>
          </button>
        </div>
      </div>
      
      <div class="ai-chat-messages">
        <div 
          v-for="(message, index) in messages" 
          :key="index" 
          :class="['message', message.sender === 'ai' ? 'ai-message' : 'user-message', message.error ? 'error-message' : '']"
        >
          <template v-if="message.sender === 'ai'">
            <div class="ai-avatar">
              <svg 
                xmlns="http://www.w3.org/2000/svg" 
                width="18" 
                height="18" 
                viewBox="0 0 24 24" 
                fill="none" 
                stroke="currentColor" 
                stroke-width="2" 
                stroke-linecap="round" 
                stroke-linejoin="round"
              >
                <path d="M12 2a8 8 0 0 1 8 8v12l-4-4H4a2 2 0 0 1-2-2V10a8 8 0 0 1 8-8h0z"></path>
                <path d="M14 9.5a6 6 0 0 0-6 0"></path>
                <path d="M12 13a1 1 0 1 0 0-2 1 1 0 0 0 0 2Z"></path>
              </svg>
            </div>
            <div class="message-content">
              <p>{{ message.content }}</p>
              <div v-if="message.provider && message.model" class="message-meta">
                via {{ message.provider }} ({{ message.model }})
              </div>
            </div>
          </template>
          
          <template v-else>
            <div class="message-content">
              <p>{{ message.content }}</p>
            </div>
            <div class="user-avatar">
              <svg 
                xmlns="http://www.w3.org/2000/svg" 
                width="18" 
                height="18" 
                viewBox="0 0 24 24" 
                fill="none" 
                stroke="currentColor" 
                stroke-width="2" 
                stroke-linecap="round" 
                stroke-linejoin="round"
              >
                <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path>
                <circle cx="12" cy="7" r="4"></circle>
              </svg>
            </div>
          </template>
        </div>
        
        <!-- Loading indicator -->
        <div v-if="isLoading" class="message ai-message loading-message">
          <div class="ai-avatar">
            <svg 
              xmlns="http://www.w3.org/2000/svg" 
              width="18" 
              height="18" 
              viewBox="0 0 24 24" 
              fill="none" 
              stroke="currentColor" 
              stroke-width="2" 
              stroke-linecap="round" 
              stroke-linejoin="round"
            >
              <path d="M12 2a8 8 0 0 1 8 8v12l-4-4H4a2 2 0 0 1-2-2V10a8 8 0 0 1 8-8h0z"></path>
              <path d="M14 9.5a6 6 0 0 0-6 0"></path>
              <path d="M12 13a1 1 0 1 0 0-2 1 1 0 0 0 0 2Z"></path>
            </svg>
          </div>
          <div class="message-content">
            <p class="loading-dots">Thinking<span>.</span><span>.</span><span>.</span></p>
          </div>
        </div>
      </div>
      
      <div class="ai-chat-footer">
        <div v-if="providers" class="ai-chat-provider-selector">
          <select v-model="selectedProvider" class="provider-select">
            <option value="auto">Auto-select provider</option>
            <option v-if="providers.ollama?.available" value="ollama">Ollama</option>
            <option v-if="providers.openai?.available" value="openai">OpenAI</option>
          </select>
          
          <select v-if="selectedProvider !== 'auto'" v-model="selectedModel" class="model-select">
            <option v-if="selectedProvider === 'ollama'" 
                    v-for="model in providers.ollama?.models" 
                    :key="model" 
                    :value="model">{{ model }}</option>
            <option v-if="selectedProvider === 'openai'" 
                    v-for="model in providers.openai?.models" 
                    :key="model" 
                    :value="model">{{ model }}</option>
          </select>
        </div>
        
        <div class="ai-chat-input">
          <textarea 
            placeholder="Ask me anything about your project..."
            rows="1"
            ref="chatInput"
            v-model="userInput"
            @keydown.enter.prevent="sendMessage"
            @input="autoResizeTextarea"
            :disabled="isLoading"
          ></textarea>
          <button class="send-button" @click="sendMessage" :disabled="!userInput.trim() || isLoading">
            <template v-if="!isLoading">
              <svg 
                xmlns="http://www.w3.org/2000/svg" 
                width="20" 
                height="20" 
                viewBox="0 0 24 24" 
                fill="none" 
                stroke="currentColor" 
                stroke-width="2" 
                stroke-linecap="round" 
                stroke-linejoin="round"
              >
                <line x1="22" y1="2" x2="11" y2="13"></line>
                <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
              </svg>
            </template>
            <template v-else>
              <svg 
                xmlns="http://www.w3.org/2000/svg" 
                width="20" 
                height="20" 
                viewBox="0 0 24 24" 
                fill="none" 
                stroke="currentColor" 
                stroke-width="2" 
                stroke-linecap="round" 
                stroke-linejoin="round"
                class="loading-spinner"
              >
                <circle cx="12" cy="12" r="10"></circle>
                <path d="M12 6v6l4 2"></path>
              </svg>
            </template>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'AIChat',
  props: {
    // When set to true, chat button is hidden (controlled by sidebar)
    isSidebarIntegrated: {
      type: Boolean,
      default: true
    },
    // External control of expanded state
    forceExpanded: {
      type: Boolean,
      default: false
    }
  },
  data() {
    return {
      isExpanded: false,
      userInput: '',
      messages: [
        {
          sender: 'ai',
          content: 'Hello! I\'m your project assistant. Ask me about tasks, suggest project improvements, or get help with planning.'
        }
      ],
      isLoading: false,
      providers: null,
      selectedProvider: 'auto',
      selectedModel: null,
      error: null
    }
  },
  created() {
    console.log('AIChat component created');
  },
  mounted() {
    console.log('AIChat component mounted');
    
    // Set initial expanded state if required by prop
    if (this.forceExpanded) {
      this.isExpanded = true;
    }
    
    // Fetch available LLM providers and models
    this.fetchProviders();
  },
  watch: {
    // Watch for changes in the forceExpanded prop and update isExpanded accordingly
    forceExpanded(newValue) {
      console.log('forceExpanded changed to:', newValue);
      if (this.isExpanded !== newValue) {
        this.isExpanded = newValue;
      }
    }
  },
  methods: {
    toggleChat() {
      console.log('AIChat toggleChat called, current state:', this.isExpanded);
      this.isExpanded = !this.isExpanded;
      console.log('New expanded state:', this.isExpanded);
      
      // Emit event to notify parent component
      this.$emit('update:expanded', this.isExpanded);
      
      // Add a visual debug element to the DOM when expanded
      if (this.isExpanded) {
        document.body.classList.add('ai-chat-expanded');
        console.log('AI chat expanded, panel should be visible');
        this.$nextTick(() => {
          if (this.$refs.chatInput) {
            this.$refs.chatInput.focus();
          } else {
            console.error('Chat input reference not found');
          }
        });
      } else {
        document.body.classList.remove('ai-chat-expanded');
        console.log('AI chat collapsed');
      }
    },
    
    sendMessage() {
      if (!this.userInput.trim() || this.isLoading) return;
      
      const prompt = this.userInput.trim();
      
      // Add user message
      this.messages.push({
        sender: 'user',
        content: prompt
      });
      
      // Clear input and reset height
      this.userInput = '';
      this.$refs.chatInput.style.height = 'auto';
      
      // Scroll to bottom
      this.scrollToBottom();
      
      // Set loading state
      this.isLoading = true;
      
      // Send request to the API endpoint
      fetch('/api/v1/ai_chat/message', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
        },
        body: JSON.stringify({
          prompt: prompt,
          provider: this.selectedProvider,
          model: this.selectedModel
        })
      })
      .then(response => {
        if (!response.ok) {
          throw new Error(`Server responded with ${response.status}: ${response.statusText}`);
        }
        return response.json();
      })
      .then(data => {
        // Add AI response to messages
        this.messages.push({
          sender: 'ai',
          content: data.response,
          provider: data.provider,
          model: data.model
        });
        
        // Scroll to bottom after receiving response
        this.$nextTick(() => {
          this.scrollToBottom();
        });
      })
      .catch(error => {
        console.error('Error sending message to AI:', error);
        
        // Add error message
        this.messages.push({
          sender: 'ai',
          content: 'Sorry, there was an error processing your request. Please try again later.',
          error: true
        });
        
        this.error = error.message;
      })
      .finally(() => {
        this.isLoading = false;
        this.scrollToBottom();
      });
    },
    
    fetchProviders() {
      fetch('/api/v1/ai_chat/providers')
        .then(response => response.json())
        .then(data => {
          this.providers = data.providers;
          
          // Set default model if available
          if (this.providers?.ollama?.available) {
            this.selectedProvider = 'ollama';
            this.selectedModel = this.providers.ollama.default_model;
          } else if (this.providers?.openai?.available) {
            this.selectedProvider = 'openai';
            this.selectedModel = this.providers.openai.default_model;
          } else {
            // No providers available
            this.selectedProvider = 'auto';
            this.selectedModel = null;
          }
        })
        .catch(error => {
          console.error('Error fetching LLM providers:', error);
          this.error = 'Failed to load AI providers. Using automatic selection.';
          this.selectedProvider = 'auto';
        });
    },
    
    scrollToBottom() {
      const messagesContainer = this.$el.querySelector('.ai-chat-messages');
      if (messagesContainer) {
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
      }
    },
    
    autoResizeTextarea() {
      // Reset height to auto to get the correct scrollHeight
      this.$refs.chatInput.style.height = 'auto';
      
      // Set new height based on scrollHeight (with max height limit)
      const newHeight = Math.min(this.$refs.chatInput.scrollHeight, 100);
      this.$refs.chatInput.style.height = `${newHeight}px`;
    }
  }
}
</script>

<style>
/* AI Chat Container */
.ai-chat-container {
  position: fixed;
  bottom: 20px;
  right: 20px; /* Default to right for most pages */
  z-index: 1000;
  font-family: Avenir, Helvetica, Arial, sans-serif;
  transition: all 0.3s ease;
}

/* Standalone mode (floating button visible) */
.ai-chat-container.standalone-mode {
  left: auto;
  right: 20px;
}

/* Collapsed State */
.ai-chat-container.collapsed {
  width: auto;
  height: auto;
}

/* Expanded State */
.ai-chat-container.expanded {
  width: 380px;
  height: 500px;
  max-width: 90vw;  /* Responsive width */
  max-height: 80vh; /* Responsive height */
  display: flex !important; /* Force display */
  flex-direction: column;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.7);
  background-color: white;
  z-index: 9999999 !important; /* Ensure it's on top of EVERYTHING */
  opacity: 1 !important; /* Force visibility */
  border: 5px solid #FF0000;
  /* Debug styling */
  outline: 4px dashed red;
  outline-offset: 5px;
  /* Force the panel to appear in a fixed position above everything */
  position: fixed !important;
  /* Center it on screen for maximum visibility */
  top: 50% !important;
  left: 50% !important;
  transform: translate(-50%, -50%) !important;
}

/* Position adjustments removed - we're now centering the chat panel on screen */

/* Toggle Button */
.ai-chat-toggle {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 12px 16px;
  background-color: #6699CC;
  color: white;
  border-radius: 12px;
  cursor: pointer;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
  transition: all 0.2s ease;
}

.ai-chat-toggle:hover {
  background-color: #5588BB;
  transform: translateY(-2px);
}

.expanded .ai-chat-toggle {
  border-radius: 0;
  width: 100%;
  justify-content: flex-end;
  padding: 0;
  box-shadow: none;
  background-color: transparent;
}

.close-icon {
  font-size: 24px;
  line-height: 1;
  color: #666;
  padding: 8px 16px;
}

.ai-icon {
  display: flex;
  align-items: center;
}

.ai-label {
  margin-left: 8px;
  font-weight: 500;
}

/* Chat Panel Content */
.ai-chat-content {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.ai-chat-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px;
  border-bottom: 1px solid #eee;
}

.ai-chat-title {
  display: flex;
  align-items: center;
  font-weight: 600;
  color: #333;
}

.ai-chat-title .ai-icon {
  margin-right: 8px;
  color: #6699CC;
}

.ai-chat-controls {
  display: flex;
  gap: 8px;
}

.ai-chat-settings, .ai-chat-close {
  background: none;
  border: none;
  color: #666;
  cursor: pointer;
  padding: 4px;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.ai-chat-settings:hover, .ai-chat-close:hover {
  background-color: #f5f5f5;
}

.ai-chat-close {
  color: #888;
}

/* Chat Messages */
.ai-chat-messages {
  flex: 1;
  overflow-y: auto;
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 16px;
  background-color: #f9f9f9;
}

.message {
  display: flex;
  max-width: 80%;
}

.user-message {
  margin-left: auto;
  flex-direction: row-reverse;
}

.ai-avatar, .user-avatar {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.ai-avatar {
  background-color: #6699CC;
  margin-right: 8px;
}

.user-avatar {
  background-color: #4CAF50;
  margin-left: 8px;
}

.message-content {
  padding: 10px 14px;
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.ai-message .message-content {
  background-color: white;
}

.user-message .message-content {
  background-color: #E7F5E8;
}

.message-content p {
  margin: 0;
  line-height: 1.4;
}

/* Chat Input */
.ai-chat-input {
  display: flex;
  padding: 12px;
  border-top: 1px solid #eee;
  background-color: white;
}

/* Add a global indicator when chat is expanded */
:global(.ai-chat-expanded) .ai-chat-container {
  border: 3px solid #6699CC !important;
}

.ai-chat-input textarea {
  flex: 1;
  border: 1px solid #ddd;
  border-radius: 20px;
  padding: 10px 14px;
  font-family: inherit;
  resize: none;
  outline: none;
  max-height: 100px;
  overflow-y: auto;
  margin-right: 8px;
}

.ai-chat-input textarea:focus {
  border-color: #6699CC;
}

.send-button {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background-color: #6699CC;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  border: none;
  flex-shrink: 0;
  transition: all 0.2s ease;
}

.send-button:hover {
  background-color: #5588BB;
  transform: scale(1.05);
}

.send-button:disabled {
  background-color: #ccc;
  cursor: not-allowed;
  transform: none;
}

/* Loading animation */
.loading-dots span {
  animation: loading 1.4s infinite;
  display: inline-block;
  opacity: 0;
}

.loading-dots span:nth-child(1) {
  animation-delay: 0.2s;
}

.loading-dots span:nth-child(2) {
  animation-delay: 0.4s;
}

.loading-dots span:nth-child(3) {
  animation-delay: 0.6s;
}

@keyframes loading {
  0% {
    opacity: 0;
  }
  50% {
    opacity: 1;
  }
  100% {
    opacity: 0;
  }
}

.loading-spinner {
  animation: spin 2s linear infinite;
}

@keyframes spin {
  0% {
    transform: rotate(0deg);
  }
  100% {
    transform: rotate(360deg);
  }
}

/* Error message styling */
.error-message .message-content {
  background-color: #FFEBEE !important;
  color: #D32F2F;
}

/* Message metadata */
.message-meta {
  font-size: 0.7rem;
  color: #888;
  margin-top: 4px;
  font-style: italic;
}

/* Provider selector */
.ai-chat-footer {
  display: flex;
  flex-direction: column;
  border-top: 1px solid #eee;
  background-color: white;
}

.ai-chat-provider-selector {
  display: flex;
  padding: 8px;
  border-bottom: 1px solid #f5f5f5;
  background-color: #fafafa;
  gap: 8px;
}

.provider-select, .model-select {
  font-size: 0.8rem;
  padding: 4px;
  border: 1px solid #ddd;
  border-radius: 4px;
  background-color: white;
}

.provider-select {
  flex: 1;
}

.model-select {
  flex: 2;
}
</style>