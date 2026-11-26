-- Smart Inventory — consultas del Sprint 2
-- Ejecutar cada SELECT conectado a la base deber02DB.

-- 1. Stock disponible por producto, lote y ubicación.
-- Disponible = físico - reservado; se conserva el detalle para rastrear el saldo.
SELECT p.sku,
       p.nombre AS producto,
       b.nombre AS bodega,
       u.codigo AS ubicacion,
       l.codigo_lote,
       l.fecha_vencimiento,
       e.cantidad_fisica,
       e.cantidad_reservada,
       e.cantidad_fisica - e.cantidad_reservada AS cantidad_disponible
FROM existencia_lote e
JOIN lote l ON l.lote_id = e.lote_id
JOIN producto p ON p.sku = l.sku
JOIN ubicacion u ON u.ubicacion_id = e.ubicacion_id
JOIN bodega b ON b.bodega_id = u.bodega_id
ORDER BY p.sku, b.nombre, u.codigo, l.fecha_vencimiento NULLS LAST, l.codigo_lote;

-- 2. Lotes vigentes que vencen dentro de los próximos 30 días.
-- Agrupa por producto y lote, sumando disponibilidad en sus ubicaciones.
SELECT p.sku,
       p.nombre AS producto,
       l.lote_id,
       l.codigo_lote,
       l.fecha_vencimiento,
       SUM(e.cantidad_fisica - e.cantidad_reservada) AS cantidad_disponible
FROM lote l
JOIN producto p ON p.sku = l.sku
JOIN existencia_lote e ON e.lote_id = l.lote_id
JOIN ubicacion u ON u.ubicacion_id = e.ubicacion_id
WHERE l.fecha_vencimiento BETWEEN CURRENT_DATE AND CURRENT_DATE + 30
  AND e.cantidad_fisica > e.cantidad_reservada
GROUP BY p.sku, p.nombre, l.lote_id, l.codigo_lote, l.fecha_vencimiento
ORDER BY l.fecha_vencimiento, p.sku, l.codigo_lote;

-- 3. Picking FEFO para la primera línea pendiente de arroz.
-- La suma acumulada permite repartir la cantidad solicitada entre lotes elegibles.
WITH linea_objetivo AS (
    SELECT lp.linea_pedido_id,
           lp.sku,
           lp.cantidad_solicitada
    FROM linea_pedido lp
    JOIN pedido_cliente pc ON pc.pedido_id = lp.pedido_id
    WHERE pc.estado IN ('pendiente', 'parcial')
      AND lp.sku = 'SKU-ARROZ'
    ORDER BY pc.fecha, lp.linea_pedido_id
    LIMIT 1
), candidatos AS (
    SELECT lo.linea_pedido_id,
           lo.cantidad_solicitada,
           l.lote_id,
           l.codigo_lote,
           l.fecha_vencimiento,
           b.nombre AS bodega,
           u.codigo AS ubicacion,
           e.cantidad_fisica - e.cantidad_reservada AS disponible,
           SUM(e.cantidad_fisica - e.cantidad_reservada) OVER (
               PARTITION BY lo.linea_pedido_id
               ORDER BY l.fecha_vencimiento ASC NULLS LAST, l.lote_id, u.ubicacion_id
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS disponible_acumulado
    FROM linea_objetivo lo
    JOIN lote l ON l.sku = lo.sku
    JOIN existencia_lote e ON e.lote_id = l.lote_id
    JOIN ubicacion u ON u.ubicacion_id = e.ubicacion_id
    JOIN bodega b ON b.bodega_id = u.bodega_id
    WHERE (l.fecha_vencimiento IS NULL OR l.fecha_vencimiento >= CURRENT_DATE)
      AND e.cantidad_fisica > e.cantidad_reservada
)
SELECT linea_pedido_id,
       lote_id,
       codigo_lote,
       fecha_vencimiento,
       bodega,
       ubicacion,
       LEAST(disponible,
             GREATEST(cantidad_solicitada - (disponible_acumulado - disponible), 0)
       ) AS cantidad_a_pikear
FROM candidatos
WHERE LEAST(disponible,
            GREATEST(cantidad_solicitada - (disponible_acumulado - disponible), 0)
      ) > 0
ORDER BY fecha_vencimiento ASC NULLS LAST, lote_id, ubicacion;

-- 4. Reposición: productos bajo el mínimo, excluyendo stock vencido.
-- La cantidad sugerida lleva la disponibilidad hasta el objetivo configurado.
SELECT p.sku,
       p.nombre AS producto,
       p.stock_minimo,
       p.stock_objetivo,
       COALESCE(SUM(
           CASE WHEN l.fecha_vencimiento IS NULL OR l.fecha_vencimiento >= CURRENT_DATE
                THEN e.cantidad_fisica - e.cantidad_reservada
                ELSE 0
           END
       ), 0) AS disponible_vigente,
       GREATEST(
           p.stock_objetivo - COALESCE(SUM(
               CASE WHEN l.fecha_vencimiento IS NULL OR l.fecha_vencimiento >= CURRENT_DATE
                    THEN e.cantidad_fisica - e.cantidad_reservada
                    ELSE 0
               END
           ), 0),
           0
       ) AS cantidad_sugerida
FROM producto p
LEFT JOIN lote l ON l.sku = p.sku
LEFT JOIN existencia_lote e ON e.lote_id = l.lote_id
GROUP BY p.sku, p.nombre, p.stock_minimo, p.stock_objetivo
HAVING COALESCE(SUM(
           CASE WHEN l.fecha_vencimiento IS NULL OR l.fecha_vencimiento >= CURRENT_DATE
                THEN e.cantidad_fisica - e.cantidad_reservada
                ELSE 0
           END
       ), 0) < p.stock_minimo
ORDER BY p.sku;

-- 5. Trazabilidad de pedidos: reservas por lote/ubicación y despachos vinculados.
-- Las subconsultas agregadas evitan duplicar cantidades entre reservas y movimientos.
SELECT pc.pedido_id,
       pc.fecha AS fecha_pedido,
       pc.estado AS estado_pedido,
       lp.linea_pedido_id,
       p.sku,
       p.nombre AS producto,
       lp.cantidad_solicitada,
       COALESCE(r.cantidad_reservada_activa, 0) AS cantidad_reservada_activa,
       COALESCE(d.cantidad_despachada, 0) AS cantidad_despachada,
       r.lotes_y_ubicaciones
FROM pedido_cliente pc
JOIN linea_pedido lp ON lp.pedido_id = pc.pedido_id
JOIN producto p ON p.sku = lp.sku
LEFT JOIN LATERAL (
    SELECT SUM(rv.cantidad) FILTER (WHERE rv.estado = 'activa') AS cantidad_reservada_activa,
           STRING_AGG(
               l.codigo_lote || ' @ ' || b.nombre || '/' || u.codigo ||
               ' (' || rv.cantidad || ', ' || rv.estado || ')',
               '; ' ORDER BY l.fecha_vencimiento NULLS LAST, l.codigo_lote
           ) AS lotes_y_ubicaciones
    FROM reserva rv
    JOIN lote l ON l.lote_id = rv.lote_id
    JOIN ubicacion u ON u.ubicacion_id = rv.ubicacion_id
    JOIN bodega b ON b.bodega_id = u.bodega_id
    WHERE rv.linea_pedido_id = lp.linea_pedido_id
) r ON TRUE
LEFT JOIN LATERAL (
    SELECT SUM(m.cantidad) AS cantidad_despachada
    FROM movimiento m
    JOIN reserva rv ON rv.reserva_id = m.reserva_id
    WHERE rv.linea_pedido_id = lp.linea_pedido_id
      AND m.tipo = 'despacho'
) d ON TRUE
ORDER BY pc.fecha, pc.pedido_id, lp.linea_pedido_id;

-- 6. Recepciones parciales por línea de compra.
-- Compara lo ordenado con lo recibido y calcula el saldo pendiente.
SELECT oc.orden_compra_id,
       pr.nombre AS proveedor,
       oc.estado AS estado_orden,
       loc.linea_orden_id,
       p.sku,
       p.nombre AS producto,
       loc.cantidad_ordenada,
       COALESCE(SUM(dr.cantidad_recibida), 0) AS cantidad_recibida,
       loc.cantidad_ordenada - COALESCE(SUM(dr.cantidad_recibida), 0) AS pendiente_recibir,
       COUNT(DISTINCT rec.recepcion_id) AS numero_recepciones
FROM orden_compra oc
JOIN proveedor pr ON pr.proveedor_id = oc.proveedor_id
JOIN linea_orden_compra loc ON loc.orden_compra_id = oc.orden_compra_id
JOIN producto p ON p.sku = loc.sku
LEFT JOIN recepcion rec ON rec.orden_compra_id = oc.orden_compra_id
LEFT JOIN detalle_recepcion dr
       ON dr.recepcion_id = rec.recepcion_id
      AND dr.linea_orden_id = loc.linea_orden_id
GROUP BY oc.orden_compra_id, pr.nombre, oc.estado,
         loc.linea_orden_id, p.sku, p.nombre, loc.cantidad_ordenada
HAVING COALESCE(SUM(dr.cantidad_recibida), 0) < loc.cantidad_ordenada
ORDER BY oc.orden_compra_id, loc.linea_orden_id;

-- 7. Rotación operativa aproximada de 30 días.
-- Mide unidades despachadas en el período / disponibilidad vigente actual.
-- El modelo no guarda saldos históricos promedio, por eso se usa el saldo actual.
WITH salidas AS (
    SELECT l.sku,
           SUM(m.cantidad) AS unidades_despachadas_30d
    FROM movimiento m
    JOIN lote l ON l.lote_id = m.lote_id
    WHERE m.tipo = 'despacho'
      AND m.fecha >= CURRENT_TIMESTAMP - INTERVAL '30 days'
    GROUP BY l.sku
), saldo AS (
    SELECT l.sku,
           SUM(CASE WHEN l.fecha_vencimiento IS NULL OR l.fecha_vencimiento >= CURRENT_DATE
                    THEN e.cantidad_fisica - e.cantidad_reservada
                    ELSE 0
               END) AS disponible_vigente
    FROM lote l
    JOIN existencia_lote e ON e.lote_id = l.lote_id
    GROUP BY l.sku
)
SELECT p.sku,
       p.nombre AS producto,
       COALESCE(s.unidades_despachadas_30d, 0) AS unidades_despachadas_30d,
       COALESCE(sa.disponible_vigente, 0) AS disponible_vigente,
       ROUND(
           COALESCE(s.unidades_despachadas_30d, 0)::NUMERIC /
           NULLIF(COALESCE(sa.disponible_vigente, 0), 0),
           2
       ) AS rotacion_aproximada
FROM producto p
LEFT JOIN salidas s ON s.sku = p.sku
LEFT JOIN saldo sa ON sa.sku = p.sku
ORDER BY p.sku;

-- 8. Nivel de servicio por unidades y líneas con quiebre en pedidos recientes.
-- El quiebre actual se marca cuando no queda disponibilidad vigente del SKU.
WITH demanda AS (
    SELECT pc.pedido_id,
           lp.linea_pedido_id,
           lp.sku,
           lp.cantidad_solicitada
    FROM pedido_cliente pc
    JOIN linea_pedido lp ON lp.pedido_id = pc.pedido_id
    WHERE pc.fecha >= CURRENT_TIMESTAMP - INTERVAL '30 days'
      AND pc.estado <> 'cancelado'
), despachos AS (
    SELECT rv.linea_pedido_id,
           SUM(m.cantidad) AS unidades_despachadas
    FROM movimiento m
    JOIN reserva rv ON rv.reserva_id = m.reserva_id
    WHERE m.tipo = 'despacho'
    GROUP BY rv.linea_pedido_id
), saldo AS (
    SELECT l.sku,
           SUM(CASE WHEN l.fecha_vencimiento IS NULL OR l.fecha_vencimiento >= CURRENT_DATE
                    THEN e.cantidad_fisica - e.cantidad_reservada
                    ELSE 0
               END) AS disponible_vigente
    FROM lote l
    JOIN existencia_lote e ON e.lote_id = l.lote_id
    GROUP BY l.sku
)
SELECT p.sku,
       p.nombre AS producto,
       SUM(d.cantidad_solicitada) AS unidades_solicitadas,
       SUM(LEAST(d.cantidad_solicitada, COALESCE(m.unidades_despachadas, 0)))
           AS unidades_atendidas,
       ROUND(
           100.0 * SUM(LEAST(d.cantidad_solicitada, COALESCE(m.unidades_despachadas, 0))) /
           NULLIF(SUM(d.cantidad_solicitada), 0),
           2
       ) AS nivel_servicio_pct,
       COUNT(*) FILTER (
           WHERE COALESCE(m.unidades_despachadas, 0) < d.cantidad_solicitada
       ) AS lineas_no_atendidas_completamente,
       COALESCE(MAX(sa.disponible_vigente), 0) = 0 AS quiebre_actual
FROM demanda d
JOIN producto p ON p.sku = d.sku
LEFT JOIN despachos m ON m.linea_pedido_id = d.linea_pedido_id
LEFT JOIN saldo sa ON sa.sku = d.sku
GROUP BY p.sku, p.nombre
ORDER BY p.sku;
