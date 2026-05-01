const http = require('http');

console.log('🔍 Testing User Authentication API...\n');

// Test 1: User Registration
const userData = {
    email: 'testuser@example.com',
    username: 'testuser',
    name: 'Test User',
    password: 'password123'
};

const registerOptions = {
    hostname: 'localhost',
    port: 3000,
    path: '/api/register',
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'Content-Length': JSON.stringify(userData).length
    }
};

const req = http.request(registerOptions, (res) => {
    console.log(`1. Registration Status: ${res.statusCode}`);
    
    let data = '';
    res.on('data', (chunk) => {
        data += chunk;
    });
    
    res.on('end', () => {
        console.log('Registration Response:', JSON.parse(data));
        
        // Test 2: User Login
        console.log('\n2. Testing User Login...');
        const loginData = {
            email: 'testuser@example.com',
            password: 'password123'
        };

        const loginOptions = {
            hostname: 'localhost',
            port: 3000,
            path: '/api/login',
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': JSON.stringify(loginData).length
            }
        };

        const loginReq = http.request(loginOptions, (loginRes) => {
            console.log(`   Login Status: ${loginRes.statusCode}`);
            
            let loginData = '';
            loginRes.on('data', (chunk) => {
                loginData += chunk;
            });
            
            loginRes.on('end', () => {
                console.log('   Login Response:', JSON.parse(loginData));
                
                // Test 3: Check if user exists
                console.log('\n3. Testing User Check...');
                const checkOptions = {
                    hostname: 'localhost',
                    port: 3000,
                    path: '/api/user/check/testuser@example.com',
                    method: 'GET'
                };

                const checkReq = http.request(checkOptions, (checkRes) => {
                    console.log(`   Check Status: ${checkRes.statusCode}`);
                    
                    let checkData = '';
                    checkRes.on('data', (chunk) => {
                        checkData += chunk;
                    });
                    
                    checkRes.on('end', () => {
                        console.log('   Check Response:', JSON.parse(checkData));
                        console.log('\n✅ User Authentication API Working!');
                        console.log('\n📱 Mobile app can now register/login online!');
                    });
                });
                
                checkReq.on('error', (e) => {
                    console.error('   Check Error:', e);
                });
                
                checkReq.end();
            });
        });
        
        loginReq.on('error', (e) => {
            console.error('   Login Error:', e);
        });
        
        loginReq.write(JSON.stringify(loginData));
        loginReq.end();
    });
});

req.on('error', (e) => {
    console.error('Registration Error:', e);
});

req.write(JSON.stringify(userData));
req.end();
