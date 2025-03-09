<template>
  <div class="gantt-app" @click="onChartClick">
    <div class="gantt-container">
      <div class="gantt-sidebar" :style="{ width: sidebarWidth + 'px' }">
        <div class="task-list">
          <div class="table-header-row">
            <div class="table-cell table-name">
              Task Name
            </div>
            <div v-if="visibleColumns.startDate" class="table-cell table-date">
              Start Date
              <button class="column-toggle-button" @click.stop="toggleColumnVisibility('startDate')">×</button>
            </div>
            <div v-if="visibleColumns.endDate" class="table-cell table-date">
              End Date
              <button class="column-toggle-button" @click.stop="toggleColumnVisibility('endDate')">×</button>
            </div>
            <div v-if="visibleColumns.progress" class="table-cell table-progress">
              Progress
              <button class="column-toggle-button" @click.stop="toggleColumnVisibility('progress')">×</button>
            </div>
            <div v-if="visibleColumns.resources" class="table-cell table-resources">
              Resources
              <button class="column-toggle-button" @click.stop="toggleColumnVisibility('resources')">×</button>
            </div>
            <div class="column-options">
              <button class="column-options-button" @click="showColumnOptions = !showColumnOptions">☰</button>
              <div v-if="showColumnOptions" class="column-options-menu">
                <div class="column-option" v-for="(label, col) in columnLabels" :key="col">
                  <input 
                    type="checkbox" 
                    :id="'col-' + col" 
                    :checked="visibleColumns[col]" 
                    @change="toggleColumnVisibility(col)"
                  />
                  <label :for="'col-' + col">{{ label }}</label>
                </div>
              </div>
            </div>
          </div>
          <task-item 
            v-for="task in tasks" 
            :key="task.id" 
            :task="task" 
            :level="0"
            :available-resources="resources"
            :visible-columns="visibleColumns"
            :date-input-width="dateInputWidth"
            @toggle="toggleTask"
            @update="updateTask"
            @delete="confirmDeleteTask"
          />
        </div>
      </div>
      
      <div class="gantt-slider" 
           @mousedown="startSliderDrag"
           :class="{ 'dragging': isDraggingSlider }">
        <div class="slider-handle">⋮⋮</div>
      </div>
      
      <div class="gantt-timeline" ref="timeline">
        <div class="gantt-header">
          <timeline-header :start-date="startDate" :end-date="endDate" :zoom-level="zoomLevel" />
        </div>
        <div class="gantt-bars">
          <task-bar 
            v-for="task in flattenedTasks" 
            :key="task.id" 
            :task="task" 
            :start-date="startDate"
            :zoom-level="zoomLevel"
            :ref="'taskBar_' + task.id"
            @update="updateTaskDates"
            @connectionStart="onConnectionStart"
            @connectionEnd="onConnectionEnd"
          />
        </div>
        <task-dependencies 
          :tasks="flattenedTasks" 
          :start-date="startDate"
          :zoom-level="zoomLevel"
          :dependencies="dependencies"
          :selected-dependency-index="selectedDependencyIndex"
          @select="onDependencySelect"
        />
      </div>
    </div>
  </div>
</template>

<script>
import TaskItem from './TaskItem.vue'
import TaskBar from './TaskBar.vue'
import TimelineHeader from './TimelineHeader.vue'
import TaskDependencies from './TaskDependencies.vue'

export default {
  name: 'GanttChart',
  components: {
    TaskItem,
    TaskBar,
    TimelineHeader,
    TaskDependencies
  },
  props: {
    // Data passed from parent
    tasks: {
      type: Array,
      required: true
    },
    resources: {
      type: Array,
      required: true
    },
    dependencies: {
      type: Array,
      required: true
    },
    selectedDependencyIndex: {
      type: Number,
      default: -1
    }
  },
  data() {
    return {
      // Date range
      startDate: new Date(2025, 2, 1),
      endDate: new Date(2025, 3, 15),
      zoomLevel: 1,
      
      // Active connection state
      activeConnection: null,
      hoveredTaskId: null,
      
      // Column visibility settings
      visibleColumns: {
        startDate: true,
        endDate: true,
        progress: true,
        resources: true
      },
      columnLabels: {
        startDate: 'Start Date',
        endDate: 'End Date',
        progress: 'Progress',
        resources: 'Resources'
      },
      showColumnOptions: false,
      
      // Slider related state
      sidebarWidth: 730,
      minSidebarWidth: 200,
      maxSidebarWidth: 900,
      isDraggingSlider: false,
      startDragX: 0,
      startDragWidth: 0,
      
      // Date input control width
      dateInputWidth: 105,
      
      // Pentagon shape width for summary tasks
      pentagonWidth: 20,
      pentagonHeight: 65
    }
  },
  mounted() {
    // Initialize the pentagon width
    this.updatePentagonWidth();
  },
  computed: {
    flattenedTasks() {
      const result = []
      let rowIndex = 0
      
      const flatten = (tasks, level) => {
        tasks.forEach(task => {
          // Assign a row index to each task
          const taskWithPosition = { 
            ...task, 
            level,
            rowIndex: rowIndex++ 
          }
          
          result.push(taskWithPosition)
          
          if (task.expanded && task.children && task.children.length > 0) {
            flatten(task.children, level + 1)
          }
        })
      }
      
      flatten(this.tasks, 0)
      return result
    }
  },
  methods: {
    zoomIn() {
      if (this.zoomLevel < 3) {
        this.zoomLevel += 0.5;
      }
    },
    
    zoomOut() {
      if (this.zoomLevel > 0.5) {
        this.zoomLevel -= 0.5;
      }
    },
    
    toggleTask(taskId) {
      console.log("GanttChart - Toggle task:", taskId);
      
      // Find the task in the flattened array
      const task = this.findTaskById(taskId);
      
      if (task) {
        // Create an updated task with toggled expanded state
        const updatedTask = {
          ...task,
          expanded: !task.expanded
        };
        
        // Emit the task update
        this.$emit('update:task', updatedTask);
      }
    },
    
    updateTask(updatedTask) {
      // Forward to parent
      this.$emit('update:task', updatedTask);
    },
    
    updateTaskDates(taskId, newStart, newEnd) {
      const task = this.findTaskById(taskId);
      if (task) {
        const updatedTask = { 
          ...task, 
          startDate: newStart, 
          endDate: newEnd 
        };
        this.$emit('update:task', updatedTask);
      }
    },
    
    recalculateSummaryTaskDates(summaryTask) {
      if (!summaryTask.children || summaryTask.children.length === 0) return;
      
      // Convert dates to timestamps for comparison
      const childStartDates = summaryTask.children.map(child => new Date(child.startDate).getTime());
      const childEndDates = summaryTask.children.map(child => new Date(child.endDate).getTime());
      
      // Find the earliest start date and latest end date
      const minStartTime = Math.min(...childStartDates);
      const maxEndTime = Math.max(...childEndDates);
      
      // Create an updated task with new date range
      const updatedTask = {
        ...summaryTask,
        startDate: new Date(minStartTime),
        endDate: new Date(maxEndTime)
      };
      
      this.$emit('update:task', updatedTask);
    },
    
    confirmDeleteTask(taskId) {
      this.$emit('delete:task', taskId);
    },
    
    findTaskById(taskId) {
      const searchInTasks = (tasks) => {
        for (const task of tasks) {
          if (task.id === taskId) {
            return task;
          }
          
          if (task.children && task.children.length > 0) {
            const found = searchInTasks(task.children);
            if (found) return found;
          }
        }
        return null;
      };
      
      return searchInTasks(this.tasks);
    },
    
    // Dependency connection handlers
    onConnectionStart({ taskId, connectionType }) {
      this.activeConnection = {
        fromTaskId: taskId,
        fromType: connectionType
      }
      
      // Add event listener to handle hover detection on other tasks
      document.addEventListener('mousemove', this.onConnectionMouseMove)
    },
    
    onConnectionMouseMove(e) {
      if (!this.activeConnection) return
      
      // Check if we're hovering over a task connection point
      this.hoveredTaskId = null
      
      // Reset all task connection points active state
      this.flattenedTasks.forEach(task => {
        const taskBarRef = this.$refs[`taskBar_${task.id}`]
        if (taskBarRef && taskBarRef[0]) {
          taskBarRef[0].setConnectionPointActive(false)
        }
      })
      
      // Get the element under the cursor
      const elementsUnderCursor = document.elementsFromPoint(e.clientX, e.clientY)
      
      // Check if any of those elements is a connection point
      for (const element of elementsUnderCursor) {
        if (element.classList.contains('connection-point')) {
          // Find the task bar containing this connection point
          let taskBarElement = element.closest('.task-bar')
          if (taskBarElement) {
            // Extract task ID from the ref attribute
            const taskId = parseInt(taskBarElement.getAttribute('data-task-id'))
            if (taskId && taskId !== this.activeConnection.fromTaskId) {
              this.hoveredTaskId = taskId
              
              // Highlight the connection point
              const taskBarRef = this.$refs[`taskBar_${taskId}`]
              if (taskBarRef && taskBarRef[0]) {
                taskBarRef[0].setConnectionPointActive(true)
              }
              
              break
            }
          }
        }
      }
    },
    
    onConnectionEnd({ fromTaskId, fromType, mouseX, mouseY }) {
      if (!this.activeConnection) return
      
      document.removeEventListener('mousemove', this.onConnectionMouseMove)
      
      // Check if we ended on a valid connection point
      if (this.hoveredTaskId) {
        // Get the connection type of the hovered task
        const elementsUnderCursor = document.elementsFromPoint(mouseX, mouseY)
        let toType = null
        
        for (const element of elementsUnderCursor) {
          if (element.classList.contains('connection-point')) {
            if (element.classList.contains('connection-point-start')) {
              toType = 'start'
              break
            } else if (element.classList.contains('connection-point-end')) {
              toType = 'end'
              break
            }
          }
        }
        
        if (toType) {
          // Add the new dependency
          this.addDependency(fromTaskId, this.hoveredTaskId, fromType, toType)
        }
      }
      
      // Reset
      this.activeConnection = null
      this.hoveredTaskId = null
      
      // Reset all task connection points active state
      this.flattenedTasks.forEach(task => {
        const taskBarRef = this.$refs[`taskBar_${task.id}`]
        if (taskBarRef && taskBarRef[0]) {
          taskBarRef[0].setConnectionPointActive(false)
        }
      })
    },
    
    addDependency(fromTaskId, toTaskId, fromType, toType) {
      // Check if this dependency already exists
      const existingDep = this.dependencies.find(
        dep => dep.from === fromTaskId && dep.to === toTaskId
      )
      
      if (!existingDep) {
        // Create a direct copy to ensure proper reference update
        const newDependency = {
          from: parseInt(fromTaskId),
          to: parseInt(toTaskId),
          fromType,
          toType
        };
        
        // Create a fresh copy of dependencies and add the new one
        const updatedDependencies = JSON.parse(JSON.stringify(this.dependencies));
        updatedDependencies.push(newDependency);
        
        // Emit the updated dependencies array
        this.$emit('update:dependency', updatedDependencies);
        
        // Force refresh of dependency lines
        this.$nextTick(() => {
          // Any components that need to redraw will do so on the next tick
          console.log("Added dependency:", newDependency);
        });
      }
    },
    
    // Handle dependency selection
    onDependencySelect(index, dependency, event) {
      // Stop event propagation to prevent immediate deselection
      if (event) {
        event.stopPropagation();
      }
      this.$emit('select:dependency', index);
    },
    
    // Deselect dependency when clicking elsewhere
    onChartClick(event) {
      // Only proceed if we have a selected dependency and
      // we're not clicking the delete button or another dependency
      if (this.selectedDependencyIndex >= 0 && 
          !event.target.closest('.dependency-path') && 
          !event.target.closest('.btn-delete-dependency')) {
        this.$emit('select:dependency', -1);
      }
    },
    
    // Column visibility
    toggleColumnVisibility(columnName) {
      // Toggle the visibility of the specified column
      this.visibleColumns[columnName] = !this.visibleColumns[columnName];
      
      // If we're hiding the column options menu and clicking on a column toggle,
      // we need to prevent the menu from hiding
      if (columnName !== 'showColumnOptions') {
        this.showColumnOptions = false;
      }
    },
    
    // Slider drag methods
    startSliderDrag(event) {
      // Start tracking the slider drag
      this.isDraggingSlider = true;
      this.startDragX = event.clientX;
      this.startDragWidth = this.sidebarWidth;
      
      // Add event listeners for mouse move and mouse up
      document.addEventListener('mousemove', this.handleSliderDrag);
      document.addEventListener('mouseup', this.stopSliderDrag);
    },
    
    handleSliderDrag(event) {
      if (!this.isDraggingSlider) return;
      
      // Calculate the new width
      const deltaX = event.clientX - this.startDragX;
      let newWidth = this.startDragWidth + deltaX;
      
      // Enforce min and max constraints
      newWidth = Math.max(this.minSidebarWidth, Math.min(this.maxSidebarWidth, newWidth));
      
      // Update the sidebar width
      this.sidebarWidth = newWidth;
    },
    
    stopSliderDrag() {
      // Stop tracking the slider drag
      this.isDraggingSlider = false;
      
      // Remove event listeners
      document.removeEventListener('mousemove', this.handleSliderDrag);
      document.removeEventListener('mouseup', this.stopSliderDrag);
    },
    
    updatePentagonWidth() {
      // Apply the pentagon width and height to the CSS using a custom CSS rule
      // First, check if our custom style element exists, if not create it
      let styleEl = document.getElementById('gantt-custom-styles');
      if (!styleEl) {
        styleEl = document.createElement('style');
        styleEl.id = 'gantt-custom-styles';
        document.head.appendChild(styleEl);
      }
      
      // Update the pentagon width and clip-path in the CSS
      styleEl.textContent = `
        .summary-task-bar::before,
        .summary-task-bar::after {
          width: ${this.pentagonWidth}px !important;
          clip-path: polygon(
            0% 0%,
            100% 0%,
            100% ${this.pentagonHeight}%,
            50% 100%,
            0% ${this.pentagonHeight}%
          ) !important;
        }
        
        .summary-task .task-bar-label {
          left: ${this.pentagonWidth + 2}px !important;
        }
      `;
    }
  }
}
</script>

<style>
.gantt-app {
  height: 100%;
  width: 100%;
  overflow: hidden;
}

.gantt-container {
  display: flex;
  height: 100%;
  width: 100%;
  overflow: hidden;
}

.gantt-sidebar {
  border-right: none;
  overflow-y: auto;
  position: relative;
  min-width: 200px;
  max-width: 800px;
  background-color: #fff;
  border-right: 1px solid #e1e4e8;
  transition: width 0.1s ease;
}

.gantt-slider {
  width: 8px;
  background-color: #f0f0f0;
  cursor: col-resize;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  z-index: 20;
  transition: background-color 0.2s;
}

.gantt-slider:hover,
.gantt-slider.dragging {
  background-color: #ddd;
}

.slider-handle {
  color: #999;
  font-size: 12px;
  user-select: none;
  writing-mode: vertical-rl;
  text-orientation: upright;
}

.gantt-timeline {
  flex: 1;
  overflow-x: auto;
  overflow-y: auto;
  position: relative;
  background-color: #fff;
}

.gantt-header {
  position: sticky;
  top: 0;
  background-color: #f5f5f5;
  border-bottom: 1px solid #ddd;
  z-index: 10;
}

.task-header {
  padding: 8px;
  font-weight: bold;
}

.task-list {
  overflow-y: auto;
}

.table-header-row {
  display: flex;
  align-items: center;
  height: 36px;
  background-color: #f5f5f5;
  border-bottom: 1px solid #ddd;
  font-weight: bold;
  position: sticky;
  top: 0;
  z-index: 5;
  padding: 0 8px;
}

.table-cell {
  padding: 0 8px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  display: flex;
  align-items: center;
  position: relative; /* Added for absolute positioning of buttons */
}

.table-name {
  flex: 1;
  min-width: 150px;
}

.table-date {
  width: 120px;
  background-color: #f8f8ff; /* Light blue background for date fields */
}

.table-progress {
  width: 80px;
  text-align: right;
  justify-content: flex-end;
}

.table-resources {
  width: 120px;
  background-color: #fff8f8; /* Light red background for resource fields */
}

.column-toggle-button {
  background: none;
  border: none;
  color: #999;
  cursor: pointer;
  font-size: 12px;
  margin-left: 5px;
  opacity: 0.5; /* Slightly visible by default */
  transition: opacity 0.2s;
  position: absolute;
  right: 2px;
  top: 50%;
  transform: translateY(-50%);
}

.table-cell:hover .column-toggle-button {
  opacity: 1;
}

.column-options {
  display: flex;
  align-items: center;
  position: relative;
  padding: 0 8px;
}

.column-options-button {
  background: none;
  border: none;
  cursor: pointer;
  font-size: 14px;
  color: #666;
  padding: 4px 8px;
}

.column-options-menu {
  position: absolute;
  top: 100%;
  right: 0;
  background-color: white;
  border: 1px solid #ccc;
  border-radius: 4px;
  box-shadow: 0 2px 5px rgba(0,0,0,0.1);
  z-index: 1000;
  min-width: 150px;
  padding: 8px 0;
}

.column-option {
  padding: 6px 12px;
  display: flex;
  align-items: center;
}

.column-option input {
  margin-right: 8px;
}

.gantt-bars {
  position: relative;
  min-height: 100%;
}
</style>