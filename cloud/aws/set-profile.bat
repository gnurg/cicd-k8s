@echo off
set AWS_PROFILE=cicd-k8s
echo AWS_PROFILE set to: %AWS_PROFILE%
echo.
echo WARNING: Run this script with "call" to persist the variable in your session:
echo   call cloud\aws\set-profile.bat
echo.
echo To verify it worked, run: echo %%AWS_PROFILE%%
echo Expected output: cicd-k8s
