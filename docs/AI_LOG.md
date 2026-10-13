# AI Usage Log

## 2026-10-13 — SwiftData warranty model

Cursor agent added `WarrantyItem`, `ItemCategory`, and `WarrantyStatus`, plus `WarrantyRepository` for create, read, update, delete, search, sort, and filter. The model is registered in `ModelContainerFactory`. Existing container tests now expect that schema. Preview sample warranties were added. I reviewed the generated model, repository, and tests before keeping them.
