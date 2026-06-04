# PostgreSQL Docker example

This directory contains a local PostgreSQL example for testing the optional
`learnrTrackR` PostgreSQL backend.

This setup is intended for local development and deployment rehearsal. It is
not a full production configuration.

## Start PostgreSQL

Copy the example environment file and replace the password:

```sh
cp env.example .env
```

Edit `.env`, then start the service:

```sh
docker compose --env-file .env up -d
```

## Run the R smoke test

From this directory:

```sh
Rscript smoke-test.R
```

The script connects to PostgreSQL, creates the tracking schema, inserts a
unique demo course, student, question set, and attempt, then prints the
gradebook row.

## Stop PostgreSQL

```sh
docker compose --env-file .env down
```

To delete the local PostgreSQL data volume:

```sh
docker compose --env-file .env down -v
```
