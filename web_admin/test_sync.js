const http = require('http');

// Test sync endpoint with mobile app data
const syncData = {
    user: {
        email: 'test@example.com',
        username: 'test_user',
        name: 'Test User',
        password: 'password123'
    },
    scans: [
        {
            dessert_name: 'Cheesecake',
            confidence: 0.94,
            calories: 380,
            protein_grams: 6,
            carbs_grams: 38,
            fat_grams: 22,
            category: 'Cake',
            is_favorite: true,
            image_base64: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI9jU77yQAAAABJRU5ErkJggg==',
            timestamp: new Date().toISOString()
        }
    ]
};

const syncOptions = {
    hostname: 'localhost',
    port: 3000,
    path: '/api/sync',
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'Content-Length': JSON.stringify(syncData).length
    }
};

const req = http.request(syncOptions, (res) => {
    console.log(`Sync Status: ${res.statusCode}`);
    
    let data = '';
    res.on('data', (chunk) => {
        data += chunk;
    });
    
    res.on('end', () => {
        console.log('Sync Response:', JSON.parse(data));
        
        // Test getting all users
        const usersOptions = {
            hostname: 'localhost',
            port: 3000,
            path: '/api/admin/users',
            method: 'GET'
        };
        
        const usersReq = http.request(usersOptions, (usersRes) => {
            console.log(`\nUsers Status: ${usersRes.statusCode}`);
            
            let usersData = '';
            usersRes.on('data', (chunk) => {
                usersData += chunk;
            });
            
            usersRes.on('end', () => {
                console.log('Users Response:', JSON.parse(usersData));
            });
        });
        
        usersReq.on('error', (e) => {
            console.error('Users Error:', e);
        });
        
        usersReq.end();
    });
});

req.on('error', (e) => {
    console.error('Sync Error:', e);
});

req.write(JSON.stringify(syncData));
req.end();

console.log('Testing mobile app sync functionality...');
