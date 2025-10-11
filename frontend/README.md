# TWL Pipeline Frontend

Next.js frontend for the TWL Data Pipeline project.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Configure environment variables:
```bash
cp .env.example .env.local
# Edit .env.local with your API Gateway URL
```

3. Run development server:
```bash
npm run dev
```

4. Open [http://localhost:3000](http://localhost:3000)

## Features

- **Dashboard**: Real-time analytics with charts (records by source, ingestion timeline)
- **Records List**: Browse all ingested records with source filtering
- **Record Detail**: View complete information for each record

## Tech Stack

- Next.js 14 (App Router)
- TypeScript
- Tailwind CSS
- Recharts (data visualization)

