

# Manual Steps

1. Adding a new database for LibreChat

Navigate to the query builder in Amazon RDS. Connect to the LiteLLM database to start (`litellm`). Run the command

```
create database rag;
```

2. Enable the vector extension

Connect to the newly created RAG database (`rag`). Run the command

```
CREATE EXTENSION vector;
```
