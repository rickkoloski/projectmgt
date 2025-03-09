<template>
  <div class="timeline-header">
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
    <div class="day-row">
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
    }
  },
  computed: {
    dayWidth() {
      return 24 * this.zoomLevel;
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
          const width = (i - startIdx) * this.dayWidth;
          
          result.push({
            month: currentMonth,
            year: currentYear,
            label: this.getMonthLabel(currentMonth, currentYear),
            width: i === days.length - 1 ? width + this.dayWidth : width
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
</style>