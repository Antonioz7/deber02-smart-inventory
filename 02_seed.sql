-- Smart Inventory — datos de prueba del Sprint 2
-- Ejecutar una sola vez, después de 01_schema.sql, en una base vacía.

BEGIN;

INSERT INTO proveedor (nombre) VALUES
    ('Distribuidora Norte'),
    ('Comercial Andina');

INSERT INTO producto (sku, nombre, stock_minimo, stock_objetivo) VALUES
    ('SKU-ARROZ', 'Arroz 1 kg', 10, 60),
    ('SKU-ACEITE', 'Aceite 1 litro', 8, 30),
    ('SKU-CAFE', 'Cafe molido 500 g', 12, 50);

INSERT INTO producto_proveedor (sku, proveedor_id, preferido)
SELECT x.sku, p.proveedor_id, TRUE
FROM (VALUES
    ('SKU-ARROZ', 'Distribuidora Norte'),
    ('SKU-ACEITE', 'Distribuidora Norte'),
    ('SKU-CAFE', 'Comercial Andina')
) AS x(sku, nombre_proveedor)
JOIN proveedor p ON p.nombre = x.nombre_proveedor;

INSERT INTO bodega (nombre) VALUES
    ('Bodega Quito'),
    ('Bodega Cuenca');

INSERT INTO ubicacion (bodega_id, codigo)
SELECT b.bodega_id, x.codigo
FROM (VALUES
    ('Bodega Quito', 'A-01'),
    ('Bodega Quito', 'A-02'),
    ('Bodega Cuenca', 'B-01'),
    ('Bodega Cuenca', 'B-02')
) AS x(nombre_bodega, codigo)
JOIN bodega b ON b.nombre = x.nombre_bodega;

INSERT INTO lote (sku, codigo_lote, fecha_vencimiento)
VALUES
    ('SKU-ARROZ', 'AR-100', CURRENT_DATE + 90),
    ('SKU-ARROZ', 'AR-101', CURRENT_DATE + 180),
    ('SKU-ARROZ', 'AR-090', CURRENT_DATE - 30),
    ('SKU-ARROZ', 'AR-099', CURRENT_DATE + 120),
    ('SKU-ACEITE', 'AC-200', CURRENT_DATE + 150),
    ('SKU-CAFE', 'CA-300', CURRENT_DATE + 365);

-- Arroz: dos lotes vigentes suman 37 unidades; ninguno alcanza solo
-- el pedido de 30. También se incluye un lote vencido y uno agotado.
-- El saldo de cafe incluye 20 unidades de la recepción parcial de abajo.
INSERT INTO existencia_lote
    (lote_id, ubicacion_id, cantidad_fisica, cantidad_reservada)
SELECT l.lote_id, u.ubicacion_id, x.cantidad, 0
FROM (VALUES
    ('SKU-ARROZ', 'AR-100', 'Bodega Quito', 'A-01', 12),
    ('SKU-ARROZ', 'AR-101', 'Bodega Cuenca', 'B-01', 25),
    ('SKU-ARROZ', 'AR-090', 'Bodega Quito', 'A-02', 5),
    ('SKU-ARROZ', 'AR-099', 'Bodega Cuenca', 'B-02', 0),
    ('SKU-ACEITE', 'AC-200', 'Bodega Quito', 'A-02', 4),
    ('SKU-CAFE', 'CA-300', 'Bodega Cuenca', 'B-02', 40)
) AS x(sku, codigo_lote, nombre_bodega, codigo_ubicacion, cantidad)
JOIN lote l ON l.sku = x.sku AND l.codigo_lote = x.codigo_lote
JOIN bodega b ON b.nombre = x.nombre_bodega
JOIN ubicacion u ON u.bodega_id = b.bodega_id AND u.codigo = x.codigo_ubicacion;

-- Movimientos de ajuste para representar el saldo inicial. En cafe
-- se registran 20 de saldo inicial; las otras 20 vienen de la recepción.
INSERT INTO movimiento
    (lote_id, tipo, cantidad, ubicacion_origen_id, ubicacion_destino_id)
SELECT l.lote_id, 'ajuste',
       CASE WHEN l.sku = 'SKU-CAFE' THEN e.cantidad_fisica - 20
            ELSE e.cantidad_fisica END,
       NULL, e.ubicacion_id
FROM existencia_lote e
JOIN lote l ON l.lote_id = e.lote_id
WHERE e.cantidad_fisica > 0;

-- Orden de compra de cafe por 50 unidades; se reciben 20 (recepcion parcial).
WITH nueva_orden AS (
    INSERT INTO orden_compra (proveedor_id, estado)
    SELECT proveedor_id, 'parcial'
    FROM proveedor
    WHERE nombre = 'Comercial Andina'
    RETURNING orden_compra_id
), nueva_linea AS (
    INSERT INTO linea_orden_compra (orden_compra_id, sku, cantidad_ordenada)
    SELECT o.orden_compra_id, p.sku, 50
    FROM nueva_orden o
    CROSS JOIN producto p
    WHERE p.sku = 'SKU-CAFE'
    RETURNING linea_orden_id, orden_compra_id
), nueva_recepcion AS (
    INSERT INTO recepcion (orden_compra_id)
    SELECT orden_compra_id FROM nueva_orden
    RETURNING recepcion_id, orden_compra_id
), nuevo_movimiento AS (
    INSERT INTO movimiento
        (lote_id, tipo, cantidad, ubicacion_origen_id, ubicacion_destino_id)
    SELECT l.lote_id, 'recepcion', 20, NULL, u.ubicacion_id
    FROM lote l
    JOIN existencia_lote e ON e.lote_id = l.lote_id
    JOIN ubicacion u ON u.ubicacion_id = e.ubicacion_id
    JOIN bodega b ON b.bodega_id = u.bodega_id
    WHERE l.sku = 'SKU-CAFE'
      AND l.codigo_lote = 'CA-300'
      AND b.nombre = 'Bodega Cuenca'
      AND u.codigo = 'B-02'
    RETURNING movimiento_id, lote_id, ubicacion_destino_id
)
INSERT INTO detalle_recepcion
    (recepcion_id, linea_orden_id, lote_id, ubicacion_id,
     movimiento_id, cantidad_recibida)
SELECT r.recepcion_id, ln.linea_orden_id, m.lote_id,
       m.ubicacion_destino_id, m.movimiento_id, 20
FROM nueva_recepcion r
JOIN nueva_linea ln ON ln.orden_compra_id = r.orden_compra_id
CROSS JOIN nuevo_movimiento m;

-- Pedido de arroz por 30 unidades: debe repartirse entre AR-100 y AR-101.
WITH nuevo_pedido AS (
    INSERT INTO pedido_cliente (estado)
    VALUES ('pendiente')
    RETURNING pedido_id
)
INSERT INTO linea_pedido (pedido_id, sku, cantidad_solicitada)
SELECT p.pedido_id, producto.sku, 30
FROM nuevo_pedido p
CROSS JOIN producto
WHERE producto.sku = 'SKU-ARROZ';

COMMIT;
