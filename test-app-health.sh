#!/bin/bash

# Verify app is running and check subscription workflow

echo "=========================================="
echo "Testing Application Setup"
echo "=========================================="

# 1. Check if app is running
echo ""
echo "1. Checking if app is running on port 8080..."
if ps aux | grep "npm start" | grep -v grep > /dev/null; then
    echo "   ✓ App is running"
else
    echo "   ✗ App is NOT running - restarting..."
    cd ~/webapp
    pkill -f "npm start"
    sleep 2
    nohup npm start > app.log 2>&1 &
    sleep 3
fi

# 2. Check if port is listening
echo ""
echo "2. Checking if port 8080 is listening..."
if netstat -tlnp 2>/dev/null | grep 8080 > /dev/null; then
    echo "   ✓ Port 8080 is listening"
elif ss -tlnp 2>/dev/null | grep 8080 > /dev/null; then
    echo "   ✓ Port 8080 is listening"
else
    echo "   ✗ Port 8080 is NOT listening"
fi

# 3. Test health endpoint
echo ""
echo "3. Testing /health endpoint..."
HEALTH=$(curl -s http://localhost:8080/health 2>&1)
if echo "$HEALTH" | grep -q "healthy"; then
    echo "   ✓ Health check passed"
    echo "   Response: $HEALTH"
else
    echo "   Response: $HEALTH"
fi

# 4. Check app logs
echo ""
echo "4. Recent app logs:"
tail -10 ~/webapp/app.log 2>/dev/null || echo "   (No logs found)"

# 5. Check SNS credentials
echo ""
echo "5. Checking AWS credentials..."
aws sts get-caller-identity --region ap-south-1 2>&1 | head -3

# 6. Check SNS topic exists
echo ""
echo "6. Checking SNS topic..."
TOPIC=$(aws sns get-topic-attributes --topic-arn arn:aws:sns:ap-south-1:908601827639:webproject-UploadsNotificationTopic --region ap-south-1 2>&1 | grep -o "webproject-UploadsNotificationTopic" || echo "NOT FOUND")
echo "   Topic: $TOPIC"

echo ""
echo "=========================================="
echo "Setup Summary"
echo "=========================================="
echo "App URL: http://localhost:8080"
echo "Health: http://localhost:8080/health"
echo "Subscribe to emails and CHECK YOUR INBOX for confirmation!"
echo "=========================================="
