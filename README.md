# Project Management Tool

A secure project management system that allows credentialed accounts to share tasks and assignments with both credentialed and non-credentialed users.

## Technology Stack

- Ruby on Rails 8.0 for the backend
- Vite Ruby for asset bundling
- Vue.js for the client-side framework
- PostgreSQL for the database, using Supabase for hosting
- Row-level security (RLS) for fine-grained access control
- SolidQueue for background job processing
- SolidCache for caching
- SolidCable for ActionCable

## Features

- Multi-organization support with secure data separation
- User authentication and role-based permissions
- Project and task management with Gantt chart visualization
- Task dependencies and hierarchies
- Secure sharing with external users (non-credentialed)
- Email notifications for task assignments and updates
- Row-level security at the database level

## Development Setup

### Prerequisites

- Ruby 3.4+
- Node.js 20+
- PostgreSQL 14+ or Supabase account

### Step 1: Clone and Setup

```bash
git clone [repository_url]
cd projectmgt
bin/setup
```

### Step 2: Configure Supabase

1. Create a new Supabase project
2. Copy the project URL and API key from your Supabase dashboard
3. Create a `.env` file based on `.env.template`
4. Update the following variables in your `.env` file:
   ```
   SUPABASE_URL=https://your-project-id.supabase.co
   SUPABASE_API_KEY=your-supabase-key
   DATABASE_URL=postgres://postgres:password@db.your-project-id.supabase.co:5432/postgres
   SUPABASE_JWT_SECRET=your-jwt-secret-from-supabase
   ```

### Step 3: Initialize Database

```bash
rails db:create
rails db:migrate
rails db:seed
```

### Step 4: Run the Application

```bash
bin/dev
```

The application will be available at `http://localhost:3000`.

## Deployment

The application can be deployed using Kamal:

```bash
bin/kamal setup
bin/kamal deploy
```

## Security

This application implements row-level security at both the database and application levels:

1. PostgreSQL RLS policies for data isolation
2. Organization-based access controls
3. Fine-grained permissions for resources
4. Secure sharing via tokenized links
5. Authentication via JWT for API access

## License

MIT
