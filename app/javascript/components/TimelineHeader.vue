<template>
  <div class="timeline-header">
    <!-- Top row - always shows months -->
    <div class="month-row">
      <div 
        v-for="(month, index) in months" 
        :key="'month-' + index"
        class="month-cell"
        :style="{ width: month.width + 'px' }"
      >
        {{ month.label }}
      </div>
    </div>
    
    <!-- Second row - shows days, weeks, or nothing depending on mode -->
    <div v-if="timelineMode === 'day'" class="day-row">
      <div 
        v-for="(day, index) in days" 
        :key="'day-' + index"
        class="day-cell"
        :style="{ width: dayWidth + 'px' }"
        :class="{ 'weekend': day.isWeekend }"
      >
        {{ day.dayOfMonth }}
      </div>
    </div>
    
    <!-- Week row displayed when in week mode -->
    <div v-else-if="timelineMode === 'week'" class="week-row">
      <div 
        v-for="(week, index) in weeks" 
        :key="'week-' + index"
        class="week-cell"
        :style="{ width: week.width + 'px' }"
      >
        <span class="week-number">W{{ week.weekNumber }}</span>
      </div>
    </div>
    
    <!-- For month mode, we don't need a third row as the month row is sufficient -->
  </div>
</template>

<script>
export default {
  name: 'TimelineHeader',
  props: {
    startDate: {
      type: Date,
      required: true
    },
    endDate: {
      type: Date,
      required: true
    },
    zoomLevel: {
      type: Number,
      default: 1
    },
    timelineMode: {
      type: String,
      default: 'day',
      validator: function(value) {
        return ['day', 'week', 'month'].indexOf(value) !== -1
      }
    }
  },
  computed: {
    // Width of a single day, week, or month column based on mode
    dayWidth() {
      if (this.timelineMode === 'day') {
        return 24 * this.zoomLevel;
      } else if (this.timelineMode === 'week') {
        return 7 * 24 * this.zoomLevel; // 7 days per week
      } else {
        // For month view, we don't show individual days
        return 0;
      }
    },
    
    // Width of a week column
    weekWidth() {
      return 7 * 24 * this.zoomLevel; // 7 days per week
    },
    days() {
      const result = [];
      const dayCount = this.getDayCount();
      
      const currentDate = new Date(this.startDate);
      
      for (let i = 0; i < dayCount; i++) {
        const isWeekend = currentDate.getDay() === 0 || currentDate.getDay() === 6;
        
        result.push({
          date: new Date(currentDate),
          dayOfMonth: currentDate.getDate(),
          isWeekend
        });
        
        currentDate.setDate(currentDate.getDate() + 1);
      }
      
      return result;
    },
    // Weeks array for week mode
    weeks() {
      const result = [];
      const days = this.days;
      
      if (days.length === 0) return result;
      
      let currentMonth = days[0].date.getMonth();
      let currentYear = days[0].date.getFullYear();
      let currentWeek = 1; // Start with week 1 for each month
      let startIdx = 0;
      let lastDayOfWeek = 6; // 0 = Sunday, 6 = Saturday
      
      for (let i = 0; i < days.length; i++) {
        const date = days[i].date;
        const month = date.getMonth();
        const year = date.getFullYear();
        const dayOfWeek = date.getDay();
        
        // If month or year changes, reset week counter
        if (month !== currentMonth || year !== currentYear) {
          // Process the last week of the previous month
          const daysInWeek = (i - startIdx);
          const width = daysInWeek * 24 * this.zoomLevel;
          
          result.push({
            weekNumber: currentWeek,
            year: currentYear,
            month: currentMonth,
            width: width
          });
          
          // Reset for the new month
          currentMonth = month;
          currentYear = year;
          currentWeek = 1; // Start with week 1 for the new month
          startIdx = i;
        }
        // If we've reached the last day of the week (Saturday) or the end of days
        else if (dayOfWeek === lastDayOfWeek || i === days.length - 1) {
          // Calculate width based on number of days
          const daysInWeek = (i - startIdx) + 1; // +1 to include the current day
          const width = daysInWeek * 24 * this.zoomLevel;
          
          result.push({
            weekNumber: currentWeek,
            year: currentYear,
            month: currentMonth,
            width: width
          });
          
          // Update for the next week
          startIdx = i + 1; // Start from the next day
          currentWeek++; // Increment week counter within the month
        }
      }
      
      return result;
    },
    
    months() {
      const result = [];
      const days = this.days;
      
      if (days.length === 0) return result;
      
      let currentMonth = days[0].date.getMonth();
      let currentYear = days[0].date.getFullYear();
      let startIdx = 0;
      
      for (let i = 0; i < days.length; i++) {
        const month = days[i].date.getMonth();
        const year = days[i].date.getFullYear();
        
        if (month !== currentMonth || year !== currentYear || i === days.length - 1) {
          const width = (i - startIdx) * (24 * this.zoomLevel); // Use raw day width calculation
          
          result.push({
            month: currentMonth,
            year: currentYear,
            label: this.getMonthLabel(currentMonth, currentYear),
            width: i === days.length - 1 ? width + (24 * this.zoomLevel) : width
          });
          
          startIdx = i;
          currentMonth = month;
          currentYear = year;
        }
      }
      
      return result;
    }
  },
  methods: {
    getDayCount() {
      return Math.ceil((this.endDate - this.startDate) / (1000 * 60 * 60 * 24)) + 1;
    },
    getMonthLabel(month, year) {
      const date = new Date(year, month, 1);
      return date.toLocaleString('default', { month: 'short', year: 'numeric' });
    },
    // Get ISO week number from date
    getWeekNumber(date) {
      const d = new Date(date);
      d.setHours(0, 0, 0, 0);
      // Thursday in current week decides the year
      d.setDate(d.getDate() + 3 - (d.getDay() + 6) % 7);
      // January 4 is always in week 1
      const week1 = new Date(d.getFullYear(), 0, 4);
      // Adjust to Thursday in week 1 and count number of weeks from date to week1
      return 1 + Math.round(((d.getTime() - week1.getTime()) / 86400000 - 3 + (week1.getDay() + 6) % 7) / 7);
    }
  }
}
</script>

<style>
.timeline-header {
  position: sticky;
  top: 0;
  background-color: #f5f5f5;
  z-index: 20;
}

.month-row, .day-row {
  display: flex;
  height: 24px;
  border-bottom: 1px solid #ddd;
}

.month-cell {
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: bold;
  border-right: 1px solid #ddd;
  user-select: none;
}

.day-cell {
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  border-right: 1px solid #eee;
  font-size: 12px;
  user-select: none;
}

.day-cell.weekend {
  background-color: #f0f0f0;
}

/* Week row styling */
.week-row {
  display: flex;
  height: 24px;
  border-bottom: 1px solid #ddd;
}

.week-cell {
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  border-right: 1px solid #ddd;
  font-size: 12px;
  user-select: none;
  background-color: #f8f8f8;
}

.week-number {
  font-weight: 500;
}
</style>