# Informe final — Smart Inventory

**Deber 02 | PostgreSQL | 25 de noviembre de 2026**

## 1. Objetivo y alcance

Smart Inventory administra productos en lotes y ubicaciones, calcula el inventario disponible, prioriza el picking por fecha de vencimiento (FEFO) y registra pedidos, reservas, movimientos y recepciones de compra. La entrega comprende cinco scripts SQL, resultados de ocho consultas, pruebas de integridad, una estrategia transaccional, vistas, índices y material de exposición.

## 2. Modelo relacional y normalización

El esquema separa producto, proveedor, bodega, ubicación, lote, existencia, pedido, línea de pedido, reserva, movimiento, orden de compra y recepción. `existencia_lote` almacena físico y reservado por combinación lote/ubicación; la disponibilidad se calcula como físico menos reservado. Esta decisión mantiene saldo rápido y detalle trazable, pero obliga a sincronizar las modificaciones del saldo con los movimientos.

Dependencias funcionales principales: `sku -> nombre, stock_minimo, stock_objetivo`; `lote_id -> sku, codigo_lote, fecha_vencimiento`; `(lote_id, ubicacion_id) -> cantidad_fisica, cantidad_reservada`; `linea_pedido_id -> pedido_id, sku, cantidad_solicitada`; `linea_orden_id -> orden_compra_id, sku, cantidad_ordenada`. En una relación desnormalizada, los datos del producto repetidos por lote o línea causarían anomalías de actualización. La separación de entidades y el uso de tablas de detalle resuelven esa repetición; las claves identifican las filas y los atributos dependen de ellas. El diseño alcanza 3FN en las relaciones centrales. En producto, lote y existencia, cada determinante documentado es una clave candidata, por lo que satisfacen BCNF bajo las restricciones únicas declaradas.

## 3. Reglas e integridad

PK identifican filas; FK mantienen relaciones; `UNIQUE` impide códigos/nombres duplicados donde corresponde; `CHECK` restringe cantidades y estados permitidos. Un trigger verifica que la fecha de recepción no anteceda a la orden de compra. Las cinco pruebas observadas rechazaron FK inexistente (`23503`), cantidad física negativa (`23514`), nombre de bodega repetido (`23505`), estado de orden inválido (`23514`) y fecha de recepción anterior a la orden (`23514`). La matriz registra también que la primera prueba de fecha se revirtió antes de añadir el trigger, y volvió a fallar como se esperaba después.

## 4. Consultas y resultados observados

Las ocho consultas cubren saldo por lote/ubicación, lotes por vencer, picking FEFO, reposición, trazabilidad, recepción parcial, rotación y nivel de servicio. El picking usa una suma acumulada para repartir demanda entre lotes en orden de vencimiento. En las capturas guardadas, distribuyó 30 unidades: 12 del lote AR-100 y 18 de AR-101. La consulta de vencimientos dentro de 30 días devolvió cero filas. Reposición sugirió 26 unidades para SKU-ACEITE (disponible 4, objetivo 30). El pedido de arroz mostró demanda de 30 pendiente. Las capturas de rotación muestran cero despachos para los productos del seed, por lo que la rotación calculada es cero. La consulta de nivel de servicio muestra 30 solicitadas, cero despachadas y nivel 0% para arroz. Ver las imágenes en `evidencia_consultas/`.

## 5. Transacción FEFO y concurrencia

`04_transactions.sql` crea `reservar_fefo(linea_pedido_id)`. Bloquea la línea y las filas de existencia elegibles con `FOR UPDATE`, las ordena por vencimiento, vuelve a calcular disponibilidad y registra reserva y saldo reservado. Si el stock total es insuficiente, lanza excepción dentro de la llamada; PostgreSQL revierte sus cambios con la transacción.

El fixture aislado plantea dos solicitudes de 6 contra 10 unidades vigentes: 4 en el primer lote y 6 en el segundo. También contiene 99 unidades vencidas, excluidas del picking. El resultado esperado es que una sesión confirme 6 (4 + 2), y la segunda, tras esperar el lock y releer, falle por stock insuficiente; al final quedan 4. **La prueba de dos sesiones no se ejecutó/observó en esta entrega.** `EVIDENCIA_CONCURRENCIA.md` incluye pasos para correrla y los resultados esperados, no evidencia experimental. Por tanto, no se atribuyen tiempos de espera, deadlocks ni reintentos observados.

## 6. Vistas, índices y plan de rendimiento

`05_indexes_views.sql` define `vw_stock_disponible`, para consultar saldo con trazabilidad hasta ubicación/lote, y `vw_reposicion_sugerida`, que combina stock vigente y compras pendientes con el objetivo. Incluye tres consultas y cuatro índices sobre lote, existencia, reserva y movimiento. El script se ejecutó en DBeaver: se crearon las vistas e índices y se generaron los seis planes EXPLAIN (ANALYZE, BUFFERS). Las mediciones visibles se registraron en `EVIDENCIA_RENDIMIENTO.md`; no quedó copiado el plan anterior de la consulta de stock. Los datos son pequeños y varios planes usan `Seq Scan`, por lo que las diferencias observadas no demuestran rendimiento productivo. Índices consumen espacio y añaden costo de escritura.

## 7. Límites y decisiones

Las consultas de rotación usan saldo disponible actual como aproximación, pues no hay snapshots históricos para calcular inventario promedio. El seed y las capturas prueban funcionalidad, no carga productiva. El saldo guardado en `existencia_lote` y el libro de `movimiento` deben mantenerse coherentes por los flujos de recepción, reserva, liberación, ajuste y despacho; esta entrega no debe interpretarse como una conciliación automática completa de ambos. La prueba de concurrencia con dos sesiones aún requiere ejecución y captura en DBeaver; los planes de rendimiento sí se ejecutaron, con el límite de registro descrito arriba.

## 8. Archivos de entrega

`01_schema.sql`, `02_seed.sql`, `03_queries.sql`, `04_transactions.sql`, `05_indexes_views.sql`, `README.md`, matriz de integridad, plan, capturas y Word de resultados, `EVIDENCIA_CONCURRENCIA.md`, `EVIDENCIA_RENDIMIENTO.md` y `exposicion_sprint3.md`.

## Conclusión

El repositorio contiene el modelo, las consultas y una implementación transaccional que define cómo proteger reservas FEFO. Las consultas de Sprint 2, las reglas de integridad y los seis planes EXPLAIN se ejecutaron; se guardaron resultados y mediciones disponibles. Para cerrar la validación experimental de Sprint 3 falta ejecutar la prueba de dos sesiones y guardar su evidencia, además de recuperar el plan anterior de la consulta de stock.
