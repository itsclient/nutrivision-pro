// Smart Camera Scans Management
window.nutrivision = window.nutrivision || {};

window.nutrivision.smartCamera = {
    // Load smart camera scans
    async loadSmartCameraScans() {
        try {
            const response = await fetch('/api/analytics/overview');
            const data = await response.json();
            
            // Update stats
            document.getElementById('total-camera-scans').textContent = data.smartCameraScans || 0;
            
            // Calculate average confidence
            const avgConfidence = await this.calculateAverageConfidence();
            document.getElementById('avg-confidence').textContent = avgConfidence + '%';
            
            // Count unique foods
            const uniqueFoods = await this.countUniqueFoods();
            document.getElementById('unique-foods').textContent = uniqueFoods;
            
            // Load scans table
            await this.loadScansTable();
        } catch (error) {
            console.error('Error loading smart camera data:', error);
        }
    },

    // Calculate average confidence
    async calculateAverageConfidence() {
        try {
            const response = await fetch('/api/smart-camera/scans/all');
            const scans = await response.json();
            
            if (scans.length === 0) return 0;
            
            const totalConfidence = scans.reduce((sum, scan) => sum + (scan.confidence || 0), 0);
            return Math.round((totalConfidence / scans.length) * 100);
        } catch (error) {
            console.error('Error calculating confidence:', error);
            return 0;
        }
    },

    // Count unique foods
    async countUniqueFoods() {
        try {
            const response = await fetch('/api/smart-camera/scans/all');
            const scans = await response.json();
            
            const uniqueFoods = new Set(scans.map(scan => scan.food_name));
            return uniqueFoods.size;
        } catch (error) {
            console.error('Error counting unique foods:', error);
            return 0;
        }
    },

    // Load scans table
    async loadScansTable() {
        try {
            const response = await fetch('/api/smart-camera/scans/all');
            const scans = await response.json();
            
            const tbody = document.getElementById('camera-scans-table-body');
            tbody.innerHTML = '';
            
            scans.slice(0, 50).forEach(scan => {
                const row = this.createScanRow(scan);
                tbody.appendChild(row);
            });
        } catch (error) {
            console.error('Error loading scans:', error);
        }
    },

    // Create scan row
    createScanRow(scan) {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${scan.user_email}</td>
            <td>${scan.food_name}</td>
            <td>
                <div class="confidence-bar">
                    <div class="confidence-fill" style="width: ${(scan.confidence * 100).toFixed(1)}%"></div>
                    <span class="confidence-text">${(scan.confidence * 100).toFixed(1)}%</span>
                </div>
            </td>
            <td>${scan.calories || 'N/A'}</td>
            <td>${scan.protein_grams || 'N/A'}g</td>
            <td><span class="badge ${this.getSourceBadgeClass(scan.scan_source)}">${scan.scan_source || 'Unknown'}</span></td>
            <td>${new Date(scan.timestamp).toLocaleString()}</td>
        `;
        return row;
    },

    // Get source badge class
    getSourceBadgeClass(source) {
        switch (source?.toLowerCase()) {
            case 'localml': return 'badge-success';
            case 'googlevision': return 'badge-primary';
            case 'customapi': return 'badge-info';
            default: return 'badge-secondary';
        }
    },

    // View scan details
    async viewScanDetails(scanId) {
        try {
            const response = await fetch(`/api/smart-camera/scans/${scanId}`);
            const scan = await response.json();
            
            this.showScanModal(scan);
        } catch (error) {
            console.error('Error viewing scan:', error);
        }
    },

    // Show scan modal
    showScanModal(scan) {
        const modal = document.createElement('div');
        modal.className = 'modal';
        modal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h3>Smart Camera Scan Details</h3>
                    <button class="modal-close" onclick="this.closest('.modal').remove()">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
                <div class="modal-body">
                    <div class="scan-details">
                        <div class="detail-row">
                            <strong>User:</strong> ${scan.user_email}
                        </div>
                        <div class="detail-row">
                            <strong>Food Name:</strong> ${scan.food_name}
                        </div>
                        <div class="detail-row">
                            <strong>Confidence:</strong> ${(scan.confidence * 100).toFixed(1)}%
                        </div>
                        <div class="detail-row">
                            <strong>Scan Source:</strong> <span class="badge ${this.getSourceBadgeClass(scan.scan_source)}">${scan.scan_source}</span>
                        </div>
                        <div class="detail-row">
                            <strong>Nutrition Information:</strong>
                        </div>
                        <div class="nutrition-info">
                            <div class="nutrition-item">
                                <span class="nutrition-label">Calories:</span>
                                <span class="nutrition-value">${scan.calories || 'N/A'}</span>
                            </div>
                            <div class="nutrition-item">
                                <span class="nutrition-label">Protein:</span>
                                <span class="nutrition-value">${scan.protein_grams || 'N/A'}g</span>
                            </div>
                            <div class="nutrition-item">
                                <span class="nutrition-label">Carbs:</span>
                                <span class="nutrition-value">${scan.carbs_grams || 'N/A'}g</span>
                            </div>
                            <div class="nutrition-item">
                                <span class="nutrition-label">Fat:</span>
                                <span class="nutrition-value">${scan.fat_grams || 'N/A'}g</span>
                            </div>
                            <div class="nutrition-item">
                                <span class="nutrition-label">Fiber:</span>
                                <span class="nutrition-value">${scan.fiber_grams || 'N/A'}g</span>
                            </div>
                            <div class="nutrition-item">
                                <span class="nutrition-label">Sugar:</span>
                                <span class="nutrition-value">${scan.sugar_grams || 'N/A'}g</span>
                            </div>
                            <div class="nutrition-item">
                                <span class="nutrition-label">Sodium:</span>
                                <span class="nutrition-value">${scan.sodium || 'N/A'}mg</span>
                            </div>
                        </div>
                        <div class="detail-row">
                            <strong>Serving Size:</strong> ${scan.serving_size || 'N/A'}
                        </div>
                        <div class="detail-row">
                            <strong>Timestamp:</strong> ${new Date(scan.timestamp).toLocaleString()}
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

    // Search scans
    searchScans(query) {
        const rows = document.querySelectorAll('#camera-scans-table-body tr');
        
        rows.forEach(row => {
            const text = row.textContent.toLowerCase();
            const matches = text.includes(query.toLowerCase());
            row.style.display = matches ? '' : 'none';
        });
    },

    // Initialize search functionality
    initSearch() {
        const searchInput = document.getElementById('camera-search');
        if (searchInput) {
            searchInput.addEventListener('input', (e) => {
                this.searchScans(e.target.value);
            });
        }
    }
};
