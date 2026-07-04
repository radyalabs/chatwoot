# Remove Mongoid Integration Plan

## Goal

Remove the Mongoid integration completely, including the MongoDB-backed Excel import feature that currently depends on Mongoid.

## Current Usage

Mongoid is used by the Excel import flow:

- `Gemfile` includes `gem 'mongoid', '~> 8.0'`.
- `Gemfile.lock` includes `mongoid` and its dependencies.
- `config/initializers/mongoid.rb` loads Mongoid configuration.
- `config/mongoid.yml` reads `MONGODB_URL`.
- `app/services/excel_import/excel_import_service.rb` includes `Mongoid::Document` and stores import records.
- `app/services/excel_import/excel_import_row.rb` includes `Mongoid::Document` and stores imported rows.
- `app/controllers/api/v2/accounts/excel_imports_controller.rb` calls the Mongoid-backed service and rescues `Mongoid::Errors::DocumentNotFound`.
- `config/routes.rb` exposes `knowledge_sources/excel_imports` routes.
- `app/javascript/dashboard/api/aiAgents.js` exposes frontend API wrappers for Excel import upload/delete.
- `app/models/knowledge_source.rb` has `add_excel_file!`, which stores the MongoDB import id in `knowledge_source_files.loader_id`.

Generated/runtime files such as `coverage/`, `log/`, `.git/`, and `.ruby-lsp/` may contain Mongoid references, but they are not part of the runtime integration.

## Decision

Delete the Excel import feature completely instead of migrating it to PostgreSQL.

This means:

- The Excel import API endpoint will be removed.
- The frontend API client methods for this endpoint will be removed.
- Existing `knowledge_source_files` rows whose `loader_id` points to MongoDB import ids will no longer have a MongoDB backend path.
- No compatibility fallback will be added.

## Implementation Steps

1. Remove Mongoid dependency from `Gemfile`.
2. Run `bundle install` to update `Gemfile.lock`.
3. Delete `config/initializers/mongoid.rb`.
4. Delete `config/mongoid.yml`.
5. Delete `app/services/excel_import/excel_import_service.rb`.
6. Delete `app/services/excel_import/excel_import_row.rb`.
7. Delete `app/controllers/api/v2/accounts/excel_imports_controller.rb`.
8. Remove the `knowledge_sources/excel_imports` route from `config/routes.rb`.
9. Remove `addExcelKnowledgeFile` and `deleteExcelKnowledgeFile` from `app/javascript/dashboard/api/aiAgents.js`.
10. Remove `KnowledgeSource#add_excel_file!` after confirming there are no remaining callers.
11. Search for remaining active references to:
    - `mongoid`
    - `Mongoid`
    - `mongodb`
    - `MongoDB`
    - `ExcelImport`
    - `excel_imports`
    - `add_excel_file`

## Verification

Run backend boot/autoload verification:

```sh
eval "$(rbenv init -)" && bundle exec rails zeitwerk:check
```

Run focused Ruby lint:

```sh
eval "$(rbenv init -)" && bundle exec rubocop Gemfile app/models/knowledge_source.rb config/routes.rb
```

Run focused frontend lint if `aiAgents.js` changes:

```sh
pnpm eslint app/javascript/dashboard/api/aiAgents.js
```

Run final reference searches and ensure no active source/config dependency remains.
