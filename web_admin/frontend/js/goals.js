// User Goals Management
window.nutrivision = window.nutrivision || {};

window.nutrivision.goals = {
    // Load goals data
    async loadGoalsData() {
        try {
            const response = await fetch('/api/analytics/overview');
            const data = await response.json();
            
            // Update stats
            document.getElementById('total-goals').textContent = data.totalGoals || 0;
            document.getElementById('completed-goals').textContent = data.completedGoals || 0;
            document.getElementById('completion-rate').textContent = data.goalCompletionRate + '%';
            
            // Load goals table
            await this.loadGoalsTable();
        } catch (error) {
            console.error('Error loading goals data:', error);
        }
    },

    // Load goals table
    async loadGoalsTable() {
        try {
            const response = await fetch('/api/goals/all');
            const goals = await response.json();
            
            const tbody = document.getElementById('goals-table-body');
            tbody.innerHTML = '';
            
            goals.forEach(goal => {
                const row = this.createGoalRow(goal);
                tbody.appendChild(row);
            });
        } catch (error) {
            console.error('Error loading goals:', error);
        }
    },

    // Create goal row
    createGoalRow(goal) {
        const row = document.createElement('tr');
        const progress = goal.target_value > 0 ? (goal.current_value / goal.target_value * 100).toFixed(1) : 0;
        
        row.innerHTML = `
            <td>${goal.user_email}</td>
            <td><span class="badge badge-info">${goal.goal_type}</span></td>
            <td>${goal.target_value} ${goal.unit || ''}</td>
            <td>${goal.current_value} ${goal.unit || ''}</td>
            <td>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: ${Math.min(progress, 100)}%"></div>
                    <span class="progress-text">${progress}%</span>
                </div>
            </td>
            <td>
                <span class="badge ${goal.is_completed ? 'badge-success' : progress >= 100 ? 'badge-warning' : 'badge-info'}">
                    ${goal.is_completed ? 'Completed' : progress >= 100 ? 'Ready' : 'In Progress'}
                </span>
            </td>
            <td>${goal.deadline ? new Date(goal.deadline).toLocaleDateString() : 'No deadline'}</td>
        `;
        return row;
    },

    // View goal details
    async viewGoalDetails(goalId) {
        try {
            const response = await fetch(`/api/goals/${goalId}`);
            const goal = await response.json();
            
            this.showGoalModal(goal);
        } catch (error) {
            console.error('Error viewing goal:', error);
        }
    },

    // Show goal modal
    showGoalModal(goal) {
        const modal = document.createElement('div');
        modal.className = 'modal';
        modal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h3>Goal Details</h3>
                    <button class="modal-close" onclick="this.closest('.modal').remove()">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
                <div class="modal-body">
                    <div class="goal-details">
                        <div class="detail-row">
                            <strong>User:</strong> ${goal.user_email}
                        </div>
                        <div class="detail-row">
                            <strong>Goal Type:</strong> <span class="badge badge-info">${goal.goal_type}</span>
                        </div>
                        <div class="detail-row">
                            <strong>Target:</strong> ${goal.target_value} ${goal.unit || ''}
                        </div>
                        <div class="detail-row">
                            <strong>Current:</strong> ${goal.current_value} ${goal.unit || ''}
                        </div>
                        <div class="detail-row">
                            <strong>Progress:</strong>
                        </div>
                        <div class="progress-bar large">
                            <div class="progress-fill" style="width: ${Math.min((goal.current_value / goal.target_value * 100), 100)}%"></div>
                            <span class="progress-text">${(goal.current_value / goal.target_value * 100).toFixed(1)}%</span>
                        </div>
                        <div class="detail-row">
                            <strong>Status:</strong> <span class="badge ${goal.is_completed ? 'badge-success' : 'badge-info'}">${goal.is_completed ? 'Completed' : 'In Progress'}</span>
                        </div>
                        <div class="detail-row">
                            <strong>Deadline:</strong> ${goal.deadline ? new Date(goal.deadline).toLocaleDateString() : 'No deadline'}
                        </div>
                        <div class="detail-row">
                            <strong>Created:</strong> ${new Date(goal.created_at).toLocaleString()}
                        </div>
                        <div class="detail-row">
                            <strong>Last Updated:</strong> ${new Date(goal.updated_at).toLocaleString()}
                        </div>
                    </div>
                </div>
                <div class="modal-footer">
                    <button class="btn-secondary" onclick="this.closest('.modal').remove()">Close</button>
                    <button class="btn-primary" onclick="window.nutrivision.goals.editGoal('${goal.id}')">Edit Goal</button>
                </div>
            </div>
        `;
        
        document.body.appendChild(modal);
    },

    // Edit goal
    editGoal(goalId) {
        // Close current modal and open edit modal
        document.querySelector('.modal').remove();
        
        const modal = document.createElement('div');
        modal.className = 'modal';
        modal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h3>Edit Goal</h3>
                    <button class="modal-close" onclick="this.closest('.modal').remove()">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
                <div class="modal-body">
                    <form id="edit-goal-form">
                        <div class="form-group">
                            <label for="goal-current">Current Value</label>
                            <input type="number" id="goal-current" class="form-control" step="0.1">
                        </div>
                        <div class="form-group">
                            <label for="goal-completed">
                                <input type="checkbox" id="goal-completed"> Mark as Completed
                            </label>
                        </div>
                    </form>
                </div>
                <div class="modal-footer">
                    <button class="btn-secondary" onclick="this.closest('.modal').remove()">Cancel</button>
                    <button class="btn-primary" onclick="window.nutrivision.goals.updateGoal('${goalId}')">Update Goal</button>
                </div>
            </div>
        `;
        
        document.body.appendChild(modal);
    },

    // Update goal
    async updateGoal(goalId) {
        try {
            const currentValue = parseFloat(document.getElementById('goal-current').value);
            const isCompleted = document.getElementById('goal-completed').checked;
            
            const response = await fetch(`/api/goals/${goalId}`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    currentValue,
                    isCompleted
                })
            });
            
            if (response.ok) {
                document.querySelector('.modal').remove();
                this.loadGoalsData();
                window.nutrivision.showNotification('Goal updated successfully!', 'success');
            } else {
                throw new Error('Failed to update goal');
            }
        } catch (error) {
            console.error('Error updating goal:', error);
            window.nutrivision.showNotification('Failed to update goal', 'error');
        }
    },

    // Create new goal
    createNewGoal() {
        const modal = document.createElement('div');
        modal.className = 'modal';
        modal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h3>Create New Goal</h3>
                    <button class="modal-close" onclick="this.closest('.modal').remove()">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
                <div class="modal-body">
                    <form id="create-goal-form">
                        <div class="form-group">
                            <label for="goal-user">User Email</label>
                            <input type="email" id="goal-user" class="form-control" required>
                        </div>
                        <div class="form-group">
                            <label for="goal-type">Goal Type</label>
                            <select id="goal-type" class="form-control">
                                <option value="weight_loss">Weight Loss</option>
                                <option value="weight_gain">Weight Gain</option>
                                <option value="calorie_intake">Calorie Intake</option>
                                <option value="protein_intake">Protein Intake</option>
                                <option value="exercise">Exercise</option>
                                <option value="water_intake">Water Intake</option>
                                <option value="sleep">Sleep</option>
                                <option value="custom">Custom</option>
                            </select>
                        </div>
                        <div class="form-row">
                            <div class="form-group">
                                <label for="goal-target">Target Value</label>
                                <input type="number" id="goal-target" class="form-control" step="0.1" required>
                            </div>
                            <div class="form-group">
                                <label for="goal-unit">Unit</label>
                                <input type="text" id="goal-unit" class="form-control" placeholder="kg, calories, minutes, etc.">
                            </div>
                        </div>
                        <div class="form-group">
                            <label for="goal-deadline">Deadline (optional)</label>
                            <input type="date" id="goal-deadline" class="form-control">
                        </div>
                    </form>
                </div>
                <div class="modal-footer">
                    <button class="btn-secondary" onclick="this.closest('.modal').remove()">Cancel</button>
                    <button class="btn-primary" onclick="window.nutrivision.goals.saveGoal()">Create Goal</button>
                </div>
            </div>
        `;
        
        document.body.appendChild(modal);
    },

    // Save goal
    async saveGoal() {
        try {
            const form = document.getElementById('create-goal-form');
            const formData = new FormData(form);
            
            const goalData = {
                userEmail: formData.get('goal-user'),
                goalType: formData.get('goal-type'),
                targetValue: parseFloat(formData.get('goal-target')),
                unit: formData.get('goal-unit'),
                deadline: formData.get('goal-deadline')
            };
            
            const response = await fetch('/api/goals', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(goalData)
            });
            
            if (response.ok) {
                document.querySelector('.modal').remove();
                this.loadGoalsData();
                window.nutrivision.showNotification('Goal created successfully!', 'success');
            } else {
                throw new Error('Failed to create goal');
            }
        } catch (error) {
            console.error('Error saving goal:', error);
            window.nutrivision.showNotification('Failed to create goal', 'error');
        }
    },

    // Search goals
    searchGoals(query) {
        const rows = document.querySelectorAll('#goals-table-body tr');
        
        rows.forEach(row => {
            const text = row.textContent.toLowerCase();
            const matches = text.includes(query.toLowerCase());
            row.style.display = matches ? '' : 'none';
        });
    },

    // Initialize search functionality
    initSearch() {
        const searchInput = document.getElementById('goals-search');
        if (searchInput) {
            searchInput.addEventListener('input', (e) => {
                this.searchGoals(e.target.value);
            });
        }
    }
};
