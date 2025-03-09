#\!/bin/bash
echo "Stopping vite and rails servers..."
lsof -t -i:5173 | xargs kill -9 2>/dev/null
lsof -t -i:3000 | xargs kill -9 2>/dev/null
echo "Rebuilding assets..."
yarn build
echo "Starting servers again..."
foreman start -f Procfile.dev
