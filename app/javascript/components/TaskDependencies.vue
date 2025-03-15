<template>
  <svg class="dependencies-svg">
    <g v-for="(dep, index) in parsedDependencies" :key="'dep-' + index">
      <!-- Draw the dependency path -->
      <path 
        :d="dep.path" 
        :class="['dependency-path', { 'selected': selectedIndex === index }]"
        @click.stop="selectDependency(index)"
      />
      
      <!-- Debug markers at connection points -->
      <circle 
        v-if="debug"
        :cx="dep.startX" 
        :cy="dep.startY" 
        r="5" 
        fill="red" 
        stroke="white"
        stroke-width="1"
      />
      <circle 
        v-if="debug"
        :cx="dep.endX" 
        :cy="dep.endY" 
        r="5" 
        fill="green" 
        stroke="white"
        stroke-width="1"
      />
    </g>
  </svg>
</template>

<script>
export default {
  name: 'TaskDependencies',
  props: {
    tasks: {
      type: Array,
      required: true
    },
    startDate: {
      type: Date,
      required: true
    },
    zoomLevel: {
      type: Number,
      default: 1
    },
    dependencies: {
      type: Array,
      default: () => []
    },
    selectedDependencyIndex: {
      type: Number,
      default: -1
    }
  },
  data() {
    return {
      debug: false, // Set to false to hide debug markers
      selectedIndex: -1, // -1 means no dependency selected
    }
  },
  watch: {
    selectedDependencyIndex(newVal) {
      // Update the internal state when the prop changes
      this.selectedIndex = newVal;
    }
  },
  mounted() {
    // Initialize the internal state with the prop value
    this.selectedIndex = this.selectedDependencyIndex;
  },
  
  // Add watcher for zoom level to force redraw of dependencies
  watch: {
    selectedDependencyIndex(newVal) {
      // Update the internal state when the prop changes
      this.selectedIndex = newVal;
    },
    zoomLevel() {
      // Force reactivity update when zoom level changes
      this.$forceUpdate();
    }
  },
  computed: {
    parsedDependencies() {
      // Key with zoom level to trigger recalculation on zoom change
      const zoomKey = this.zoomLevel;
      
      return this.dependencies.map(dep => {
        // Find the tasks
        const fromTask = this.tasks.find(task => task.id === dep.from);
        const toTask = this.tasks.find(task => task.id === dep.to);
        
        if (!fromTask || !toTask) return null;
        
        // Calculate positions based on task data
        const dayWidth = 24 * this.zoomLevel;
        const rowHeight = 36;
        
        // Helper function to safely create a date
        const safeDate = (dateString) => {
          if (!dateString) return new Date(); // Default to today if missing
          
          try {
            const date = new Date(dateString);
            // Check if the date is valid
            if (isNaN(date.getTime())) {
              console.warn(`Invalid date: ${dateString}, using today's date`);
              return new Date();
            }
            return date;
          } catch (e) {
            console.warn(`Error parsing date: ${dateString}`, e);
            return new Date();
          }
        };
        
        // Helper function to safely calculate days difference
        const safeDaysDiff = (date1, date2) => {
          try {
            return Math.floor((date1 - date2) / (1000 * 60 * 60 * 24));
          } catch (e) {
            console.warn('Error calculating days difference:', e);
            return 0;
          }
        };
        
        // From task position - with error handling
        const fromStartDate = safeDate(fromTask.startDate);
        const fromEndDate = safeDate(fromTask.endDate || fromTask.dueDate || fromTask.startDate);
        const fromDaysDiff = safeDaysDiff(fromStartDate, this.startDate);
        
        // Make sure fromDuration is at least 1 day
        let fromDuration;
        try {
          fromDuration = Math.max(1, Math.ceil((fromEndDate - fromStartDate) / (1000 * 60 * 60 * 24)) + 1);
        } catch (e) {
          console.warn('Error calculating duration:', e);
          fromDuration = 1;
        }
        
        const fromLeft = fromDaysDiff * dayWidth;
        const fromWidth = fromDuration * dayWidth;
        const fromRowIndex = typeof fromTask.rowIndex === 'number' ? fromTask.rowIndex : 0;
        const fromTop = (rowHeight * fromRowIndex) + (rowHeight / 2); // center vertically in the row
        
        // To task position - with error handling
        const toStartDate = safeDate(toTask.startDate);
        const toEndDate = safeDate(toTask.endDate || toTask.dueDate || toTask.startDate);
        const toDaysDiff = safeDaysDiff(toStartDate, this.startDate);
        
        // Make sure toDuration is at least 1 day
        let toDuration;
        try {
          toDuration = Math.max(1, Math.ceil((toEndDate - toStartDate) / (1000 * 60 * 60 * 24)) + 1);
        } catch (e) {
          console.warn('Error calculating duration:', e);
          toDuration = 1;
        }
        
        const toLeft = toDaysDiff * dayWidth;
        const toWidth = toDuration * dayWidth;
        const toRowIndex = typeof toTask.rowIndex === 'number' ? toTask.rowIndex : 0;
        const toTop = (rowHeight * toRowIndex) + (rowHeight / 2); // center vertically in the row
        
        // Determine connection points based on dependency type
        let startX, startY, endX, endY;
        
        if (dep.fromType === 'start') {
          startX = fromLeft;
          startY = fromTop;
        } else { // 'end'
          startX = fromLeft + fromWidth;
          startY = fromTop;
        }
        
        if (dep.toType === 'start') {
          endX = toLeft;
          endY = toTop;
        } else { // 'end'
          endX = toLeft + toWidth;
          endY = toTop;
        }
        
        // Create the path with consistent S-shaped routing
        let path;
        
        // We need to create a path that:
        // 1. Exits the source task in a logical direction based on dependency type
        // 2. Routes in an S shape through open space
        // 3. Enters the target task from a logical direction
        
        // Constants for path generation
        const extendRight = 20; // Extension from start point
        const backOffset = 10; // Offset from end point
        const verticalMidPoint = (startY + endY) / 2; // Middle point between tasks
        
        // Determine if we're dealing with a finish-to-start dependency (most common)
        const isFinishToStart = dep.fromType === 'end' && dep.toType === 'start';
        
        if (isFinishToStart) {
          // For finish-to-start: always create a clean right-to-left S path
          path = `M ${startX} ${startY} 
                  H ${startX + extendRight} 
                  V ${verticalMidPoint} 
                  H ${endX - backOffset} 
                  V ${endY} 
                  H ${endX}`;
        } else if (dep.fromType === 'end' && dep.toType === 'end') {
          // For finish-to-finish: exit right, enter left
          path = `M ${startX} ${startY} 
                  H ${startX + extendRight} 
                  V ${verticalMidPoint} 
                  H ${toLeft - backOffset} 
                  V ${endY} 
                  H ${endX}`;
        } else if (dep.fromType === 'start' && dep.toType === 'start') {
          // For start-to-start: exit right from start point, enter left
          // This ensures we don't cross over task bars
          const fromRightSide = fromLeft + fromWidth;
          path = `M ${startX} ${startY} 
                  H ${fromRightSide + 10} 
                  V ${fromTop - 15} 
                  H ${endX - backOffset * 2} 
                  V ${endY} 
                  H ${endX}`;
        } else if (dep.fromType === 'start' && dep.toType === 'end') {
          // For start-to-finish: exit right from start point, enter left
          const fromRightSide = fromLeft + fromWidth;
          path = `M ${startX} ${startY} 
                  H ${fromRightSide + 10} 
                  V ${fromTop - 15} 
                  H ${toLeft - backOffset} 
                  V ${endY} 
                  H ${endX}`;
        } else {
          // Default fallback path for any unforeseen combinations
          // Use the same pattern as finish-to-start as it's most common
          console.warn('Unknown dependency type combination:', dep.fromType, dep.toType);
          path = `M ${startX} ${startY} 
                  H ${startX + extendRight} 
                  V ${verticalMidPoint} 
                  H ${endX - backOffset} 
                  V ${endY} 
                  H ${endX}`;
        }
        
        // Validate that all coordinates are valid numbers before returning
        if (isNaN(startX) || isNaN(startY) || isNaN(endX) || isNaN(endY)) {
          console.warn('Invalid coordinates detected for dependency:', {
            from: dep.from,
            to: dep.to,
            startX,
            startY,
            endX,
            endY
          });
          
          // Return null so this dependency is filtered out
          return null;
        }
        
        return {
          startX,
          startY,
          endX,
          endY,
          path
        };
      }).filter(Boolean);
    }
  },
  methods: {
    // Method to update deps when task positions change
    updateDependencyLines() {
      // This would be called when tasks are moved
      // Currently handled by the computed property
    },
    
    // Select a dependency when clicked
    selectDependency(index, event) {
      // Toggle selection if clicking the already selected dependency
      this.selectedIndex = (this.selectedIndex === index) ? -1 : index;
      // Emit event to parent with the event object
      this.$emit('select', index, this.selectedIndex === index ? this.dependencies[index] : null, event);
    }
  }
}
</script>

<style>
.dependencies-svg {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  pointer-events: none; /* Keep as 'none' to allow clicks to pass through to task bars */
  z-index: 5;
  overflow: visible; /* Ensure lines aren't cut off */
}

.dependency-path {
  fill: none;
  stroke: rgba(74, 144, 226, 0.8); /* Match connection point color */
  stroke-width: 2px;
  stroke-dasharray: 4 3;
  pointer-events: stroke; /* Make only the stroke of the line clickable */
  cursor: pointer;
  stroke-linecap: round; /* Makes the line easier to click */
}

.dependency-path.selected {
  stroke: #dc3545; /* Red color for selected dependency */
  stroke-width: 3px;
  stroke-dasharray: none; /* Remove dash pattern */
}
</style>