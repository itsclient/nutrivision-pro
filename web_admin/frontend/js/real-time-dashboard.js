// Real-time Dashboard Updates
window.nutrivision = window.nutrivision || {};

window.nutrivision.realTimeDashboard = {
    // Initialize real-time updates
    init() {
        this.setupWebSocket();
        this.startPeriodicUpdates();
        this.setupActivityFeed();
    },

    // WebSocket connection for real-time updates
    setupWebSocket() {
        // For now, use polling as fallback
        console.log('Real-time dashboard initialized');
    },

    // Start periodic updates
    startPeriodicUpdates() {
        // Update every 30 seconds
        setInterval(() => {
            this.updateDashboardStats();
            this.updateActivityFeed();
        }, 30000);
    },

    // Update dashboard statistics
    async updateDashboardStats() {
        try {
            const response = await fetch('/api/analytics/overview');
            const data = await response.json();
            
            // Update overview stats with animations
            this.animateValue('total-users', data.totalUsers);
            this.animateValue('total-scans', data.totalScans);
            this.animateValue('smart-camera-scans', data.smartCameraScans);
            this.animateValue('allergy-scans', data.allergyScans);
            this.animateValue('ai-chat-messages', data.aiChatMessages);
            this.animateValue('active-challenges', data.activeChallenges);
            
            // Update completion rate
            const completionElement = document.getElementById('completion-rate');
            if (completionElement) {
                completionElement.textContent = data.goalCompletionRate + '%';
            }
            
        } catch (error) {
            console.error('Error updating dashboard stats:', error);
        }
    },

    // Animate number changes
    animateValue(elementId, newValue) {
        const element = document.getElementById(elementId);
        if (!element) return;
        
        const currentValue = parseInt(element.textContent) || 0;
        const difference = newValue - currentValue;
        const steps = 20;
        const stepValue = difference / steps;
        let step = 0;
        
        const timer = setInterval(() => {
            step++;
            const value = Math.round(currentValue + (stepValue * step));
            element.textContent = value;
            
            if (step >= steps) {
                clearInterval(timer);
                element.textContent = newValue;
            }
        }, 50);
    },

    // Setup activity feed
    setupActivityFeed() {
        this.createActivityFeedWidget();
        this.loadRecentActivity();
    },

    // Create activity feed widget
    createActivityFeedWidget() {
        const overviewTab = document.getElementById('overview-tab');
        if (!overviewTab) return;
        
        const activityFeed = document.createElement('div');
        activityFeed.className = 'activity-feed-widget';
        activityFeed.innerHTML = `
            <div class="widget-header">
                <h3><i class="fas fa-stream"></i> Live Activity Feed</h3>
                <button class="btn-control" onclick="window.nutrivision.realTimeDashboard.loadRecentActivity()">
                    <i class="fas fa-sync"></i>
                </button>
            </div>
            <div class="activity-feed" id="activity-feed">
                <div class="no-activity">Loading recent activity...</div>
            </div>
        `;
        
        // Insert after charts
        const chartsRow = overviewTab.querySelector('.charts-row');
        if (chartsRow) {
            chartsRow.parentNode.insertBefore(activityFeed, chartsRow.nextSibling);
        }
    },

    // Load recent activity
    async loadRecentActivity() {
        try {
            const response = await fetch('/api/activities/recent');
            const activities = await response.json();
            
            const feedContainer = document.getElementById('activity-feed');
            if (!feedContainer) return;
            
            if (activities.length === 0) {
                feedContainer.innerHTML = '<div class="no-activity">No recent activity</div>';
                return;
            }
            
            feedContainer.innerHTML = activities.map(activity => this.createActivityItem(activity)).join('');
            
            // Add animation to new items
            const items = feedContainer.querySelectorAll('.activity-item');
            items.forEach((item, index) => {
                setTimeout(() => {
                    item.classList.add('animate-in');
                }, index * 100);
            });
            
        } catch (error) {
            console.error('Error loading recent activity:', error);
            const feedContainer = document.getElementById('activity-feed');
            if (feedContainer) {
                feedContainer.innerHTML = '<div class="no-activity">Error loading activity</div>';
            }
        }
    },

    // Create activity item HTML
    createActivityItem(activity) {
        const icon = this.getActivityIcon(activity.activity_type);
        const color = this.getActivityColor(activity.activity_type);
        const timeAgo = this.getTimeAgo(activity.created_at);
        
        return `
            <div class="activity-item">
                <div class="activity-icon" style="background: ${color}">
                    <i class="fas ${icon}"></i>
                </div>
                <div class="activity-content">
                    <div class="activity-user">${activity.user_email}</div>
                    <div class="activity-description">${activity.description}</div>
                    <div class="activity-time">${timeAgo}</div>
                </div>
            </div>
        `;
    },

    // Get activity icon
    getActivityIcon(type) {
        const icons = {
            'ai_chat': 'fa-robot',
            'smart_camera_scan': 'fa-camera',
            'allergy_scan': 'fa-shield-alt',
            'goal_created': 'fa-bullseye',
            'goal_completed': 'fa-check-circle',
            'achievement_earned': 'fa-medal',
            'challenge_joined': 'fa-trophy',
            'challenge_created': 'fa-flag',
            'scan': 'fa-camera',
            'login': 'fa-sign-in-alt'
        };
        return icons[type] || 'fa-circle';
    },

    // Get activity color
    getActivityColor(type) {
        const colors = {
            'ai_chat': 'linear-gradient(135deg, #9C27B0, #7B1FA2)',
            'smart_camera_scan': 'linear-gradient(135deg, #4CAF50, #388E3C)',
            'allergy_scan': 'linear-gradient(135deg, #F44336, #D32F2F)',
            'goal_created': 'linear-gradient(135deg, #2196F3, #1976D2)',
            'goal_completed': 'linear-gradient(135deg, #4CAF50, #388E3C)',
            'achievement_earned': 'linear-gradient(135deg, #FFC107, #FFA000)',
            'challenge_joined': 'linear-gradient(135deg, #FF9800, #F57C00)',
            'challenge_created': 'linear-gradient(135deg, #FF9800, #F57C00)',
            'scan': 'linear-gradient(135deg, #FF6B6B, #EE5A5A)',
            'login': 'linear-gradient(135deg, #2196F3, #1976D2)'
        };
        return colors[type] || 'linear-gradient(135deg, #666, #444)';
    },

    // Get time ago string
    getTimeAgo(timestamp) {
        const now = new Date();
        const time = new Date(timestamp);
        const diff = Math.floor((now - time) / 1000); // seconds
        
        if (diff < 60) return 'just now';
        if (diff < 3600) return Math.floor(diff / 60) + ' minutes ago';
        if (diff < 86400) return Math.floor(diff / 3600) + ' hours ago';
        return Math.floor(diff / 86400) + ' days ago';
    },

    // Update activity feed
    updateActivityFeed() {
        this.loadRecentActivity();
    },

    // Add new activity to feed (for real-time updates)
    addActivityToFeed(activity) {
        const feedContainer = document.getElementById('activity-feed');
        if (!feedContainer) return;
        
        // Remove "no activity" message if present
        const noActivity = feedContainer.querySelector('.no-activity');
        if (noActivity) {
            noActivity.remove();
        }
        
        // Create new activity item
        const activityItem = document.createElement('div');
        activityItem.className = 'activity-item animate-in';
        activityItem.innerHTML = this.createActivityItem(activity);
        
        // Add to top of feed
        feedContainer.insertBefore(activityItem, feedContainer.firstChild);
        
        // Remove old items if too many
        const items = feedContainer.querySelectorAll('.activity-item');
        if (items.length > 10) {
            items[items.length - 1].remove();
        }
    }
};
