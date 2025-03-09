<template>
  <div class="resource-manager">
    <div class="resource-header">
      <h2>Resource Management</h2>
      <div>
        <span class="resource-count">{{ resources.length }} resource{{ resources.length !== 1 ? 's' : '' }}</span>
        <button class="btn-add-resource" @click="showAddForm">Add Resource</button>
      </div>
    </div>
    
    <div class="resource-list-container">
      <div v-if="resources.length === 0" class="no-resources">
        No resources available. Add your first resource.
      </div>
      
      <div v-if="resources.length > 0" class="scroll-indicator">
        ↓ Scroll to see all resources ↓
      </div>
      
      <!-- Simplified layout with flex-wrap -->
      <div class="resources-grid">
        <!-- Regular resource cards -->
        <template v-for="resource in resources" :key="resource.id">
          <div 
            class="resource-card"
            :class="{ 'is-editing': editingResource && editingResource.id === resource.id }"
          >
            <div v-if="editingResource && editingResource.id === resource.id" class="resource-edit-form">
              <div class="form-header">
                <h3>Edit Resource</h3>
                <button class="btn-close" @click="cancelEdit">×</button>
              </div>
              
              <div class="form-body">
                <div class="form-row">
                  <label>Name:</label>
                  <input type="text" v-model="editingResource.name" placeholder="Full Name" />
                </div>
                
                <div class="form-row">
                  <label>Email:</label>
                  <input type="email" v-model="editingResource.email" placeholder="Email Address" />
                </div>
                
                <div class="form-row">
                  <label>Phone:</label>
                  <input type="tel" v-model="editingResource.phone" placeholder="Phone Number" />
                </div>
                
                <div class="form-row">
                  <label>Role:</label>
                  <input type="text" v-model="editingResource.role" placeholder="Job Title/Role" />
                </div>
                
                <div class="form-row">
                  <label>Bill Rate ($/h):</label>
                  <input type="number" v-model.number="editingResource.billRate" min="0" step="0.01" />
                </div>
                
                <div class="form-row">
                  <label>Availability (%):</label>
                  <input 
                    type="range" 
                    v-model.number="editingResource.availability" 
                    min="0" 
                    max="100" 
                    step="5"
                    class="availability-slider"
                  />
                  <span class="availability-value">{{ editingResource.availability }}%</span>
                </div>
                
                <div class="form-row">
                  <label>Profile Image URL:</label>
                  <input type="url" v-model="editingResource.imageUrl" placeholder="https://..." />
                </div>
                
                <div class="form-preview">
                  <div class="preview-image">
                    <img 
                      :src="editingResource.imageUrl || 'https://via.placeholder.com/150?text=No+Image'" 
                      alt="Profile preview"
                    />
                  </div>
                </div>
              </div>
              
              <div class="form-footer">
                <button class="btn-cancel" @click="cancelEdit">Cancel</button>
                <button class="btn-save" @click="saveEdit">Save Changes</button>
              </div>
            </div>
            
            <div v-else class="resource-display">
              <div class="resource-info">
                <div class="resource-avatar">
                  <img 
                    :src="resource.imageUrl || 'https://via.placeholder.com/150?text=No+Image'" 
                    :alt="resource.name"
                  />
                </div>
                <div class="resource-details">
                  <h3 class="resource-name">{{ resource.name }}</h3>
                  <div class="resource-role">{{ resource.role || 'No role specified' }}</div>
                  <div class="resource-meta">
                    <div v-if="resource.email" class="meta-item">
                      <span class="meta-icon">✉️</span> {{ resource.email }}
                    </div>
                    <div v-if="resource.phone" class="meta-item">
                      <span class="meta-icon">📱</span> {{ resource.phone }}
                    </div>
                  </div>
                </div>
              </div>
              
              <div class="resource-stats">
                <div class="stat-item">
                  <div class="stat-label">Bill Rate</div>
                  <div class="stat-value">${{ resource.billRate || 0 }}/h</div>
                </div>
                <div class="stat-item">
                  <div class="stat-label">Availability</div>
                  <div class="stat-value">{{ resource.availability || 0 }}%</div>
                  <div class="availability-bar">
                    <div 
                      class="availability-fill" 
                      :style="{ width: `${resource.availability || 0}%` }"
                      :class="getAvailabilityClass(resource.availability)"
                    ></div>
                  </div>
                </div>
              </div>
              
              <div class="resource-actions">
                <button class="btn-edit" @click="editResource(resource)">Edit</button>
                <button class="btn-delete" @click="confirmDelete(resource)">Delete</button>
              </div>
            </div>
          </div>
        </template>

        <!-- Add Resource Card -->
        <div class="resource-card add-resource-card" @click="showAddForm">
          <div class="add-resource-content">
            <div class="add-icon">+</div>
            <h3>Add New Resource</h3>
            <p>Click to add another team member</p>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Add Resource Modal -->
    <div v-if="showAddModal" class="modal-backdrop">
      <div class="modal-container resource-modal">
        <div class="modal-header">
          <h3>Add New Resource</h3>
          <button class="btn-close" @click="showAddModal = false">×</button>
        </div>
        <div class="modal-body">
          <div class="form-row">
            <label>Name:</label>
            <input type="text" v-model="newResource.name" placeholder="Full Name" required />
          </div>
          
          <div class="form-row">
            <label>Email:</label>
            <input type="email" v-model="newResource.email" placeholder="Email Address" />
          </div>
          
          <div class="form-row">
            <label>Phone:</label>
            <input type="tel" v-model="newResource.phone" placeholder="Phone Number" />
          </div>
          
          <div class="form-row">
            <label>Role:</label>
            <input type="text" v-model="newResource.role" placeholder="Job Title/Role" />
          </div>
          
          <div class="form-row">
            <label>Bill Rate ($/h):</label>
            <input type="number" v-model.number="newResource.billRate" min="0" step="0.01" />
          </div>
          
          <div class="form-row">
            <label>Availability (%):</label>
            <input 
              type="range" 
              v-model.number="newResource.availability" 
              min="0" 
              max="100" 
              step="5"
              class="availability-slider"
            />
            <span class="availability-value">{{ newResource.availability }}%</span>
          </div>
          
          <div class="form-row">
            <label>Profile Image URL:</label>
            <input type="url" v-model="newResource.imageUrl" placeholder="https://..." />
          </div>
          
          <div class="form-preview">
            <div class="preview-image">
              <img 
                :src="newResource.imageUrl || 'https://via.placeholder.com/150?text=No+Image'" 
                alt="Profile preview"
              />
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn-cancel" @click="showAddModal = false">Cancel</button>
          <button class="btn-save" @click="addResource">Create Resource</button>
        </div>
      </div>
    </div>
    
    <!-- Delete Confirmation Modal -->
    <div v-if="resourceToDelete" class="modal-backdrop">
      <div class="modal-container delete-modal">
        <div class="modal-header">
          <h3>Delete Resource</h3>
        </div>
        <div class="modal-body">
          <p>Are you sure you want to delete <strong>{{ resourceToDelete.name }}</strong>?</p>
          <p class="warning-text">
            <strong>Warning:</strong> This will remove the resource from all tasks it is assigned to.
          </p>
        </div>
        <div class="modal-footer">
          <button class="btn-cancel" @click="cancelDelete">Cancel</button>
          <button class="btn-danger" @click="deleteResource">Delete</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  props: {
    resources: {
      type: Array,
      required: true
    }
  },
  data() {
    return {
      showAddModal: false,
      newResource: this.getEmptyResource(),
      editingResource: null,
      resourceToDelete: null
    };
  },
  methods: {
    getEmptyResource() {
      return {
        name: '',
        email: '',
        phone: '',
        role: '',
        billRate: 0,
        availability: 100,
        imageUrl: ''
      };
    },
    
    getAvailabilityClass(availability) {
      if (!availability) return 'low';
      if (availability < 30) return 'low';
      if (availability < 70) return 'medium';
      return 'high';
    },
    
    showAddForm() {
      this.newResource = this.getEmptyResource();
      this.showAddModal = true;
    },
    
    addResource() {
      if (!this.newResource.name) {
        alert('Resource name is required');
        return;
      }
      
      // Create a new resource with a unique ID
      const newId = this.resources.length > 0 
        ? Math.max(...this.resources.map(r => r.id)) + 1 
        : 1;
        
      const resourceToAdd = {
        id: newId,
        ...this.newResource
      };
      
      // Emit event to add the resource
      this.$emit('add', resourceToAdd);
      
      // Close modal and reset form
      this.showAddModal = false;
      this.newResource = this.getEmptyResource();
    },
    
    editResource(resource) {
      // Create a copy of the resource to edit
      this.editingResource = { ...resource };
    },
    
    saveEdit() {
      if (!this.editingResource.name) {
        alert('Resource name is required');
        return;
      }
      
      // Emit event to update the resource
      this.$emit('update', this.editingResource);
      
      // Exit edit mode
      this.editingResource = null;
    },
    
    cancelEdit() {
      this.editingResource = null;
    },
    
    confirmDelete(resource) {
      this.resourceToDelete = resource;
    },
    
    deleteResource() {
      // Emit event to delete the resource
      this.$emit('delete', this.resourceToDelete.id);
      
      // Close modal
      this.resourceToDelete = null;
    },
    
    cancelDelete() {
      this.resourceToDelete = null;
    }
  }
};
</script>

<style>
.resource-manager {
  padding: 20px;
  background-color: #f9fafb;
  height: 100%;
  width: 100%;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  box-sizing: border-box; /* Ensure padding is included in width calculation */
}

.resource-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  padding-bottom: 15px;
  border-bottom: 1px solid #e5e7eb;
  flex-shrink: 0; /* Prevent header from shrinking */
}

.resource-header h2 {
  margin: 0;
  font-size: 22px;
  color: #1f2937;
}

.resource-count {
  margin-right: 15px;
  font-size: 14px;
  color: #6b7280;
  font-weight: 500;
}

.btn-add-resource {
  padding: 8px 16px;
  background-color: #10b981;
  color: white;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
}

.btn-add-resource:hover {
  background-color: #059669;
}

.resource-list-container {
  flex: 1;
  overflow-y: auto;
  min-height: 0; /* Important for flexbox to allow scrolling */
  padding: 0 10px 20px 0; /* Right padding for scrollbar, bottom for spacing */
  
  /* Custom scrollbar styling */
  scrollbar-width: thin; /* Firefox */
  scrollbar-color: #cbd5e1 transparent; /* Firefox */
}

.resources-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); /* Responsive grid */
  gap: 20px;
  padding-top: 10px;
  width: 100%; /* Ensure it takes up full width */
  box-sizing: border-box;
}

/* Webkit scrollbar customization (Chrome, Safari) */
.resource-list-container::-webkit-scrollbar {
  width: 8px;
}

.resource-list-container::-webkit-scrollbar-track {
  background: #f1f5f9;
  border-radius: 4px;
}

.resource-list-container::-webkit-scrollbar-thumb {
  background-color: #cbd5e1;
  border-radius: 4px;
}

.resource-list-container::-webkit-scrollbar-thumb:hover {
  background-color: #94a3b8;
}

.scroll-indicator {
  position: sticky;
  top: 0;
  left: 0;
  right: 0;
  text-align: center;
  color: #6b7280;
  font-size: 12px;
  background-color: rgba(255, 255, 255, 0.9);
  padding: 8px 0;
  margin-bottom: 15px;
  border-radius: 4px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  z-index: 10;
  animation: fadeOut 3s forwards;
  animation-delay: 4s;
  pointer-events: none;
  grid-column: 1 / -1; /* Span all columns in the grid */
  width: 100%; /* Ensure full width */
}

@keyframes fadeOut {
  from { opacity: 1; }
  to { opacity: 0; }
}

.no-resources {
  grid-column: 1 / -1;
  text-align: center;
  padding: 40px;
  background-color: white;
  border-radius: 6px;
  border: 1px dashed #d1d5db;
  color: #6b7280;
  font-size: 16px;
}

.resource-card {
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  overflow: hidden;
  transition: all 0.3s ease;
  position: relative; /* For positioning child elements */
  min-width: 0; /* Prevent overflow in grid cells */
}

.resource-card:hover {
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.12);
  transform: translateY(-2px);
}

/* Add Resource Card Styles */
.add-resource-card {
  background-color: #f9fafb;
  border: 2px dashed #e5e7eb;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s ease;
}

.add-resource-card:hover {
  background-color: #f3f4f6;
  border-color: #d1d5db;
  transform: translateY(-2px);
}

.add-resource-content {
  text-align: center;
  padding: 30px 20px;
}

.add-icon {
  font-size: 32px;
  width: 60px;
  height: 60px;
  line-height: 56px;
  border-radius: 50%;
  background-color: #eef2ff;
  color: #6366f1;
  margin: 0 auto 15px;
  border: 2px solid #e0e7ff;
}

.add-resource-content h3 {
  margin: 0 0 8px;
  color: #4f46e5;
  font-size: 18px;
}

.add-resource-content p {
  margin: 0;
  color: #6b7280;
  font-size: 14px;
}

.resource-card.is-editing {
  box-shadow: 0 0 0 2px #4a8bf4;
}

.resource-display {
  display: flex;
  flex-direction: column;
}

.resource-info {
  display: flex;
  padding: 16px;
  border-bottom: 1px solid #f3f4f6;
}

.resource-avatar {
  width: 60px;
  height: 60px;
  border-radius: 50%;
  overflow: hidden;
  flex-shrink: 0;
  margin-right: 15px;
  border: 2px solid #e5e7eb;
}

.resource-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.resource-details {
  flex: 1;
}

.resource-name {
  margin: 0 0 5px 0;
  font-size: 16px;
  color: #111827;
}

.resource-role {
  font-size: 14px;
  color: #4b5563;
  margin-bottom: 8px;
}

.resource-meta {
  font-size: 12px;
  color: #6b7280;
}

.meta-item {
  display: flex;
  align-items: center;
  margin-bottom: 4px;
}

.meta-icon {
  margin-right: 6px;
  font-size: 14px;
}

.resource-stats {
  display: flex;
  padding: 12px 16px;
  background-color: #f9fafb;
  border-bottom: 1px solid #f3f4f6;
}

.stat-item {
  flex: 1;
}

.stat-label {
  font-size: 11px;
  color: #6b7280;
  margin-bottom: 4px;
}

.stat-value {
  font-size: 14px;
  font-weight: 600;
  color: #374151;
  margin-bottom: 5px;
}

.availability-bar {
  height: 6px;
  background-color: #e5e7eb;
  border-radius: 3px;
  overflow: hidden;
}

.availability-fill {
  height: 100%;
  border-radius: 3px;
}

.availability-fill.low {
  background-color: #ef4444;
}

.availability-fill.medium {
  background-color: #f59e0b;
}

.availability-fill.high {
  background-color: #10b981;
}

.resource-actions {
  display: flex;
  padding: 12px 16px;
  justify-content: flex-end;
  gap: 8px;
}

.btn-edit {
  padding: 6px 12px;
  background-color: #e5e7eb;
  color: #374151;
  border: none;
  border-radius: 4px;
  font-size: 13px;
  cursor: pointer;
  transition: background-color 0.2s;
}

.btn-edit:hover {
  background-color: #d1d5db;
}

.btn-delete {
  padding: 6px 12px;
  background-color: rgba(239, 68, 68, 0.1);
  color: #ef4444;
  border: none;
  border-radius: 4px;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-delete:hover {
  background-color: #ef4444;
  color: white;
}

/* Form Styles */
.resource-edit-form {
  padding: 16px;
}

.form-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.form-header h3 {
  margin: 0;
  font-size: 16px;
  color: #111827;
}

.btn-close {
  background: none;
  border: none;
  font-size: 20px;
  color: #6b7280;
  cursor: pointer;
  padding: 0;
  margin: 0;
}

.form-body {
  margin-bottom: 16px;
}

.form-row {
  margin-bottom: 12px;
}

.form-row label {
  display: block;
  margin-bottom: 4px;
  font-size: 13px;
  color: #4b5563;
}

.form-row input {
  width: 100%;
  padding: 8px;
  border: 1px solid #d1d5db;
  border-radius: 4px;
  font-size: 14px;
}

.form-row input:focus {
  outline: none;
  border-color: #4a8bf4;
  box-shadow: 0 0 0 2px rgba(74, 139, 244, 0.15);
}

.availability-slider {
  flex: 1;
  margin-right: 10px;
}

.availability-value {
  font-size: 14px;
  font-weight: 500;
  color: #374151;
  width: 40px;
  text-align: right;
}

.form-preview {
  display: flex;
  justify-content: center;
  margin: 16px 0;
}

.preview-image {
  width: 100px;
  height: 100px;
  border-radius: 50%;
  overflow: hidden;
  border: 2px solid #e5e7eb;
}

.preview-image img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.form-footer {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}

/* Modal Styles */
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
  z-index: 1000;
}

.modal-container {
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.2);
  max-height: 90vh;
  overflow-y: auto;
}

.resource-modal {
  width: 500px;
  max-width: 90vw;
}

.delete-modal {
  width: 400px;
  max-width: 90vw;
}

.modal-header {
  padding: 16px;
  background-color: #f8f9fa;
  border-bottom: 1px solid #e5e7eb;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.modal-header h3 {
  margin: 0;
  font-size: 18px;
  color: #111827;
}

.modal-body {
  padding: 16px;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  padding: 16px;
  background-color: #f8f9fa;
  border-top: 1px solid #e5e7eb;
  gap: 8px;
}

.btn-cancel {
  padding: 8px 16px;
  background-color: #e5e7eb;
  color: #374151;
  border: none;
  border-radius: 4px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
}

.btn-cancel:hover {
  background-color: #d1d5db;
}

.btn-save {
  padding: 8px 16px;
  background-color: #3b82f6;
  color: white;
  border: none;
  border-radius: 4px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
}

.btn-save:hover {
  background-color: #2563eb;
}

.btn-danger {
  padding: 8px 16px;
  background-color: #ef4444;
  color: white;
  border: none;
  border-radius: 4px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
}

.btn-danger:hover {
  background-color: #dc2626;
}

.warning-text {
  padding: 12px;
  background-color: #fff3cd;
  border-left: 4px solid #ffc107;
  color: #856404;
  margin: 16px 0;
  border-radius: 4px;
}
</style>