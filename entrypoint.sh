#!/bin/bash
# entrypoint.sh

# Wait for the database to be ready
until pg_isready -h db -p 5432 -U postgres; do
  echo "Waiting for database..."
  sleep 2
done

# Run migrations
/app/bin/migrate

# Start the server
/app/bin/server
