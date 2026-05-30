@echo off
REM run.bat — Local development launcher (DO NOT use this in Docker builds)
REM Uses the .env file in this folder; it does not export system-wide environment variables.
REM Recommendation: add .env to .dockerignore so it won't be included in images.

SETLOCAL

REM Check if we're in the correct folder (Dockerapp)
if not exist "app.py" (
    if exist "Dockerapp\app.py" (
        echo Navigating to Dockerapp folder...
        cd Dockerapp
    ) else (
        echo Error: app.py not found. Please run this script from the Dockerapp folder.
        pause
        exit /b 1
    )
)

REM Create virtualenv if missing
if not exist ".venv\Scripts\activate" (
    echo Creating virtual environment...
    python -m venv .venv
)

REM Activate virtualenv
echo Activating virtual environment...
call .venv\Scripts\activate

REM Install dependencies (no global changes)
echo Installing dependencies...
pip install -r requirements.txt

REM Run the app (dotenv is loaded by app.py)
echo Starting app...
python app.py

ENDLOCAL
pause
