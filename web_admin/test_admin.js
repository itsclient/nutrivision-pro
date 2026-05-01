const http = require('http');

// Test admin login
const loginData = JSON.stringify({
    email: 'admin@gmail.com',
    password: 'admin123'
});

const loginOptions = {
    hostname: 'localhost',
    port: 3000,
    path: '/api/admin/login',
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'Content-Length': loginData.length
    }
};

const req = http.request(loginOptions, (res) => {
    console.log(`Login Status: ${res.statusCode}`);
    
    let data = '';
    res.on('data', (chunk) => {
        data += chunk;
    });
    
    res.on('end', () => {
        console.log('Login Response:', JSON.parse(data));
        
        // Test getting stats
        const statsOptions = {
            hostname: 'localhost',
            port: 3000,
            path: '/api/admin/stats',
            method: 'GET'
        };
        
        const statsReq = http.request(statsOptions, (statsRes) => {
            console.log(`\nStats Status: ${statsRes.statusCode}`);
            
            let statsData = '';
            statsRes.on('data', (chunk) => {
                statsData += chunk;
            });
            
            statsRes.on('end', () => {
                console.log('Stats Response:', JSON.parse(statsData));
            });
        });
        
        statsReq.on('error', (e) => {
            console.error('Stats Error:', e);
        });
        
        statsReq.end();
    });
});

req.on('error', (e) => {
    console.error('Login Error:', e);
});

req.write(loginData);
req.end();

console.log('Testing admin dashboard API...');
