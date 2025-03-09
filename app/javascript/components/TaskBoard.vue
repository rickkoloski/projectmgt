<template>
  <div class="task-board">
    <div class="board-columns">
      <div 
        v-for="column in columns" 
        :key="column.id" 
        class="board-column"
        @dragover.prevent="onDragOver"
        @drop="onDrop($event, column.status)"
      >
        <div class="column-header">
          <h3>{{ column.name }}</h3>
          <span class="task-count">{{ tasksInColumn(column).length }}</span>
        </div>
        <div 
          class="column-content"
          :class="{ 'drag-over': dragOverColumn === column.status }"
          @dragenter.prevent="dragOverColumn = column.status"
          @dragleave="onDragLeave($event, column.status)"
        >
          <task-card 
            v-for="task in tasksInColumn(column)" 
            :key="task.id" 
            :task="task"
            :resources="resources"
            @update:task="updateTask"
            @dragstart="onDragStart($event, task)"
            @delete="deleteTask"
            draggable="true"
          />
          
          <!-- Drop placeholder that appears when column is empty -->
          <div 
            v-if="tasksInColumn(column).length === 0" 
            class="empty-column-placeholder"
            :class="{ 'drag-over': dragOverColumn === column.status }"
          >
            Drop tasks here
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import TaskCard from './TaskCard.vue';

export default {
  components: {
    TaskCard
  },
  props: {
    tasks: {
      type: Array,
      required: true
    },
    resources: {
      type: Array,
      default: () => []
    }
  },
  created() {
    console.log('TaskBoard initialized with resources:', this.resources);
  },
  data() {
    return {
      columns: [
        { id: 'backlog', name: 'Backlog', status: 'backlog' },
        { id: 'todo', name: 'To Do', status: 'todo' },
        { id: 'inProgress', name: 'In Progress', status: 'inProgress' },
        { id: 'review', name: 'Review', status: 'review' },
        { id: 'done', name: 'Done', status: 'done' }
      ],
      draggedTask: null,
      dragOverColumn: null,
      dragLeaveTimeout: null
    };
  },
  methods: {
    // Only display non-summary tasks (tasks without children)
    isLeafTask(task) {
      return !task.children || task.children.length === 0;
    },
    
    // Get all leaf tasks from the hierarchical structure
    getAllLeafTasks(tasks) {
      let leafTasks = [];
      
      const processTask = (task) => {
        if (this.isLeafTask(task)) {
          leafTasks.push(task);
        } else if (task.children && task.children.length > 0) {
          task.children.forEach(child => processTask(child));
        }
      };
      
      tasks.forEach(task => processTask(task));
      return leafTasks;
    },
    
    // Get tasks for a specific column
    tasksInColumn(column) {
      const leafTasks = this.getAllLeafTasks(this.tasks);
      return leafTasks.filter(task => task.status === column.status);
    },
    
    // Update task data
    updateTask(updatedTask) {
      this.$emit('update:task', updatedTask);
    },
    
    // Delete a task
    deleteTask(taskId) {
      this.$emit('delete', taskId);
    },
    
    // Drag and drop handlers
    onDragStart(event, task) {
      this.draggedTask = task;
      // Set data for drag operation
      event.dataTransfer.effectAllowed = 'move';
      event.dataTransfer.setData('text/plain', task.id);
      
      // Add a class to the dragged element for styling
      event.target.classList.add('dragging');
    },
    
    onDragOver(event) {
      event.preventDefault();
      // Change the cursor to indicate a drop is allowed
      event.dataTransfer.dropEffect = 'move';
    },
    
    onDragLeave(event, columnStatus) {
      // Check if we're leaving the column and not just moving between its children
      // We need to check if the relatedTarget (what we're entering) is not inside the column
      const column = event.currentTarget;
      
      // Clear any existing timeout to prevent flickering
      if (this.dragLeaveTimeout) {
        clearTimeout(this.dragLeaveTimeout);
      }
      
      // Set a short timeout to avoid flickering when moving between tasks
      this.dragLeaveTimeout = setTimeout(() => {
        if (!column.contains(event.relatedTarget)) {
          if (this.dragOverColumn === columnStatus) {
            this.dragOverColumn = null;
          }
        }
      }, 50);
    },
    
    onDrop(event, columnStatus) {
      event.preventDefault();
      // Reset the dragover state
      this.dragOverColumn = null;
      
      // If no task is being dragged, exit
      if (!this.draggedTask) return;
      
      // Update the task's status
      const updatedTask = { ...this.draggedTask, status: columnStatus };
      this.updateTask(updatedTask);
      
      // Reset the dragged task
      this.draggedTask = null;
      
      // Remove the dragging class from all elements
      document.querySelectorAll('.dragging').forEach(el => {
        el.classList.remove('dragging');
      });
    }
  }
};
</script>

<style>
.task-board {
  display: flex;
  flex-direction: column;
  height: 100%; /* Fill the parent container */
  padding: 15px;
  overflow: hidden;
  background-color: #f9fafb; /* Subtle background color */
}

.board-columns {
  display: flex;
  gap: 15px;
  height: 100%;
  width: 100%;
  overflow-x: auto;
  padding-bottom: 8px; /* Space for scrollbar */
}

.board-column {
  flex: 1 1 0;
  min-width: 200px; /* Reduced min-width to allow more columns */
  max-width: none; /* Remove the max-width restriction */
  background-color: #f5f7fa;
  border-radius: 5px;
  display: flex;
  flex-direction: column;
  transition: background-color 0.2s;
}

.column-header {
  padding: 12px;
  background-color: #e1e5eb;
  border-radius: 5px 5px 0 0;
  display: flex;
  justify-content: space-between;
  align-items: center;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
  position: sticky;
  top: 0;
  z-index: 10;
}

.column-header h3 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: #333;
}

.task-count {
  background-color: rgba(0, 0, 0, 0.1);
  border-radius: 12px;
  padding: 3px 10px;
  font-size: 12px;
  font-weight: 500;
  color: #555;
}

.column-content {
  padding: 12px;
  flex: 1;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 12px;
  /* Add a subtle scrollbar */
  scrollbar-width: thin;
  scrollbar-color: #ccc transparent;
  min-height: 120px; /* Ensure there's always a drop area */
  transition: background-color 0.2s, box-shadow 0.2s;
}

/* Custom scrollbar for webkit browsers */
.column-content::-webkit-scrollbar {
  width: 6px;
}

.column-content::-webkit-scrollbar-track {
  background: transparent;
}

.column-content::-webkit-scrollbar-thumb {
  background-color: #ccc;
  border-radius: 6px;
}

/* Drag and drop styles */
.column-content.drag-over {
  background-color: rgba(144, 202, 249, 0.15);
  box-shadow: inset 0 0 0 2px #4a8bf4;
}

.empty-column-placeholder {
  padding: 16px;
  text-align: center;
  color: #aaa;
  border: 2px dashed #ddd;
  border-radius: 4px;
  margin: 8px 0;
  font-size: 14px;
  background-color: rgba(0, 0, 0, 0.02);
  transition: all 0.2s;
}

.empty-column-placeholder.drag-over {
  border-color: #4a8bf4;
  background-color: rgba(144, 202, 249, 0.15);
  color: #4a8bf4;
}

/* Style for cards being dragged */
.task-card.dragging {
  opacity: 0.6;
  transform: scale(0.95);
  box-shadow: 0 5px 15px rgba(0, 0, 0, 0.1);
}
</style>