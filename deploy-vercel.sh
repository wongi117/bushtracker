#!/bin/bash
# BushTrack Vercel Deployment Script
# Usage: ./deploy-vercel.sh

echo "🚀 BushTrack Vercel Deployment"
echo "================================"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter not found! Please install Flutter first.${NC}"
    exit 1
fi

# Check if Vercel CLI is installed
if ! command -v vercel &> /dev/null; then
    echo -e "${YELLOW}⚠️  Vercel CLI not found. Installing...${NC}"
    npm install -g vercel
fi

echo -e "${GREEN}✅ Dependencies checked${NC}"

# Build Flutter web app
echo -e "${YELLOW}🏗️  Building Flutter web app...${NC}"
flutter build web --release

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Flutter build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Flutter build successful${NC}"

# Deploy to Vercel
echo -e "${YELLOW}🚀 Deploying to Vercel...${NC}"

# Check if already logged in to Vercel
vercel whoami &> /dev/null
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}🔑 Please login to Vercel:${NC}"
    vercel login
fi

# Check if project is already linked
if [ -d ".vercel" ]; then
    echo -e "${GREEN}✅ Project already linked to Vercel${NC}"
    # Deploy to production
    vercel --prod
else
    echo -e "${YELLOW}🔗 Linking new project to Vercel...${NC}"
    # First time deployment
    vercel
fi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Deployment successful!${NC}"
    echo -e "${GREEN}🌐 Your app is now live!${NC}"
else
    echo -e "${RED}❌ Deployment failed!${NC}"
    exit 1
fi
