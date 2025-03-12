<template>
  <div 
    class="task-bar" 
    :style="barStyle"
    :class="{ 'is-dragging': isDragging, 'summary-task-bar': isSummaryTask }"
    :data-task-id="task.id"
  >
    <div 
      class="task-bar-content"
      :class="{ 'summary-task': isSummaryTask }"
      :style="{ backgroundColor: getTaskColor() }"
      :title="task.description || task.name"
    >
      <div class="task-bar-progress" :style="{ width: `${task.progress}%` }"></div>
      <div class="task-bar-label">{{ task.name }}</div>
    </div>
    
    <!-- Resize and move handles - Only for leaf/detail tasks -->
    <div 
      v-if="!isSummaryTask" 
      class="task-handle task-handle-left"
      @mousedown="startResizeLeft"
    ></div>
    <div 
      v-if="!isSummaryTask"
      class="task-handle task-handle-right"
      @mousedown="startResizeRight"
    ></div>
    <div 
      v-if="!isSummaryTask"
      class="task-handle task-handle-move"
      @mousedown="startMove"
    ></div>
    
    <!-- Dependency connection points - only show on hover -->
    <div 
      class="connection-point connection-point-start"
      @mousedown="startConnection('start')"
      :class="{ 'active': isConnectionPointActive }"
      title="Start connection point"
    ></div>
    <div 
      class="connection-point connection-point-end"
      @mousedown="startConnection('end')"
      :class="{ 'active': isConnectionPointActive }"
      title="End connection point"
    ></div>

    <!-- Connection line while dragging -->
    <svg v-if="isConnecting" class="connection-line-container">
      <path :d="connectionPath" class="connection-line-path"></path>
    </svg>
  </div>
</template>

<script>
export default {
  name: 'TaskBar',
  props: {
    task: {
      type: Object,
      required: true
    },
    startDate: {
      type: Date,
      required: true
    },
    zoomLevel: {
      type: Number,
      default: 1
    }
  },
  data() {
    return {
      isDragging: false,
      dragType: null, // 'move', 'left', 'right'
      dragStartX: 0,
      dragStartY: 0,
      dragStartLeft: 0,
      dragStartWidth: 0,
      dragStartDate: null,
      dragEndDate: null,
      
      // Dependency connection properties
      isConnecting: false,
      connectionType: null, // 'start' or 'end'
      connectionPoint: { x: 0, y: 0 },
      currentMousePosition: { x: 0, y: 0 },
      isConnectionPointActive: false
    }
  },
  computed: {
    isSummaryTask() {
      // A task is a summary task if it has children
      return this.task.children && this.task.children.length > 0;
    },
    barStyle() {
      const dayWidth = 24 * this.zoomLevel;
      const taskStartDate = new Date(this.task.startDate);
      const taskEndDate = new Date(this.task.endDate);
      
      const daysDiff = Math.floor((taskStartDate - this.startDate) / (1000 * 60 * 60 * 24));
      const taskDuration = Math.ceil((taskEndDate - taskStartDate) / (1000 * 60 * 60 * 24)) + 1;
      
      const left = daysDiff * dayWidth;
      const width = taskDuration * dayWidth;
      
      // Use rowIndex for vertical positioning instead of level
      const rowIndex = typeof this.task.rowIndex === 'number' ? this.task.rowIndex : 0;
      
      // Summary tasks have different height and vertical positioning
      const height = this.isSummaryTask ? '20px' : '25px';
      const top = `${36 * rowIndex + (this.isSummaryTask ? 5 : 3)}px`; // Center tasks vertically
      
      return {
        left: `${left}px`,
        width: `${width}px`,
        top: top,
        height: height
      };
    },
    dayWidth() {
      return 24 * this.zoomLevel;
    },
    connectionPath() {
      if (!this.isConnecting) return '';
      
      // Calculate the path for the connection line
      const startX = this.connectionPoint.x;
      const startY = this.connectionPoint.y;
      const endX = this.currentMousePosition.x;
      const endY = this.currentMousePosition.y;
      
      // Create a bezier curve path for smoother appearance
      return `M ${startX} ${startY} C ${(startX + endX) / 2} ${startY}, ${(startX + endX) / 2} ${endY}, ${endX} ${endY}`;
    }
  },
  methods: {
    getTaskColor() {
      // Summary tasks use gray scale
      if (this.isSummaryTask) {
        // Use darker gray for higher progress
        if (this.task.progress === 100) return '#555555';
        if (this.task.progress > 60) return '#666666';
        if (this.task.progress > 30) return '#777777';
        return '#888888';
      } else {
        // Regular tasks use the color scale based on progress
        if (this.task.progress === 100) return '#4caf50';
        if (this.task.progress > 60) return '#8bc34a';
        if (this.task.progress > 30) return '#ffc107';
        return '#ff9800';
      }
    },
    startResizeLeft(e) {
      e.preventDefault();
      this.isDragging = true;
      this.dragType = 'left';
      this.dragStartX = e.clientX;
      this.dragStartLeft = parseInt(this.barStyle.left);
      this.dragStartWidth = parseInt(this.barStyle.width);
      this.dragStartDate = new Date(this.task.startDate);
      this.dragEndDate = new Date(this.task.endDate);
      
      document.addEventListener('mousemove', this.onDrag);
      document.addEventListener('mouseup', this.stopDrag);
    },
    startResizeRight(e) {
      e.preventDefault();
      this.isDragging = true;
      this.dragType = 'right';
      this.dragStartX = e.clientX;
      this.dragStartWidth = parseInt(this.barStyle.width);
      this.dragStartDate = new Date(this.task.startDate);
      this.dragEndDate = new Date(this.task.endDate);
      
      document.addEventListener('mousemove', this.onDrag);
      document.addEventListener('mouseup', this.stopDrag);
    },
    startMove(e) {
      e.preventDefault();
      this.isDragging = true;
      this.dragType = 'move';
      this.dragStartX = e.clientX;
      this.dragStartLeft = parseInt(this.barStyle.left);
      this.dragStartDate = new Date(this.task.startDate);
      this.dragEndDate = new Date(this.task.endDate);
      
      document.addEventListener('mousemove', this.onDrag);
      document.addEventListener('mouseup', this.stopDrag);
    },
    onDrag(e) {
      if (!this.isDragging) return;
      
      const diff = e.clientX - this.dragStartX;
      const daysDiff = Math.round(diff / this.dayWidth);
      
      if (this.dragType === 'left') {
        // Resize from left (change start date)
        const newStartDate = new Date(this.dragStartDate);
        newStartDate.setDate(newStartDate.getDate() + daysDiff);
        
        // Don't allow start date to be after end date
        if (newStartDate < this.dragEndDate) {
          this.$emit('update', this.task.id, newStartDate, this.task.endDate);
        }
      } else if (this.dragType === 'right') {
        // Resize from right (change end date)
        const newEndDate = new Date(this.dragEndDate);
        newEndDate.setDate(newEndDate.getDate() + daysDiff);
        
        // Don't allow end date to be before start date
        if (newEndDate > this.dragStartDate) {
          this.$emit('update', this.task.id, this.task.startDate, newEndDate);
        }
      } else if (this.dragType === 'move') {
        // Move the entire task (change both start and end date)
        const newStartDate = new Date(this.dragStartDate);
        newStartDate.setDate(newStartDate.getDate() + daysDiff);
        
        const newEndDate = new Date(this.dragEndDate);
        newEndDate.setDate(newEndDate.getDate() + daysDiff);
        
        this.$emit('update', this.task.id, newStartDate, newEndDate);
      }
    },
    stopDrag() {
      this.isDragging = false;
      document.removeEventListener('mousemove', this.onDrag);
      document.removeEventListener('mouseup', this.stopDrag);
    },
    
    // Dependency connection methods
    startConnection(type) {
      // Prevent starting a connection if we're already dragging the task
      if (this.isDragging) return;
      
      this.isConnecting = true;
      this.connectionType = type;
      
      // Calculate the connection start point position
      const rect = this.$el.getBoundingClientRect();
      if (type === 'start') {
        this.connectionPoint = {
          x: rect.left,
          y: rect.top + rect.height / 2
        };
      } else { // 'end'
        this.connectionPoint = {
          x: rect.right,
          y: rect.top + rect.height / 2
        };
      }
      
      // Initialize mouse position
      this.currentMousePosition = { ...this.connectionPoint };
      
      // Add event listeners for dragging
      document.addEventListener('mousemove', this.onConnectionDrag);
      document.addEventListener('mouseup', this.endConnection);
      
      // Emit event to notify the parent that we're starting a connection
      this.$emit('connectionStart', {
        taskId: this.task.id,
        connectionType: type
      });
    },
    
    onConnectionDrag(e) {
      if (!this.isConnecting) return;
      
      // Update the current mouse position for drawing the connection line
      this.currentMousePosition = {
        x: e.clientX,
        y: e.clientY
      };
    },
    
    endConnection(e) {
      if (!this.isConnecting) return;
      
      this.isConnecting = false;
      
      // Check if we're over another task's connection point
      // This will be handled by the parent component
      this.$emit('connectionEnd', {
        fromTaskId: this.task.id,
        fromType: this.connectionType,
        mouseX: e.clientX,
        mouseY: e.clientY
      });
      
      document.removeEventListener('mousemove', this.onConnectionDrag);
      document.removeEventListener('mouseup', this.endConnection);
    },
    
    // Method to highlight this connection point when another connection is being dragged over it
    setConnectionPointActive(isActive) {
      this.isConnectionPointActive = isActive;
    }
  }
}
</script>

<style>
.task-bar {
  position: absolute;
  border-radius: 4px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.24);
  overflow: visible !important; /* Force visible overflow */
  cursor: move;
  z-index: 5; /* Ensure proper stacking with home plate shapes */
}

.task-bar.is-dragging {
  z-index: 100;
  opacity: 0.8;
}

.task-bar-content {
  position: relative;
  height: 100%;
  overflow: visible !important; /* Changed from hidden to show home plate shapes */
  border-radius: 4px;
  /* Background color is set dynamically */
}

/* Summary task styling with "home plate" end caps */
.task-bar-content.summary-task {
  border-radius: 0; /* Remove default rounded corners for summary tasks */
  position: relative;
  /* No margins needed - pseudo-elements are positioned absolutely */
  overflow: visible !important; /* Force visible overflow */
}

.task-bar-content.summary-task::before,
.task-bar-content.summary-task::after {
  content: '';
  position: absolute;
}

/* Create separate, absolutely positioned home plate shapes */
.summary-task-bar::before,
.summary-task-bar::after {
  content: "";
  position: absolute;
  height: 30px; /* Match task bar height */
  width: 20px; /* Wider shape as requested */
  background-color: #555555; /* Match summary task color */
  z-index: 20; /* Very high z-index */
}

/* Left home plate - true pentagon shape */
.summary-task-bar::before {
  left: 0; /* Align with left edge of task bar */
  top: 0; /* Align with top of task bar */
  /* Create pentagon with 3 horizontal sides and 2 angled sides */
  clip-path: polygon(
    0% 0%,    /* Top left corner */
    100% 0%,  /* Top right corner */
    100% 60%, /* Right middle point */
    50% 100%, /* Bottom center point */
    0% 60%    /* Left middle point */
  );
}

/* Right home plate - true pentagon shape */
.summary-task-bar::after {
  right: 0; /* Align with right edge of task bar */
  top: 0; /* Align with top of task bar */
  /* Create pentagon with 3 horizontal sides and 2 angled sides */
  clip-path: polygon(
    0% 0%,    /* Top left corner */
    100% 0%,  /* Top right corner */
    100% 60%, /* Right middle point */
    50% 100%, /* Bottom center point */
    0% 60%    /* Left middle point */
  );
}

.task-bar-progress {
  position: absolute;
  top: 0;
  left: 0;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.2);
}

.task-bar-label {
  position: absolute;
  top: 0;
  left: 4px; /* Default padding for regular tasks */
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  height: 100%;
  display: flex;
  align-items: center;
  font-size: 12px;
  color: white;
  text-shadow: 0 1px 1px rgba(0,0,0,0.4);
}

/* Add more left padding for summary task labels to avoid the home plate icon */
.summary-task .task-bar-label {
  left: 22px; /* Increased padding to clear the home plate icon */
}

.task-handle {
  position: absolute;
  z-index: 10;
}

.task-handle-left {
  left: 0;
  top: 0;
  width: 10px;
  height: 100%;
  cursor: w-resize;
}

.task-handle-right {
  right: 0;
  top: 0;
  width: 10px;
  height: 100%;
  cursor: e-resize;
}

.task-handle-move {
  left: 10px;
  right: 10px;
  top: 0;
  height: 100%;
  cursor: move;
}

/* Connection points styles */
.connection-point {
  position: absolute;
  width: 14px;
  height: 14px;
  border-radius: 50%;
  background-color: rgba(74, 144, 226, 0.7); /* Exact match to dependency line color */
  border: 2px solid rgba(74, 144, 226, 0.7); /* Exact match to dependency line color */
  top: 50%;
  transform: translate(-50%, -50%);
  cursor: pointer;
  z-index: 5; /* Same as other elements */
  transition: all 0.2s ease;
  opacity: 0; /* Hidden by default */
}

/* Show on hover */
.task-bar:hover .connection-point {
  opacity: 1;
}

.connection-point:hover, 
.connection-point.active {
  background-color: #2463b6; /* Darker blue when active/hover */
  border-color: #2463b6;
  transform: translate(-50%, -50%) scale(1.2);
  opacity: 1; /* Always visible when active or hovered */
}

.connection-point-start {
  left: 0;
}

.connection-point-end {
  left: 100%;
}

/* Connection line styles */
.connection-line-container {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;
  z-index: 50; /* Higher than existing dependencies but lower than connection points */
}

.connection-line-path {
  fill: none;
  stroke: #4a90e2;
  stroke-width: 2px;
  stroke-dasharray: 4 2;
}
</style>