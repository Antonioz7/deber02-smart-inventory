# Matriz de pruebas de integridad — Sprint 2

| Regla probada | Operación | Resultado observado | Conclusión |
|---|---|---|---|
| FK inválida | Insertar una ubicación con `bodega_id = -999999` | Error `23503`, `ubicacion_bodega_id_fkey`; bodega no existe | Rechazada correctamente |
| Cantidad negativa | Insertar `cantidad_fisica = -1` en `existencia_lote` | Error `23514`, `existencia_lote_cantidad_fisica_check` | Rechazada correctamente |
| Clave duplicada | Insertar otra bodega con nombre `Bodega Quito` | Error `23505`, `bodega_nombre_key` | Rechazada correctamente |
| Estado no permitido | Insertar orden con estado `estado_invalido` | Error `23514`, `orden_compra_estado_check` | Rechazada correctamente |
| Recepción anterior a la orden | Insertar recepción con fecha un día anterior a la orden parcial | Antes del trigger se aceptó y se revirtió; luego el trigger la rechazó con error `23514` | Regla aplicada tras agregar `trg_validar_fecha_recepcion_orden` a `01_schema.sql` |

Las inserciones de prueba que podían aceptar datos se ejecutaron dentro de una transacción y se revirtieron. La regla de fecha se volvió a probar después de aplicar el trigger a la base.
