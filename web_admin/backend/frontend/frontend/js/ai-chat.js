// AI Chat Management
window.nutrivision = window.nutrivision || {};

window.nutrivision.aiChat = {
    // Load AI chat messages
    async loadChatMessages() {
        try {
            const response = await fetch('/api/analytics/overview');
            const data = await response.json();
            
            // Update stats
            document.getElementById('total-chat-messages').textContent = data.aiChatMessages || 0;
            
            // Load recent messages
            await this.loadRecentMessages();
        } catch (error) {
            console.error('Error loading AI chat data:', error);
        }
    },

    // Load recent chat messages
    async loadRecentMessages() {
        try {
            const response = await fetch('/api/ai-chat/messages/all');
            const messages = await response.json();
            
            const tbody = document.getElementById('chat-messages-table-body');
            tbody.innerHTML = '';
            
            messages.slice(0, 50).forEach(message => {
                const row = this.createMessageRow(message);
                tbody.appendChild(row);
            });
        } catch (error) {
            console.error('Error loading chat messages:', error);
        }
    },

    // Create message row
    createMessageRow(message) {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${message.user_email}</td>
            <td class="message-content">${this.truncateMessage(message.message_text, 50)}</td>
            <td><span class="badge ${message.sender_type === 'user' ? 'badge-primary' : 'badge-secondary'}">${message.sender_type}</span></td>
            <td>${new Date(message.timestamp).toLocaleString()}</td>
            <td>
                <button class="btn-action" onclick="window.nutrivision.aiChat.viewMessage('${message.id}')">
                    <i class="fas fa-eye"></i>
                </button>
            </td>
        `;
        return row;
    },

    // Truncate message text
    truncateMessage(text, maxLength) {
        return text.length > maxLength ? text.substring(0, maxLength) + '...' : text;
    },

    // View full message
    async viewMessage(messageId) {
        try {
            const response = await fetch(`/api/ai-chat/messages/${messageId}`);
            const message = await response.json();
            
            // Show message details in modal
            this.showMessageModal(message);
        } catch (error) {
            console.error('Error viewing message:', error);
        }
    },

    // Show message modal
    showMessageModal(message) {
        const modal = document.createElement('div');
        modal.className = 'modal';
        modal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h3>Chat Message Details</h3>
                    <button class="modal-close" onclick="this.closest('.modal').remove()">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
                <div class="modal-body">
                    <div class="message-details">
                        <div class="detail-row">
                            <strong>User:</strong> ${message.user_email}
                        </div>
                        <div class="detail-row">
                            <strong>Type:</strong> <span class="badge ${message.sender_type === 'user' ? 'badge-primary' : 'badge-secondary'}">${message.sender_type}</span>
                        </div>
                        <div class="detail-row">
                            <strong>Timestamp:</strong> ${new Date(message.timestamp).toLocaleString()}
                        </div>
                        <div class="detail-row">
                            <strong>Message:</strong>
                        </div>
                        <div class="message-text">
                            ${message.message_text}
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

    // Search chat messages
    searchMessages(query) {
        const rows = document.querySelectorAll('#chat-messages-table-body tr');
        
        rows.forEach(row => {
            const text = row.textContent.toLowerCase();
            const matches = text.includes(query.toLowerCase());
            row.style.display = matches ? '' : 'none';
        });
    },

    // Initialize search functionality
    initSearch() {
        const searchInput = document.getElementById('chat-search');
        if (searchInput) {
            searchInput.addEventListener('input', (e) => {
                this.searchMessages(e.target.value);
            });
        }
    }
};
