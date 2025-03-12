<template>
  <div class="app-container">
    <!-- App Header - Smaller and with app switcher -->
    <header class="app-header">
      <div class="app-left-controls">
        <div class="debug-button" @click="toggleDebugPanel">
          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M8 2l1 2.5M12 2l-1 2.5M16 2l-1 2.5M2.75 9.5h18.5M2.75 14.5h18.5M12 12a4 4 0 0 0-4 4M12 12a4 4 0 0 1 4 4M18 18.5a7 7 0 1 1-12 0"/>
            <circle cx="8" cy="9.5" r="1"/>
            <circle cx="16" cy="9.5" r="1"/>
          </svg>
        </div>
        <div class="build-info">
          <span class="build-number">Build #20250312.05</span>
        </div>
        <div class="app-switcher">
          <!-- App Switcher Icon - Google style dots -->
          <button class="app-switcher-button" @click="toggleAppSwitcher">
            <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
              <path d="M6 10c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm12 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm-6 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z"/>
            </svg>
          </button>
          
          <!-- App Switcher Menu (hidden by default) -->
          <div v-if="showAppSwitcher" class="app-switcher-menu">
            <div class="app-option active">
              <span class="app-icon">📊</span>
              <span class="app-name">Project Management</span>
            </div>
            <div class="app-option disabled">
              <span class="app-icon">📈</span>
              <span class="app-name">Analytics (Coming Soon)</span>
            </div>
            <div class="app-option disabled">
              <span class="app-icon">📅</span>
              <span class="app-name">Calendar (Coming Soon)</span>
            </div>
          </div>
        </div>
        <div class="app-title">
          <h1>Harmoniq Project Management</h1>
          <!-- Project subheader will be dynamically shown when on a project page -->
          <div v-if="projectId" class="project-subtitle">
            <h2>Project: {{ projectName }}</h2>
          </div>
        </div>
      </div>
      
      <div class="app-right-controls">
        <form action="/logout" method="post" class="logout-form">
          <input type="hidden" name="_method" value="delete">
          <input type="hidden" name="authenticity_token" :value="csrfToken">
          <button type="submit" class="logout-button">Logout</button>
        </form>
      </div>
    </header>
    
    <!-- Main Layout: Sidebar + Content Area -->
    <div class="main-container">
      <!-- Navigation Sidebar -->
      <aside class="nav-sidebar" :class="{ 'collapsed': sidebarCollapsed }">
        <!-- Toggle Button -->
        <div class="sidebar-toggle" @click="toggleSidebar">
          <span v-if="sidebarCollapsed">→</span>
          <span v-else>←</span>
        </div>
        
        <!-- Main Navigation Items -->
        <div class="nav-items-container">
          <a href="/dashboard" class="nav-item" :title="sidebarCollapsed ? 'Home Dashboard' : ''">
            <span class="nav-icon">🏠</span>
            <span class="nav-label" v-if="!sidebarCollapsed">Home</span>
          </a>
          <div class="nav-item" :class="{ active: currentView === 'gantt' }" @click="switchView('gantt')" :title="sidebarCollapsed ? 'Gantt' : ''">
            <span class="nav-icon">📊</span>
            <span class="nav-label" v-if="!sidebarCollapsed">Gantt</span>
          </div>
          <div class="nav-item" :class="{ active: currentView === 'board' }" @click="switchView('board')" :title="sidebarCollapsed ? 'Board' : ''">
            <span class="nav-icon">📋</span>
            <span class="nav-label" v-if="!sidebarCollapsed">Board</span>
          </div>
          <div class="nav-item" :class="{ active: currentView === 'resources' }" @click="switchView('resources')" :title="sidebarCollapsed ? 'Resources' : ''">
            <span class="nav-icon">👥</span>
            <span class="nav-label" v-if="!sidebarCollapsed">Resources</span>
          </div>
          <div class="nav-item disabled" :title="sidebarCollapsed ? 'Reports (Coming Soon)' : ''">
            <span class="nav-icon">📈</span>
            <span class="nav-label" v-if="!sidebarCollapsed">Reports</span>
          </div>
          <div class="nav-item disabled" :title="sidebarCollapsed ? 'Settings (Coming Soon)' : ''">
            <span class="nav-icon">⚙️</span>
            <span class="nav-label" v-if="!sidebarCollapsed">Settings</span>
          </div>
        </div>
        
        <!-- AI Assistant Link (Fixed at Bottom) -->
        <div class="sidebar-footer">
          <div 
            class="nav-item ai-item" 
            @click="toggleAIChat"
            :title="sidebarCollapsed ? 'AI Assistant' : ''"
            :class="{ 'ai-active': aiChatExpanded }"
          >
            <span class="nav-icon">💬</span>
            <span class="nav-label" v-if="!sidebarCollapsed">AI Assistant</span>
          </div>
        </div>
      </aside>
      
      <!-- Main Content Area -->
      <main class="content-area">
        <!-- Workspace Toolbar (customized per view) -->
        <div class="workspace-toolbar">
          <div class="toolbar-left">
            <button v-if="currentView !== 'resources'" @click="addTask">Add Task</button>
            <button 
              v-if="currentView === 'gantt' && selectedDependencyIndex >= 0" 
              @click="deleteDependency"
              class="btn-delete-dependency"
            >
              Delete Dependency
            </button>
          </div>
          
          <div class="toolbar-right">
            <button v-if="currentView === 'gantt'" @click="$refs.ganttChart.zoomIn()">Zoom In</button>
            <button v-if="currentView === 'gantt'" @click="$refs.ganttChart.zoomOut()">Zoom Out</button>
          </div>
        </div>
        
        <!-- Workspace Content -->
        <div class="workspace-content">
          <!-- Gantt Chart View -->
          <gantt-chart 
            ref="ganttChart"
            v-if="currentView === 'gantt'" 
            :tasks="tasks"
            :resources="resources"
            :dependencies="dependencies"
            :selected-dependency-index="selectedDependencyIndex"
            @update:task="updateTask"
            @update:dependency="updateDependency"
            @select:dependency="selectDependency"
            @delete:task="confirmDeleteTask"
          />
          
          <!-- Board View -->
          <task-board 
            v-else-if="currentView === 'board'" 
            :tasks="tasks"
            :resources="resources"
            @update:task="updateTask"
            @delete="confirmDeleteTask"
          />
          
          <!-- Resources View -->
          <resource-manager
            v-else-if="currentView === 'resources'"
            :resources="resources"
            @add="addResource"
            @update="updateResource"
            @delete="deleteResource"
          />
        </div>
      </main>
    </div>
    
    <!-- Debug Panel (Hidden by Default) -->
    <div 
      class="debug-panel" 
      v-if="showDebugPanel"
      :class="{ 'dragging': isDraggingDebugPanel }"
      :style="{ top: debugPanelPosition.top + 'px', left: debugPanelPosition.left + 'px' }"
    >
      <div 
        class="debug-panel-header"
        @mousedown="startDragDebugPanel"
      >
        <h3>Debug Panel</h3>
        <div class="debug-panel-controls">
          <span class="drag-indicator">⬌</span>
          <button @click="showDebugPanel = false">×</button>
        </div>
      </div>
      <div class="debug-panel-content">
        <div class="debug-section">
          <h4>Application State</h4>
          <div class="debug-info">
            <p><strong>Current View:</strong> {{ currentView }}</p>
            <p><strong>Resources Count:</strong> {{ resources.length }}</p>
            <button 
              type="button" 
              class="btn-danger" 
              style="margin-top: 10px"
              @click="forceUpdate"
            >
              Force UI Refresh
            </button>
          </div>
        </div>
        
        <!-- Task Bar Styling Controls -->
        <div class="debug-section" v-if="currentView === 'gantt'">
          <h4>Gantt Styling</h4>
          <div class="debug-info">
            <div class="debug-control">
              <label for="detailBarHeight"><strong>Detail Bar Height:</strong></label>
              <div class="debug-input-group">
                <input 
                  type="range" 
                  id="detailBarHeight" 
                  v-model="detailTaskBarHeight" 
                  min="10" 
                  max="50" 
                  step="1"
                  @input="updateDetailBarHeight"
                />
                <span class="debug-value">{{ detailTaskBarHeight }}px</span>
              </div>
            </div>
            
            <button 
              type="button" 
              class="btn-debug-action"
              @click="resetBarHeights"
            >
              Reset Heights
            </button>
          </div>
        </div>
      </div>
    </div>
    
    <!-- AI Chat Panel -->
    <div 
      class="ai-chat-panel" 
      v-if="aiChatExpanded"
      :class="{ 
        'dragging': isDraggingAIChatPanel,
        'docked': aiChatDockPosition !== 'free',
        'dock-north': aiChatDockPosition === 'north',
        'dock-south': aiChatDockPosition === 'south',
        'dock-east': aiChatDockPosition === 'east',
        'dock-west': aiChatDockPosition === 'west'
      }"
      :style="aiChatDockPosition === 'free' ? { 
        top: aiChatPanelPosition.top + 'px', 
        left: aiChatPanelPosition.left + 'px',
        width: aiChatPanelSize.width + 'px',
        height: aiChatPanelSize.height + 'px'
      } : {}"
    >
      <!-- Resize handles based on dock position -->
      <!-- Free mode (all handles) -->
      <template v-if="aiChatDockPosition === 'free'">
        <div class="resize-handle resize-e" @mousedown.prevent="startResize($event, 'right')"></div>
        <div class="resize-handle resize-s" @mousedown.prevent="startResize($event, 'bottom')"></div>
        <div class="resize-handle resize-se" @mousedown.prevent="startResize($event, 'corner')"></div>
      </template>
      
      <!-- North dock (can resize bottom) -->
      <template v-if="aiChatDockPosition === 'north'">
        <div class="resize-handle resize-s" @mousedown.prevent="startResize($event, 'bottom')"></div>
      </template>
      
      <!-- South dock (can resize top) -->
      <template v-if="aiChatDockPosition === 'south'">
        <div class="resize-handle resize-n" @mousedown.prevent="startResize($event, 'top')"></div>
      </template>
      
      <!-- East dock (can resize left) -->
      <template v-if="aiChatDockPosition === 'east'">
        <div class="resize-handle resize-w" @mousedown.prevent="startResize($event, 'left')"></div>
      </template>
      
      <!-- West dock (can resize right) -->
      <template v-if="aiChatDockPosition === 'west'">
        <div class="resize-handle resize-e" @mousedown.prevent="startResize($event, 'right')"></div>
      </template>
      <div 
        class="ai-chat-panel-header"
        @mousedown="startDragAIChatPanel"
      >
        <h3>AI Assistant</h3>
        <div class="ai-chat-panel-controls">
          <!-- Dock Position Controls -->
          <div class="dock-controls">
            <button 
              class="dock-button" 
              :class="{ 'active': aiChatDockPosition === 'north' }"
              title="Dock to top"
              @click.stop="dockAIChat('north')"
            >
              ↑
            </button>
            <button 
              class="dock-button" 
              :class="{ 'active': aiChatDockPosition === 'west' }"
              title="Dock to left"
              @click.stop="dockAIChat('west')"
            >
              ←
            </button>
            <button 
              class="dock-button" 
              :class="{ 'active': aiChatDockPosition === 'free' }"
              title="Undock (free floating)"
              @click.stop="dockAIChat('free')"
            >
              ⊙
            </button>
            <button 
              class="dock-button" 
              :class="{ 'active': aiChatDockPosition === 'east' }"
              title="Dock to right"
              @click.stop="dockAIChat('east')"
            >
              →
            </button>
            <button 
              class="dock-button" 
              :class="{ 'active': aiChatDockPosition === 'south' }"
              title="Dock to bottom"
              @click.stop="dockAIChat('south')"
            >
              ↓
            </button>
          </div>
          
          <span class="drag-indicator" v-if="aiChatDockPosition === 'free'">⬌</span>
          <button @click="toggleAIChat">×</button>
        </div>
      </div>
      <div class="ai-chat-panel-content">
        <div class="ai-chat-messages">
          <div class="ai-message">
            <div class="ai-avatar">H</div>
            <div class="message-content">
              <p>Hello! I'm your Harmoniq assistant. Ask me about tasks, suggest project improvements, or get help with orchestrating your workstreams.</p>
            </div>
          </div>
          
          <div v-for="(message, index) in aiChatMessages" :key="index" 
               :class="['message', message.sender === 'ai' ? 'ai-message' : 'user-message', message.loading ? 'loading-message' : '', message.error ? 'error-message' : '']">
            <div v-if="message.sender === 'ai'" class="ai-avatar">H</div>
            <div class="message-content">
              <p v-if="!message.loading">{{ message.content }}</p>
              <p v-else class="loading-dots">Thinking<span>.</span><span>.</span><span>.</span></p>
              <div v-if="message.provider && message.model" class="message-meta">
                via {{ message.provider }} ({{ message.model }})
              </div>
            </div>
            <div v-if="message.sender === 'user'" class="user-avatar">You</div>
          </div>
        </div>
        
        <div class="ai-chat-input">
          <textarea 
            placeholder="Ask me anything about your project..."
            rows="2"
            v-model="aiChatInput"
            @keydown.enter.prevent="sendAIChatMessage"
          ></textarea>
          <button 
            class="send-button" 
            @click="sendAIChatMessage" 
            :disabled="!aiChatInput.trim()"
          >
            Send
          </button>
        </div>
      </div>
    </div>
    
    <!-- Delete Confirmation Modal -->
    <div v-if="showDeleteConfirmModal" class="modal-backdrop">
      <div class="modal-container">
        <div class="modal-header">
          <h3>Delete Task</h3>
        </div>
        <div class="modal-body">
          <p>Are you sure you want to delete this task?</p>
        </div>
        <div class="modal-footer">
          <button class="btn-cancel" @click="cancelDeleteTask">Cancel</button>
          <button class="btn-danger" @click="deleteTask">Delete</button>
        </div>
      </div>
    </div>
    
  </div>
</template>

<script>
import GanttChart from './components/GanttChart.vue'
import TaskBoard from './components/TaskBoard.vue'
import ResourceManager from './components/ResourceManager.vue'

export default {
  name: 'App',
  components: {
    GanttChart,
    TaskBoard,
    ResourceManager
  },
  data() {
    return {
      // CSRF Token for form submissions
      csrfToken: document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
      
      // Project information
      projectId: null,
      projectName: '',
      
      // View Management
      currentView: 'gantt',
      showAppSwitcher: false,
      sidebarCollapsed: false,
      aiChatExpanded: false,
      
      // Debug Panel
      showDebugPanel: false,
      debugPanelPosition: {
        top: 20,
        left: 20
      },
      isDraggingDebugPanel: false,
      debugPanelDragStart: { x: 0, y: 0 },
      debugPanelDragInitialPosition: { top: 0, left: 0 },
      
      // AI Chat Panel
      aiChatPanelPosition: {
        top: 100,
        left: 100
      },
      aiChatPanelSize: {
        width: 400,
        height: 500
      },
      isDraggingAIChatPanel: false,
      isResizing: false,
      resizeType: null,
      resizeStartPos: { x: 0, y: 0 },
      resizeStartSize: { width: 0, height: 0 },
      aiChatPanelDragStart: { x: 0, y: 0 },
      aiChatPanelDragInitialPosition: { top: 0, left: 0 },
      aiChatDockPosition: 'free', // Possible values: 'free', 'north', 'south', 'east', 'west'
      
      // Task Bar Styling
      detailTaskBarHeight: 25, // Default height from TaskBar.vue
      
      // AI Chat
      aiChatInput: '',
      aiChatMessages: [],
      
      // Task Management
      showDeleteConfirmModal: false,
      taskToDelete: null,
      selectedDependencyIndex: -1,
      
      // Application Data
      tasks: [
        {
          id: 1,
          name: 'Project Planning',
          startDate: new Date(2025, 2, 1),
          endDate: new Date(2025, 2, 15),
          progress: 60,
          expanded: true,
          resources: [1],
          status: 'inProgress',
          children: [
            {
              id: 2,
              name: 'Requirements Analysis',
              startDate: new Date(2025, 2, 1),
              endDate: new Date(2025, 2, 5),
              progress: 100,
              resources: [1, 2],
              status: 'done',
              children: []
            },
            {
              id: 3,
              name: 'Design Planning',
              startDate: new Date(2025, 2, 6),
              endDate: new Date(2025, 2, 10),
              progress: 80,
              resources: [2, 3],
              status: 'review',
              children: []
            },
            {
              id: 4,
              name: 'Resource Allocation',
              startDate: new Date(2025, 2, 11),
              endDate: new Date(2025, 2, 15),
              progress: 30,
              resources: [1],
              status: 'inProgress',
              children: []
            }
          ]
        },
        {
          id: 5,
          name: 'Implementation',
          startDate: new Date(2025, 2, 16),
          endDate: new Date(2025, 3, 15),
          progress: 10,
          expanded: true,
          resources: [4],
          status: 'todo',
          children: [
            {
              id: 6,
              name: 'Frontend Development',
              startDate: new Date(2025, 2, 16),
              endDate: new Date(2025, 2, 31),
              progress: 20,
              resources: [2, 4],
              status: 'todo',
              children: []
            },
            {
              id: 7,
              name: 'Backend Development',
              startDate: new Date(2025, 3, 1),
              endDate: new Date(2025, 3, 15),
              progress: 0,
              resources: [3, 5],
              status: 'backlog',
              children: []
            }
          ]
        }
      ],
      dependencies: [
        { from: 2, to: 3, fromType: 'end', toType: 'start' },
        { from: 6, to: 7, fromType: 'end', toType: 'start' },
        { from: 3, to: 4, fromType: 'end', toType: 'start' }
      ],
      resources: [
        { 
          id: 1, 
          name: 'John Smith',
          email: 'john.smith@example.com',
          phone: '(555) 123-4567',
          role: 'Project Manager',
          billRate: 85,
          availability: 90,
          imageUrl: 'https://randomuser.me/api/portraits/men/42.jpg'
        },
        { 
          id: 2, 
          name: 'Jane Doe',
          email: 'jane.doe@example.com',
          phone: '(555) 234-5678',
          role: 'UX Designer',
          billRate: 75,
          availability: 100,
          imageUrl: 'https://randomuser.me/api/portraits/women/65.jpg'
        },
        { 
          id: 3, 
          name: 'Robert Johnson',
          email: 'robert.johnson@example.com',
          phone: '(555) 345-6789',
          role: 'Lead Developer',
          billRate: 95,
          availability: 80,
          imageUrl: 'https://randomuser.me/api/portraits/men/22.jpg'
        },
        { 
          id: 4, 
          name: 'Sarah Williams',
          email: 'sarah.williams@example.com',
          phone: '(555) 456-7890',
          role: 'QA Engineer',
          billRate: 70,
          availability: 100,
          imageUrl: 'https://randomuser.me/api/portraits/women/33.jpg'
        },
        { 
          id: 5, 
          name: 'Michael Brown',
          email: 'michael.brown@example.com',
          phone: '(555) 567-8901',
          role: 'Full Stack Developer',
          billRate: 90,
          availability: 60,
          imageUrl: 'https://randomuser.me/api/portraits/men/91.jpg'
        }
      ]
    }
  },
  mounted() {
    // Get project info from DOM
    const appElement = document.getElementById('main-app');
    if (appElement && appElement.dataset.projectId) {
      this.projectId = appElement.dataset.projectId;
      console.log('Project ID loaded from DOM:', this.projectId);
      
      // Get project name from data attribute first (most reliable)
      if (appElement.dataset.projectName) {
        this.projectName = appElement.dataset.projectName;
      }
      // Fallback to initialData if available
      else if (window.initialData && window.initialData.projects && window.initialData.projects.length > 0) {
        this.projectName = window.initialData.projects[0].name;
      }
      
      console.log('Project name loaded:', this.projectName);
    }
    
    // Get initial data from window if available
    if (window.initialData) {
      console.log('Initial data loaded from window:', window.initialData);
      // Process any data from initialData if needed
    }
    
    // Fetch tasks and dependencies from the server
    this.fetchTasksFromServer();
  },
  beforeDestroy() {
    // Clean up custom style elements to prevent them from persisting
    const barStyleEl = document.getElementById('gantt-bar-styles');
    if (barStyleEl) {
      barStyleEl.parentNode.removeChild(barStyleEl);
    }
    
    // Clear global data to prevent it from persisting
    window.initialData = null;
  },
  methods: {
    // Navigation
    triggerDashboardButton() {
      // Attempt to find the Back to Dashboard button and click it
      console.log('Looking for Back to Dashboard button');
      
      // Look for the button by class first, which is most specific
      let dashboardButton = document.querySelector('.btn-back');
      
      // If not found by class, look by href
      if (!dashboardButton) {
        dashboardButton = document.querySelector('a[href="/dashboard"]');
      }
      
      // If still not found, try looking by text content
      if (!dashboardButton) {
        // Loop through all links to find one with "Back to Dashboard" text
        const allLinks = document.querySelectorAll('a');
        for (let i = 0; i < allLinks.length; i++) {
          if (allLinks[i].textContent.includes('Back to Dashboard')) {
            dashboardButton = allLinks[i];
            break;
          }
        }
      }
      
      if (dashboardButton) {
        console.log('Found Back to Dashboard button, clicking it');
        // Directly trigger the working button's click
        dashboardButton.click();
      } else {
        // Fallback if we can't find the button
        console.log('Back to Dashboard button not found, using direct navigation');
        // For direct navigation, use a hard href with force refresh
        window.location.href = '/dashboard';
      }
    },
    
    // Keep this as a backup method
    goToDashboard() {
      // Use window.location.replace to ensure proper URL change with full navigation
      console.log('Navigating to dashboard with full page reload');
      window.location.replace('/dashboard');
      
      // In case replace doesn't work well in all browsers, also try href with prevent caching
      // This adds a random query parameter to prevent caching
      setTimeout(() => {
        window.location.href = '/dashboard?nocache=' + new Date().getTime();
      }, 100);
    },
    
    switchView(view) {
      if (view === 'gantt' || view === 'board' || view === 'resources') {
        this.currentView = view;
      }
    },
    
    toggleAppSwitcher() {
      this.showAppSwitcher = !this.showAppSwitcher;
    },
    
    toggleSidebar() {
      this.sidebarCollapsed = !this.sidebarCollapsed;
    },
    
    // Task Management
    addTask() {
      const newId = Math.max(...this.tasks.map(t => t.id)) + 1;
      const newTask = {
        id: newId,
        name: 'New Task',
        startDate: new Date(),
        endDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days from now
        progress: 0,
        expanded: true,
        resources: [],
        children: []
      };
      this.tasks.push(newTask);
    },
    
    updateTask(updatedTask) {
      console.log("App - Update task:", updatedTask.id, "Expanded:", updatedTask.expanded);
      const updateTaskInList = (tasks) => {
        for (let i = 0; i < tasks.length; i++) {
          if (tasks[i].id === updatedTask.id) {
            // Check if only the expanded state is changing
            const isOnlyExpanding = 
              Object.keys(updatedTask).length === 2 && // Only id and expanded
              'expanded' in updatedTask && 
              tasks[i].expanded !== updatedTask.expanded;
              
            // Update the task with the changes
            tasks[i] = { ...tasks[i], ...updatedTask };
            
            // For expansion-only changes, we don't need to recalculate dates
            if (isOnlyExpanding) {
              console.log("Task expansion toggled:", tasks[i].expanded);
              return { updated: true, hasChanged: false, expandOnly: true };
            }
            
            // For other changes, signal that dates may need to be recalculated
            return { updated: true, hasChanged: true, expandOnly: false };
          }
          
          if (tasks[i].children && tasks[i].children.length > 0) {
            const result = updateTaskInList(tasks[i].children);
            if (result && result.updated) {
              // If a child was updated and it's not just an expansion change
              if (result.hasChanged && !result.expandOnly) {
                this.recalculateSummaryTaskDates(tasks[i]);
              }
              return { 
                updated: true, 
                hasChanged: false, 
                expandOnly: result.expandOnly 
              };
            }
          }
        }
        return { updated: false, hasChanged: false, expandOnly: false };
      };
      
      updateTaskInList(this.tasks);
    },
    
    // Method to recalculate summary task dates
    recalculateSummaryTaskDates(summaryTask) {
      if (!summaryTask.children || summaryTask.children.length === 0) return;
      
      // Convert dates to timestamps for comparison
      const childStartDates = summaryTask.children.map(child => new Date(child.startDate).getTime());
      const childEndDates = summaryTask.children.map(child => new Date(child.endDate).getTime());
      
      // Find the earliest start date and latest end date
      const minStartTime = Math.min(...childStartDates);
      const maxEndTime = Math.max(...childEndDates);
      
      // Update the summary task dates
      summaryTask.startDate = new Date(minStartTime);
      summaryTask.endDate = new Date(maxEndTime);
    },
    
    confirmDeleteTask(taskId) {
      const findTask = (tasks) => {
        for (const task of tasks) {
          if (task.id === taskId) {
            return task;
          }
          if (task.children && task.children.length > 0) {
            const foundTask = findTask(task.children);
            if (foundTask) return foundTask;
          }
        }
        return null;
      };
      
      this.taskToDelete = findTask(this.tasks);
      if (this.taskToDelete) {
        this.showDeleteConfirmModal = true;
      }
    },
    
    cancelDeleteTask() {
      this.showDeleteConfirmModal = false;
      this.taskToDelete = null;
    },
    
    deleteTask() {
      if (!this.taskToDelete) return;
      
      const deleteTaskFromList = (tasks, taskId) => {
        for (let i = 0; i < tasks.length; i++) {
          if (tasks[i].id === taskId) {
            tasks.splice(i, 1);
            return true;
          }
          if (tasks[i].children && tasks[i].children.length > 0) {
            if (deleteTaskFromList(tasks[i].children, taskId)) {
              return true;
            }
          }
        }
        return false;
      };
      
      deleteTaskFromList(this.tasks, this.taskToDelete.id);
      
      // Also remove any dependencies involving this task
      this.dependencies = this.dependencies.filter(
        dep => dep.from !== this.taskToDelete.id && dep.to !== this.taskToDelete.id
      );
      
      this.showDeleteConfirmModal = false;
      this.taskToDelete = null;
    },
    
    // Dependency Management
    updateDependency(updatedDependencies) {
      if (Array.isArray(updatedDependencies)) {
        // Create a clean copy to ensure reactivity
        this.dependencies = JSON.parse(JSON.stringify(updatedDependencies));
        console.log("Dependencies updated:", this.dependencies);
      } else if (updatedDependencies && updatedDependencies.index >= 0) {
        // Handle single dependency update
        const { dependency, index } = updatedDependencies;
        if (index >= 0 && index < this.dependencies.length) {
          // Make a clean copy of the dependencies array
          const newDeps = [...this.dependencies];
          newDeps[index] = { ...dependency };
          this.dependencies = newDeps;
        }
      }
    },
    
    selectDependency(index) {
      this.selectedDependencyIndex = (this.selectedDependencyIndex === index) ? -1 : index;
    },
    
    deleteDependency() {
      if (this.selectedDependencyIndex >= 0 && this.selectedDependencyIndex < this.dependencies.length) {
        this.dependencies.splice(this.selectedDependencyIndex, 1);
        this.selectedDependencyIndex = -1;
      }
    },
    
    // Zoom Controls
    zoomIn() {
      // Will be handled by the GanttChart component
    },
    
    zoomOut() {
      // Will be handled by the GanttChart component
    },
    
    // AI Chat Controls
    toggleAIChat() {
      console.log('Toggling AI Chat');
      this.aiChatExpanded = !this.aiChatExpanded;
    },
    
    sendAIChatMessage() {
      if (!this.aiChatInput.trim()) return;
      
      // Add user message
      this.aiChatMessages.push({
        sender: 'user',
        content: this.aiChatInput.trim()
      });
      
      const userMessage = this.aiChatInput.trim();
      
      // Clear input
      this.aiChatInput = '';
      
      // Scroll to bottom
      this.$nextTick(() => {
        const messagesContainer = document.querySelector('.ai-chat-messages');
        if (messagesContainer) {
          messagesContainer.scrollTop = messagesContainer.scrollHeight;
        }
      });
      
      // Set loading state
      const loadingId = Date.now();
      let loadingContent = 'Thinking...';
      
      // If the message indicates task creation, provide more specific feedback
      if (this.isTaskCreationRequest(userMessage)) {
        loadingContent = 'Creating your project plan... This may take a minute.';
      }
      
      const loadingMessage = {
        id: loadingId,
        sender: 'ai',
        content: loadingContent,
        loading: true
      };
      this.aiChatMessages.push(loadingMessage);
      
      // Send request to the API endpoint
      fetch('/api/v1/ai_chat/message', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
        },
        body: JSON.stringify({
          prompt: userMessage,
          provider: 'auto', // Use auto to let the backend choose
          model: null
        })
      })
      .then(response => {
        if (!response.ok) {
          throw new Error(`Server responded with ${response.status}: ${response.statusText}`);
        }
        return response.json();
      })
      .then(data => {
        // Remove loading message
        const index = this.aiChatMessages.findIndex(m => m.id === loadingId);
        if (index !== -1) {
          this.aiChatMessages.splice(index, 1);
        }
        
        // Add AI response to messages
        this.aiChatMessages.push({
          sender: 'ai',
          content: data.response,
          provider: data.provider,
          model: data.model,
          action: data.action
        });
        
        // Check if we need to refresh the tasks/gantt chart
        if (data.action === 'refresh_tasks') {
          console.log('Refreshing tasks after AI task creation');
          // Force refresh after a short delay to ensure backend has completed transaction
          setTimeout(() => {
            this.fetchTasksFromServer();
          }, 500); // 500ms delay
        }
        
        // If there's an error in the response, log it
        if (data.error) {
          console.error('AI chat error:', data.error);
        }
        
        // Scroll to bottom after receiving response
        this.$nextTick(() => {
          const messagesContainer = document.querySelector('.ai-chat-messages');
          if (messagesContainer) {
            messagesContainer.scrollTop = messagesContainer.scrollHeight;
          }
        });
      })
      .catch(error => {
        console.error('Error sending message to AI:', error);
        
        // Remove loading message
        const index = this.aiChatMessages.findIndex(m => m.id === loadingId);
        if (index !== -1) {
          this.aiChatMessages.splice(index, 1);
        }
        
        // Add error message
        this.aiChatMessages.push({
          sender: 'ai',
          content: 'Sorry, there was an error processing your request. Please try again later.',
          error: true
        });
      });
    },
    
    // Task data management
    fetchTasksFromServer() {
      console.log('Fetching tasks from server for project:', this.projectId);
      
      // Make API call to get tasks with project filter
      const url = this.projectId ? `/api/v1/tasks?project_id=${this.projectId}` : '/api/v1/tasks';
      
      fetch(url)
        .then(response => response.json())
        .then(data => {
          console.log('Received tasks from server:', data);
          console.log(`API returned ${data.length} tasks`);
          
          // Count tasks with parent_id to verify hierarchy
          const tasksWithParents = data.filter(task => task.parent_id).length;
          console.log(`Tasks with parent_id: ${tasksWithParents}`);
          
          // Log all unique parent_ids to verify they exist
          const uniqueParentIds = [...new Set(data.filter(task => task.parent_id).map(task => task.parent_id))];
          console.log(`Unique parent_ids: ${uniqueParentIds.join(', ')}`);
          
          // Clear existing tasks and replace with server data
          this.tasks = [];
          
          // Process tasks and rebuild hierarchy
          if (Array.isArray(data)) {
            // Group tasks by parent
            const taskMap = {};
            const rootTasks = [];
            
            // First pass: create task map
            data.forEach(task => {
              // Create a task object with our expected structure
              const taskObj = {
                id: task.id,
                name: task.name,
                description: task.description,
                startDate: new Date(task.start_date),
                endDate: new Date(task.due_date),
                progress: task.percent_complete || 0,
                expanded: true,
                resources: task.assignee_id ? [task.assignee_id] : [],
                status: task.status,
                children: []
              };
              
              taskMap[task.id] = taskObj;
              
              // If it doesn't have a parent, it's a root task
              if (!task.parent_id) {
                rootTasks.push(taskObj);
              }
            });
            
            // Second pass: build hierarchy
            data.forEach(task => {
              if (task.parent_id && taskMap[task.parent_id] && taskMap[task.id]) {
                taskMap[task.parent_id].children.push(taskMap[task.id]);
              }
            });
            
            // Set the tasks array to the root tasks
            this.tasks = rootTasks;
            
            console.log('Tasks rebuilt:', this.tasks);
            console.log(`Built ${rootTasks.length} root tasks with hierarchical structure.`);
            
            // Additional debugging to check hierarchy
            const countAllTasks = (tasks) => {
              let count = tasks.length;
              tasks.forEach(task => {
                if (task.children && task.children.length) {
                  count += countAllTasks(task.children);
                }
              });
              return count;
            };
            const totalTaskCount = countAllTasks(rootTasks);
            console.log(`Total tasks in hierarchy: ${totalTaskCount}`);
            
            // Force UI update to ensure everything rerenders
            this.$nextTick(() => {
              this.forceUpdate();
            });
          }
          
          // Fetch dependencies
          this.fetchDependenciesFromServer();
        })
        .catch(error => {
          console.error('Error fetching tasks:', error);
        });
    },
    
    fetchDependenciesFromServer() {
      // Fetch dependencies from server with project filter
      const url = this.projectId ? `/api/v1/task_dependencies?project_id=${this.projectId}` : '/api/v1/task_dependencies';
      
      fetch(url)
        .then(response => response.json())
        .then(data => {
          console.log('Received dependencies from server:', data);
          
          // Clear existing dependencies and replace with server data
          this.dependencies = [];
          
          // Process dependencies
          if (Array.isArray(data)) {
            this.dependencies = data.map(dep => ({
              from: dep.task_id,
              to: dep.dependent_task_id,
              fromType: this.mapDependencyType(dep.dependency_type, 'start'),
              toType: this.mapDependencyType(dep.dependency_type, 'end')
            }));
          }
          
          console.log('Dependencies rebuilt:', this.dependencies);
          
          // Force UI update after dependencies are loaded
          this.$nextTick(() => {
            this.forceUpdate();
          });
        })
        .catch(error => {
          console.error('Error fetching dependencies:', error);
        });
    },
    
    // Helper to map backend dependency types to frontend fromType/toType format
    mapDependencyType(type, position) {
      // Default to finish_to_start which is most common
      const dependencyType = type || 'finish_to_start';
      
      // Map based on position (start or end) and dependency type
      if (position === 'start') {
        // Map to "from" side of dependency
        switch (dependencyType) {
          case 'finish_to_start': return 'end';
          case 'start_to_start': return 'start';
          case 'finish_to_finish': return 'end';
          case 'start_to_finish': return 'start';
          default: return 'end';
        }
      } else {
        // Map to "to" side of dependency
        switch (dependencyType) {
          case 'finish_to_start': return 'start';
          case 'start_to_start': return 'start';
          case 'finish_to_finish': return 'end';
          case 'start_to_finish': return 'end';
          default: return 'start';
        }
      }
    },
    
    // Helper to detect if a message is likely a task creation request
    isTaskCreationRequest(message) {
      if (!message) return false;
      
      const msgLower = message.toLowerCase();
      
      // Check for task creation patterns
      const taskKeywords = ['task', 'project', 'plan', 'schedule', 'gantt', 'timeline'];
      const createKeywords = ['create', 'generate', 'make', 'build', 'develop', 'setup'];
      
      // Check if at least one word from each category is in the message
      const hasTaskKeyword = taskKeywords.some(word => msgLower.includes(word));
      const hasCreateKeyword = createKeywords.some(word => msgLower.includes(word));
      
      return hasTaskKeyword && hasCreateKeyword;
    },
    
    // Resource Management
    addResource(resource) {
      this.resources.push(resource);
    },
    
    updateResource(updatedResource) {
      const index = this.resources.findIndex(r => r.id === updatedResource.id);
      if (index !== -1) {
        this.resources[index] = { ...updatedResource };
      }
    },
    
    deleteResource(resourceId) {
      // Remove the resource
      const index = this.resources.findIndex(r => r.id === resourceId);
      if (index !== -1) {
        this.resources.splice(index, 1);
      }
      
      // Also remove this resource from all tasks
      const removeResourceFromTask = (task) => {
        if (task.resources && task.resources.includes(resourceId)) {
          task.resources = task.resources.filter(id => id !== resourceId);
        }
        
        if (task.children && task.children.length > 0) {
          task.children.forEach(child => removeResourceFromTask(child));
        }
      };
      
      this.tasks.forEach(task => removeResourceFromTask(task));
    },
    
    // Debug Panel
    toggleDebugPanel() {
      this.showDebugPanel = !this.showDebugPanel;
    },
    
    startDragDebugPanel(event) {
      if (event.target.tagName === 'BUTTON' || event.target.tagName === 'INPUT') {
        return;
      }
      
      this.isDraggingDebugPanel = true;
      this.debugPanelDragStart = {
        x: event.clientX,
        y: event.clientY
      };
      
      this.debugPanelDragInitialPosition = {
        top: this.debugPanelPosition.top,
        left: this.debugPanelPosition.left
      };
      
      document.addEventListener('mousemove', this.dragDebugPanel);
      document.addEventListener('mouseup', this.stopDragDebugPanel);
    },
    
    dragDebugPanel(event) {
      if (!this.isDraggingDebugPanel) return;
      
      const deltaX = event.clientX - this.debugPanelDragStart.x;
      const deltaY = event.clientY - this.debugPanelDragStart.y;
      
      this.debugPanelPosition = {
        top: Math.max(0, this.debugPanelDragInitialPosition.top + deltaY),
        left: Math.max(0, this.debugPanelDragInitialPosition.left + deltaX)
      };
    },
    
    stopDragDebugPanel() {
      this.isDraggingDebugPanel = false;
      document.removeEventListener('mousemove', this.dragDebugPanel);
      document.removeEventListener('mouseup', this.stopDragDebugPanel);
    },
    
    // AI Chat Panel Dragging
    startDragAIChatPanel(event) {
      if (event.target.tagName === 'BUTTON' || event.target.tagName === 'INPUT') {
        return;
      }
      
      this.isDraggingAIChatPanel = true;
      this.aiChatPanelDragStart = {
        x: event.clientX,
        y: event.clientY
      };
      
      this.aiChatPanelDragInitialPosition = {
        top: this.aiChatPanelPosition.top,
        left: this.aiChatPanelPosition.left
      };
      
      document.addEventListener('mousemove', this.dragAIChatPanel);
      document.addEventListener('mouseup', this.stopDragAIChatPanel);
    },
    
    dragAIChatPanel(event) {
      if (!this.isDraggingAIChatPanel) return;
      
      const deltaX = event.clientX - this.aiChatPanelDragStart.x;
      const deltaY = event.clientY - this.aiChatPanelDragStart.y;
      
      this.aiChatPanelPosition = {
        top: Math.max(0, this.aiChatPanelDragInitialPosition.top + deltaY),
        left: Math.max(0, this.aiChatPanelDragInitialPosition.left + deltaX)
      };
    },
    
    stopDragAIChatPanel() {
      this.isDraggingAIChatPanel = false;
      document.removeEventListener('mousemove', this.dragAIChatPanel);
      document.removeEventListener('mouseup', this.stopDragAIChatPanel);
      
      // Auto-dock to edges if the panel is near an edge
      this.autoDockAIChat();
    },
    
    autoDockAIChat() {
      const windowWidth = window.innerWidth;
      const windowHeight = window.innerHeight;
      const dockThreshold = 50; // px from the edge to trigger docking
      
      const left = this.aiChatPanelPosition.left;
      const top = this.aiChatPanelPosition.top;
      
      // Check if near any edges
      if (left < dockThreshold) {
        this.dockAIChat('west');
      } else if (left > windowWidth - 400 - dockThreshold) {
        this.dockAIChat('east');
      } else if (top < dockThreshold) {
        this.dockAIChat('north');
      } else if (top > windowHeight - 500 - dockThreshold) {
        this.dockAIChat('south');
      }
    },
    
    dockAIChat(position) {
      const previousPosition = this.aiChatDockPosition;
      
      // Update the dock position
      this.aiChatDockPosition = position;
      
      // Set appropriate dimensions based on dock position
      const windowWidth = window.innerWidth;
      const windowHeight = window.innerHeight;
      
      // Set default sizes for each dock position if coming from a different position
      if (previousPosition !== position) {
        switch (position) {
          case 'north':
          case 'south':
            // For top/bottom docking, set height to 300px (or 30% of screen) and width to full screen
            this.aiChatPanelSize.height = Math.min(300, Math.floor(windowHeight * 0.3));
            break;
            
          case 'east':
          case 'west':
            // For left/right docking, set width to 350px (or 30% of screen) and height to full screen
            this.aiChatPanelSize.width = Math.min(350, Math.floor(windowWidth * 0.3));
            break;
            
          case 'free':
            // Set to center of screen if currently docked
            this.aiChatPanelPosition = {
              top: (windowHeight - this.aiChatPanelSize.height) / 2,
              left: (windowWidth - this.aiChatPanelSize.width) / 2
            };
            
            // Reset to default size if coming from docked
            if (previousPosition !== 'free') {
              this.aiChatPanelSize = {
                width: 400,
                height: 500
              };
            }
            break;
        }
      }
    },
    
    // Resize methods for the AI Chat panel
    startResize(e, type) {
      // Prevent default and stop propagation to avoid conflicts
      e.preventDefault();
      e.stopPropagation();
      
      // Store start values
      this.isResizing = true;
      this.resizeType = type;
      this.resizeStartPos = { x: e.clientX, y: e.clientY };
      this.resizeStartSize = { 
        width: this.aiChatPanelSize.width, 
        height: this.aiChatPanelSize.height 
      };
      
      // Add event listeners
      document.addEventListener('mousemove', this.onResize);
      document.addEventListener('mouseup', this.stopResize);
      
      // Add visual indication
      document.body.classList.add('resizing');
      
      // Set cursor for the whole document based on resize type
      switch (type) {
        case 'right':
        case 'left':
          document.body.style.cursor = 'ew-resize';
          break;
        case 'top':
        case 'bottom':
          document.body.style.cursor = 'ns-resize';
          break;
        case 'corner':
          document.body.style.cursor = 'se-resize';
          break;
      }
    },
    
    onResize(e) {
      if (!this.isResizing) return;
      
      const dx = e.clientX - this.resizeStartPos.x;
      const dy = e.clientY - this.resizeStartPos.y;
      
      // Minimum dimensions
      const MIN_WIDTH = 300;
      const MIN_HEIGHT = 200;
      
      // Maximum dimensions (for window boundaries)
      const MAX_WIDTH = window.innerWidth;
      const MAX_HEIGHT = window.innerHeight;
      
      // Apply resizing based on handle type
      switch (this.resizeType) {
        case 'right':
          const newWidth = this.resizeStartSize.width + dx;
          if (newWidth >= MIN_WIDTH && newWidth <= MAX_WIDTH) {
            this.aiChatPanelSize.width = newWidth;
          }
          break;
          
        case 'left':
          const newLeftWidth = this.resizeStartSize.width - dx;
          if (newLeftWidth >= MIN_WIDTH && newLeftWidth <= MAX_WIDTH) {
            this.aiChatPanelSize.width = newLeftWidth;
          }
          break;
          
        case 'bottom':
          const newHeight = this.resizeStartSize.height + dy;
          if (newHeight >= MIN_HEIGHT && newHeight <= MAX_HEIGHT) {
            this.aiChatPanelSize.height = newHeight;
          }
          break;
          
        case 'top':
          const newTopHeight = this.resizeStartSize.height - dy;
          if (newTopHeight >= MIN_HEIGHT && newTopHeight <= MAX_HEIGHT) {
            this.aiChatPanelSize.height = newTopHeight;
          }
          break;
          
        case 'corner':
          // Resize both width and height
          const cornerWidth = this.resizeStartSize.width + dx;
          const cornerHeight = this.resizeStartSize.height + dy;
          
          if (cornerWidth >= MIN_WIDTH && cornerWidth <= MAX_WIDTH) {
            this.aiChatPanelSize.width = cornerWidth;
          }
          
          if (cornerHeight >= MIN_HEIGHT && cornerHeight <= MAX_HEIGHT) {
            this.aiChatPanelSize.height = cornerHeight;
          }
          break;
      }
    },
    
    stopResize() {
      if (!this.isResizing) return;
      
      // Clean up
      this.isResizing = false;
      this.resizeType = null;
      document.removeEventListener('mousemove', this.onResize);
      document.removeEventListener('mouseup', this.stopResize);
      
      // Remove visual indication
      document.body.classList.remove('resizing');
      document.body.style.cursor = '';
    },
    
    forceUpdate() {
      // Force a UI refresh by creating a temporary copy
      this.resources = [...this.resources];
    },
    
    // Methods for controlling task bar height
    updateDetailBarHeight() {
      // Create a custom style element or update it if it exists
      let styleEl = document.getElementById('gantt-bar-styles');
      if (!styleEl) {
        styleEl = document.createElement('style');
        styleEl.id = 'gantt-bar-styles';
        document.head.appendChild(styleEl);
      }
      
      // Set the custom CSS for the detail task bars
      styleEl.textContent = `
        .task-bar:not(.summary-task-bar) {
          height: ${this.detailTaskBarHeight}px !important;
        }
        
        .task-bar:not(.summary-task-bar) .task-bar-content {
          height: ${this.detailTaskBarHeight}px !important;
        }
        
        /* Update connection points vertical positioning */
        .connection-point {
          top: ${this.detailTaskBarHeight / 2}px;
        }
      `;
      
      // Force a UI refresh
      this.forceUpdate();
    },
    
    resetBarHeights() {
      // Reset to default values
      this.detailTaskBarHeight = 25;
      
      // Remove the custom style element
      const styleEl = document.getElementById('gantt-bar-styles');
      if (styleEl) {
        styleEl.remove();
      }
      
      // Force a UI refresh
      this.forceUpdate();
    }
  }
}
</script>

<style>
/* ===== Base Styles ===== */
body {
  margin: 0;
  padding: 0;
  font-family: Avenir, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  color: #2c3e50;
  height: 100vh;
  overflow: hidden;
}

/* ===== App Container ===== */
.app-container {
  display: grid;
  grid-template-rows: auto 1fr;
  height: 100vh;
  overflow: hidden;
}

/* ===== App Header ===== */
.app-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 20px;
  height: 50px;
  background-color: #fff;
  border-bottom: 1px solid #e1e4e8;
  box-shadow: 0 1px 3px rgba(0,0,0,0.05);
}

.app-title h1 {
  font-size: 18px;
  margin: 0;
  font-weight: 600;
}

.project-subtitle {
  margin-top: 3px;
}

.project-subtitle h2 {
  font-size: 14px;
  margin: 0;
  color: #666;
  font-weight: normal;
}

.app-left-controls {
  display: flex;
  align-items: center;
  gap: 15px;
}

.app-right-controls {
  display: flex;
  align-items: center;
}

.logout-button {
  background-color: #6699CC;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 4px;
  cursor: pointer;
  font-weight: 500;
  transition: background-color 0.2s;
}

.logout-button:hover {
  background-color: #003366;
}

.debug-button {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 26px;
  height: 26px;
  border-radius: 4px;
  cursor: pointer;
  color: #6b7280;
  transition: background-color 0.2s;
}

.debug-button:hover {
  background-color: #f3f4f6;
  color: #4b5563;
}

.build-info {
  display: flex;
  align-items: center;
}

.build-number {
  font-size: 10px;
  color: #6b7280;
  font-family: monospace;
}

/* App Switcher */
.app-switcher {
  position: relative;
}

.app-switcher-button {
  background: none;
  border: none;
  cursor: pointer;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #5f6368;
  transition: background-color 0.2s;
}

.app-switcher-button:hover {
  background-color: #f1f3f4;
}

.app-switcher-menu {
  position: absolute;
  top: 100%;
  right: 0;
  width: 280px;
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0,0,0,0.15);
  padding: 8px;
  margin-top: 8px;
  z-index: 1000;
}

.app-option {
  display: flex;
  align-items: center;
  padding: 10px 16px;
  border-radius: 4px;
  cursor: pointer;
}

.app-option:hover:not(.disabled) {
  background-color: #f1f3f4;
}

.app-option.active {
  background-color: #e8f0fe;
  color: #1a73e8;
}

.app-option.disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.app-icon {
  font-size: 20px;
  margin-right: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.app-name {
  font-size: 14px;
}

/* ===== Main Container ===== */
.main-container {
  display: grid;
  grid-template-columns: auto 1fr;
  overflow: hidden;
}

/* ===== Navigation Sidebar ===== */
.nav-sidebar {
  width: 220px;
  background-color: #f8f9fa;
  border-right: 1px solid #e1e4e8;
  padding: 15px 0;
  position: relative;
  transition: width 0.3s ease;
  display: flex;
  flex-direction: column;
  height: 100%;
}

.nav-sidebar.collapsed {
  width: 60px;
}

.sidebar-toggle {
  position: absolute;
  top: 10px;
  right: 10px;
  width: 24px;
  height: 24px;
  background-color: #fff;
  border: 1px solid #e1e4e8;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  z-index: 10;
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  transition: all 0.2s;
}

.collapsed .sidebar-toggle {
  right: 5px;
}

.sidebar-toggle:hover {
  background-color: #f3f4f6;
  transform: scale(1.05);
}

/* Sidebar Navigation Sections */
.nav-items-container {
  flex: 1;
  overflow-y: auto;
  padding-top: 10px;
}

.sidebar-footer {
  padding: 10px 0;
  border-top: 1px solid #e1e4e8;
  margin-top: auto;
  width: 100%;
  position: sticky;
  bottom: 0;
  background-color: #f8f9fa;
  z-index: 5;
}

.nav-item {
  display: flex;
  align-items: center;
  padding: 10px 15px;
  cursor: pointer;
  color: #4a5568;
  border-radius: 4px;
  margin: 2px 8px;
  transition: all 0.2s;
  text-decoration: none;
}

/* Style for the cloned Back to Dashboard button */
.btn-back-clone {
  /* Ensure it looks like a nav item while preserving the essential behavior */
  background-color: #e6f0ff !important;
  font-weight: 500 !important;
}

.nav-item:hover:not(.disabled) {
  background-color: #edf2f7;
}

.nav-item.active {
  background-color: #e6f0ff;
  color: #2b6cb0;
  font-weight: 500;
}

.nav-item.disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.nav-item.ai-item {
  color: #6699CC;
  font-weight: 500;
  background-color: #e6f0ff;
  border: 1px solid #c0d5e8;
  margin: 2px 15px; /* Wider margin for better appearance */
}

.nav-item.ai-item:hover {
  background-color: #d8e8ff;
  border-color: #6699CC;
}

.nav-item.ai-item.ai-active {
  background-color: #6699CC;
  color: white;
  font-weight: 500;
  border-color: #5588bb;
}

.nav-icon {
  font-size: 18px;
  display: flex;
  align-items: center;
  margin-right: 12px;
}

.collapsed .nav-icon {
  margin-right: 0;
}

.collapsed .nav-item {
  justify-content: center;
  padding: 10px 5px;
}

.nav-label {
  font-size: 14px;
  white-space: nowrap;
}

/* ===== Content Area ===== */
.content-area {
  display: flex;
  flex-direction: column;
  flex: 1;
  overflow: hidden;
  margin-right: 2px; /* Small margin to prevent content from being cut off */
  height: calc(100vh - 50px); /* Full height minus header */
}

/* Workspace Toolbar */
.workspace-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  background-color: #f8f9fa;
  border-bottom: 1px solid #e1e4e8;
  position: sticky;
  top: 0;
  z-index: 10;
}

.toolbar-left, .toolbar-right {
  display: flex;
  gap: 10px;
}

.workspace-toolbar button {
  padding: 6px 12px;
  background-color: #fff;
  border: 1px solid #d1d5db;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  transition: all 0.2s;
}

.workspace-toolbar button:hover {
  background-color: #f9fafb;
  border-color: #c0c5ce;
}

.btn-delete-dependency {
  background-color: #dc3545 !important;
  border: 1px solid #c82333 !important;
  color: white !important;
}

.btn-delete-dependency:hover {
  background-color: #c82333 !important;
}

/* Workspace Content */
.workspace-content {
  flex: 1;
  overflow: visible; /* Changed from hidden to visible */
  position: relative;
  box-sizing: border-box;
  width: 100%;
  height: calc(100% - 48px); /* Subtract toolbar height */
}

/* ===== Debug Panel ===== */
.debug-panel {
  position: fixed;
  width: 320px;
  background-color: white;
  border: 1px solid #ccc;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0,0,0,0.1);
  z-index: 9999;
  overflow: hidden;
}

.debug-panel-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 15px;
  background-color: #f5f5f5;
  border-bottom: 1px solid #ddd;
  cursor: move;
  user-select: none;
}

.debug-panel-header h3 {
  margin: 0;
  font-size: 16px;
  color: #333;
}

.debug-panel-controls {
  display: flex;
  align-items: center;
  gap: 10px;
}

.drag-indicator {
  font-size: 16px;
  color: #aaa;
  cursor: move;
}

.debug-panel-header button {
  background: none;
  border: none;
  font-size: 18px;
  cursor: pointer;
  color: #666;
}

.debug-panel-content {
  padding: 15px;
  max-height: 80vh;
  overflow-y: auto;
}

.debug-section {
  margin-bottom: 15px;
}

.debug-section h4 {
  margin: 0 0 10px 0;
  font-size: 14px;
  color: #555;
  border-bottom: 1px solid #eee;
  padding-bottom: 5px;
}

.debug-info {
  background-color: #f8f9fa;
  padding: 12px;
  border-radius: 4px;
  margin-bottom: 12px;
  font-size: 13px;
  line-height: 1.5;
}

.debug-info p {
  margin: 4px 0;
}

.debug-control {
  margin-bottom: 12px;
}

.debug-input-group {
  display: flex;
  align-items: center;
  margin-top: 4px;
}

.debug-input-group input[type="range"] {
  flex: 1;
  margin-right: 8px;
}

.debug-value {
  min-width: 40px;
  font-family: monospace;
  text-align: right;
}

.btn-debug-action {
  background-color: #6699CC;
  color: white;
  border: none;
  padding: 6px 12px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 12px;
  margin-top: 8px;
}

.btn-debug-action:hover {
  background-color: #003366;
}

/* ===== AI Chat Panel ===== */
.ai-chat-panel {
  position: fixed;
  width: 400px;
  height: 500px;
  background-color: white;
  border: 3px solid #6699CC;
  border-radius: 10px;
  box-shadow: 0 4px 20px rgba(0,0,0,0.3);
  z-index: 9999;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  transition: all 0.3s ease;
}

/* Docked states */
.ai-chat-panel.docked {
  border-radius: 0;
}

.ai-chat-panel.dock-north {
  top: 0;
  left: 0;
  width: 100%;
  height: 300px;
  border-radius: 0 0 10px 10px;
}

.ai-chat-panel.dock-south {
  bottom: 0;
  left: 0;
  width: 100%;
  height: 300px;
  border-radius: 10px 10px 0 0;
}

.ai-chat-panel.dock-east {
  top: 0;
  right: 0;
  width: 350px;
  height: 100%;
  border-radius: 10px 0 0 10px;
}

.ai-chat-panel.dock-west {
  top: 0;
  left: 0;
  width: 350px;
  height: 100%;
  border-radius: 0 10px 10px 0;
}

/* Custom sizing for docked panels */
.ai-chat-panel.dock-north, 
.ai-chat-panel.dock-south {
  height: v-bind('aiChatPanelSize.height + "px"');
}

.ai-chat-panel.dock-east, 
.ai-chat-panel.dock-west {
  width: v-bind('aiChatPanelSize.width + "px"');
}

/* Resize handles */
.resize-handle {
  position: absolute;
  z-index: 999;
  background-color: rgba(102, 153, 204, 0.1); /* #6699CC with transparency */
  transition: background-color 0.2s ease;
}

.resize-handle.resize-e {
  width: 8px;
  height: 100%; 
  top: 0;
  right: -4px;
  cursor: e-resize;
}

.resize-handle.resize-w {
  width: 8px;
  height: 100%;
  top: 0;
  left: -4px;
  cursor: w-resize;
}

.resize-handle.resize-s {
  width: 100%;
  height: 8px;
  bottom: -4px;
  left: 0;
  cursor: s-resize;
}

.resize-handle.resize-n {
  width: 100%;
  height: 8px;
  top: -4px;
  left: 0;
  cursor: n-resize;
}

.resize-handle.resize-se {
  width: 16px;
  height: 16px;
  bottom: -8px;
  right: -8px;
  cursor: se-resize;
  border-radius: 0 0 8px 0;
  background-color: rgba(102, 153, 204, 0.2); /* Slightly more visible */
}

.resize-handle:hover {
  background-color: rgba(102, 153, 204, 0.4); /* More visible on hover */
}

body.resizing {
  cursor: auto !important;
  user-select: none;
}

/* Add subtle highlight during resize */
body.resizing .ai-chat-panel {
  box-shadow: 0 0 15px rgba(102, 153, 204, 0.4);
  border-color: #6699CC;
}

.ai-chat-panel-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 15px;
  background-color: #6699CC;
  color: white;
  border-bottom: 1px solid #5588BB;
  user-select: none;
}

.ai-chat-panel-header h3 {
  margin: 0;
  font-size: 16px;
  font-weight: bold;
}

.ai-chat-panel-controls {
  display: flex;
  align-items: center;
  gap: 10px;
}

.dock-controls {
  display: flex;
  gap: 5px;
}

.dock-button {
  width: 24px;
  height: 24px;
  border: 1px solid rgba(255, 255, 255, 0.3);
  background-color: rgba(255, 255, 255, 0.2);
  color: white;
  border-radius: 3px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  padding: 0;
  cursor: pointer;
  transition: all 0.2s ease;
}

.dock-button:hover {
  background-color: rgba(255, 255, 255, 0.3);
}

.dock-button.active {
  background-color: rgba(255, 255, 255, 0.4);
  border-color: rgba(255, 255, 255, 0.6);
}

.ai-chat-panel-content {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
  padding: 0;
}

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
  align-items: flex-start;
}

.user-message {
  margin-left: auto;
  flex-direction: row-reverse;
}

.ai-avatar, .user-avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 14px;
  font-weight: bold;
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

.ai-chat-input {
  display: flex;
  padding: 12px;
  border-top: 1px solid #eee;
  background-color: white;
}

.ai-chat-input textarea {
  flex: 1;
  border: 1px solid #ddd;
  border-radius: 20px;
  padding: 10px 14px;
  font-family: inherit;
  resize: none;
  outline: none;
  margin-right: 8px;
}

.ai-chat-input textarea:focus {
  border-color: #6699CC;
}

.send-button {
  min-width: 60px;
  height: 36px;
  border-radius: 18px;
  background-color: #6699CC;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  border: none;
  transition: all 0.2s ease;
}

.send-button:hover {
  background-color: #5588BB;
}

.send-button:disabled {
  background-color: #ccc;
  cursor: not-allowed;
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

.btn-danger {
  padding: 8px 16px;
  background-color: #dc3545;
  color: white;
  border: 1px solid #dc3545;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
}

/* ===== Modal Styles ===== */
.modal-backdrop {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 9999;
}

.modal-container {
  background-color: white;
  border-radius: 8px;
  width: 400px;
  max-width: 90%;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.2);
  overflow: hidden;
}

.modal-header {
  padding: 16px;
  background-color: #f8f9fa;
  border-bottom: 1px solid #eee;
}

.modal-header h3 {
  margin: 0;
  font-size: 18px;
  color: #333;
}

.modal-body {
  padding: 16px;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  padding: 12px 16px;
  background-color: #f8f9fa;
  border-top: 1px solid #eee;
  gap: 10px;
}

.btn-cancel {
  padding: 8px 16px;
  background-color: #e9ecef;
  border: 1px solid #ced4da;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  color: #495057;
}
</style>