

## Manual Steps

### Adding an Additional PostgreSQL Database

Manual steps are neded to add another psql database. The `litellm` database is created by default and the `rag` database
needs to be manually added. Follow the steps below from within the AWS Console under "Amazon RDS".

1. Adding a new database for the RAG API

Navigate to the query builder in Amazon RDS. Connect to the LiteLLM database to start (`litellm`). Run the command

```
create database rag;
```

2. Enable the vector extension

Connect to the newly created RAG database (`rag`). Run the command

```
CREATE EXTENSION vector;
```

Now the new database should be present with vector datastore capabilities.
