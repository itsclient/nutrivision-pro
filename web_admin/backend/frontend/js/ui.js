import { elements, currentToken } from './config.js';

export function showDashboard() {
    console.log('Showing dashboard...');
    
    // Hide login screen
    elements.loginScreen.classList.add('d-none');
    elements.loginScreen.classList.remove('d-flex', 'active');
    
    // Show dashboard screen
    elements.dashboardScreen.classList.remove('d-none');
    elements.dashboardScreen.classList.add('d-flex', 'active');
    
    // Force direct style as backup
    elements.loginScreen.style.setProperty('display', 'none', 'important');
    elements.dashboardScreen.style.setProperty('display', 'flex', 'important');
    
    console.log('Dashboard classes:', elements.dashboardScreen.className);
    console.log('Login classes:', elements.loginScreen.className);
}

export function showLogin() {
    // Hide dashboard screen
    elements.dashboardScreen.classList.add('d-none');
    elements.dashboardScreen.classList.remove('d-flex', 'active');
    
    // Show login screen
    elements.loginScreen.classList.remove('d-none');
    elements.loginScreen.classList.add('d-flex', 'active');
    
    // Force direct style as backup
    elements.dashboardScreen.style.setProperty('display', 'none', 'important');
    elements.loginScreen.style.setProperty('display', 'flex', 'important');
}

export function initNavigation() {
    elements.navItems.forEach(item => {
        item.addEventListener('click', () => {
            const tabId = item.dataset.tab;

            elements.navItems.forEach(nav => nav.classList.remove('active'));
            item.classList.add('active');

            elements.tabContents.forEach(content => {
                content.classList.remove('active');
                if (content.id === `${tabId}-tab`) {
                    content.classList.add('active');
                }
            });

            const title = 
                tabId === 'overview' ? 'Dashboard Overview' :
                tabId === 'users' ? 'User Management' :
                tabId === 'scans' ? 'Scan History' :
                tabId === 'analytics' ? 'Analytics' :
                tabId === 'user-analytics' ? 'User Analytics' :
                tabId === 'alerts' ? 'Real-time Alerts' :
                tabId === 'mobile' ? 'Mobile Integration' :
                tabId === 'performance' ? 'Performance Monitoring' :
                tabId === 'segments' ? 'User Segmentation' :
                'Dashboard';
            elements.pageTitle.textContent = title;
        });
    });
}

// Debug function - can be called from console
export function debugScreenSwitch() {
    console.log('Debug: Manually switching to dashboard');
    console.log('Login screen element:', elements.loginScreen);
    console.log('Dashboard screen element:', elements.dashboardScreen);
    showDashboard();
    console.log('After switch - Login display:', getComputedStyle(elements.loginScreen).display);
    console.log('After switch - Dashboard display:', getComputedStyle(elements.dashboardScreen).display);
}
