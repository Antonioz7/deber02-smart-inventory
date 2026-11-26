# Smart Inventory — Deber 02

Proyecto académico de base de datos para inventario por producto, lote y ubicación, implementado en PostgreSQL.

## Contenido

- `01_schema.sql`: tablas, claves, restricciones y trigger para validar que una recepción no preceda a la orden de compra.
- `02_seed.sql`: datos de ejemplo para dos bodegas, lotes vigentes, vencidos y agotados, un pedido que requiere más de un lote y una recepción parcial.
- `03_queries.sql`: las ocho consultas requeridas para el Sprint 2.
- `04_transactions.sql`: reserva FEFO atómica y datos aislados para el escenario de concurrencia.
- `05_indexes_views.sql`: dos vistas de dashboard, tres consultas de plan y cuatro índices propuestos.
- `MATRIZ_PRUEBAS_INTEGRIDAD.md`: resultados observados de las cinco pruebas de integridad.
- `PLAN_DE_TRABAJO.md`: alcance y plan de los sprints.
- `EVIDENCIA_CONCURRENCIA.md` y `EVIDENCIA_RENDIMIENTO.md`: procedimiento reproducible y registro de estado de las pruebas.
- `informe_final.pdf`: informe del proyecto y límites de validación.
- `exposicion_sprint3.md`: guion para una exposición de 8–10 minutos.
- `evidencia_consultas/`: capturas de los ocho resultados de Sprint 2 y documento Word original.
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

Sprint 2: esquema y seed ejecutados; cinco pruebas de integridad rechazadas como se esperaba; el estudiante ejecutó las ocho consultas y guardó sus resultados en Word. Las capturas están en `evidencia_consultas/`.

Sprint 3: scripts, vistas, índices, informe y guion de exposición incluidos. `04_transactions.sql` y `05_indexes_views.sql` se ejecutaron en DBeaver; los seis planes EXPLAIN se generaron y las mediciones visibles se registraron en `EVIDENCIA_RENDIMIENTO.md`. Falta ejecutar y capturar la prueba de concurrencia con dos sesiones. Tampoco quedó copiado el plan anterior de la consulta de stock.

## Orden para Sprint 3

1. Ejecutar `04_transactions.sql` conectado a `deber02DB`. Revisar los dos `linea_pedido_id` que genera.
2. Seguir `EVIDENCIA_CONCURRENCIA.md` en dos sesiones para FEFO, rollback y contención de stock; guardar capturas/resultados.
3. Recuperar el plan previo de la consulta de stock y anexarlo a `EVIDENCIA_RENDIMIENTO.md` para completar el registro.
