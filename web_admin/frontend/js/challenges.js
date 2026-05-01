// Group Challenges Management
window.nutrivision = window.nutrivision || {};

window.nutrivision.challenges = {
    // Load challenges data
    async loadChallenges() {
        try {
            const response = await fetch('/api/challenges');
            const challenges = await response.json();
            
            // Update stats
            const activeChallenges = challenges.filter(c => c.is_active).length;
            const totalParticipants = challenges.reduce((sum, c) => sum + c.current_participants, 0);
            const totalPrizePool = challenges.reduce((sum, c) => sum + c.prize_pool, 0);
            
            document.getElementById('active-challenges').textContent = activeChallenges;
            document.getElementById('total-participants').textContent = totalParticipants;
            document.getElementById('total-prize-pool').textContent = totalPrizePool;
            
            // Load challenges table
            this.loadChallengesTable(challenges);
        } catch (error) {
            console.error('Error loading challenges:', error);
        }
    },

    // Load challenges table
    loadChallengesTable(challenges) {
        const tbody = document.getElementById('challenges-table-body');
        tbody.innerHTML = '';
        
        challenges.forEach(challenge => {
            const row = this.createChallengeRow(challenge);
            tbody.appendChild(row);
        });
    },

    // Create challenge row
    createChallengeRow(challenge) {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${challenge.name}</td>
            <td><span class="badge badge-info">${challenge.challenge_type || 'General'}</span></td>
            <td><span class="badge ${this.getDifficultyBadgeClass(challenge.difficulty)}">${challenge.difficulty || 'Medium'}</span></td>
            <td>${challenge.current_participants}/${challenge.max_participants}</td>
            <td>${challenge.prize_pool} pts</td>
            <td><span class="badge ${challenge.is_active ? 'badge-success' : 'badge-secondary'}">${challenge.is_active ? 'Active' : 'Inactive'}</span></td>
            <td>
                <button class="btn-action" onclick="window.nutrivision.challenges.viewChallenge('${challenge.id}')">
                    <i class="fas fa-eye"></i>
                </button>
                <button class="btn-action" onclick="window.nutrivision.challenges.editChallenge('${challenge.id}')">
                    <i class="fas fa-edit"></i>
                </button>
                <button class="btn-action btn-danger" onclick="window.nutrivision.challenges.deleteChallenge('${challenge.id}')">
                    <i class="fas fa-trash"></i>
                </button>
            </td>
        `;
        return row;
    },

    // Get difficulty badge class
    getDifficultyBadgeClass(difficulty) {
        switch (difficulty?.toLowerCase()) {
            case 'easy': return 'badge-success';
            case 'medium': return 'badge-warning';
            case 'hard': return 'badge-danger';
            case 'expert': return 'badge-dark';
            default: return 'badge-secondary';
        }
    },

    // View challenge details
    async viewChallenge(challengeId) {
        try {
            const response = await fetch(`/api/challenges/${challengeId}`);
            const challenge = await response.json();
            
            // Show challenge details modal
            this.showChallengeModal(challenge);
        } catch (error) {
            console.error('Error viewing challenge:', error);
        }
    },

    // Show challenge modal
    showChallengeModal(challenge) {
        const modal = document.createElement('div');
        modal.className = 'modal';
        modal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h3>Challenge Details</h3>
                    <button class="modal-close" onclick="this.closest('.modal').remove()">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
                <div class="modal-body">
                    <div class="challenge-details">
                        <div class="detail-row">
                            <strong>Name:</strong> ${challenge.name}
                        </div>
                        <div class="detail-row">
                            <strong>Description:</strong> ${challenge.description || 'No description'}
                        </div>
                        <div class="detail-row">
                            <strong>Type:</strong> <span class="badge badge-info">${challenge.challenge_type || 'General'}</span>
                        </div>
                        <div class="detail-row">
                            <strong>Difficulty:</strong> <span class="badge ${this.getDifficultyBadgeClass(challenge.difficulty)}">${challenge.difficulty || 'Medium'}</span>
                        </div>
                        <div class="detail-row">
                            <strong>Participants:</strong> ${challenge.current_participants}/${challenge.max_participants}
                        </div>
                        <div class="detail-row">
                            <strong>Prize Pool:</strong> ${challenge.prize_pool} points
                        </div>
                        <div class="detail-row">
                            <strong>Start Date:</strong> ${new Date(challenge.start_date).toLocaleDateString()}
                        </div>
                        <div class="detail-row">
                            <strong>End Date:</strong> ${new Date(challenge.end_date).toLocaleDateString()}
                        </div>
                        <div class="detail-row">
                            <strong>Requirements:</strong>
                        </div>
                        <div class="requirements-list">
                            ${this.parseJsonList(challenge.requirements).map(req => `<div class="requirement-item">- ${req}</div>`).join('')}
                        </div>
                        <div class="detail-row">
                            <strong>Rewards:</strong>
                        </div>
                        <div class="rewards-list">
                            ${this.parseJsonList(challenge.rewards).map(reward => `<div class="reward-item">- ${reward}</div>`).join('')}
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

    // Parse JSON list
    parseJsonList(jsonString) {
        try {
            return JSON.parse(jsonString || '[]');
        } catch (e) {
            return [];
        }
    },

    // Create new challenge
    createNewChallenge() {
        const modal = document.createElement('div');
        modal.className = 'modal';
        modal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h3>Create New Challenge</h3>
                    <button class="modal-close" onclick="this.closest('.modal').remove()">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
                <div class="modal-body">
                    <form id="create-challenge-form">
                        <div class="form-group">
                            <label for="challenge-name">Challenge Name</label>
                            <input type="text" id="challenge-name" class="form-control" required>
                        </div>
                        <div class="form-group">
                            <label for="challenge-description">Description</label>
                            <textarea id="challenge-description" class="form-control" rows="3"></textarea>
                        </div>
                        <div class="form-row">
                            <div class="form-group">
                                <label for="challenge-type">Type</label>
                                <select id="challenge-type" class="form-control">
                                    <option value="streak">Streak</option>
                                    <option value="calorie">Calorie</option>
                                    <option value="protein">Protein</option>
                                    <option value="scans">Scans</option>
                                    <option value="weight">Weight</option>
                                    <option value="custom">Custom</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label for="challenge-difficulty">Difficulty</label>
                                <select id="challenge-difficulty" class="form-control">
                                    <option value="easy">Easy</option>
                                    <option value="medium">Medium</option>
                                    <option value="hard">Hard</option>
                                    <option value="expert">Expert</option>
                                </select>
                            </div>
                        </div>
                        <div class="form-row">
                            <div class="form-group">
                                <label for="start-date">Start Date</label>
                                <input type="date" id="start-date" class="form-control" required>
                            </div>
                            <div class="form-group">
                                <label for="end-date">End Date</label>
                                <input type="date" id="end-date" class="form-control" required>
                            </div>
                        </div>
                        <div class="form-row">
                            <div class="form-group">
                                <label for="max-participants">Max Participants</label>
                                <input type="number" id="max-participants" class="form-control" min="1" required>
                            </div>
                            <div class="form-group">
                                <label for="prize-pool">Prize Pool (points)</label>
                                <input type="number" id="prize-pool" class="form-control" min="0" required>
                            </div>
                        </div>
                        <div class="form-group">
                            <label for="requirements">Requirements (one per line)</label>
                            <textarea id="requirements" class="form-control" rows="3" placeholder="Enter requirements, one per line"></textarea>
                        </div>
                        <div class="form-group">
                            <label for="rewards">Rewards (one per line)</label>
                            <textarea id="rewards" class="form-control" rows="3" placeholder="Enter rewards, one per line"></textarea>
                        </div>
                    </form>
                </div>
                <div class="modal-footer">
                    <button class="btn-secondary" onclick="this.closest('.modal').remove()">Cancel</button>
                    <button class="btn-primary" onclick="window.nutrivision.challenges.saveChallenge()">Create Challenge</button>
                </div>
            </div>
        `;
        
        document.body.appendChild(modal);
    },

    // Save challenge
    async saveChallenge() {
        try {
            const form = document.getElementById('create-challenge-form');
            const formData = new FormData(form);
            
            const challengeData = {
                name: formData.get('challenge-name'),
                description: formData.get('challenge-description'),
                challengeType: formData.get('challenge-type'),
                difficulty: formData.get('challenge-difficulty'),
                startDate: formData.get('start-date'),
                endDate: formData.get('end-date'),
                maxParticipants: parseInt(formData.get('max-participants')),
                prizePool: parseInt(formData.get('prize-pool')),
                requirements: formData.get('requirements').split('\n').filter(r => r.trim()),
                rewards: formData.get('rewards').split('\n').filter(r => r.trim()),
                createdBy: 'admin@gmail.com' // In real app, get from session
            };
            
            const response = await fetch('/api/challenges', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(challengeData)
            });
            
            if (response.ok) {
                // Close modal and reload
                document.querySelector('.modal').remove();
                this.loadChallenges();
                window.nutrivision.showNotification('Challenge created successfully!', 'success');
            } else {
                throw new Error('Failed to create challenge');
            }
        } catch (error) {
            console.error('Error saving challenge:', error);
            window.nutrivision.showNotification('Failed to create challenge', 'error');
        }
    },

    // Edit challenge
    editChallenge(challengeId) {
        // Similar to create but with pre-filled data
        window.nutrivision.showNotification('Edit feature coming soon!', 'info');
    },

    // Delete challenge
    async deleteChallenge(challengeId) {
        if (!confirm('Are you sure you want to delete this challenge?')) {
            return;
        }
        
        try {
            const response = await fetch(`/api/challenges/${challengeId}`, {
                method: 'DELETE'
            });
            
            if (response.ok) {
                this.loadChallenges();
                window.nutrivision.showNotification('Challenge deleted successfully!', 'success');
            } else {
                throw new Error('Failed to delete challenge');
            }
        } catch (error) {
            console.error('Error deleting challenge:', error);
            window.nutrivision.showNotification('Failed to delete challenge', 'error');
        }
    }
};
