<template>
  <div class="gantt-app" @click="onChartClick" ref="ganttApp">
    <!-- Global connection line SVG overlay for dependency creation -->
    <svg v-if="activeConnection" class="global-connection-svg">
      <path :d="connectionPath" class="global-connection-path"></path>
    </svg>
    
    <div class="gantt-container">
      <!-- Headers section with fixed sidebar header and scrollable timeline header -->
      <div class="gantt-headers-container">
        <!-- Left side header (fixed) -->
        <div class="gantt-sidebar-header" :style="{ width: sidebarWidth + 'px' }">
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
              <button class="column-options-button" ref="columnOptionsButton" @click="toggleColumnOptionsMenu">☰</button>
              <div v-if="showColumnOptions" class="column-options-menu" :style="columnOptionsMenuStyle">
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
        </div>
        
        <!-- Slider between the headers -->
        <div class="gantt-slider-header" :style="{ width: '8px' }"></div>
        
        <!-- Right side header wrapper (with horizontal scroll) -->
        <div class="gantt-timeline-header-wrapper" ref="timelineHeaderWrapper">
          <!-- Timeline header (scrolls with timeline) -->
          <div class="gantt-timeline-header" ref="timelineHeader">
            <timeline-header 
              :start-date="startDate" 
              :end-date="endDate" 
              :zoom-level="zoomLevel"
              :timeline-mode="timelineMode" 
            />
          </div>
        </div>
      </div>
      
      <!-- Content area with fixed sidebar and scrollable timeline -->
      <div class="gantt-content-container">
        <!-- Left side (fixed sidebar with task details) -->
        <div class="gantt-sidebar" :style="{ width: sidebarWidth + 'px' }">
          <div class="task-list" ref="taskList">
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
              draggable="true"
              :class="{ 'dragging': draggedTaskId === task.id }"
              :data-task-id="task.id"
              :data-gantt-order="task.gantt_order"
            />
          </div>
          <!-- Drop placeholder that appears during drag operation -->
          <div 
            v-if="isDragging" 
            :class="['gantt-drop-placeholder', {'active': isDraggedOver}]"
            :style="{ top: dropIndicatorPosition + 'px' }"
          ></div>
        </div>
        
        <!-- Slider for resizing -->
        <div class="gantt-slider" 
             @mousedown="startSliderDrag"
             :class="{ 'dragging': isDraggingSlider }">
          <div class="slider-handle">⋮⋮</div>
        </div>
        
        <!-- Right side scrollable wrapper -->
        <div class="gantt-timeline-wrapper" @scroll="handleTimelineScroll" ref="timelineWrapper">
          <!-- Gantt bars (timeline) -->
          <div class="gantt-timeline" ref="timeline">
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
    </div>
    
    <!-- Debug Modal: Task Order After Drop -->
    <div v-if="showDebugModal" class="debug-modal-overlay">
      <div class="debug-modal">
        <div class="debug-modal-header">
          <h3>Task Order After Drop</h3>
          <button @click="closeDebugModal">×</button>
        </div>
        <div class="debug-modal-content">
          <div class="debug-section">
            <h4>Drop Operation Details</h4>
            <p><strong>Dragged Task ID:</strong> {{ lastDraggedTaskId }}</p>
            <p><strong>Original Position:</strong> {{ lastDragOriginalPosition }}</p>
            <p><strong>Drop Position:</strong> {{ lastDropPosition }} (Client-side)</p>
            <p><strong>Adjusted Position:</strong> {{ lastDropPosition + 1 }} (for backend)</p>
          </div>
          <div class="debug-section">
            <h4>Task List Before Server Update</h4>
            <div class="task-list-preview">
              <div v-for="(task, index) in debugTasks" :key="task.id" 
                  :class="['task-item-preview', {
                    'original-position': task.id === lastDraggedTaskId && index === lastDragOriginalPosition,
                    'new-position': task.id === lastDraggedTaskId && index === lastDropPosition,
                    'dragged-task': task.id === lastDraggedTaskId
                  }]">
                <span class="task-index">{{ index }}</span>
                <span class="task-id">[ID: {{ task.id }}]</span>
                <span class="task-name">{{ task.name }}</span>
                <span class="task-order">(Order: {{ task.gantt_order }})</span>
              </div>
            </div>
          </div>
          <div class="debug-section">
            <h4>Task List After Server Update</h4>
            <div class="task-list-preview">
              <div v-for="(task, index) in tasks" :key="task.id + '-server'" 
                  :class="['task-item-preview', {
                    'dragged-task': task.id === lastDraggedTaskId
                  }]">
                <span class="task-index">{{ index }}</span>
                <span class="task-id">[ID: {{ task.id }}]</span>
                <span class="task-name">{{ task.name }}</span>
                <span class="task-order">(Order: {{ task.gantt_order }})</span>
              </div>
            </div>
          </div>
        </div>
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
    },
    projectId: {
      type: Number,
      default: null
    }
  },
  data() {
    return {
      // Date range
      startDate: new Date(2025, 2, 1),
      endDate: new Date(2025, 3, 15),
      zoomLevel: 1,
      timelineMode: 'day', // Can be 'day', 'week', or 'month'
      
      // Timeline mode breakpoints for zoom levels
      zoomBreakpoints: {
        day: 0.7,   // Show days when zoom level is >= 0.7
        week: 0.35,  // Show weeks when zoom level is >= 0.35 but < 0.7
        month: 0     // Show months when zoom level is < 0.35
      },
      
      // Active connection state
      activeConnection: null,
      hoveredTaskId: null,
      hoveredConnectionType: null,
      connectionFrom: null, // Start point coordinates
      connectionTo: null,   // Current mouse coordinates
      
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
      sidebarWidth: 250, // Will be calculated in adjustSidebarWidth
      minSidebarWidth: 200,
      maxSidebarWidth: 900,
      isDraggingSlider: false,
      startDragX: 0,
      startDragWidth: 0,
      
      // Date input control width
      dateInputWidth: 105,
      
      // Pentagon shape width for summary tasks
      pentagonWidth: 20,
      pentagonHeight: 65,
      
      // Column options menu position
      columnOptionsMenuPosition: {
        top: 0,
        left: 0
      },
      
      // Task drag and drop state
      isDragging: false,
      isDraggedOver: false,
      draggedTaskId: null,
      dropIndicatorPosition: 0,
      currentProjectId: null,
      
      // Debug modal for task order
      showDebugModal: false,
      debugTasks: [],
      lastDraggedTaskId: null,
      lastDragOriginalPosition: -1,
      lastDropPosition: -1
    }
  },
  mounted() {
    // Initialize the pentagon width
    this.updatePentagonWidth();
    
    // Set initial sidebar width based on visible columns
    this.adjustSidebarWidth();
    
    // Ensure we have a project ID by collecting it from all possible sources
    this.ensureProjectId();
    
    // Add window resize event listener
    window.addEventListener('resize', this.handleResize);
    
    // Initialize scrolling sync between header and timeline
    // Set a small timeout to ensure DOM is fully rendered
    setTimeout(() => {
      // Force initial sync if needed
      if (this.$refs.timelineWrapper && this.$refs.timelineHeaderWrapper) {
        this.$refs.timelineHeaderWrapper.scrollLeft = this.$refs.timelineWrapper.scrollLeft;
      }
    }, 100);
    
    // Enable task reordering via drag and drop
    this.setupTaskReordering();
  },
  
  beforeDestroy() {
    // Remove window resize event listener
    window.removeEventListener('resize', this.handleResize);
    
    // Remove global click handler if active
    document.removeEventListener('click', this.handleOutsideClick);
    
    // Remove drag and drop event listeners
    if (this.$refs.taskList) {
      this.$refs.taskList.removeEventListener('dragstart', this.onDragStart);
      this.$refs.taskList.removeEventListener('dragover', this.onDragOver);
      this.$refs.taskList.removeEventListener('drop', this.onDrop);
      this.$refs.taskList.removeEventListener('dragleave', this.onDragLeave);
    }
    
    // Clean up custom style element to prevent it from persisting
    const styleEl = document.getElementById('gantt-custom-styles');
    if (styleEl) {
      styleEl.parentNode.removeChild(styleEl);
    }
  },
  watch: {
    // Watch for zoom level changes to update the timeline mode
    zoomLevel: {
      immediate: true, // Run on component creation
      handler(newZoomLevel) {
        // Set timeline mode based on zoom breakpoints
        if (newZoomLevel >= this.zoomBreakpoints.day) {
          this.timelineMode = 'day';
        } else if (newZoomLevel >= this.zoomBreakpoints.week) {
          this.timelineMode = 'week';
        } else {
          this.timelineMode = 'month';
        }
        console.log(`Zoom level: ${newZoomLevel}, Timeline mode: ${this.timelineMode}`);
      }
    },
    // Watch for visibility changes to update sidebar width
    visibleColumns: {
      deep: true, // Watch for nested property changes
      handler() {
        this.adjustSidebarWidth();
      }
    },
    // Watch for task changes to update draggable elements
    tasks: {
      deep: true,
      handler() {
        console.log("Tasks changed, updating draggable elements");
        this.makeTaskItemsDraggable();
      }
    }
  },
  computed: {
    columnOptionsMenuStyle() {
      return {
        top: `${this.columnOptionsMenuPosition.top}px`,
        left: `${this.columnOptionsMenuPosition.left}px`
      };
    },
    
    connectionPath() {
      // If we don't have both connection points, return an empty path
      if (!this.connectionFrom || !this.connectionTo) return '';
      
      const startX = this.connectionFrom.x;
      const startY = this.connectionFrom.y;
      const endX = this.connectionTo.x;
      const endY = this.connectionTo.y;
      
      // Create a bezier curve path for smoother appearance
      return `M ${startX} ${startY} C ${(startX + endX) / 2} ${startY}, ${(startX + endX) / 2} ${endY}, ${endX} ${endY}`;
    },
    
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
        // Increase zoom level with smaller steps when at lower values for finer control
        const increment = this.zoomLevel < 1 ? 0.2 : 0.5;
        this.zoomLevel = Math.min(3, this.zoomLevel + increment);
        
        // Round to 2 decimal places for consistency
        this.zoomLevel = Math.round(this.zoomLevel * 100) / 100;
      }
    },
    
    zoomOut() {
      if (this.zoomLevel > 0.2) {
        // Decrease zoom level with smaller steps when at lower values
        const decrement = this.zoomLevel <= 1 ? 0.2 : 0.5;
        this.zoomLevel = Math.max(0.2, this.zoomLevel - decrement);
        
        // Round to 2 decimal places for consistency
        this.zoomLevel = Math.round(this.zoomLevel * 100) / 100;
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
      console.log('Connection start:', taskId, connectionType);
      
      this.activeConnection = {
        fromTaskId: taskId,
        fromType: connectionType
      }
      
      // Find the source task bar element to get its connection point coordinates
      const sourceTaskBar = this.$refs[`taskBar_${taskId}`];
      if (sourceTaskBar && sourceTaskBar[0]) {
        const taskBarEl = sourceTaskBar[0].$el;
        const rect = taskBarEl.getBoundingClientRect();
        
        // Determine the starting connection point
        if (connectionType === 'start') {
          this.connectionFrom = {
            x: rect.left,
            y: rect.top + rect.height / 2
          };
        } else { // 'end'
          this.connectionFrom = {
            x: rect.right,
            y: rect.top + rect.height / 2
          };
        }
        
        // Initialize the end point at the same place (will be updated by mouse move)
        this.connectionTo = { ...this.connectionFrom };
      }
      
      // Add a class to the body to indicate connection creation mode
      document.body.classList.add('is-connecting');
      
      // Add event listener to handle hover detection and mouse movement
      document.addEventListener('mousemove', this.onConnectionMouseMove)
    },
    
    onConnectionMouseMove(e) {
      if (!this.activeConnection) return
      
      // Update the end point of the connection line to follow the mouse
      this.connectionTo = {
        x: e.clientX,
        y: e.clientY
      };
      
      // Check if we're hovering over a task connection point
      let newHoveredTaskId = null;
      let newHoveredConnectionType = null;
      
      // Reset all task connection points active state
      this.flattenedTasks.forEach(task => {
        const taskBarRef = this.$refs[`taskBar_${task.id}`]
        if (taskBarRef && taskBarRef[0]) {
          taskBarRef[0].setConnectionPointActive(false, null)
        }
      })
      
      console.log('Checking for connection points under cursor');
      
      // Get the element under the cursor
      const elementsUnderCursor = document.elementsFromPoint(e.clientX, e.clientY)
      
      // Check elements under cursor
      
      // Check if any of those elements is a connection point
      for (const element of elementsUnderCursor) {
        if (element.classList.contains('connection-point')) {
          // Find the task bar containing this connection point
          let taskBarElement = element.closest('.task-bar')
          if (taskBarElement) {
            // Extract task ID from the data attribute
            const taskId = parseInt(taskBarElement.getAttribute('data-task-id'))
            
            if (taskId && taskId !== this.activeConnection.fromTaskId) {
              // Set the hoveredTaskId to the current task we're over
              newHoveredTaskId = taskId;
              
              // Determine which connection point type is under the cursor
              let connectionPointType = null;
              
              if (element.classList.contains('connection-point-start')) {
                connectionPointType = 'start';
              } else if (element.classList.contains('connection-point-end')) {
                connectionPointType = 'end';
              }
              newHoveredConnectionType = connectionPointType;
              
              // Only proceed if we found a valid connection point type
              if (connectionPointType) {
                console.log(`Hovering over ${connectionPointType} connection point of task ${taskId}`);
                
                // Highlight the connection point
                const taskBarRef = this.$refs[`taskBar_${taskId}`]
                if (taskBarRef && taskBarRef[0]) {
                  taskBarRef[0].setConnectionPointActive(true, connectionPointType);
                  // Force update to ensure UI reflects the change
                  this.$forceUpdate();
                }
              }
              
              break;
            }
          }
        }
      }
      
      // Finally, update the hoveredTaskId with our new value
      if (newHoveredTaskId !== this.hoveredTaskId) {
        console.log('Updating hoveredTaskId from', this.hoveredTaskId, 'to', newHoveredTaskId);
        this.hoveredTaskId = newHoveredTaskId;
      }
      
      // Also track the connection type we're over
      if (this.hoveredTaskId && newHoveredConnectionType) {
        console.log('Tracking connection point type:', newHoveredConnectionType);
        this.hoveredConnectionType = newHoveredConnectionType;
      } else {
        this.hoveredConnectionType = null;
      }
    },
    
    onConnectionEnd({ fromTaskId, fromType, mouseX, mouseY }) {
      console.log('onConnectionEnd called with:', { fromTaskId, fromType, mouseX, mouseY });
      console.log('Current state:', { 
        activeConnection: this.activeConnection,
        hoveredTaskId: this.hoveredTaskId 
      });
      
      if (!this.activeConnection) {
        console.log('No active connection, returning early');
        return;
      }
      
      document.removeEventListener('mousemove', this.onConnectionMouseMove);
      
      // CRITICAL FIX: If we're releasing over a connection point but hoveredTaskId 
      // hasn't been set, try to find it manually
      if (!this.hoveredTaskId) {
        console.log('DEBUG: No hoveredTaskId, searching manually');
        const elementsUnderCursor = document.elementsFromPoint(mouseX, mouseY);
        
        for (const element of elementsUnderCursor) {
          if (element.classList.contains('connection-point')) {
            
            // Find the task bar containing this connection point
            let taskBarElement = element.closest('.task-bar');
            
            if (taskBarElement) {
              // Extract task ID from the data attribute
              const taskId = parseInt(taskBarElement.getAttribute('data-task-id'));
              
              if (taskId && taskId !== fromTaskId) {
                console.log('Found target task manually:', taskId);
                this.hoveredTaskId = taskId;
                
                // Also set the connection type
                if (element.classList.contains('connection-point-start')) {
                  this.hoveredConnectionType = 'start';
                } else if (element.classList.contains('connection-point-end')) {
                  this.hoveredConnectionType = 'end';
                } else {
                  this.hoveredConnectionType = 'start';
                }
                
                break;
              }
            }
          }
        }
      }
      
      // Check if we ended on a valid connection point
      if (this.hoveredTaskId) {
        // If hoveredConnectionType is missing, default to 'start'
        const toType = this.hoveredConnectionType || 'start';
        
        console.log(`Creating dependency from task ${fromTaskId} (${fromType}) to task ${this.hoveredTaskId} (${toType})`);
        
        // Add the new dependency
        this.addDependency(fromTaskId, this.hoveredTaskId, fromType, toType);
          
        // Provide visual feedback
        const targetTaskBar = this.$refs[`taskBar_${this.hoveredTaskId}`];
        if (targetTaskBar && targetTaskBar[0]) {
          // Briefly flash the connection point
          targetTaskBar[0].setConnectionPointActive(true, toType);
          setTimeout(() => {
            if (targetTaskBar && targetTaskBar[0]) {
              targetTaskBar[0].setConnectionPointActive(false, null);
            }
          }, 300);
        }
      }
      
      // Reset all connection state
      this.activeConnection = null;
      this.hoveredTaskId = null;
      this.hoveredConnectionType = null;
      this.connectionFrom = null;
      this.connectionTo = null;
      
      // Remove the connection mode class from the body
      document.body.classList.remove('is-connecting');
      
      // Reset all task connection points active state
      this.flattenedTasks.forEach(task => {
        const taskBarRef = this.$refs[`taskBar_${task.id}`]
        if (taskBarRef && taskBarRef[0]) {
          taskBarRef[0].setConnectionPointActive(false, null)
        }
      })
    },
    
    addDependency(fromTaskId, toTaskId, fromType, toType) {
      console.log('GanttChart.addDependency called with:', { fromTaskId, toTaskId, fromType, toType });
      
      // Ensure types are parsed to integers
      fromTaskId = parseInt(fromTaskId);
      toTaskId = parseInt(toTaskId);
      
      console.log('Current dependencies:', this.dependencies);
      
      // Check if this dependency already exists
      const existingDep = this.dependencies.find(
        dep => dep.from === fromTaskId && dep.to === toTaskId
      );
      
      console.log('Existing dependency check:', existingDep ? 'Found' : 'Not found');
      
      if (!existingDep) {
        // Create a direct copy to ensure proper reference update
        const newDependency = {
          from: fromTaskId,
          to: toTaskId,
          fromType,
          toType
        };
        
        console.log('New dependency object:', newDependency);
        
        // Create a fresh copy of dependencies and add the new one
        const updatedDependencies = JSON.parse(JSON.stringify(this.dependencies));
        updatedDependencies.push(newDependency);
        
        console.log('Emitting update:dependency event with:', updatedDependencies);
        
        // Emit the updated dependencies array - this will trigger App.vue's updateDependency method
        this.$emit('update:dependency', updatedDependencies);
        
        // Force refresh of dependency lines
        this.$nextTick(() => {
          // Any components that need to redraw will do so on the next tick
          console.log("Added dependency:", newDependency);
        });
      } else {
        console.log('Dependency already exists, not adding.');
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
    
    // Toggle column options menu visibility with proper positioning
    toggleColumnOptionsMenu() {
      if (!this.showColumnOptions) {
        // If opening the menu, calculate its position
        if (this.$refs.columnOptionsButton) {
          const buttonRect = this.$refs.columnOptionsButton.getBoundingClientRect();
          this.columnOptionsMenuPosition = {
            top: buttonRect.bottom + 5,
            left: buttonRect.left
          };
        }
      }
      
      // Toggle menu visibility
      this.showColumnOptions = !this.showColumnOptions;
      
      // Add a global click handler when menu is shown
      if (this.showColumnOptions) {
        setTimeout(() => {
          document.addEventListener('click', this.handleOutsideClick);
        }, 10);
      }
    },
    
    // Handle clicks outside the menu to close it
    handleOutsideClick(event) {
      // If clicking outside the menu and not on the toggle button, close the menu
      if (this.showColumnOptions && 
          !event.target.closest('.column-options-menu') && 
          !event.target.closest('.column-options-button')) {
        this.showColumnOptions = false;
        document.removeEventListener('click', this.handleOutsideClick);
      }
    },
    
    // Column visibility
    toggleColumnVisibility(columnName) {
      // Toggle the visibility of the specified column
      this.visibleColumns[columnName] = !this.visibleColumns[columnName];
      
      // Adjust sidebar width based on visible columns
      this.adjustSidebarWidth();
    },
    
    // Dynamically adjust sidebar width based on visible columns
    adjustSidebarWidth() {
      // Base width for task name column
      let newWidth = 250; // Starting width for task name
      
      // Add width for each visible column
      if (this.visibleColumns.startDate) newWidth += 120;
      if (this.visibleColumns.endDate) newWidth += 120;
      if (this.visibleColumns.progress) newWidth += 80;
      if (this.visibleColumns.resources) newWidth += 120;
      
      // Add width for controls/padding
      newWidth += 40;
      
      // Enforce min and max constraints
      newWidth = Math.max(this.minSidebarWidth, Math.min(this.maxSidebarWidth, newWidth));
      
      // Update the sidebar width
      this.sidebarWidth = newWidth;
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
    
    // Handle content scrolling with synchronized vertical scroll
    handleTimelineScroll(event) {
      // Synchronize the timeline header scroll with the timeline content scroll
      if (this.$refs.timelineHeaderWrapper) {
        this.$refs.timelineHeaderWrapper.scrollLeft = event.target.scrollLeft;
      }
    },
    
    // Handle window resize
    handleResize() {
      // Adjust heights or widths if needed when window resizes
      if (this.$refs.ganttApp) {
        // Any resize adjustments can be done here
      }
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
    },
    
    // Debug modal methods
    prepareDebugTasks(taskId, newPosition) {
      console.log("Preparing debug tasks for modal");
      
      // Create a deep copy of the tasks array for the initial state
      const initialTasks = JSON.parse(JSON.stringify(this.tasks));
      
      // Log the initial state of tasks
      console.log("Initial task order before reordering:", 
        initialTasks.map((t, idx) => ({
          id: t.id, 
          name: t.name, 
          order: t.gantt_order,
          idx: idx
        }))
      );
      
      // Create a deep copy of the tasks array for reordering
      const tasksToReorder = JSON.parse(JSON.stringify(this.tasks));
      
      // Find the task's current position
      const taskIndex = tasksToReorder.findIndex(t => t.id === taskId);
      if (taskIndex === -1) {
        console.error("Task not found in tasks array:", taskId);
        return;
      }
      
      console.log(`Task ${taskId} found at index ${taskIndex} with order ${tasksToReorder[taskIndex].gantt_order}`);
      console.log(`Moving to new position ${newPosition}`);
      
      // Remove the task from its current position
      const [removedTask] = tasksToReorder.splice(taskIndex, 1);
      
      // Insert the task at the new position
      tasksToReorder.splice(newPosition, 0, removedTask);
      
      // Log the state after reordering but before updating gantt_order
      console.log("Task order after reordering but before updating gantt_order:", 
        tasksToReorder.map((t, idx) => ({
          id: t.id, 
          name: t.name, 
          order: t.gantt_order,
          idx: idx
        }))
      );
      
      // Update the gantt_order property on all tasks
      tasksToReorder.forEach((task, index) => {
        const newOrder = index + 1; // Store as 1-based
        console.log(`Setting task ${task.id} gantt_order from ${task.gantt_order} to ${newOrder}`);
        task.gantt_order = newOrder;
      });
      
      // Log the final expected state
      console.log("Final expected task order after reordering:", 
        tasksToReorder.map((t, idx) => ({
          id: t.id, 
          name: t.name, 
          order: t.gantt_order,
          idx: idx
        }))
      );
      
      // Store the reordered tasks for the debug modal
      this.debugTasks = tasksToReorder;
    },
    
    // Handle closing the debug modal and updating the UI
    closeDebugModal() {
      // Before closing, log the difference between client and server states
      const clientTaskOrder = this.debugTasks.map(t => ({ id: t.id, name: t.name, order: t.gantt_order }));
      const serverTaskOrder = this.tasks.map(t => ({ id: t.id, name: t.name, order: t.gantt_order }));
      
      console.log('=== COMPARING CLIENT VS SERVER STATES ===');
      console.log('Client-side task order:', clientTaskOrder);
      console.log('Server-side task order:', serverTaskOrder);
      
      // Find the dragged task position in each list
      const clientDraggedIndex = this.debugTasks.findIndex(t => t.id === this.lastDraggedTaskId);
      const serverDraggedIndex = this.tasks.findIndex(t => t.id === this.lastDraggedTaskId);
      
      if (clientDraggedIndex !== -1 && serverDraggedIndex !== -1) {
        console.log(`Dragged task ${this.lastDraggedTaskId} position: client=${clientDraggedIndex}, server=${serverDraggedIndex}`);
        console.log(`Position difference: ${serverDraggedIndex - clientDraggedIndex} (positive means server placed it lower)`);
      }
      
      // Close the modal
      this.showDebugModal = false;
      
      // No need to update from debug tasks since we have server response
      console.log('Keeping server-provided task order as the source of truth.');
      
      // Force a re-render to ensure the UI is up-to-date
      this.$forceUpdate();
    },
    
    // Task vertical reordering functionality
    setupTaskReordering() {
      if (!this.$refs.taskList) return;
      
      // Ensure we have a project ID if it wasn't already set
      if (!this.currentProjectId) {
        this.ensureProjectId();
        
        // If we still don't have a project ID, log a warning
        if (!this.currentProjectId) {
          console.warn("WARNING: No project ID available after setupTaskReordering - drag and drop may not work correctly");
        }
      }
      
      // Use event delegation for drag events
      const taskList = this.$refs.taskList;
      
      // Setup with appropriate event listeners and delegation
      taskList.addEventListener('dragstart', this.onDragStart, false);
      taskList.addEventListener('dragover', this.onDragOver, false);
      taskList.addEventListener('drop', this.onDrop, false);
      taskList.addEventListener('dragleave', this.onDragLeave, false);
      
      // Make all task items draggable
      this.makeTaskItemsDraggable();
      
      // Add dragend listener to the document to handle case when dragged outside
      document.addEventListener('dragend', this.onDragEnd, false);
    },
    
    // Make all task items draggable - call this whenever tasks change
    makeTaskItemsDraggable() {
      setTimeout(() => {
        // Set draggable attribute on all task items
        const taskItems = this.$refs.taskList?.querySelectorAll('.task-item');
        if (!taskItems) return;
        
        taskItems.forEach(item => {
          item.setAttribute('draggable', 'true');
          
          // Make the drag handle the key element for drag initiation
          const dragHandle = item.querySelector('.drag-handle');
          if (dragHandle) {
            dragHandle.addEventListener('mousedown', () => {
              item.draggable = true;
            }, false);
          }
        });
        
        console.log(`Made ${taskItems.length} task items draggable`);
      }, 100); // Small delay to ensure DOM is ready
    },
    
    onDragStart(event) {
      // Get the task element being dragged
      let taskElement = event.target.closest('[data-task-id]');
      if (!taskElement) return;
      
      // Get task ID from the data attribute
      const taskId = parseInt(taskElement.getAttribute('data-task-id'));
      if (!taskId) return;
      
      // Store the dragged task ID
      this.draggedTaskId = taskId;
      this.isDragging = true;
      
      // Set data transfer for the drag operation
      event.dataTransfer.effectAllowed = 'move';
      event.dataTransfer.setData('text/plain', taskId);
      
      // Add a class to the dragged element for styling
      taskElement.classList.add('dragging');
      
      // Delay to make sure the dragover events work correctly
      setTimeout(() => {
        if (this.$refs.taskList) {
          this.$refs.taskList.classList.add('dragging-active');
        }
      }, 50);
    },
    
    onDragOver(event) {
      event.preventDefault();
      
      // Only handle if we have a dragged task
      if (!this.isDragging || !this.draggedTaskId) return;
      
      // Change the cursor to indicate a drop is allowed
      event.dataTransfer.dropEffect = 'move';
      
      // Get the task list container
      const taskList = this.$refs.taskList;
      if (!taskList) return;
      
      // Get the position of the cursor
      const taskListRect = taskList.getBoundingClientRect();
      const mouseY = event.clientY;
      
      // Create an array of all task elements
      const allTaskElements = Array.from(taskList.querySelectorAll('.task-item'));
      
      // Skip the dragged task
      const otherTaskElements = allTaskElements.filter(el => {
        return parseInt(el.getAttribute('data-task-id')) !== this.draggedTaskId;
      });
      
      // Find the task element we're hovering over
      let targetElement = null;
      let insertAtEnd = true;
      
      for (let i = 0; i < otherTaskElements.length; i++) {
        const el = otherTaskElements[i];
        const rect = el.getBoundingClientRect();
        const elementMiddle = rect.top + (rect.height / 2);
        
        if (mouseY < elementMiddle) {
          // If mouse is above the middle of this element, show indicator above it
          targetElement = el;
          insertAtEnd = false;
          this.dropIndicatorPosition = rect.top - taskListRect.top;
          console.log(`Indicator above element ${i} at position ${this.dropIndicatorPosition}px`);
          break;
        }
      }
      
      // If we're not over any task or below the middle of the last element
      if (insertAtEnd) {
        if (otherTaskElements.length > 0) {
          const lastElement = otherTaskElements[otherTaskElements.length - 1];
          const rect = lastElement.getBoundingClientRect();
          this.dropIndicatorPosition = rect.bottom - taskListRect.top;
          console.log(`Indicator at bottom of list at position ${this.dropIndicatorPosition}px`);
        } else {
          // Empty list
          this.dropIndicatorPosition = 0;
          console.log(`Indicator in empty list at position 0px`);
        }
      }
      
      // Show the drop indicator
      this.isDraggedOver = true;
    },
    
    onDragLeave(event) {
      // Check if we're leaving the task list
      const taskList = this.$refs.taskList;
      if (!taskList) return;
      
      // Only consider it a leave if we're not moving into a child element
      if (!taskList.contains(event.relatedTarget)) {
        this.isDraggedOver = false;
      }
    },
    
    onDragEnd(event) {
      // Reset all drag state
      this.isDragging = false;
      this.isDraggedOver = false;
      
      // Cache task ID before clearing it
      const taskId = this.draggedTaskId;
      this.draggedTaskId = null;
      
      // Remove classes
      if (this.$refs.taskList) {
        this.$refs.taskList.classList.remove('dragging-active');
      }
      
      // Remove dragging class from all task elements
      document.querySelectorAll('.dragging').forEach(el => {
        el.classList.remove('dragging');
      });
      
      // If drag ended outside a valid drop area, restore original position
      if (taskId && event && !event.target.closest('.task-list')) {
        // Make tasks draggable again (will restore original order)
        this.makeTaskItemsDraggable();
      }
    },
    
    onDrop(event) {
      event.preventDefault();
      
      // Only process if we have a drag operation in progress
      if (!this.isDragging || !this.draggedTaskId) {
        this.onDragEnd();
        return;
      }
      
      console.log("Processing drop for task ID:", this.draggedTaskId);
      
      // Get all visible task elements and determine position based on vertical mouse position
      const taskList = this.$refs.taskList;
      if (!taskList) return;
      
      const draggedTaskId = this.draggedTaskId;
      let newPosition = -1;
      
      // Create an array of all task elements in their current DOM order
      const allTaskElements = Array.from(taskList.querySelectorAll('.task-item'));
      
      // Get the dragged element and its original position
      const draggedElement = allTaskElements.find(el => parseInt(el.getAttribute('data-task-id')) === draggedTaskId);
      const originalIndex = allTaskElements.indexOf(draggedElement);
      
      // Get task elements excluding the dragged one
      const taskElements = allTaskElements.filter(el => parseInt(el.getAttribute('data-task-id')) !== draggedTaskId);
      
      console.log(`Found ${taskElements.length} task elements (excluding dragged task)`);
      console.log(`Dragged task original position: ${originalIndex}`);
      
      // Get the Y coordinate of the mouse relative to the viewport
      const mouseY = event.clientY;
      
      // Find the position where the cursor is relative to other task elements
      let insertAtEnd = true;
      
      for (let i = 0; i < taskElements.length; i++) {
        const element = taskElements[i];
        const rect = element.getBoundingClientRect();
        const elementMiddle = rect.top + (rect.height / 2);
        
        if (mouseY < elementMiddle) {
          // If mouse is above the middle of this element, insert before it
          newPosition = i;
          insertAtEnd = false;
          console.log(`Mouse (${mouseY}) is above middle of element ${i} (middle: ${elementMiddle}), inserting at position ${i}`);
          break;
        }
      }
      
      // If we didn't find a position or if we're below the middle of the last element, insert at the end
      if (insertAtEnd) {
        newPosition = taskElements.length;
        console.log(`Mouse is positioned for insertion at the end: position ${newPosition}`);
      }
      
      // Store task ID before resetting drag state
      const taskId = this.draggedTaskId;
      
      // For debugging (though modal is hidden)
      this.lastDraggedTaskId = taskId;
      this.lastDragOriginalPosition = originalIndex;
      this.lastDropPosition = newPosition;
      
      // Reset drag state
      this.onDragEnd();
      
      // Deep copy of tasks for debug modal
      this.prepareDebugTasks(taskId, newPosition);
      
      // Check for special case where dragging down by 1 position
      // This is where we often see the "jumping" issue
      let clientPosition = newPosition;
      if (originalIndex < newPosition) {
        console.log("Dragging downward: original=" + originalIndex + ", new=" + newPosition);
        
        // In downward drags, the position is accurate for UI since the
        // element being dragged has already been removed from the DOM flow
      } else {
        console.log("Dragging upward or to same position: original=" + originalIndex + ", new=" + newPosition);
        // In upward drags, the position is correct (no adjustment needed)
      }
      
      console.log(`Adjusted position for optimistic update: ${clientPosition}`);
      
      // Apply optimistic update to UI using the client-side position
      this.updateLocalTaskOrder(taskId, clientPosition);
      
      // Show the debug modal
      this.showDebugModal = true;
      
      // Reorder task on the server - passing current position for debugging
      console.log(`Final determination: Reordering task ${taskId} to position ${newPosition} from original ${originalIndex}`);
      
      // Use the exact client position - the server will handle the indexing adjustments
      this.reorderTask(taskId, newPosition, originalIndex);
    },
    
    // Helper method to ensure we have a project ID from any available source
    ensureProjectId() {
      // First check props
      if (this.projectId) {
        this.currentProjectId = this.projectId;
        console.log(`Set currentProjectId from prop: ${this.currentProjectId}`);
        return;
      }
      
      // Check the DOM data attribute
      const appElement = document.getElementById('main-app');
      const dataProjectId = appElement?.dataset?.projectId;
      if (dataProjectId) {
        this.currentProjectId = parseInt(dataProjectId);
        console.log(`Set currentProjectId from DOM attribute: ${this.currentProjectId}`);
        return;
      }
      
      // Check window.initialData
      if (window.initialData && window.initialData.projects && window.initialData.projects.length > 0) {
        this.currentProjectId = window.initialData.projects[0].id;
        console.log(`Set currentProjectId from initialData: ${this.currentProjectId}`);
        return;
      }
      
      // Check tasks if available
      if (this.tasks && this.tasks.length > 0) {
        // Try to find a task with a project
        for (const task of this.tasks) {
          if (task.project?.id) {
            this.currentProjectId = task.project.id;
            console.log(`Set currentProjectId from task.project.id: ${this.currentProjectId}`);
            return;
          } else if (task.project_id) {
            this.currentProjectId = task.project_id;
            console.log(`Set currentProjectId from task.project_id: ${this.currentProjectId}`);
            return;
          }
        }
      }
      
      console.warn("Could not find a valid project ID from any source");
    },
    
    // Call the API to reorder the task
    reorderTask(taskId, newPosition, originalPosition) {
      // IMPORTANT DEBUG: Log the state at the start of the method
      console.log("==== TASK REORDERING DEBUG START ====");
      console.log(`currentProjectId: ${this.currentProjectId}`);
      console.log(`taskId: ${taskId}`);
      console.log(`newPosition: ${newPosition}`);
      console.log(`originalPosition: ${originalPosition}`);
      console.log(`tasks available: ${this.tasks.length}`);
      
      // If we don't have a project ID yet, try to find one again
      if (!this.currentProjectId) {
        // Find the specific task being dragged to get its project_id directly
        const taskBeingReordered = this.tasks.find(t => t.id === taskId);
        
        // Access nested project object if it exists
        let taskProjectId;
        if (taskBeingReordered) {
          // First try to access project.id if it exists
          if (taskBeingReordered.project && taskBeingReordered.project.id) {
            taskProjectId = taskBeingReordered.project.id;
            console.log(`Found project.id: ${taskProjectId} in task`);
          } 
          // Then try project_id property
          else if (taskBeingReordered.project_id) {
            taskProjectId = taskBeingReordered.project_id;
            console.log(`Found project_id: ${taskProjectId} in task`);
          }
        }
        
        // Check if the app element has a project ID data attribute
        const appElement = document.getElementById('main-app');
        const dataProjectId = appElement?.dataset?.projectId;
        if (dataProjectId) {
          console.log(`Found project ID in DOM data attribute: ${dataProjectId}`);
        }
        
        // Check if we have a project ID from various sources
        let projectIdToUse = this.currentProjectId || 
                            taskProjectId || 
                            dataProjectId || 
                            (window.initialData && window.initialData.projects?.[0]?.id);
        
        if (!projectIdToUse) {
          console.warn("No project ID found in primary sources, searching tasks...");
          
          // Last attempt - search through all tasks
          for (const task of this.tasks) {
            // Try all possible ways to get project ID
            if (task.project?.id) {
              projectIdToUse = task.project.id;
              console.log(`Found project.id from task: ${projectIdToUse}`);
              break;
            } else if (task.project_id) {
              projectIdToUse = task.project_id;
              console.log(`Found project_id from task: ${projectIdToUse}`);
              break;
            }
          }
        }
        
        // Set the currentProjectId for future use
        if (projectIdToUse && !this.currentProjectId) {
          this.currentProjectId = projectIdToUse;
          console.log(`Updated currentProjectId: ${this.currentProjectId}`);
        }
      }
      
      // Use the currentProjectId as our main project ID
      let projectIdToUse = this.currentProjectId;
      
      // Final check - abort if no project ID
      if (!projectIdToUse) {
        console.error("CRITICAL ERROR: No project ID found anywhere. Cannot reorder task.");
        return;
      }
      
      console.log(`FINAL: Reordering task ${taskId} to position ${newPosition} in project ${projectIdToUse}`);
      
      const url = '/api/v1/tasks/reorder_gantt';
      const data = {
        project_id: projectIdToUse,
        task_id: taskId,
        position: newPosition
      };
      
      // Get CSRF token from meta tag
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
      if (!csrfToken) {
        console.error("CSRF token not found! Cannot make API request.");
        return;
      }
      
      // Log the current tasks before making the API call
      console.log("Current tasks before API call:", this.tasks.map(t => ({
        id: t.id, 
        name: t.name,
        order: t.gantt_order,
        project_id: t.project_id
      })));
      
      // Debug: Log the actual data being sent
      console.log("Making API POST request to:", url);
      console.log("Request data:", JSON.stringify(data));
      console.log("Using CSRF token:", csrfToken.substring(0, 10) + '...');
      
      // Make the API call with proper CSRF protection
      console.log("Initiating fetch request...");
      fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken,
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'application/json'
        },
        body: JSON.stringify(data),
        credentials: 'same-origin' // Important for CSRF cookies
      })
      .then(response => {
        console.log(`Server response status: ${response.status} ${response.statusText}`);
        
        // Log the raw response headers
        const headers = {};
        response.headers.forEach((value, key) => {
          headers[key] = value;
        });
        console.log('Response headers:', headers);
        
        if (!response.ok) {
          console.error(`Server error: ${response.status} ${response.statusText}`);
          return response.text().then(text => {
            console.error(`Error response body: ${text}`);
            throw new Error(`Failed to reorder task: ${text}`);
          });
        }
        
        return response.text().then(text => {
          console.log('Raw response body:', text.substring(0, 200) + (text.length > 200 ? '...' : ''));
          try {
            return JSON.parse(text);
          } catch (e) {
            console.error('Failed to parse response as JSON:', e);
            throw new Error('Invalid JSON response from server');
          }
        });
      })
      .then(updatedTasks => {
        console.log('Tasks reordered successfully, received from server:', updatedTasks);
        console.log('Number of tasks received:', updatedTasks?.length || 0);
        
        if (!Array.isArray(updatedTasks)) {
          console.error('Server returned non-array response:', updatedTasks);
          return;
        }
        
        // Replace the tasks with the server response
        this.updateTasksFromServerResponse(updatedTasks);
        
        // Emit an event to update parent component's tasks
        this.$emit('tasks-reordered', updatedTasks);
        
        // Save the updated tasks to debugTasks so the dialog will show them correctly
        this.debugTasks = [...updatedTasks];
        
        // Force re-render of the component
        this.$forceUpdate();
        
        // Log the task state after update
        console.log("Tasks after server update:", this.tasks.map(t => ({
          id: t.id, 
          name: t.name, 
          order: t.gantt_order
        })));
      })
      .catch(error => {
        console.error('Error reordering tasks:', error);
        console.error('Stack trace:', error.stack);
        console.error('IMPORTANT: This error indicates the request failed.');
        
        // Revert the optimistic UI update
        this.fetchTasksFromServer();
      });
      
      // Final debug message to confirm we reached the end of the method
      console.log("==== TASK REORDERING DEBUG END ====");
    },
    
    // Fetch tasks from server to reset UI state if needed
    fetchTasksFromServer() {
      if (!this.currentProjectId) return;
      
      fetch(`/api/v1/tasks?project_id=${this.currentProjectId}&view=gantt`)
        .then(response => response.json())
        .then(tasks => {
          console.log('Fetched tasks from server to reset UI state:', tasks);
          this.updateTasksFromServerResponse(tasks);
          this.$emit('tasks-reordered', tasks);
        })
        .catch(error => {
          console.error('Error fetching tasks:', error);
        });
    },
    
    // Helper to update tasks from server response
    updateTasksFromServerResponse(serverTasks) {
      if (!Array.isArray(serverTasks) || serverTasks.length === 0) {
        console.warn('Received empty or invalid tasks array from server');
        return;
      }
      
      console.log('Updating tasks from server response:', serverTasks);
      
      // Log ordering of tasks before update
      console.log('Current tasks before server update:', this.tasks.map(t => ({
        id: t.id,
        name: t.name,
        gantt_order: t.gantt_order
      })));
      
      // Make sure server tasks are sorted by gantt_order
      const sortedServerTasks = [...serverTasks].sort((a, b) => {
        // Handle the case where tasks might not have gantt_order
        const orderA = a.gantt_order || 0;
        const orderB = b.gantt_order || 0;
        return orderA - orderB;
      });
      
      console.log('Server tasks sorted by gantt_order:', sortedServerTasks.map(t => ({
        id: t.id,
        name: t.name,
        gantt_order: t.gantt_order
      })));
      
      // Clear the current tasks array
      while (this.tasks.length > 0) {
        this.tasks.pop();
      }
      
      // Add the tasks from the server in the correct order
      sortedServerTasks.forEach(serverTask => {
        this.tasks.push(serverTask);
      });
      
      // Deep logging of the updated tasks
      console.log('Updated tasks array:', this.tasks.map(t => ({ 
        id: t.id, 
        name: t.name, 
        gantt_order: t.gantt_order 
      })));
      
      // Force re-render
      this.$forceUpdate();
      
      // Schedule a delayed check to make sure the tasks rendered properly
      setTimeout(() => {
        console.log('Delayed refresh, task list is now:', this.tasks);
      }, 100);
    },
    
    // Update the local task order immediately for smoother UX
    updateLocalTaskOrder(taskId, newPosition) {
      console.log(`Updating local task order: Task ${taskId} to position ${newPosition}`);
      
      const taskToMove = this.findTaskById(taskId);
      if (!taskToMove) {
        console.error("Task not found:", taskId);
        return;
      }
      
      // Create a completely new deep copy of the tasks array
      const tasksToReorder = JSON.parse(JSON.stringify(this.tasks));
      
      // Find the task's current position within the root tasks array
      const taskIndex = tasksToReorder.findIndex(t => t.id === taskId);
      if (taskIndex === -1) {
        console.error("Task not found in root tasks:", taskId);
        return;
      }
      
      console.log(`Found task at index ${taskIndex}, moving to index ${newPosition}`);
      
      // Remove the task from its current position
      const [removedTask] = tasksToReorder.splice(taskIndex, 1);
      
      // Insert the task at the new position
      tasksToReorder.splice(newPosition, 0, removedTask);
      
      // Log before updating gantt_order properties
      console.log("Task array after reordering but before gantt_order update:", 
        tasksToReorder.map((t, i) => ({ id: t.id, name: t.name, index: i }))
      );
      
      // Update the gantt_order property on all tasks 
      // Important: We're setting the visual order only - when the server responds,
      // it will assign the actual DB-compatible values
      tasksToReorder.forEach((task, index) => {
        const newOrder = index + 1; // Use 1-based indexing to match backend
        console.log(`Setting task ${task.id} (${task.name}) gantt_order to ${newOrder} (at visual position ${index})`);
        task.gantt_order = newOrder;
      });
      
      console.log("Tasks reordered locally, new order:", tasksToReorder.map(t => ({ id: t.id, name: t.name, order: t.gantt_order })));
      
      // Clear the tasks array and add all tasks back in the new order
      while (this.tasks.length > 0) {
        this.tasks.pop();
      }
      
      // Now push all tasks in their new order
      tasksToReorder.forEach(task => {
        this.tasks.push(task);
      });
      
      // Emit events to ensure parent components update
      this.$emit('update:tasks', tasksToReorder);
      this.$emit('tasks-reordered', tasksToReorder);
      
      // Force a render update to reflect the changes
      this.$forceUpdate();
      
      // Schedule another update to ensure UI is consistent
      setTimeout(() => {
        // Double check task order after the fact
        console.log("Verifying task order after 50ms:", this.tasks.map(t => ({ id: t.id, name: t.name, order: t.gantt_order })));
        this.$forceUpdate();
      }, 50);
    }
  }
}
</script>

<style>
.gantt-app {
  height: 100%;
  width: 100%;
  display: flex;
  flex-direction: column;
  overflow: hidden; /* No overflow at app level */
}

.gantt-container {
  display: flex;
  flex-direction: column;
  flex: 1;
  width: 100%;
  overflow: hidden;
}

/* Headers section - Fixed at the top with independent scrolling */
.gantt-headers-container {
  display: flex;
  width: 100%;
  z-index: 100;
  background-color: #f5f5f5;
  border-bottom: 1px solid #ddd;
  flex-shrink: 0; /* Do not allow shrinking */
  overflow: hidden; /* Hide overflow */
}

.gantt-sidebar-header {
  flex-shrink: 0;
  background-color: #f5f5f5;
  position: sticky;
  left: 0;
  z-index: 10; /* Ensure it stays above other content */
}

.gantt-slider-header {
  flex-shrink: 0;
  background-color: #f0f0f0;
}

.gantt-timeline-header-wrapper {
  flex: 1;
  overflow-x: scroll; /* Enable horizontal scrolling */
  overflow-y: hidden; /* Hide vertical scrolling */
  scrollbar-width: thin; /* For Firefox */
}

.gantt-timeline-header {
  flex: 1;
  min-width: max-content; /* Ensure it expands to fit all timeline content */
}

/* Content container with fixed sidebar and scrollable timeline */
.gantt-content-container {
  display: flex;
  flex: 1;
  width: 100%;
  overflow: hidden; /* Hide overflow at container level */
  position: relative;
  height: calc(100% - 36px); /* Subtract header height */
}

/* Timeline wrapper - scrollable area */
.gantt-timeline-wrapper {
  flex: 1;
  overflow: auto; /* Enable both scrolling directions */
  position: relative;
  height: 100%;
}

.gantt-sidebar {
  flex-shrink: 0;
  background-color: #fff;
  border-right: 1px solid #e1e4e8;
  transition: width 0.2s ease-in-out;
  height: fit-content;
  min-height: 100%;
}

.gantt-slider {
  width: 8px;
  flex-shrink: 0;
  background-color: #f0f0f0;
  cursor: col-resize;
  display: flex;
  align-items: center;
  justify-content: center;
  position: sticky;
  top: 0;
  align-self: stretch;
  z-index: 20;
  transition: background-color 0.2s;
  height: 100%;
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
  position: relative;
  background-color: #fff;
  min-height: 100%;
  height: fit-content;
  min-width: max-content; /* Ensure it expands to fit all content */
}

.task-header {
  padding: 8px;
  font-weight: bold;
}

.task-list {
  position: relative;
}

/* Task drag-and-drop styles */
.task-list.dragging-active {
  cursor: move;
}

[draggable="true"] {
  cursor: grab;
}

.task-item.dragging {
  opacity: 0.5;
  background-color: #f5f7fa;
  border: 1px dashed #ccc;
}

.gantt-drop-placeholder {
  position: absolute;
  left: 0;
  right: 0;
  height: 2px;
  background-color: transparent;
  z-index: 100;
  pointer-events: none;
  transition: background-color 0.2s, transform 0.2s, height 0.2s;
}

.gantt-drop-placeholder.active {
  background-color: #4a90e2;
  height: 4px;
  transform: scaleX(0.98);
  box-shadow: 0 0 5px rgba(0, 0, 0, 0.3);
  border-radius: 2px;
}

.table-header-row {
  display: flex;
  align-items: center;
  height: 36px;
  background-color: #f5f5f5;
  font-weight: bold;
  padding: 0 8px;
}

.table-cell {
  padding: 0 8px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  display: flex;
  align-items: center;
  position: relative;
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
  justify-content: center;
  position: relative;
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
  position: fixed; /* Change from absolute to fixed positioning */
  background-color: white;
  border: 1px solid #ccc;
  border-radius: 4px;
  box-shadow: 0 2px 5px rgba(0,0,0,0.3);
  z-index: 9999; /* Very high z-index to ensure it's on top */
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
  height: 100%;
}

/* Global connection SVG styles */
.global-connection-svg {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  pointer-events: none;
  z-index: 9000; /* Very high to ensure it's visible above everything */
  overflow: visible;
}

.global-connection-path {
  fill: none;
  stroke: #4a90e2;
  stroke-width: 3px;
  stroke-dasharray: 5 3;
  stroke-linecap: round;
}

/* Debug Modal Styles */
.debug-modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.6);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 10000;
}

.debug-modal {
  width: 80%;
  max-width: 800px;
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 2px 20px rgba(0, 0, 0, 0.2);
  display: flex;
  flex-direction: column;
  max-height: 80vh;
  overflow: hidden;
}

.debug-modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 15px 20px;
  background-color: #f5f5f5;
  border-bottom: 1px solid #ddd;
}

.debug-modal-header h3 {
  margin: 0;
  font-size: 18px;
  color: #333;
}

.debug-modal-header button {
  background: none;
  border: none;
  font-size: 20px;
  cursor: pointer;
  color: #666;
}

.debug-modal-content {
  padding: 20px;
  overflow-y: auto;
}

.debug-section {
  margin-bottom: 20px;
}

.debug-section h4 {
  margin: 0 0 10px 0;
  font-size: 16px;
  color: #555;
  border-bottom: 1px solid #eee;
  padding-bottom: 5px;
}

.task-list-preview {
  border: 1px solid #ddd;
  border-radius: 4px;
  overflow: hidden;
}

.task-item-preview {
  padding: 8px 12px;
  display: flex;
  align-items: center;
  border-bottom: 1px solid #eee;
  background-color: white;
}

.task-item-preview:last-child {
  border-bottom: none;
}

.task-item-preview.dragged-task {
  font-weight: bold;
}

.task-item-preview.original-position {
  background-color: #ffeeee;
}

.task-item-preview.new-position {
  background-color: #eeffee;
}

.task-index {
  display: inline-block;
  width: 30px;
  margin-right: 8px;
  font-weight: bold;
  color: #999;
}

.task-id {
  margin-right: 10px;
  color: #666;
  font-size: 12px;
  font-family: monospace;
}

.task-name {
  flex: 1;
}

.task-order {
  margin-left: 10px;
  color: #666;
  font-size: 12px;
}
</style>