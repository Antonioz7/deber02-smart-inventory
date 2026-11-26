# Evidencia de vistas e índices — Sprint 3

## Qué incluye el script

`05_indexes_views.sql` crea las vistas `vw_stock_disponible` y `vw_reposicion_sugerida`, ejecuta tres consultas con `EXPLAIN (ANALYZE, BUFFERS)`, crea cuatro índices y repite las mismas consultas.

| Índice | Acceso que busca apoyar |
|---|---|
| `idx_lote_sku_vencimiento` | Selección de lotes de un SKU en orden FEFO |
| `idx_existencia_ubicacion_lote` | Búsquedas por ubicación y lote |
| `idx_reserva_linea_estado` | Trazabilidad de reservas activas por línea |
| `idx_movimiento_reserva_tipo_fecha` | Movimientos de una reserva, tipo y fecha |

## Estado de las mediciones

`05_indexes_views.sql` se ejecutó en DBeaver sobre `deber02DB`; se crearon las vistas e índices y se ejecutaron los seis planes. La base tenía el seed y los fixtures de `04_transactions.sql`. Se copiaron estas mediciones visibles en DBeaver:

| Consulta | Momento | Execution Time | Buffers observados | Plan observado |
|---|---|---:|---|---|
| Stock por SKU/ubicación | Después | 0.126–0.128 ms | shared hit=16 | Incluye Index Only Scan en `producto_pkey`; Seq Scan en existencia |
| Lotes por vencer | Antes | 0.048 ms | shared hit=3 | Seq Scan en lotes |
| Lotes por vencer | Después | 0.035–0.036 ms | shared hit=2 | Seq Scan en lotes |
| Rotación/nivel de servicio | Antes | 0.047–0.048 ms | shared hit=6 | GroupAggregate y Seq Scan |
| Rotación/nivel de servicio | Después | 0.013–0.015 ms | shared hit=33, read=2 | HashAggregate/Hash Right Join y Seq Scan |

La medición anterior de la consulta de stock no quedó copiada en este registro. En estas tablas pequeñas el optimizador mantuvo varios `Seq Scan`; una ejecución aislada con tiempos submilisegundo tampoco demuestra una mejora estable. Las observaciones describen únicamente esta base y no una carga productiva.

## Cómo registrar la comparación

Para completar la comparación, recuperar/capturar también el plan anterior de la consulta de stock y guardar los seis resultados completos. Comparar nodos, filas estimadas/reales, `Planning Time`, `Execution Time` y buffers con la misma base y datos. Repetir con datos representativos si el objetivo es decidir índices para producción.

Los índices pueden reducir lecturas y tiempo de ciertas búsquedas, pero usan espacio y añaden costo a `INSERT`, `UPDATE` y `DELETE`. La existencia de un índice no obliga al optimizador a usarlo.
