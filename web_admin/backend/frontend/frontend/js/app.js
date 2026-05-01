// Main entry point for Admin Dashboard
import { initAuth } from './auth.js';
import { initNavigation, showLogin, showDashboard } from './ui.js';
import { loadAllData } from './data.js';
import { initUserSearch } from './users.js';
import { initScanSearch } from './scans.js';
import { initAdvancedFilters } from './filters.js';
import { initBulkActions } from './bulk-actions.js';
import { initThemeToggle } from './theme-toggle.js';
import { exportUsers, exportScans, exportAllData } from './export.js';
import { loadUserAnalytics } from './user-analytics.js';
import { initAlerts } from './alerts.js';
import { loadMobileStats } from './mobile-integration.js';
import { initPerformanceMonitoring } from './performance-monitoring.js';
import { loadUserSegments } from './user-segmentation.js';
import { checkExistingToken } from './config.js';
import { refreshAlerts } from './alerts.js';
import { refreshPerformance } from './performance-monitoring.js';

// Import new feature modules
import { loadChatMessages, initSearch as initChatSearch } from './ai-chat.js';
import { loadChallenges } from './challenges.js';
import { loadSmartCameraScans, initSearch as initCameraSearch } from './smart-camera.js';
import { loadAllergyScannerData, initSearch as initAllergySearch } from './allergy-scanner.js';
import { loadGoalsData, initSearch as initGoalsSearch } from './goals.js';
import { loadAchievementsData, initSearch as initAchievementsSearch } from './achievements.js';
import { init as initRealTimeDashboard } from './real-time-dashboard.js';

// Initialize all modules
document.addEventListener('DOMContentLoaded', () => {
    initAuth();
    initNavigation();
    initUserSearch();
    initScanSearch();
    initAdvancedFilters();
    initBulkActions();
    initThemeToggle();
    initAlerts();
    initPerformanceMonitoring();
    
    // Initialize new feature modules
    initChatSearch();
    initCameraSearch();
    initAllergySearch();
    initGoalsSearch();
    initAchievementsSearch();
    
    // Initialize real-time dashboard
    initRealTimeDashboard();
    
    // Expose functions globally for onclick handlers
    window.nutrivision = {
        exportUsers,
        exportScans,
        exportAllData,
        loadUserAnalytics,
        loadMobileStats,
        loadUserSegments,
        aiChat: {
            loadChatMessages
        },
        challenges: {
            loadChallenges,
            createNewChallenge
        },
        smartCamera: {
            loadSmartCameraScans
        },
        allergyScanner: {
            loadAllergyScannerData
        },
        goals: {
            loadGoalsData,
            createNewGoal
        },
        achievements: {
            loadAchievementsData,
            createNewAchievement
        },
        showNotification: function(message, type = 'info') {
            // Simple notification system
            const notification = document.createElement('div');
            notification.className = `notification notification-${type}`;
            notification.textContent = message;
            document.body.appendChild(notification);
            
            setTimeout(() => {
                notification.remove();
            }, 3000);
        }
    };
    
    // Expose individual functions for onclick handlers
    window.refreshAlerts = refreshAlerts;
    window.refreshPerformance = refreshPerformance;
    window.createNewChallenge = () => window.nutrivision.challenges.createNewChallenge();
    
    // Setup tab switching for new tabs
    setupTabSwitching();
    
    // Check for existing login token
    const existingToken = checkExistingToken();
    if (existingToken) {
        showDashboard();
        loadAllData();
    } else {
        showLogin();
    }
});

function setupTabSwitching() {
    const navItems = document.querySelectorAll('.nav-item');
    navItems.forEach(item => {
        item.addEventListener('click', () => {
            const tabId = item.dataset.tab;
            
            // Load data based on tab
            switch(tabId) {
                case 'overview':
                    loadAllData();
                    break;
                case 'users':
                    // User data loaded in loadAllData
                    break;
                case 'scans':
                    // Scan data loaded in loadAllData
                    break;
                case 'ai-chat':
                    window.nutrivision.aiChat.loadChatMessages();
                    break;
                case 'challenges':
                    window.nutrivision.challenges.loadChallenges();
                    break;
                case 'smart-camera':
                    window.nutrivision.smartCamera.loadSmartCameraScans();
                    break;
                case 'allergy-scanner':
                    window.nutrivision.allergyScanner.loadAllergyScannerData();
                    break;
                case 'goals':
                    window.nutrivision.goals.loadGoalsData();
                    break;
                case 'achievements':
                    window.nutrivision.achievements.loadAchievementsData();
                    break;
                case 'analytics':
                    // Analytics data loaded in loadAllData
                    break;
                case 'user-analytics':
                    loadUserAnalytics();
                    break;
                case 'mobile':
                    loadMobileStats();
                    break;
                case 'segments':
                    loadUserSegments();
                    break;
                case 'alerts':
                    refreshAlerts();
                    break;
                case 'performance':
                    refreshPerformance();
                    break;
            }
        });
    });
}
