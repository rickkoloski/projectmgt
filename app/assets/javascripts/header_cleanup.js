// Header Cleanup Script - Global cleaner for persistent headers
// This script runs on every page load

// Immediate cleanup function
(function cleanupProjectHeader() {
  console.log("Header cleanup script running");
  
  // Find and remove any project headers
  const projectHeaders = document.querySelectorAll('#harmoniq-project-header, .project-header');
  projectHeaders.forEach(header => {
    console.log('Global cleanup: removing project header');
    if (header && header.parentNode) {
      header.parentNode.removeChild(header);
    }
  });
  
  // Clean up stale style elements
  const styleIds = ['gantt-custom-styles', 'gantt-bar-styles'];
  styleIds.forEach(function(id) {
    const el = document.getElementById(id);
    if (el) el.parentNode.removeChild(el);
  });
  
  // Clear any global data
  window.initialData = null;
})();

// Wait for DOMContentLoaded
document.addEventListener('DOMContentLoaded', function() {
  console.log("DOM loaded - running secondary cleanup");
  
  // Check again after DOM is fully loaded
  const projectHeaders = document.querySelectorAll('#harmoniq-project-header, .project-header');
  projectHeaders.forEach(header => {
    // Only clean up if we're not on the projects page
    if (window.location.pathname.indexOf('/projects/') === -1) {
      console.log('DOM loaded cleanup: removing project header');
      if (header && header.parentNode) {
        header.parentNode.removeChild(header);
      }
    }
  });
  
  // Set up periodic checks
  let checkCount = 0;
  const checkInterval = setInterval(function() {
    const headers = document.querySelectorAll('#harmoniq-project-header, .project-header');
    if (headers.length > 0 && window.location.pathname.indexOf('/projects/') === -1) {
      console.log('Interval cleanup: removing project headers');
      headers.forEach(header => {
        if (header && header.parentNode) {
          header.parentNode.removeChild(header);
        }
      });
    }
    
    // Stop checking after 5 rounds
    if (++checkCount >= 5) {
      clearInterval(checkInterval);
    }
  }, 1000);
});

// Handle navigation events
window.addEventListener('beforeunload', function() {
  console.log('Navigation detected - cleaning up project headers');
  
  // Final cleanup before navigation
  const projectHeaders = document.querySelectorAll('#harmoniq-project-header, .project-header');
  projectHeaders.forEach(header => {
    if (header && header.parentNode) {
      header.parentNode.removeChild(header);
    }
  });
});

// Expose a global cleanup function that can be called from anywhere
window.cleanupProjectHeader = function() {
  console.log('Manual cleanup triggered');
  
  const projectHeaders = document.querySelectorAll('#harmoniq-project-header, .project-header');
  projectHeaders.forEach(header => {
    if (header && header.parentNode) {
      header.parentNode.removeChild(header);
    }
  });
};

// NEW FUNCTION: Simulate a click on the "Back to Dashboard" button
window.goToDashboardSafely = function() {
  // Look for the Back to Dashboard button that we know works correctly
  const dashboardButton = document.querySelector('.btn-back');
  
  if (dashboardButton) {
    console.log('Found Back to Dashboard button, clicking it');
    dashboardButton.click();
    return true;
  }
  
  // If we didn't find the button, try direct navigation
  console.log('Back to Dashboard button not found, navigating directly');
  window.location.href = '/dashboard';
  return false;
};