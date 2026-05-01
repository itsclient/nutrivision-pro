@echo off
echo ========================================
echo    Dessert AI Admin Dashboard Runner
echo ========================================
echo.

echo [1/4] Checking Node.js installation...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Node.js not found!
    echo Please install Node.js from https://nodejs.org
    pause
    exit /b 1
)
echo ✅ Node.js found

echo.
echo [2/4] Installing dependencies...
cd backend
call npm install
if %errorlevel% neq 0 (
    echo ❌ Failed to install dependencies
    pause
    exit /b 1
)
echo ✅ Dependencies installed

echo.
echo [3/4] Starting admin server...
echo.
echo 🌐 Admin Dashboard will be available at: http://localhost:3000
echo 🔐 Login with: admin@gmail.com / admin123
echo.
echo ⚠️  Keep this window open to keep the server running!
echo ⚠️  Press Ctrl+C to stop the server
echo.

call npm start
