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
        
        // From task position
        const fromStartDate = new Date(fromTask.startDate);
        const fromEndDate = new Date(fromTask.endDate);
        const fromDaysDiff = Math.floor((fromStartDate - this.startDate) / (1000 * 60 * 60 * 24));
        const fromDuration = Math.ceil((fromEndDate - fromStartDate) / (1000 * 60 * 60 * 24)) + 1;
        const fromLeft = fromDaysDiff * dayWidth;
        const fromWidth = fromDuration * dayWidth;
        const fromRowIndex = typeof fromTask.rowIndex === 'number' ? fromTask.rowIndex : 0;
        // Apply vertical positioning correction (adding 54px = 1.5 * rowHeight)
        const verticalOffset = 54; // 1.5 * rowHeight(36)
        const fromTop = (36 * fromRowIndex + 15) + verticalOffset; // center vertically + offset
        
        // To task position
        const toStartDate = new Date(toTask.startDate);
        const toEndDate = new Date(toTask.endDate);
        const toDaysDiff = Math.floor((toStartDate - this.startDate) / (1000 * 60 * 60 * 24));
        const toDuration = Math.ceil((toEndDate - toStartDate) / (1000 * 60 * 60 * 24)) + 1;
        const toLeft = toDaysDiff * dayWidth;
        const toWidth = toDuration * dayWidth;
        const toRowIndex = typeof toTask.rowIndex === 'number' ? toTask.rowIndex : 0;
        const toTop = (36 * toRowIndex + 15) + verticalOffset; // center vertically + offset
        
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
        
        // Create the path with improved routing for closely positioned tasks
        let path;
        
        // Calculate horizontal distance between points
        const horizontalDistance = Math.abs(endX - startX);
        const minSeparationForStandardPath = 40; // minimum pixels for standard path
        
        if (horizontalDistance < minSeparationForStandardPath) {
          // Use an "S" shaped path for closely positioned tasks
          // This is the MS Project style orthogonal "S" routing
          const extendRight = 20; // How far to extend right from start point
          const backOffset = 10; // How far to go back from the target point
          
          // We need to be precise about the midpoint position
          // Explicitly calculate the position between task bars
          // The row height is 36px, and the space we want is between the task bars
          
          // Position the middle segment exactly 2.5px above the midpoint
          // This small adjustment should place it perfectly in the whitespace
          const verticalMidPoint = (startY + endY) / 2 - 2.5;
          
          path = `M ${startX} ${startY} 
                  H ${startX + extendRight} 
                  V ${verticalMidPoint} 
                  H ${endX - backOffset} 
                  V ${endY} 
                  H ${endX}`;
        } else {
          // Standard path for normally separated tasks
          const midX = (startX + endX) / 2;
          path = `M ${startX} ${startY} H ${midX} V ${endY} H ${endX}`;
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
  z-index: 5; /* Keep as low as possible, same as task bars */
}

.dependency-path {
  fill: none;
  stroke: rgba(74, 144, 226, 0.7); /* Slightly transparent blue */
  stroke-width: 2px;
  stroke-dasharray: 4 3; /* Slightly wider gaps */
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