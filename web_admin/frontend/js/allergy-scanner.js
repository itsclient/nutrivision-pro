// Allergy Scanner Management
window.nutrivision = window.nutrivision || {};

window.nutrivision.allergyScanner = {
    // Load allergy scanner data
    async loadAllergyScannerData() {
        try {
            const response = await fetch('/api/analytics/overview');
            const data = await response.json();
            
            // Update stats
            document.getElementById('total-allergy-scans').textContent = data.allergyScans || 0;
            
            // Calculate safe vs unsafe scans
            const { safe, unsafe } = await this.calculateScanSafety();
            document.getElementById('safe-scans').textContent = safe;
            document.getElementById('unsafe-scans').textContent = unsafe;
            
            // Load scans table
            await this.loadScansTable();
        } catch (error) {
            console.error('Error loading allergy scanner data:', error);
        }
    },

    // Calculate scan safety statistics
    async calculateScanSafety() {
        try {
            const response = await fetch('/api/allergy-scans/all');
            const scans = await response.json();
            
            const safe = scans.filter(scan => scan.is_safe).length;
            const unsafe = scans.filter(scan => !scan.is_safe).length;
            
            return { safe, unsafe };
        } catch (error) {
            console.error('Error calculating safety stats:', error);
            return { safe: 0, unsafe: 0 };
        }
    },

    // Load scans table
    async loadScansTable() {
        try {
            const response = await fetch('/api/allergy-scans/all');
            const scans = await response.json();
            
            const tbody = document.getElementById('allergy-scans-table-body');
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
        const allergens = this.parseJsonArray(scan.detected_allergens);
        const allergenText = allergens.length > 0 ? allergens.join(', ') : 'None';
        
        row.innerHTML = `
            <td>${scan.user_email}</td>
            <td>${scan.product_name || 'Unknown Product'}</td>
            <td>${scan.barcode || 'N/A'}</td>
            <td class="allergen-cell">
                <div class="allergen-list">
                    ${allergens.map(allergen => `<span class="allergen-tag">${allergen}</span>`).join('')}
                </div>
            </td>
            <td>
                <span class="badge ${scan.is_safe ? 'badge-success' : 'badge-danger'}">
                    ${scan.is_safe ? 'Safe' : 'Unsafe'}
                </span>
            </td>
            <td>${new Date(scan.timestamp).toLocaleString()}</td>
        `;
        return row;
    },

    // Parse JSON array
    parseJsonArray(jsonString) {
        try {
            return JSON.parse(jsonString || '[]');
        } catch (e) {
            return [];
        }
    },

    // View scan details
    async viewScanDetails(scanId) {
        try {
            const response = await fetch(`/api/allergy-scans/${scanId}`);
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
                    <h3>Allergy Scan Details</h3>
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
                            <strong>Product:</strong> ${scan.product_name || 'Unknown Product'}
                        </div>
                        <div class="detail-row">
                            <strong>Barcode:</strong> ${scan.barcode || 'N/A'}
                        </div>
                        <div class="detail-row">
                            <strong>Status:</strong> <span class="badge ${scan.is_safe ? 'badge-success' : 'badge-danger'}">${scan.is_safe ? 'Safe' : 'Unsafe'}</span>
                        </div>
                        <div class="detail-row">
                            <strong>Detected Allergens:</strong>
                        </div>
                        <div class="allergen-details">
                            ${this.parseJsonArray(scan.detected_allergens).map(allergen => 
                                `<div class="allergen-item">
                                    <i class="fas fa-exclamation-triangle"></i>
                                    <span>${allergen}</span>
                                </div>`
                            ).join('')}
                        </div>
                        <div class="detail-row">
                            <strong>Dietary Violations:</strong>
                        </div>
                        <div class="violations-details">
                            ${this.parseJsonArray(scan.dietary_violations).map(violation => 
                                `<div class="violation-item">
                                    <i class="fas fa-times-circle"></i>
                                    <span>${violation}</span>
                                </div>`
                            ).join('')}
                        </div>
                        <div class="detail-row">
                            <strong>Recommendations:</strong>
                        </div>
                        <div class="recommendations-list">
                            ${this.parseJsonArray(scan.recommendations).map(rec => 
                                `<div class="recommendation-item">
                                    <i class="fas fa-info-circle"></i>
                                    <span>${rec}</span>
                                </div>`
                            ).join('')}
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
        const rows = document.querySelectorAll('#allergy-scans-table-body tr');
        
        rows.forEach(row => {
            const text = row.textContent.toLowerCase();
            const matches = text.includes(query.toLowerCase());
            row.style.display = matches ? '' : 'none';
        });
    },

    // Initialize search functionality
    initSearch() {
        const searchInput = document.getElementById('allergy-search');
        if (searchInput) {
            searchInput.addEventListener('input', (e) => {
                this.searchScans(e.target.value);
            });
        }
    }
};
