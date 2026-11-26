# Smart Inventory — Deber 02

Proyecto PostgreSQL para gestión de inventario por lotes.

## Archivos

- `01_schema.sql` a `05_indexes_views.sql`: esquema, datos, consultas, transacciones, vistas e índices.
- `evidencia_consultas/resultados_consultas_sprint2.docx`: resultados de las ocho consultas.
- `MATRIZ_PRUEBAS_INTEGRIDAD.md`: pruebas de restricciones.
- `EVIDENCIA_CONCURRENCIA.md` y `EVIDENCIA_RENDIMIENTO.md`: estado y procedimiento de validación.
- `informe_final.pdf`: informe.
- `exposicion_sprint3.md`: guion de exposición.
- Diagramas del modelo.

## Ejecución

En PostgreSQL, ejecutar en orden: `01_schema.sql`, `02_seed.sql`, `03_queries.sql`, `04_transactions.sql` y `05_indexes_views.sql`.

La prueba de concurrencia con dos sesiones sigue pendiente. En rendimiento falta guardar el plan previo de la consulta de stock.
