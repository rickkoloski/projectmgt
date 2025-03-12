<template>
  <div 
    class="task-card" 
    :class="{ 
      'is-expanded': expanded,
      [`status-${task.status}`]: true
    }"
    @dragstart="onDragStart"
    @dragend="onDragEnd"
  >
    <div class="card-header" @click="expanded = !expanded" :title="task.description">
      <div class="card-header-top">
        <div class="task-title">{{ task.name }}</div>
        <button class="task-delete-btn" @click.stop="confirmDelete" title="Delete task">×</button>
      </div>
      <div class="task-meta">
        <div class="card-status-badge">{{ statusLabel }}</div>
        <div v-if="task.description && !expanded" class="description-indicator">📝</div>
      </div>
      <div class="progress-indicator" :style="{ width: `${task.progress}%` }"></div>
    </div>
    
    <div v-if="expanded" class="card-details">
      <!-- Description section if available -->
      <div v-if="task.description" class="detail-row description-row">
        <div class="task-description">{{ task.description }}</div>
      </div>
      
      <div class="detail-row">
        <label>Start:</label>
        <input 
          type="date" 
          :value="formatDate(task.startDate)" 
          @change="updateStartDate"
        />
      </div>
      
      <div class="detail-row">
        <label>End:</label>
        <input 
          type="date" 
          :value="formatDate(task.endDate)" 
          @change="updateEndDate"
        />
      </div>
      
      <div class="detail-row">
        <label>Progress:</label>
        <div class="progress-control">
          <input 
            type="range" 
            min="0" 
            max="100" 
            :value="task.progress" 
            @input="updateProgress"
          />
          <span>{{ task.progress }}%</span>
        </div>
      </div>
      
      <div class="detail-row">
        <label>Status:</label>
        <select :value="task.status" @change="updateStatus">
          <option value="backlog">Backlog</option>
          <option value="todo">To Do</option>
          <option value="inProgress">In Progress</option>
          <option value="review">Review</option>
          <option value="done">Done</option>
        </select>
      </div>
      
      <div class="detail-row" v-if="task.resources && task.resources.length">
        <label>Resources:</label>
        <div class="resources-list">
          <span v-for="resourceId in task.resources" :key="resourceId" class="resource-tag">
            {{ getResourceName(resourceId) }}
          </span>
        </div>
      </div>
    </div>
    
    <!-- We'll use the entire card for dragging instead of a specific handle -->
  </div>
</template>

<script>
export default {
  props: {
    task: {
      type: Object,
      required: true
    },
    resources: {
      type: Array,
      default: () => []
    }
  },
  
  data() {
    return {
      expanded: false
    };
  },
  
  computed: {
    statusLabel() {
      const statusLabels = {
        'backlog': 'Backlog',
        'todo': 'To Do',
        'inProgress': 'In Progress',
        'review': 'Review',
        'done': 'Done'
      };
      return statusLabels[this.task.status] || 'Unknown';
    }
  },
  
  methods: {
    getResourceName(resourceId) {
      console.log('Resources passed to TaskCard:', this.resources);
      console.log('Looking for resourceId:', resourceId);
      const resource = this.resources.find(r => r.id === resourceId);
      console.log('Found resource:', resource);
      return resource ? resource.name : `Resource ${resourceId}`;
    },
    
    formatDate(date) {
      if (!date) return '';
      const d = new Date(date);
      return d.toISOString().split('T')[0];
    },
    
    updateStartDate(event) {
      const updatedTask = { ...this.task, startDate: new Date(event.target.value) };
      this.$emit('update:task', updatedTask);
    },
    
    updateEndDate(event) {
      const updatedTask = { ...this.task, endDate: new Date(event.target.value) };
      this.$emit('update:task', updatedTask);
    },
    
    updateProgress(event) {
      const progress = parseInt(event.target.value, 10);
      const updatedTask = { ...this.task, progress };
      this.$emit('update:task', updatedTask);
    },
    
    updateStatus(event) {
      const status = event.target.value;
      const updatedTask = { ...this.task, status };
      this.$emit('update:task', updatedTask);
    },
    
    // Drag and drop handling
    onDragStart(event) {
      // Prevent drag if we're clicking on an input or select
      if (
        event.target.tagName === 'INPUT' || 
        event.target.tagName === 'SELECT' ||
        event.target.tagName === 'OPTION'
      ) {
        event.preventDefault();
        return;
      }
      
      // Forward the dragstart event to the parent
      this.$emit('dragstart', event, this.task);
      
      // Add a visual style 
      this.$el.classList.add('dragging');
    },
    
    onDragEnd(event) {
      // Remove the visual style
      this.$el.classList.remove('dragging');
    },
    
    // Task deletion methods
    confirmDelete(event) {
      event.stopPropagation();
      // Directly emit the delete event to let the parent handle the confirmation
      this.$emit('delete', this.task.id);
    }
  }
};
</script>

<style>
.task-card {
  background-color: white;
  border-radius: 4px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.12);
  overflow: hidden;
  transition: all 0.2s ease;
  width: 100%; /* Ensure cards take full width of column */
  position: relative;
  cursor: grab;
}

/* Status-specific color indicators */
.task-card.status-backlog {
  border-left: 3px solid #9e9e9e; /* Gray */
}

.task-card.status-todo {
  border-left: 3px solid #2196f3; /* Blue */
}

.task-card.status-inProgress {
  border-left: 3px solid #ff9800; /* Orange */
}

.task-card.status-review {
  border-left: 3px solid #9c27b0; /* Purple */
}

.task-card.status-done {
  border-left: 3px solid #4caf50; /* Green */
}

.task-card:hover {
  box-shadow: 0 2px 5px rgba(0, 0, 0, 0.2);
  transform: translateY(-2px); /* Slight lift effect on hover */
}

.card-header {
  padding: 12px;
  position: relative;
  cursor: pointer;
  display: flex;
  flex-direction: column;
}

.card-header-top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 8px;
}

.task-title {
  font-weight: 500;
  flex: 1;
  margin-right: 8px;
}

.task-delete-btn {
  background-color: rgba(220, 53, 69, 0.1);
  border: none;
  color: #dc3545;
  font-size: 18px;
  font-weight: bold;
  line-height: 1;
  width: 24px;
  height: 24px;
  padding: 0;
  display: flex;
  justify-content: center;
  align-items: center;
  cursor: pointer;
  border-radius: 50%;
  transition: all 0.2s;
}

.task-delete-btn:hover {
  color: white;
  background-color: #dc3545;
}

.task-meta {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}

.card-status-badge {
  font-size: 11px;
  padding: 2px 8px;
  border-radius: 12px;
  display: inline-block;
  font-weight: 500;
}

.description-indicator {
  font-size: 12px;
  opacity: 0.7;
  cursor: pointer;
}

/* Status-specific badge colors */
.status-backlog .card-status-badge {
  background-color: #f5f5f5;
  color: #616161;
}

.status-todo .card-status-badge {
  background-color: #e3f2fd;
  color: #0d47a1;
}

.status-inProgress .card-status-badge {
  background-color: #fff3e0;
  color: #e65100;
}

.status-review .card-status-badge {
  background-color: #f3e5f5;
  color: #6a1b9a;
}

.status-done .card-status-badge {
  background-color: #e8f5e9;
  color: #1b5e20;
}

.progress-indicator {
  height: 4px;
  position: absolute;
  bottom: 0;
  left: 0;
}

/* Status-specific progress bar colors */
.status-backlog .progress-indicator {
  background-color: #9e9e9e;
}

.status-todo .progress-indicator {
  background-color: #2196f3;
}

.status-inProgress .progress-indicator {
  background-color: #ff9800;
}

.status-review .progress-indicator {
  background-color: #9c27b0;
}

.status-done .progress-indicator {
  background-color: #4caf50;
}

.card-details {
  padding: 12px;
  border-top: 1px solid #eee;
  background-color: #fafafa;
}

.detail-row {
  display: flex;
  align-items: center;
  margin-bottom: 10px;
}

.description-row {
  display: block;
  margin-bottom: 16px;
  padding-bottom: 12px;
  border-bottom: 1px dashed #ddd;
}

.task-description {
  font-size: 13px;
  line-height: 1.4;
  color: #555;
  white-space: pre-line;
}

.detail-row label {
  width: 80px;
  font-size: 12px;
  color: #666;
  flex-shrink: 0; /* Prevent label from shrinking */
}

.detail-row input, .detail-row select {
  flex: 1;
  padding: 6px;
  border: 1px solid #ddd;
  border-radius: 3px;
  font-size: 13px;
}

.progress-control {
  display: flex;
  align-items: center;
  flex: 1;
  gap: 10px;
}

.progress-control input {
  flex: 1;
}

.progress-control span {
  width: 40px;
  text-align: right;
  font-size: 12px;
  font-weight: 500;
}

.resources-list {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}

.resource-tag {
  background-color: #e1e5eb;
  border-radius: 3px;
  padding: 2px 6px;
  font-size: 11px;
}

/* When being dragged */
.task-card.dragging {
  cursor: grabbing;
}

/* Delete Modal Styles */
.delete-modal-backdrop {
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

.delete-modal {
  background-color: white;
  border-radius: 8px;
  width: 320px;
  max-width: 90%;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.2);
  overflow: hidden;
}

.delete-modal-header {
  padding: 12px 16px;
  background-color: #f8f9fa;
  border-bottom: 1px solid #eee;
}

.delete-modal-header h3 {
  margin: 0;
  font-size: 16px;
  color: #333;
}

.delete-modal-body {
  padding: 16px;
}

.delete-modal-footer {
  display: flex;
  justify-content: flex-end;
  padding: 12px 16px;
  background-color: #f8f9fa;
  border-top: 1px solid #eee;
  gap: 8px;
}

.btn-cancel {
  padding: 6px 12px;
  background-color: #e9ecef;
  border: 1px solid #ced4da;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  color: #495057;
}

.btn-delete {
  padding: 6px 12px;
  background-color: #dc3545;
  color: white;
  border: 1px solid #dc3545;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
}

.btn-delete:hover {
  background-color: #c82333;
  border-color: #bd2130;
}
</style>