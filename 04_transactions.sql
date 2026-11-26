-- Smart Inventory — Sprint 3: reserva FEFO y concurrencia
-- Ejecutar conectado a deber02DB. El bloque de preparación solo crea datos
-- sintéticos identificados con SKU-PRUEBA-CONCURRENCIA.

-- 1. Operación atómica de reserva.
-- Bloquea la línea y luego las existencias elegibles en orden FEFO. Si no hay
-- unidades suficientes, lanza una excepción; PostgreSQL revierte toda la llamada.
CREATE OR REPLACE FUNCTION reservar_fefo(p_linea_pedido_id INTEGER)
RETURNS TABLE (
    reserva_id BIGINT,
    lote_id BIGINT,
    codigo_lote VARCHAR,
    fecha_vencimiento DATE,
    ubicacion_id INTEGER,
    cantidad_reservada INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sku VARCHAR(30);
    v_pedida INTEGER;
    v_ya_reservada INTEGER;
    v_pendiente INTEGER;
    v_disponible_total BIGINT;
    v_tomada INTEGER;
    candidato RECORD;
BEGIN
    SELECT lp.sku, lp.cantidad_solicitada
      INTO v_sku, v_pedida
      FROM linea_pedido lp
     WHERE lp.linea_pedido_id = p_linea_pedido_id
     FOR UPDATE OF lp;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe la línea de pedido %', p_linea_pedido_id
            USING ERRCODE = '23503';
    END IF;

    SELECT COALESCE(SUM(r.cantidad) FILTER (WHERE r.estado = 'activa'), 0)::INTEGER
      INTO v_ya_reservada
      FROM reserva r
     WHERE r.linea_pedido_id = p_linea_pedido_id;

    v_pendiente := v_pedida - v_ya_reservada;
    IF v_pendiente <= 0 THEN
        RAISE EXCEPTION 'La línea % ya está reservada por completo', p_linea_pedido_id
            USING ERRCODE = '23514';
    END IF;

    -- FOR UPDATE serializa las reservas que compiten por las mismas filas.
    FOR candidato IN
        SELECT e.lote_id, e.ubicacion_id
          FROM existencia_lote e
          JOIN lote l ON l.lote_id = e.lote_id
         WHERE l.sku = v_sku
           AND (l.fecha_vencimiento IS NULL OR l.fecha_vencimiento >= CURRENT_DATE)
         ORDER BY l.fecha_vencimiento ASC NULLS LAST, l.lote_id, e.ubicacion_id
         FOR UPDATE OF e
    LOOP
        NULL;
    END LOOP;

    SELECT COALESCE(SUM(e.cantidad_fisica - e.cantidad_reservada), 0)
      INTO v_disponible_total
      FROM existencia_lote e
      JOIN lote l ON l.lote_id = e.lote_id
     WHERE l.sku = v_sku
       AND (l.fecha_vencimiento IS NULL OR l.fecha_vencimiento >= CURRENT_DATE);

    IF v_disponible_total < v_pendiente THEN
        RAISE EXCEPTION 'Stock insuficiente para la línea %: faltan %, disponibles %',
            p_linea_pedido_id, v_pendiente, v_disponible_total
            USING ERRCODE = '23514';
    END IF;

    FOR candidato IN
        SELECT e.lote_id,
               e.ubicacion_id,
               e.cantidad_fisica - e.cantidad_reservada AS disponible,
               l.codigo_lote,
               l.fecha_vencimiento
          FROM existencia_lote e
          JOIN lote l ON l.lote_id = e.lote_id
         WHERE l.sku = v_sku
           AND (l.fecha_vencimiento IS NULL OR l.fecha_vencimiento >= CURRENT_DATE)
           AND e.cantidad_fisica > e.cantidad_reservada
         ORDER BY l.fecha_vencimiento ASC NULLS LAST, l.lote_id, e.ubicacion_id
    LOOP
        EXIT WHEN v_pendiente = 0;
        v_tomada := LEAST(candidato.disponible, v_pendiente);

        UPDATE existencia_lote e
           SET cantidad_reservada = e.cantidad_reservada + v_tomada
         WHERE e.lote_id = candidato.lote_id
           AND e.ubicacion_id = candidato.ubicacion_id;

        INSERT INTO reserva (linea_pedido_id, lote_id, ubicacion_id, cantidad)
        VALUES (p_linea_pedido_id, candidato.lote_id,
                candidato.ubicacion_id, v_tomada)
        RETURNING reserva.reserva_id INTO reserva_id;

        lote_id := candidato.lote_id;
        codigo_lote := candidato.codigo_lote;
        fecha_vencimiento := candidato.fecha_vencimiento;
        ubicacion_id := candidato.ubicacion_id;
        cantidad_reservada := v_tomada;
        RETURN NEXT;

        v_pendiente := v_pendiente - v_tomada;
    END LOOP;
END;
$$;

-- 2. Preparación repetible de datos sintéticos para dos sesiones.
BEGIN;
DO $$
DECLARE
    v_pedidos INTEGER[];
    v_bodega INTEGER;
    v_ubicacion INTEGER;
    v_lote_1 BIGINT;
    v_lote_2 BIGINT;
    v_lote_vencido BIGINT;
BEGIN
    SELECT array_agg(DISTINCT lp.pedido_id)
      INTO v_pedidos
      FROM linea_pedido lp
     WHERE lp.sku = 'SKU-PRUEBA-CONCURRENCIA';

    DELETE FROM movimiento m
     WHERE m.reserva_id IN (
         SELECT r.reserva_id FROM reserva r
         JOIN linea_pedido lp ON lp.linea_pedido_id = r.linea_pedido_id
         WHERE lp.sku = 'SKU-PRUEBA-CONCURRENCIA'
     );
    DELETE FROM reserva r
     USING linea_pedido lp
     WHERE r.linea_pedido_id = lp.linea_pedido_id
       AND lp.sku = 'SKU-PRUEBA-CONCURRENCIA';
    DELETE FROM linea_pedido WHERE sku = 'SKU-PRUEBA-CONCURRENCIA';
    IF v_pedidos IS NOT NULL THEN
        DELETE FROM pedido_cliente WHERE pedido_id = ANY(v_pedidos);
    END IF;

    INSERT INTO producto (sku, nombre, stock_minimo, stock_objetivo)
    VALUES ('SKU-PRUEBA-CONCURRENCIA', 'Producto de prueba de concurrencia', 1, 20)
    ON CONFLICT (sku) DO UPDATE
       SET nombre = EXCLUDED.nombre,
           stock_minimo = EXCLUDED.stock_minimo,
           stock_objetivo = EXCLUDED.stock_objetivo;

    INSERT INTO bodega (nombre)
    VALUES ('Bodega Prueba Concurrencia')
    ON CONFLICT (nombre) DO NOTHING;
    SELECT bodega_id INTO v_bodega
      FROM bodega WHERE nombre = 'Bodega Prueba Concurrencia';

    INSERT INTO ubicacion (bodega_id, codigo)
    VALUES (v_bodega, 'CONC-01')
    ON CONFLICT (bodega_id, codigo) DO NOTHING;
    SELECT ubicacion_id INTO v_ubicacion
      FROM ubicacion WHERE bodega_id = v_bodega AND codigo = 'CONC-01';

    INSERT INTO lote (sku, codigo_lote, fecha_vencimiento)
    VALUES ('SKU-PRUEBA-CONCURRENCIA', 'CONC-PRIMERO', CURRENT_DATE + 30)
    ON CONFLICT (sku, codigo_lote) DO UPDATE
       SET fecha_vencimiento = EXCLUDED.fecha_vencimiento
    RETURNING lote_id INTO v_lote_1;
    INSERT INTO lote (sku, codigo_lote, fecha_vencimiento)
    VALUES ('SKU-PRUEBA-CONCURRENCIA', 'CONC-SEGUNDO', CURRENT_DATE + 60)
    ON CONFLICT (sku, codigo_lote) DO UPDATE
       SET fecha_vencimiento = EXCLUDED.fecha_vencimiento
    RETURNING lote_id INTO v_lote_2;
    INSERT INTO lote (sku, codigo_lote, fecha_vencimiento)
    VALUES ('SKU-PRUEBA-CONCURRENCIA', 'CONC-VENCIDO', CURRENT_DATE - 1)
    ON CONFLICT (sku, codigo_lote) DO UPDATE
       SET fecha_vencimiento = EXCLUDED.fecha_vencimiento
    RETURNING lote_id INTO v_lote_vencido;

    INSERT INTO existencia_lote (lote_id, ubicacion_id, cantidad_fisica, cantidad_reservada)
    VALUES (v_lote_1, v_ubicacion, 4, 0),
           (v_lote_2, v_ubicacion, 6, 0),
           (v_lote_vencido, v_ubicacion, 99, 0)
    ON CONFLICT (lote_id, ubicacion_id) DO UPDATE
       SET cantidad_fisica = EXCLUDED.cantidad_fisica,
           cantidad_reservada = 0;

    INSERT INTO pedido_cliente (estado) VALUES ('pendiente');
    INSERT INTO linea_pedido (pedido_id, sku, cantidad_solicitada)
    VALUES (currval(pg_get_serial_sequence('pedido_cliente', 'pedido_id')), 
            'SKU-PRUEBA-CONCURRENCIA', 6);
    INSERT INTO pedido_cliente (estado) VALUES ('pendiente');
    INSERT INTO linea_pedido (pedido_id, sku, cantidad_solicitada)
    VALUES (currval(pg_get_serial_sequence('pedido_cliente', 'pedido_id')), 
            'SKU-PRUEBA-CONCURRENCIA', 6);
END;
$$;
COMMIT;

-- 3. Revisar fixtures y copiar los dos linea_pedido_id para las sesiones:
SELECT lp.linea_pedido_id,
       lp.pedido_id,
       lp.sku,
       lp.cantidad_solicitada,
       l.codigo_lote,
       l.fecha_vencimiento,
       e.cantidad_fisica,
       e.cantidad_reservada
FROM linea_pedido lp
JOIN lote l ON l.sku = lp.sku
JOIN existencia_lote e ON e.lote_id = l.lote_id
WHERE lp.sku = 'SKU-PRUEBA-CONCURRENCIA'
ORDER BY lp.linea_pedido_id DESC, l.fecha_vencimiento;

-- 4. Prueba FEFO de una línea (ejecutar una sola vez con una de las líneas):
-- BEGIN;
-- SELECT * FROM reservar_fefo(<linea_pedido_id_1>);
-- COMMIT;
-- Esperado: CONC-PRIMERO recibe 4 y CONC-SEGUNDO recibe 2; CONC-VENCIDO no se usa.
-- Si una sentencia falla: ejecutar ROLLBACK en esa sesión.

-- 5. Concurrencia reproducible: abrir dos editores SQL independientes en DBeaver.
-- Sesión A: BEGIN; SELECT * FROM reservar_fefo(<linea_pedido_id_1>);
-- Dejar la transacción abierta tras ver los lotes; no hacer COMMIT aún.
-- Sesión B: BEGIN; SELECT * FROM reservar_fefo(<linea_pedido_id_2>);
-- La sesión B espera el bloqueo de las existencias. Luego hacer COMMIT en A.
-- B debe finalizar con SQLSTATE 23514 por stock insuficiente (solo quedan 4).
-- En B ejecutar ROLLBACK. Confirmar que total reservado = 6 y disponible = 4.
-- Ambas solicitudes suman 12; el inventario elegible suma 10.

-- 6. Verificación tras la prueba:
SELECT l.codigo_lote,
       l.fecha_vencimiento,
       e.cantidad_fisica,
       e.cantidad_reservada,
       e.cantidad_fisica - e.cantidad_reservada AS disponible,
       COALESCE(SUM(r.cantidad) FILTER (WHERE r.estado = 'activa'), 0) AS reservas_activas
FROM lote l
JOIN existencia_lote e ON e.lote_id = l.lote_id
LEFT JOIN reserva r ON r.lote_id = l.lote_id AND r.ubicacion_id = e.ubicacion_id
WHERE l.sku = 'SKU-PRUEBA-CONCURRENCIA'
GROUP BY l.lote_id, l.codigo_lote, l.fecha_vencimiento,
         e.cantidad_fisica, e.cantidad_reservada
ORDER BY l.fecha_vencimiento;

-- Análisis: READ COMMITTED por sí solo no serializa una lectura seguida de una
-- escritura. La función bloquea filas con SELECT ... FOR UPDATE, recalcula el
-- disponible tras el bloqueo y conserva las asignaciones FEFO. El CHECK existente
-- también limita cantidad_reservada <= cantidad_fisica. Si la espera termina en
-- deadlock/serialización abortada, se revierte la transacción completa y se reintenta.
