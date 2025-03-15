<template>
  <div class="task-board">
    <div class="board-columns">
      <div 
        v-for="column in columns" 
        :key="column.id" 
        class="board-column"
      >
        <div class="column-header">
          <h3>{{ column.name }}</h3>
          <span class="task-count">{{ tasksInColumn(column).length }}</span>
          <button class="add-task-btn" @click="addNewTask(column.status)">+</button>
        </div>
        <div class="column-content">
          <!-- Draggable container for task cards -->
          <draggable
            :list="getColumnTasks(column)"
            :group="{ name: 'tasks', pull: true, put: true }"
            item-key="id"
            handle=".drag-handle"
            ghost-class="ghost-card"
            chosen-class="drag-chosen"
            :animation="200"
            @change="onChange($event, column.status)"
          >
            <template #item="{ element }">
              <task-card 
                :task="element"
                :resources="resources"
                @update:task="updateTask"
                @delete="deleteTask"
                :data-task-id="element.id"
                :data-board-order="element.board_order"
              />
            </template>
          </draggable>
          
          <!-- Drop placeholder that appears when column is empty -->
          <div 
            v-if="tasksInColumn(column).length === 0" 
            class="empty-column-placeholder"
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
import { VueDraggableNext } from 'vue-draggable-next';

export default {
  components: {
    TaskCard,
    draggable: VueDraggableNext
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
    this.initializeColumnTasks();
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
      columnTasks: {
        backlog: [],
        todo: [],
        inProgress: [],
        review: [],
        done: []
      },
      currentProjectId: null
    };
  },
  watch: {
    tasks: {
      handler() {
        this.initializeColumnTasks();
      },
      deep: true
    }
  },
  methods: {
    // Initialize column tasks from props
    initializeColumnTasks() {
      const leafTasks = this.getAllLeafTasks(this.tasks);
      
      // Get project ID from the first task
      if (leafTasks.length > 0) {
        this.currentProjectId = leafTasks[0].project_id;
      }
      
      // Group tasks by status
      this.columns.forEach(column => {
        const tasksInColumn = leafTasks.filter(task => task.status === column.status);
        
        // Sort by board_order
        tasksInColumn.sort((a, b) => {
          return (a.board_order || 0) - (b.board_order || 0);
        });
        
        this.columnTasks[column.status] = tasksInColumn;
      });
    },
    
    // Get tasks for a specific column from local state
    getColumnTasks(column) {
      return this.columnTasks[column.status] || [];
    },
    
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
      return this.columnTasks[column.status] || [];
    },
    
    // Update task data
    updateTask(updatedTask) {
      this.$emit('update:task', updatedTask);
    },
    
    // Delete a task
    deleteTask(taskId) {
      this.$emit('delete', taskId);
    },
    
    // Add a new task in the specified column
    addNewTask(status) {
      console.log(`Adding new task in column: ${status}`);
      
      // Create a new task with default values
      const newTask = {
        // Temporary negative ID to identify it as new (will be replaced by server)
        id: -Math.floor(Math.random() * 1000000),
        name: `New Task in ${this.columns.find(c => c.status === status).name}`,
        description: '',
        startDate: new Date(),
        endDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 1 week from now
        progress: 0,
        status: status,
        resources: [],
        project_id: this.currentProjectId
      };
      
      // Emit the event to create the task
      this.$emit('update:task', newTask);
    },
    
    // Handle changes from draggable component
    onChange(event, columnStatus) {
      // Handle added item
      if (event.added) {
        const { newIndex, element } = event.added;
        this.handleTaskMoved(element, columnStatus, newIndex);
      }
      // Handle moved item
      else if (event.moved) {
        const { newIndex, element } = event.moved;
        this.handleTaskReordered(element, columnStatus, newIndex);
      }
      // Handle removed item (moved to another column)
      else if (event.removed) {
        // This is handled by the 'added' event in the destination column
      }
    },
    
    // Handle when a task is moved between columns
    handleTaskMoved(task, newStatus, newPosition) {
      if (task.status !== newStatus) {
        // Task was moved to a new column
        const updatedTask = { 
          ...task, 
          status: newStatus
        };
        
        // Update task first to change its status
        this.updateTask(updatedTask);
        
        // Then reorder it within the new column
        this.reorderTask(task.id, newPosition, newStatus);
      } else {
        // Just a reorder within the same column
        this.reorderTask(task.id, newPosition, newStatus);
      }
    },
    
    // Handle when a task is reordered within the same column
    handleTaskReordered(task, status, newPosition) {
      this.reorderTask(task.id, newPosition, status);
    },
    
    // Call the API to reorder tasks
    reorderTask(taskId, newPosition, status) {
      if (!this.currentProjectId) return;
      
      const url = '/api/v1/tasks/reorder_board';
      const data = {
        project_id: this.currentProjectId,
        task_id: taskId,
        position: newPosition,
        status: status
      };
      
      console.log(`Reordering board task ${taskId} to position ${newPosition}`);
      
      // Get CSRF token from meta tag
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
      
      // Optimistic update is already handled by vue-draggable-next's automatic list update
      // Note: We're keeping the server update for data persistence
      
      // Make the API call
      fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken,
          'X-Requested-With': 'XMLHttpRequest'
        },
        body: JSON.stringify(data),
        credentials: 'same-origin'
      })
      .then(response => {
        if (!response.ok) {
          throw new Error('Failed to reorder task');
        }
        return response.json();
      })
      .then(updatedTasks => {
        console.log('Tasks reordered successfully:', updatedTasks);
        // Emit an event to update parent component's tasks
        this.$emit('tasks-reordered', updatedTasks);
        // Also update our columnTasks with the latest data from server
        this.initializeColumnTasks();
      })
      .catch(error => {
        console.error('Error reordering tasks:', error);
        // If the server update fails, we should reset the UI to match server state
        this.initializeColumnTasks();
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

.add-task-btn {
  width: 24px;
  height: 24px;
  background-color: rgba(0, 0, 0, 0.1);
  border: none;
  border-radius: 50%;
  color: #333;
  font-size: 16px;
  font-weight: bold;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  margin-left: 8px;
  transition: all 0.2s ease;
}

.add-task-btn:hover {
  background-color: rgba(0, 0, 0, 0.2);
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

/* Sortable/draggable styles */
.sortable-ghost {
  opacity: 0.3;
  border: 2px dashed #4a8bf4;
  background-color: rgba(144, 202, 249, 0.15);
}

.ghost-card {
  opacity: 0.4;
  background-color: #f0f5ff !important;
  border: 2px dashed #4a8bf4 !important;
  transform: scale(0.98);
}

.drag-chosen {
  /* Style for the chosen item being dragged */
  box-shadow: 0 4px 10px rgba(0, 0, 0, 0.2);
  transform: scale(1.01);
  z-index: 100;
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

/* Gap between cards in a column */
.column-content > [data-draggable="true"] {
  padding: 5px 0;
}

/* Add gap between sortable items */
.column-content [data-draggable="true"] + [data-draggable="true"] {
  margin-top: 10px;
}
</style>