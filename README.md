# Postgres + pgvector Docker Template

A ready-to-run Postgres database with the [`pgvector`](https://github.com/pgvector/pgvector)
extension enabled, for storing OpenAI embeddings and running vector similarity
search. Your Laravel app connects to this and owns the schema via migrations.

## Stack

- **Image:** `pgvector/pgvector:pg17` (Postgres 17 with pgvector preinstalled)
- **Extension:** `vector` enabled automatically on first boot — that's all this template does

## Quick start

```bash
cp .env.example .env        # edit credentials if you like
docker compose up -d        # start in the background
docker compose logs -f db   # watch startup
```

Connect:

```bash
docker compose exec db psql -U postgres -d vectordb
# or from the host:
psql "postgresql://postgres:postgres@localhost:5432/vectordb"
```

Stop / reset:

```bash
docker compose down          # stop, keep data
docker compose down -v       # stop AND delete the data volume (re-runs init script)
```

> [init/01_init.sql](init/01_init.sql) only runs when the data volume is **empty**
> (first start). It just runs `CREATE EXTENSION IF NOT EXISTS vector;`. If the DB
> already exists, you can enable it manually once: `CREATE EXTENSION IF NOT EXISTS vector;`

## Laravel connection

In your Laravel `.env`:

```env
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=vectordb
DB_USERNAME=postgres
DB_PASSWORD=postgres
```

(If Laravel itself runs in Docker on the same compose network, set `DB_HOST` to
this service's name, e.g. `db`, instead of `127.0.0.1`.)

## Using vector columns in a migration

`pgvector` types aren't built into Laravel's schema builder, so use a raw
statement. Match the dimension to your OpenAI model:

| Model | Dimensions |
| --- | --- |
| `text-embedding-3-small` | 1536 |
| `text-embedding-ada-002` | 1536 |
| `text-embedding-3-large` | 3072 |

```php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('documents', function (Blueprint $table) {
            $table->id();
            $table->text('content');
            $table->jsonb('metadata')->default('{}');
            $table->timestamps();
        });

        // vector column + ANN index (cosine, the right fit for OpenAI embeddings)
        DB::statement('ALTER TABLE documents ADD COLUMN embedding vector(1536)');
        DB::statement('CREATE INDEX documents_embedding_hnsw_idx ON documents USING hnsw (embedding vector_cosine_ops)');
    }

    public function down(): void
    {
        Schema::dropIfExists('documents');
    }
};
```

> The `vector` extension is already enabled by this container, so your migration
> does **not** need `CREATE EXTENSION`. (If you'd rather Laravel own that too, add
> `DB::statement('CREATE EXTENSION IF NOT EXISTS vector')` — it's idempotent.)

## Distance operators

| Operator | Meaning | Index opclass |
| --- | --- | --- |
| `<=>` | cosine distance | `vector_cosine_ops` |
| `<->` | L2 / Euclidean distance | `vector_l2_ops` |
| `<#>` | negative inner product | `vector_ip_ops` |

OpenAI embeddings are normalized, so **cosine** (`<=>`) is the usual choice.
Cosine *similarity* = `1 - (a <=> b)`. Example search query:

```sql
SELECT id, content, 1 - (embedding <=> '[...]') AS similarity
FROM documents
ORDER BY embedding <=> '[...]'
LIMIT 5;
```

## Files

- [docker-compose.yml](docker-compose.yml) — the service definition
- [.env.example](.env.example) — configurable credentials / port
- [init/01_init.sql](init/01_init.sql) — enables the `vector` extension
