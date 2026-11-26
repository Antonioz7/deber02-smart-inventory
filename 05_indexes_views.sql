-- Smart Inventory — Sprint 3: vistas e índices
-- PostgreSQL. Las vistas son de lectura para el dashboard; las escrituras
-- autorizadas siguen ocurriendo en las tablas transaccionales.

-- Vista 1: saldo rastreable por SKU, bodega, ubicación y lote.
CREATE OR REPLACE VIEW vw_stock_disponible AS
SELECT p.sku,
       p.nombre AS producto,
       b.bodega_id,
       b.nombre AS bodega,
       u.ubicacion_id,
       u.codigo AS ubicacion,
       l.lote_id,
       l.codigo_lote,
       l.fecha_vencimiento,
       e.cantidad_fisica,
       e.cantidad_reservada,
       e.cantidad_fisica - e.cantidad_reservada AS cantidad_disponible,
       CASE
           WHEN l.fecha_vencimiento < CURRENT_DATE THEN 'vencido'
           WHEN l.fecha_vencimiento IS NULL THEN 'sin vencimiento'
           ELSE 'vigente'
       END AS estado_lote
FROM existencia_lote e
JOIN lote l ON l.lote_id = e.lote_id
JOIN producto p ON p.sku = l.sku
JOIN ubicacion u ON u.ubicacion_id = e.ubicacion_id
JOIN bodega b ON b.bodega_id = u.bodega_id;

-- Vista 2: posición de inventario y compra sugerida, agrupadas por SKU.
-- Posición = disponible vigente + cantidad pendiente de órdenes abiertas/parciales.
CREATE OR REPLACE VIEW vw_reposicion_sugerida AS
WITH stock AS (
    SELECT l.sku,
           SUM(e.cantidad_fisica - e.cantidad_reservada)
               FILTER (WHERE l.fecha_vencimiento IS NULL
                            OR l.fecha_vencimiento >= CURRENT_DATE) AS disponible_vigente
    FROM lote l
    JOIN existencia_lote e ON e.lote_id = l.lote_id
    GROUP BY l.sku
), compras AS (
    SELECT loc.sku,
           SUM(GREATEST(
               loc.cantidad_ordenada - COALESCE(recibido.cantidad_recibida, 0), 0
           )) AS pendiente_en_ordenes
    FROM linea_orden_compra loc
    JOIN orden_compra oc ON oc.orden_compra_id = loc.orden_compra_id
    LEFT JOIN LATERAL (
        SELECT SUM(dr.cantidad_recibida) AS cantidad_recibida
        FROM detalle_recepcion dr
        WHERE dr.linea_orden_id = loc.linea_orden_id
    ) recibido ON TRUE
    WHERE oc.estado IN ('abierta', 'parcial')
    GROUP BY loc.sku
)
SELECT p.sku,
       p.nombre AS producto,
       p.stock_minimo,
       p.stock_objetivo,
       COALESCE(s.disponible_vigente, 0) AS disponible_vigente,
       COALESCE(c.pendiente_en_ordenes, 0) AS pendiente_en_ordenes,
       COALESCE(s.disponible_vigente, 0) + COALESCE(c.pendiente_en_ordenes, 0)
           AS posicion_inventario,
       GREATEST(
           p.stock_objetivo
           - COALESCE(s.disponible_vigente, 0)
           - COALESCE(c.pendiente_en_ordenes, 0),
           0
       ) AS cantidad_sugerida,
       pr.nombre AS proveedor_preferido
FROM producto p
LEFT JOIN stock s ON s.sku = p.sku
LEFT JOIN compras c ON c.sku = p.sku
LEFT JOIN producto_proveedor pp ON pp.sku = p.sku AND pp.preferido
LEFT JOIN proveedor pr ON pr.proveedor_id = pp.proveedor_id;

-- Consultas de comprobación de las vistas.
SELECT * FROM vw_stock_disponible
ORDER BY sku, bodega, ubicacion, fecha_vencimiento NULLS LAST, codigo_lote;
SELECT * FROM vw_reposicion_sugerida
ORDER BY sku;

-- Comparación de planes: ejecutar este bloque ANTES de los índices propuestos.
-- Guardar EXPLAIN (ANALYZE, BUFFERS) para cada consulta.
EXPLAIN (ANALYZE, BUFFERS)
SELECT sku, bodega, ubicacion, codigo_lote, cantidad_disponible
FROM vw_stock_disponible
WHERE sku = 'SKU-ARROZ'
  AND (fecha_vencimiento IS NULL OR fecha_vencimiento >= CURRENT_DATE)
ORDER BY fecha_vencimiento NULLS LAST, codigo_lote;

EXPLAIN (ANALYZE, BUFFERS)
SELECT l.sku, l.codigo_lote, l.fecha_vencimiento,
       SUM(e.cantidad_fisica - e.cantidad_reservada) AS disponible
FROM lote l
JOIN existencia_lote e ON e.lote_id = l.lote_id
WHERE l.fecha_vencimiento BETWEEN CURRENT_DATE AND CURRENT_DATE + 30
  AND e.cantidad_fisica > e.cantidad_reservada
GROUP BY l.sku, l.codigo_lote, l.fecha_vencimiento
ORDER BY l.fecha_vencimiento;

EXPLAIN (ANALYZE, BUFFERS)
SELECT rv.linea_pedido_id, rv.lote_id, rv.ubicacion_id,
       SUM(rv.cantidad) AS reservado,
       SUM(m.cantidad) FILTER (WHERE m.tipo = 'despacho') AS despachado
FROM reserva rv
LEFT JOIN movimiento m ON m.reserva_id = rv.reserva_id
WHERE rv.linea_pedido_id = (
    SELECT linea_pedido_id FROM linea_pedido
    WHERE sku = 'SKU-ARROZ'
    ORDER BY linea_pedido_id LIMIT 1
)
GROUP BY rv.linea_pedido_id, rv.lote_id, rv.ubicacion_id;

-- Índices: apoyan búsqueda de lotes elegibles, FK de ubicación y trazabilidad.
-- Los índices duplicados de PK/UNIQUE no se vuelven a crear.
CREATE INDEX IF NOT EXISTS idx_lote_sku_vencimiento
    ON lote (sku, fecha_vencimiento, lote_id);
CREATE INDEX IF NOT EXISTS idx_existencia_ubicacion_lote
    ON existencia_lote (ubicacion_id, lote_id);
CREATE INDEX IF NOT EXISTS idx_reserva_linea_estado
    ON reserva (linea_pedido_id, estado);
CREATE INDEX IF NOT EXISTS idx_movimiento_reserva_tipo_fecha
    ON movimiento (reserva_id, tipo, fecha);

ANALYZE lote;
ANALYZE existencia_lote;
ANALYZE reserva;
ANALYZE movimiento;

-- Comparación DESPUÉS: repetir las mismas tres consultas y guardar los planes.
EXPLAIN (ANALYZE, BUFFERS)
SELECT sku, bodega, ubicacion, codigo_lote, cantidad_disponible
FROM vw_stock_disponible
WHERE sku = 'SKU-ARROZ'
  AND (fecha_vencimiento IS NULL OR fecha_vencimiento >= CURRENT_DATE)
ORDER BY fecha_vencimiento NULLS LAST, codigo_lote;

EXPLAIN (ANALYZE, BUFFERS)
SELECT l.sku, l.codigo_lote, l.fecha_vencimiento,
       SUM(e.cantidad_fisica - e.cantidad_reservada) AS disponible
FROM lote l
JOIN existencia_lote e ON e.lote_id = l.lote_id
WHERE l.fecha_vencimiento BETWEEN CURRENT_DATE AND CURRENT_DATE + 30
  AND e.cantidad_fisica > e.cantidad_reservada
GROUP BY l.sku, l.codigo_lote, l.fecha_vencimiento
ORDER BY l.fecha_vencimiento;

EXPLAIN (ANALYZE, BUFFERS)
SELECT rv.linea_pedido_id, rv.lote_id, rv.ubicacion_id,
       SUM(rv.cantidad) AS reservado,
       SUM(m.cantidad) FILTER (WHERE m.tipo = 'despacho') AS despachado
FROM reserva rv
LEFT JOIN movimiento m ON m.reserva_id = rv.reserva_id
WHERE rv.linea_pedido_id = (
    SELECT linea_pedido_id FROM linea_pedido
    WHERE sku = 'SKU-ARROZ'
    ORDER BY linea_pedido_id LIMIT 1
)
GROUP BY rv.linea_pedido_id, rv.lote_id, rv.ubicacion_id;

-- Interpretación: comparar tiempo real, filas estimadas/observadas y buffers.
-- Con el seed pequeño PostgreSQL puede preferir Seq Scan; eso no prueba que el
-- índice sea inútil. Repetir con una carga representativa antes de producción.
-- Cada índice acelera algunas lecturas y añade espacio/costo a INSERT/UPDATE/DELETE.
