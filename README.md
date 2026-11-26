# Smart Inventory — Deber 02

Proyecto académico de base de datos para inventario por producto, lote y ubicación, implementado en PostgreSQL.

## Contenido

- `01_schema.sql`: tablas, claves, restricciones y trigger para validar que una recepción no preceda a la orden de compra.
- `02_seed.sql`: datos de ejemplo para dos bodegas, lotes vigentes, vencidos y agotados, un pedido que requiere más de un lote y una recepción parcial.
- `03_queries.sql`: las ocho consultas requeridas para el Sprint 2.
- `MATRIZ_PRUEBAS_INTEGRIDAD.md`: resultados observados de las cinco pruebas de integridad.
- `PLAN_DE_TRABAJO.md`: alcance y plan de los sprints.
- `RELACIONAL.png` y `Smart Inventory - Modelo ER.drawio.png`: diagramas del modelo.
- `Deber2_Bases_de_Datos_Smart_Inventory_USFQ (1).docx`: documento del deber.

## Requisitos

- PostgreSQL 18 o compatible.
- DBeaver u otro cliente PostgreSQL.

## Ejecutar desde una base vacía

1. Crear la base `deber02DB`.
2. Conectarse a esa base.
3. Ejecutar `01_schema.sql`.
4. Ejecutar `02_seed.sql` una sola vez.
5. Ejecutar las consultas de `03_queries.sql` individualmente para revisar cada resultado.

En DBeaver, abrir cada archivo SQL con la conexión `deber02DB`. `Alt+X` ejecuta el script completo y `Ctrl+Enter` ejecuta la instrucción actual.

## Estado

Sprint 2: scripts creados; esquema y seed ejecutados; cinco pruebas de integridad rechazadas como se esperaba; consultas ejecutadas y resultados guardados por el estudiante.

Sprint 3: transacciones y concurrencia, índices y vistas, mediciones de rendimiento, informe PDF y exposición pendientes.
