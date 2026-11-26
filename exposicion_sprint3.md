# Guion de exposición — Smart Inventory (8–10 minutos)

## 0:00–1:00 | Problema y alcance

Smart Inventory organiza inventario por producto, lote, bodega y ubicación. El objetivo es calcular disponibilidad rastreable, evitar reservar cantidades inexistentes y priorizar lotes con vencimiento más cercano.

## 1:00–2:30 | Modelo y normalización

Las entidades principales son producto, lote, existencia por ubicación, pedidos, reservas, movimientos, proveedores y órdenes de compra. `existencia_lote` relaciona un lote con una ubicación y guarda cantidad física y reservada; disponible se calcula como diferencia. Separar producto de lote evita repetir datos del producto por cada partida. Las tablas asociativas (`producto_proveedor`, líneas de pedido/compra) representan relaciones de varios a varios y almacenan atributos propios de la relación.

Dependencias principales: `sku → nombre, stock_minimo, stock_objetivo`; `lote_id → sku, codigo_lote, fecha_vencimiento`; `(lote_id, ubicacion_id) → cantidad_fisica, cantidad_reservada`; `linea_pedido_id → pedido_id, sku, cantidad_solicitada`. Estas claves y separaciones sostienen 3FN; las relaciones con clave compuesta también se evaluaron por determinantes candidatos al discutir BCNF.

## 2:30–4:00 | Consultas de Sprint 2 y FEFO

Las ocho consultas muestran disponibilidad, vencimientos, picking, reposición, trazabilidad, recepciones parciales, rotación y nivel de servicio. La consulta de picking usa una suma acumulada para repartir demanda entre lotes por fecha de vencimiento. En las capturas entregadas, el ejemplo asigna 12 unidades de AR-100 y 18 de AR-101 para cubrir 30. La consulta de vencimientos a 30 días no devolvió filas en los datos observados. La rotación aparece en cero porque las capturas no muestran despachos registrados.

## 4:00–6:00 | Transacción y concurrencia

`reservar_fefo` bloquea la línea de pedido y las filas de existencia elegibles, ordenadas por vencimiento. Luego recalcula el saldo y registra asignaciones lote por lote. La función falla antes de reservar si el total elegible no alcanza; ante cualquier error, la transacción revierte todos sus cambios.

El caso reproducible genera dos solicitudes de 6 unidades contra 10 disponibles. El resultado esperado es que una sesión reserve 6 y la otra espere; tras el commit de la primera, la segunda recibe stock insuficiente y hace rollback. El guion SQL permite correrlo en dos sesiones. Antes de presentar el resultado como observado, mostrar las capturas reales de ambas sesiones y la consulta final del saldo.

## 6:00–7:30 | Vistas, índices y rendimiento

Las vistas resumen inventario por ubicación y sugerencias de reposición. El script compara tres consultas con `EXPLAIN (ANALYZE, BUFFERS)` antes y después de cuatro índices. Se deben mostrar los planes medidos, incluidos filas estimadas y reales, buffers y tiempo. Con pocas filas el optimizador puede elegir un escaneo secuencial; es necesario explicar que el seed de demostración no permite extrapolar el resultado a producción.

## 7:30–9:00 | Integridad, resultados y límites

Las pruebas de Sprint 2 rechazaron FK inválida, cantidad negativa, nombre duplicado, estado no permitido y fecha de recepción inconsistente. Las capturas y errores se guardan en la matriz y la carpeta de evidencia.

El modelo mantiene saldo físico y reservado para lectura rápida, junto con movimientos para trazabilidad; debe verificarse su sincronización en las operaciones de escritura. El conjunto de datos es pequeño y las dos sesiones/planes de Sprint 3 necesitan evidencia ejecutada antes de declarar esas mediciones concluidas.

## 9:00–9:30 | Cierre

El proyecto integra reglas relacionales, consulta FEFO y una estrategia explícita contra sobre-reserva. Próximo paso de validación: ejecutar las dos sesiones, capturar los planes reales y anexarlos al repositorio para cerrar la evidencia experimental.
