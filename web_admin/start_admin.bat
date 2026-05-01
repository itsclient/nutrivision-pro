@echo off
echo Starting Dessert AI Admin Dashboard...
echo.
echo Installing dependencies...
cd backend
call npm install
echo.
echo Starting server...
echo Admin dashboard will be available at: http://localhost:3000
echo Login with: admin@gmail.com / admin123
echo.
call npm start
pause
