-- Runs automatically on first container start (empty data volume only).
-- Enables the pgvector extension so your Laravel migrations can use the
-- `vector` column type. Schema/tables are owned by your app's migrations.

CREATE EXTENSION IF NOT EXISTS vector;
