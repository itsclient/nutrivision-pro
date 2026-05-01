// User Achievements Management
window.nutrivision = window.nutrivision || {};

window.nutrivision.achievements = {
    // Load achievements data
    async loadAchievementsData() {
        try {
            const response = await fetch('/api/achievements/all');
            const achievements = await response.json();
            
            // Calculate stats
            const totalAchievements = achievements.length;
            const totalPoints = achievements.reduce((sum, a) => sum + a.points_awarded, 0);
            const uniqueAchievers = new Set(achievements.map(a => a.user_email)).size;
            
            document.getElementById('total-achievements').textContent = totalAchievements;
            document.getElementById('total-points').textContent = totalPoints;
            document.getElementById('unique-achievers').textContent = uniqueAchievers;
            
            // Load achievements table
            this.loadAchievementsTable(achievements);
        } catch (error) {
            console.error('Error loading achievements data:', error);
        }
    },

    // Load achievements table
    loadAchievementsTable(achievements) {
        const tbody = document.getElementById('achievements-table-body');
        tbody.innerHTML = '';
        
        achievements.slice(0, 50).forEach(achievement => {
            const row = this.createAchievementRow(achievement);
            tbody.appendChild(row);
        });
    },

    // Create achievement row
    createAchievementRow(achievement) {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${achievement.user_email}</td>
            <td>
                <div class="achievement-name">
                    <i class="fas fa-medal achievement-icon"></i>
                    <span>${achievement.achievement_name}</span>
                </div>
            </td>
            <td><span class="badge ${this.getTypeBadgeClass(achievement.achievement_type)}">${achievement.achievement_type}</span></td>
            <td><span class="points-badge">${achievement.points_awarded} pts</span></td>
            <td>${new Date(achievement.earned_at).toLocaleString()}</td>
        `;
        return row;
    },

    // Get type badge class
    getTypeBadgeClass(type) {
        switch (type?.toLowerCase()) {
            case 'streak': return 'badge-success';
            case 'scan': return 'badge-primary';
            case 'goal': return 'badge-info';
            case 'challenge': return 'badge-warning';
            case 'social': return 'badge-secondary';
            case 'milestone': return 'badge-dark';
            default: return 'badge-light';
        }
    },

    // View achievement details
    async viewAchievementDetails(achievementId) {
        try {
            const response = await fetch(`/api/achievements/${achievementId}`);
            const achievement = await response.json();
            
            this.showAchievementModal(achievement);
        } catch (error) {
            console.error('Error viewing achievement:', error);
        }
    },

    // Show achievement modal
    showAchievementModal(achievement) {
        const modal = document.createElement('div');
        modal.className = 'modal';
        modal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h3>Achievement Details</h3>
                    <button class="modal-close" onclick="this.closest('.modal').remove()">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
                <div class="modal-body">
                    <div class="achievement-details">
                        <div class="achievement-header">
                            <div class="achievement-icon-large">
                                <i class="fas fa-medal"></i>
                            </div>
                            <div class="achievement-title-section">
                                <h4>${achievement.achievement_name}</h4>
                                <span class="badge ${this.getTypeBadgeClass(achievement.achievement_type)}">${achievement.achievement_type}</span>
                            </div>
                        </div>
                        <div class="detail-row">
                            <strong>User:</strong> ${achievement.user_email}
                        </div>
                        <div class="detail-row">
                            <strong>Points Awarded:</strong> <span class="points-badge">${achievement.points_awarded} pts</span>
                        </div>
                        <div class="detail-row">
                            <strong>Earned At:</strong> ${new Date(achievement.earned_at).toLocaleString()}
                        </div>
                        <div class="achievement-description">
                            <strong>Description:</strong>
                            <p>This achievement was awarded for ${achievement.achievement_type} activity.</p>
                        </div>
                    </div>
                </div>
                <div class="modal-footer">
                    <button class="btn-secondary" onclick="this.closest('.modal').remove()">Close</button>
                </div>
            </div>
        `;
        
        document.body.appendChild(modal);
    },

    // Create new achievement
    createNewAchievement() {
        const modal = document.createElement('div');
        modal.className = 'modal';
        modal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h3>Award New Achievement</h3>
                    <button class="modal-close" onclick="this.closest('.modal').remove()">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
                <div class="modal-body">
                    <form id="create-achievement-form">
                        <div class="form-group">
                            <label for="achievement-user">User Email</label>
                            <input type="email" id="achievement-user" class="form-control" required>
                        </div>
                        <div class="form-group">
                            <label for="achievement-name">Achievement Name</label>
                            <input type="text" id="achievement-name" class="form-control" required>
                        </div>
                        <div class="form-group">
                            <label for="achievement-type">Achievement Type</label>
                            <select id="achievement-type" class="form-control">
                                <option value="streak">Streak Achievement</option>
                                <option value="scan">Scan Achievement</option>
                                <option value="goal">Goal Achievement</option>
                                <option value="challenge">Challenge Achievement</option>
                                <option value="social">Social Achievement</option>
                                <option value="milestone">Milestone Achievement</option>
                                <option value="custom">Custom Achievement</option>
                            </select>
                        </div>
                        <div class="form-group">
                            <label for="achievement-points">Points Awarded</label>
                            <input type="number" id="achievement-points" class="form-control" min="0" required>
                        </div>
                    </form>
                </div>
                <div class="modal-footer">
                    <button class="btn-secondary" onclick="this.closest('.modal').remove()">Cancel</button>
                    <button class="btn-primary" onclick="window.nutrivision.achievements.saveAchievement()">Award Achievement</button>
                </div>
            </div>
        `;
        
        document.body.appendChild(modal);
    },

    // Save achievement
    async saveAchievement() {
        try {
            const form = document.getElementById('create-achievement-form');
            const formData = new FormData(form);
            
            const achievementData = {
                userEmail: formData.get('achievement-user'),
                achievementType: formData.get('achievement-type'),
                achievementName: formData.get('achievement-name'),
                pointsAwarded: parseInt(formData.get('achievement-points'))
            };
            
            const response = await fetch('/api/achievements', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(achievementData)
            });
            
            if (response.ok) {
                document.querySelector('.modal').remove();
                this.loadAchievementsData();
                window.nutrivision.showNotification('Achievement awarded successfully!', 'success');
            } else {
                throw new Error('Failed to award achievement');
            }
        } catch (error) {
            console.error('Error saving achievement:', error);
            window.nutrivision.showNotification('Failed to award achievement', 'error');
        }
    },

    // Search achievements
    searchAchievements(query) {
        const rows = document.querySelectorAll('#achievements-table-body tr');
        
        rows.forEach(row => {
            const text = row.textContent.toLowerCase();
            const matches = text.includes(query.toLowerCase());
            row.style.display = matches ? '' : 'none';
        });
    },

    // Initialize search functionality
    initSearch() {
        const searchInput = document.getElementById('achievements-search');
        if (searchInput) {
            searchInput.addEventListener('input', (e) => {
                this.searchAchievements(e.target.value);
            });
        }
    }
};
