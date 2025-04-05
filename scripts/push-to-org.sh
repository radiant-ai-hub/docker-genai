rm -rf .git
git init
git add .
git commit -m "init 2025"
gh repo create radiant-ai-hub/docker-genai --private --source=. --push