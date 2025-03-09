<template>
  <div class="task-item">
    <div class="task-content" :style="{ paddingLeft: `${level * 20}px` }">
      <div class="task-expand" v-if="task.children && task.children.length > 0" @click="toggle">
        {{ task.expanded ? '▼' : '►' }}
      </div>
      
      <div class="table-cell table-name" @click="openTaskDialog">
        <span>{{ task.name }}</span>
      </div>
      
      <div v-if="visibleColumns.startDate" class="table-cell table-date" @click="editField('startDate')">
        <span v-if="editingField !== 'startDate'">{{ formatDate(task.startDate) }}</span>
        <div v-else class="editor-wrapper">
          <input 
            type="date" 
            class="task-input date-input" 
            :style="{ width: dateInputWidth + 'px' }"
            :value="editValues.startDate"
            @input="e => editValues.startDate = e.target.value"
            @blur="saveField('startDate')"
            @keyup.enter="saveField('startDate')"
            ref="startDateInput"
          />
        </div>
      </div>
      
      <div v-if="visibleColumns.endDate" class="table-cell table-date" @click="editField('endDate')">
        <span v-if="editingField !== 'endDate'">{{ formatDate(task.endDate) }}</span>
        <div v-else class="editor-wrapper">
          <input 
            type="date" 
            class="task-input date-input" 
            :style="{ width: dateInputWidth + 'px' }"
            :value="editValues.endDate"
            @input="e => editValues.endDate = e.target.value"
            @blur="saveField('endDate')"
            @keyup.enter="saveField('endDate')"
            ref="endDateInput"
          />
        </div>
      </div>
      
      <div v-if="visibleColumns.progress" class="table-cell table-progress" @click="editField('progress')">
        <span v-if="editingField !== 'progress'">{{ task.progress }}%</span>
        <div v-else class="editor-wrapper">
          <input 
            type="number" 
            min="0" 
            max="100" 
            class="task-input progress-input" 
            v-model.number="editValues.progress"
            @blur="saveField('progress')"
            @keyup.enter="saveField('progress')"
            ref="progressInput"
          />
        </div>
      </div>
      
      <div v-if="visibleColumns.resources" class="table-cell table-resources" @click="editField('resources')">
        <span v-if="editingField !== 'resources'">{{ formatResources(task.resources) }}</span>
      </div>
      
      <!-- Floating Resources Selector -->
      <div v-if="editingField === 'resources'" class="floating-resource-editor">
        <div class="resource-editor-header">
          <h3>Select Resources</h3>
          <button class="close-button" @click.stop="cancelResourceEdit">×</button>
        </div>
        
        <div class="resource-selector-container">
          <div 
            v-for="resource in availableResources" 
            :key="resource.id"
            class="resource-option"
            :class="{ 'selected': isResourceSelected(resource.id) }"
            @click.stop="toggleResource(resource.id)"
          >
            <input 
              type="checkbox" 
              :checked="isResourceSelected(resource.id)" 
              @click.stop="toggleResource(resource.id)"
            />
            {{ resource.name }}
          </div>
        </div>
        
        <div class="resource-editor-footer">
          <button class="cancel-button" @click.stop="cancelResourceEdit">Cancel</button>
          <button class="save-button" @click.stop="saveField('resources')">Save</button>
        </div>
      </div>
      
      <!-- Task Dialog for editing all attributes -->
      <div v-if="showTaskDialog" class="task-dialog-backdrop" @click.self="closeTaskDialog">
        <div class="task-dialog">
          <div class="task-dialog-header">
            <h3>Edit Task</h3>
            <button class="close-button" @click.stop="closeTaskDialog">×</button>
          </div>
          
          <div class="task-dialog-content">
            <div class="tab-navigation">
              <button 
                v-for="(tab, index) in dialogTabs" 
                :key="index"
                :class="['tab-button', { active: activeTab === index }]"
                @click="activeTab = index"
              >
                {{ tab }}
              </button>
            </div>
            
            <!-- General Tab -->
            <div v-if="activeTab === 0" class="tab-content">
              <div class="form-group">
                <label for="task-name">Task Name</label>
                <input 
                  id="task-name" 
                  type="text" 
                  class="form-control" 
                  v-model="dialogValues.name"
                />
              </div>
              
              <div class="form-row">
                <div class="form-group">
                  <label for="task-start">Start Date</label>
                  <input 
                    id="task-start" 
                    type="date" 
                    class="form-control" 
                    :value="dialogValues.startDate"
                    @input="e => dialogValues.startDate = e.target.value"
                  />
                </div>
                
                <div class="form-group">
                  <label for="task-end">End Date</label>
                  <input 
                    id="task-end" 
                    type="date" 
                    class="form-control" 
                    :value="dialogValues.endDate"
                    @input="e => dialogValues.endDate = e.target.value"
                  />
                </div>
              </div>
              
              <div class="form-group">
                <label for="task-progress">Progress (%)</label>
                <input 
                  id="task-progress" 
                  type="number" 
                  min="0" 
                  max="100" 
                  class="form-control" 
                  v-model.number="dialogValues.progress"
                />
              </div>
              
              <div class="form-group">
                <label for="task-status">Status</label>
                <select 
                  id="task-status" 
                  class="form-control" 
                  v-model="dialogValues.status"
                >
                  <option value="backlog">Backlog</option>
                  <option value="todo">To Do</option>
                  <option value="inProgress">In Progress</option>
                  <option value="review">Review</option>
                  <option value="done">Done</option>
                </select>
                <div class="status-badge" :class="'status-' + dialogValues.status">
                  {{ statusLabels[dialogValues.status] }}
                </div>
              </div>
              
              <div class="form-group">
                <label>Resources</label>
                <div class="resource-list">
                  <div 
                    v-for="resource in availableResources" 
                    :key="resource.id"
                    class="resource-checkbox"
                  >
                    <input 
                      type="checkbox" 
                      :id="'resource-' + resource.id" 
                      :checked="isResourceSelectedInDialog(resource.id)" 
                      @change="toggleDialogResource(resource.id)"
                    />
                    <label :for="'resource-' + resource.id">{{ resource.name }}</label>
                  </div>
                </div>
              </div>
            </div>
            
            <!-- Advanced Tab (placeholder for future extensions) -->
            <div v-if="activeTab === 1" class="tab-content">
              <p class="coming-soon">Advanced options will be added in a future update.</p>
            </div>
            
            <!-- Dependencies Tab (placeholder for future extensions) -->
            <div v-if="activeTab === 2" class="tab-content">
              <p class="coming-soon">Dependencies management will be added in a future update.</p>
            </div>
          </div>
          
          <div class="task-dialog-footer">
            <button class="delete-button" @click.stop="deleteTask" title="Delete task">Delete</button>
            <div class="spacer"></div>
            <button class="cancel-button" @click.stop="closeTaskDialog">Cancel</button>
            <button class="save-button" @click.stop="saveTaskDialog">Save</button>
          </div>
        </div>
      </div>
    </div>
    
    <template v-if="task.expanded">
      <task-item 
        v-for="child in task.children" 
        :key="child.id" 
        :task="child" 
        :level="level + 1"
        @toggle="onChildToggle"
        @update="onChildUpdate"
        @delete="onChildDelete"
        :available-resources="availableResources"
        :visible-columns="visibleColumns"
        :date-input-width="dateInputWidth"
      />
    </template>
  </div>
</template>

<script>
export default {
  name: 'TaskItem',
  computed: {
    statusLabels() {
      return {
        'backlog': 'Backlog',
        'todo': 'To Do',
        'inProgress': 'In Progress',
        'review': 'Review',
        'done': 'Done'
      };
    }
  },
  props: {
    task: {
      type: Object,
      required: true
    },
    level: {
      type: Number,
      default: 0
    },
    availableResources: {
      type: Array,
      default: () => [
        { id: 1, name: 'John Smith' },
        { id: 2, name: 'Jane Doe' },
        { id: 3, name: 'Robert Johnson' },
        { id: 4, name: 'Sarah Williams' },
        { id: 5, name: 'Michael Brown' }
      ]
    },
    visibleColumns: {
      type: Object,
      default: () => ({
        startDate: true,
        endDate: true,
        progress: true,
        resources: true
      })
    },
    dateInputWidth: {
      type: Number,
      default: 90
    }
  },
  data() {
    return {
      editingField: null,
      editValues: {
        name: this.task.name,
        startDate: this.formatDateForInput(this.task.startDate),
        endDate: this.formatDateForInput(this.task.endDate),
        progress: this.task.progress,
        resources: this.task.resources || [],
        status: this.task.status || 'backlog'
      },
      showTaskDialog: false,
      dialogValues: {
        name: this.task.name,
        startDate: this.formatDateForInput(this.task.startDate),
        endDate: this.formatDateForInput(this.task.endDate),
        progress: this.task.progress,
        resources: [...(this.task.resources || [])],
        status: this.task.status || 'backlog'
      },
      activeTab: 0,
      dialogTabs: ['General', 'Advanced', 'Dependencies']
    }
  },
  methods: {
    toggle() {
      this.$emit('toggle', this.task.id)
    },
    onChildToggle(taskId) {
      this.$emit('toggle', taskId)
    },
    onChildUpdate(task) {
      this.$emit('update', task)
    },
    
    onChildDelete(taskId) {
      this.$emit('delete', taskId)
    },
    editField(field) {
      this.editingField = field
      this.editValues = {
        name: this.task.name,
        startDate: this.formatDateForInput(this.task.startDate),
        endDate: this.formatDateForInput(this.task.endDate),
        progress: this.task.progress,
        resources: [...(this.task.resources || [])]
      }
      
      // Focus the input field after it's rendered
      this.$nextTick(() => {
        if (this.$refs[`${field}Input`]) {
          this.$refs[`${field}Input`].focus();
        }
      })
    },
    saveField(field) {
      this.editingField = null
      
      // Convert input values to appropriate types
      let updatedValues = {}
      
      if (field === 'name' && this.editValues.name !== this.task.name) {
        updatedValues.name = this.editValues.name
      } 
      else if (field === 'startDate' && this.editValues.startDate !== this.formatDateForInput(this.task.startDate)) {
        updatedValues.startDate = new Date(this.editValues.startDate)
      } 
      else if (field === 'endDate' && this.editValues.endDate !== this.formatDateForInput(this.task.endDate)) {
        updatedValues.endDate = new Date(this.editValues.endDate)
      } 
      else if (field === 'progress' && this.editValues.progress !== this.task.progress) {
        updatedValues.progress = Math.min(100, Math.max(0, this.editValues.progress))
      } 
      else if (field === 'resources') {
        updatedValues.resources = [...this.editValues.resources]
      }
      
      // Only emit the update if something changed
      if (Object.keys(updatedValues).length > 0) {
        this.$emit('update', { ...this.task, ...updatedValues })
      }
    },
    formatDate(date) {
      if (!date) return ''
      const d = new Date(date)
      return d.toLocaleDateString()
    },
    formatDateForInput(date) {
      if (!date) return ''
      try {
        const d = new Date(date)
        if (isNaN(d.getTime())) {
          return ''
        }
        
        return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
      } catch (err) {
        return ''
      }
    },
    formatResources(resources) {
      if (!resources || resources.length === 0) return 'None'
      
      return resources.map(resourceId => {
        const resource = this.availableResources.find(r => r.id === resourceId)
        return resource ? resource.name : 'Unknown'
      }).join(', ')
    },
    isResourceSelected(resourceId) {
      return this.editValues.resources.includes(resourceId)
    },
    toggleResource(resourceId) {
      const index = this.editValues.resources.indexOf(resourceId)
      if (index === -1) {
        this.editValues.resources.push(resourceId)
      } else {
        this.editValues.resources.splice(index, 1)
      }
    },
    
    cancelResourceEdit() {
      this.editingField = null;
    },
    
    openTaskDialog() {
      // Initialize dialog values from task
      this.dialogValues = {
        name: this.task.name,
        startDate: this.formatDateForInput(this.task.startDate),
        endDate: this.formatDateForInput(this.task.endDate),
        progress: this.task.progress,
        resources: [...(this.task.resources || [])],
        status: this.task.status || 'backlog'
      };
      this.activeTab = 0;
      this.showTaskDialog = true;
    },
    
    closeTaskDialog() {
      this.showTaskDialog = false;
    },
    
    saveTaskDialog() {
      // Create an object with the updated values
      const updatedValues = {
        name: this.dialogValues.name,
        startDate: new Date(this.dialogValues.startDate),
        endDate: new Date(this.dialogValues.endDate),
        progress: Math.min(100, Math.max(0, this.dialogValues.progress)),
        resources: [...this.dialogValues.resources],
        status: this.dialogValues.status
      };
      
      // Emit the update event
      this.$emit('update', { ...this.task, ...updatedValues });
      
      // Close the dialog
      this.showTaskDialog = false;
    },
    
    isResourceSelectedInDialog(resourceId) {
      return this.dialogValues.resources.includes(resourceId);
    },
    
    toggleDialogResource(resourceId) {
      const index = this.dialogValues.resources.indexOf(resourceId);
      if (index === -1) {
        this.dialogValues.resources.push(resourceId);
      } else {
        this.dialogValues.resources.splice(index, 1);
      }
    },
    
    deleteTask() {
      // Close the dialog first
      this.closeTaskDialog();
      
      // Emit an event to the parent to delete the task
      this.$emit('delete', this.task.id);
    }
  }
}
</script>

<style>
.task-item {
  border-bottom: 1px solid #eee;
}

.task-content {
  display: flex;
  align-items: center;
  height: 36px;
  padding: 0 8px;
}

.task-content:hover {
  background-color: #f9f9f9;
}

.task-expand {
  width: 20px;
  cursor: pointer;
  user-select: none;
}

.table-cell {
  cursor: pointer;
  height: 100%;
  position: relative;
}

.task-input {
  width: 100%;
  border: 1px solid #ccc;
  border-radius: 4px;
  padding: 2px 4px;
}

.date-input {
  height: 24px;
  padding: 2px;
  border: 2px solid #4a8bf4;
}

.progress-input {
  width: 60px;
}

.editor-wrapper {
  position: relative;
  z-index: 999;
  width: 100%;
}

.floating-resource-editor {
  position: fixed;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  background-color: white;
  border: 1px solid #ccc;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  z-index: 1000;
  width: 300px;
  display: flex;
  flex-direction: column;
}

.resource-editor-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  border-bottom: 1px solid #eee;
  background-color: #f8f8f8;
  border-radius: 8px 8px 0 0;
}

.resource-editor-header h3 {
  margin: 0;
  font-size: 16px;
  color: #333;
}

.close-button {
  background: none;
  border: none;
  font-size: 20px;
  cursor: pointer;
  color: #999;
}

.close-button:hover {
  color: #333;
}

.resource-selector-container {
  max-height: 300px;
  overflow-y: auto;
  padding: 8px 0;
}

.resource-option {
  padding: 8px 16px;
  display: flex;
  align-items: center;
  cursor: pointer;
}

.resource-option:hover {
  background-color: #f5f5f5;
}

.resource-option.selected {
  background-color: #e6f7ff;
}

.resource-option input[type="checkbox"] {
  margin-right: 10px;
}

.resource-editor-footer {
  display: flex;
  justify-content: flex-end;
  padding: 12px 16px;
  border-top: 1px solid #eee;
  background-color: #f8f8f8;
  border-radius: 0 0 8px 8px;
}

.cancel-button, .save-button {
  padding: 6px 12px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  margin-left: 8px;
}

.cancel-button {
  background-color: #f0f0f0;
  border: 1px solid #d9d9d9;
  color: #333;
}

.save-button {
  background-color: #1890ff;
  border: 1px solid #1890ff;
  color: white;
}

.delete-button {
  background-color: #dc3545;
  border: 1px solid #dc3545;
  color: white;
  padding: 6px 12px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
}

.delete-button:hover {
  background-color: #c82333;
  border-color: #bd2130;
}

.spacer {
  flex: 1;
}

/* Task Dialog Styles */
.task-dialog-backdrop {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  z-index: 2000;
  display: flex;
  align-items: center;
  justify-content: center;
}

.task-dialog {
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  width: 600px;
  max-width: 90%;
  max-height: 90vh;
  display: flex;
  flex-direction: column;
}

.task-dialog-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px;
  border-bottom: 1px solid #eee;
  background-color: #f8f8f8;
  border-radius: 8px 8px 0 0;
}

.task-dialog-header h3 {
  margin: 0;
  font-size: 18px;
  color: #333;
}

.task-dialog-content {
  padding: 16px;
  overflow-y: auto;
  max-height: 60vh;
}

.task-dialog-footer {
  display: flex;
  justify-content: flex-end;
  padding: 16px;
  border-top: 1px solid #eee;
  background-color: #f8f8f8;
  border-radius: 0 0 8px 8px;
}

/* Tab Navigation */
.tab-navigation {
  display: flex;
  margin-bottom: 20px;
  border-bottom: 1px solid #eee;
}

.tab-button {
  padding: 8px 16px;
  background: none;
  border: none;
  cursor: pointer;
  font-size: 14px;
  color: #666;
  border-bottom: 2px solid transparent;
}

.tab-button.active {
  color: #1890ff;
  border-bottom: 2px solid #1890ff;
}

.tab-content {
  padding: 10px 0;
}

/* Form Styles */
.form-group {
  margin-bottom: 16px;
}

.form-row {
  display: flex;
  gap: 16px;
  margin-bottom: 16px;
}

.form-row .form-group {
  flex: 1;
  margin-bottom: 0;
}

label {
  display: block;
  margin-bottom: 6px;
  font-weight: 500;
  color: #333;
}

.form-control {
  width: 100%;
  padding: 8px 12px;
  border: 1px solid #d9d9d9;
  border-radius: 4px;
  font-size: 14px;
}

.resource-list {
  max-height: 150px;
  overflow-y: auto;
  border: 1px solid #d9d9d9;
  border-radius: 4px;
  padding: 8px;
}

.resource-checkbox {
  display: flex;
  align-items: center;
  padding: 6px 0;
}

.resource-checkbox input {
  margin-right: 8px;
}

.coming-soon {
  padding: 20px;
  color: #999;
  text-align: center;
  font-style: italic;
}

/* Status Badge in Task Dialog */
.status-badge {
  display: inline-block;
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 12px;
  margin-top: 8px;
  font-weight: 500;
}

.status-backlog {
  background-color: #f5f5f5;
  color: #616161;
}

.status-todo {
  background-color: #e3f2fd;
  color: #0d47a1;
}

.status-inProgress {
  background-color: #fff3e0;
  color: #e65100;
}

.status-review {
  background-color: #f3e5f5;
  color: #6a1b9a;
}

.status-done {
  background-color: #e8f5e9;
  color: #1b5e20;
}
</style>