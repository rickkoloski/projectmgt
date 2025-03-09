<template>
  <div class="app-container">
    <!-- App Header - Smaller and with app switcher -->
    <header class="app-header">
      <div class="app-title">
        <h1>Project Management</h1>
      </div>
      
      <div class="app-controls">
        <div class="debug-button" @click="toggleDebugPanel">
          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M8 2l1 2.5M12 2l-1 2.5M16 2l-1 2.5M2.75 9.5h18.5M2.75 14.5h18.5M12 12a4 4 0 0 0-4 4M12 12a4 4 0 0 1 4 4M18 18.5a7 7 0 1 1-12 0"/>
            <circle cx="8" cy="9.5" r="1"/>
            <circle cx="16" cy="9.5" r="1"/>
          </svg>
        </div>
        <div class="build-info">
          <span class="build-number">Build #20250305.16</span>
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
      // View Management
      currentView: 'gantt',
      showAppSwitcher: false,
      sidebarCollapsed: false,
      
      // Debug Panel
      showDebugPanel: false,
      debugPanelPosition: {
        top: 20,
        left: 20
      },
      isDraggingDebugPanel: false,
      debugPanelDragStart: { x: 0, y: 0 },
      debugPanelDragInitialPosition: { top: 0, left: 0 },
      
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
  methods: {
    // Navigation
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
    
    forceUpdate() {
      // Force a UI refresh by creating a temporary copy
      this.resources = [...this.resources];
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

.app-controls {
  display: flex;
  align-items: center;
  gap: 15px;
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
  overflow-y: auto;
  position: relative;
  transition: width 0.3s ease;
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

.nav-item {
  display: flex;
  align-items: center;
  padding: 10px 15px;
  cursor: pointer;
  color: #4a5568;
  border-radius: 4px;
  margin: 2px 8px;
  transition: all 0.2s;
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
  overflow: hidden;
  margin-right: 2px; /* Small margin to prevent content from being cut off */
}

/* Workspace Toolbar */
.workspace-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  background-color: #f8f9fa;
  border-bottom: 1px solid #e1e4e8;
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
  overflow: hidden;
  position: relative;
  box-sizing: border-box;
  width: 100%;
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