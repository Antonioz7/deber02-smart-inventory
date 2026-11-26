-- Smart Inventory — Sprint 2
-- PostgreSQL: estructura base y restricciones declarativas.
-- Ejecutar una sola vez en una base vacía.

BEGIN;

CREATE TABLE proveedor (
    proveedor_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL
);

CREATE TABLE producto (
    sku VARCHAR(30) PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    stock_minimo INTEGER NOT NULL CHECK (stock_minimo >= 0),
    stock_objetivo INTEGER NOT NULL CHECK (stock_objetivo >= stock_minimo)
);

CREATE TABLE producto_proveedor (
    sku VARCHAR(30) NOT NULL,
    proveedor_id INTEGER NOT NULL,
    preferido BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (sku, proveedor_id),
    FOREIGN KEY (sku) REFERENCES producto (sku)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    FOREIGN KEY (proveedor_id) REFERENCES proveedor (proveedor_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT
);

-- Un producto puede tener varios proveedores, pero solo uno preferido.
CREATE UNIQUE INDEX uq_producto_proveedor_preferido
    ON producto_proveedor (sku)
    WHERE preferido;

CREATE TABLE bodega (
    bodega_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE ubicacion (
    ubicacion_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bodega_id INTEGER NOT NULL,
    codigo VARCHAR(30) NOT NULL,
    UNIQUE (bodega_id, codigo),
    FOREIGN KEY (bodega_id) REFERENCES bodega (bodega_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE TABLE lote (
    lote_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku VARCHAR(30) NOT NULL,
    codigo_lote VARCHAR(60) NOT NULL,
    fecha_vencimiento DATE,
    UNIQUE (sku, codigo_lote),
    FOREIGN KEY (sku) REFERENCES producto (sku)
        ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE TABLE existencia_lote (
    lote_id BIGINT NOT NULL,
    ubicacion_id INTEGER NOT NULL,
    cantidad_fisica INTEGER NOT NULL DEFAULT 0 CHECK (cantidad_fisica >= 0),
    cantidad_reservada INTEGER NOT NULL DEFAULT 0
        CHECK (cantidad_reservada >= 0 AND cantidad_reservada <= cantidad_fisica),
    PRIMARY KEY (lote_id, ubicacion_id),
    FOREIGN KEY (lote_id) REFERENCES lote (lote_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    FOREIGN KEY (ubicacion_id) REFERENCES ubicacion (ubicacion_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE TABLE orden_compra (
    orden_compra_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    proveedor_id INTEGER NOT NULL,
    fecha TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(20) NOT NULL DEFAULT 'abierta'
        CHECK (estado IN ('abierta', 'parcial', 'completada', 'cancelada')),
    FOREIGN KEY (proveedor_id) REFERENCES proveedor (proveedor_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE TABLE linea_orden_compra (
    linea_orden_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    orden_compra_id INTEGER NOT NULL,
    sku VARCHAR(30) NOT NULL,
    cantidad_ordenada INTEGER NOT NULL CHECK (cantidad_ordenada > 0),
    UNIQUE (orden_compra_id, sku),
    FOREIGN KEY (orden_compra_id) REFERENCES orden_compra (orden_compra_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    FOREIGN KEY (sku) REFERENCES producto (sku)
        ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE TABLE recepcion (
    recepcion_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    orden_compra_id INTEGER NOT NULL,
    fecha TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (orden_compra_id) REFERENCES orden_compra (orden_compra_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT
);

-- La fecha de una recepción no puede ser anterior a la fecha de su orden.
CREATE OR REPLACE FUNCTION validar_fecha_recepcion_orden()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    fecha_orden TIMESTAMPTZ;
BEGIN
    SELECT fecha
      INTO fecha_orden
      FROM orden_compra
     WHERE orden_compra_id = NEW.orden_compra_id;

    IF NEW.fecha < fecha_orden THEN
        RAISE EXCEPTION 'La fecha de recepción no puede preceder a la orden de compra.'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_fecha_recepcion_orden
BEFORE INSERT OR UPDATE OF orden_compra_id, fecha ON recepcion
FOR EACH ROW
EXECUTE FUNCTION validar_fecha_recepcion_orden();
CREATE TABLE pedido_cliente (
    pedido_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente'
        CHECK (estado IN ('pendiente', 'parcial', 'completado', 'cancelado'))
);

CREATE TABLE linea_pedido (
    linea_pedido_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pedido_id INTEGER NOT NULL,
    sku VARCHAR(30) NOT NULL,
    cantidad_solicitada INTEGER NOT NULL CHECK (cantidad_solicitada > 0),
    UNIQUE (pedido_id, sku),
    FOREIGN KEY (pedido_id) REFERENCES pedido_cliente (pedido_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    FOREIGN KEY (sku) REFERENCES producto (sku)
        ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE TABLE reserva (
    reserva_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    linea_pedido_id INTEGER NOT NULL,
    lote_id BIGINT NOT NULL,
    ubicacion_id INTEGER NOT NULL,
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    estado VARCHAR(20) NOT NULL DEFAULT 'activa'
        CHECK (estado IN ('activa', 'liberada', 'consumida', 'cancelada')),
    fecha_reserva TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (linea_pedido_id) REFERENCES linea_pedido (linea_pedido_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    FOREIGN KEY (lote_id, ubicacion_id)
        REFERENCES existencia_lote (lote_id, ubicacion_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE TABLE movimiento (
    movimiento_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lote_id BIGINT NOT NULL,
    tipo VARCHAR(20) NOT NULL
        CHECK (tipo IN ('recepcion', 'despacho', 'transferencia', 'ajuste')),
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    fecha TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ubicacion_origen_id INTEGER,
    ubicacion_destino_id INTEGER,
    reserva_id BIGINT,
    FOREIGN KEY (lote_id) REFERENCES lote (lote_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    FOREIGN KEY (ubicacion_origen_id) REFERENCES ubicacion (ubicacion_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    FOREIGN KEY (ubicacion_destino_id) REFERENCES ubicacion (ubicacion_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    FOREIGN KEY (reserva_id) REFERENCES reserva (reserva_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CHECK (
        (tipo = 'recepcion' AND ubicacion_origen_id IS NULL AND ubicacion_destino_id IS NOT NULL)
        OR (tipo = 'despacho' AND ubicacion_origen_id IS NOT NULL AND ubicacion_destino_id IS NULL)
        OR (tipo = 'transferencia' AND ubicacion_origen_id IS NOT NULL
            AND ubicacion_destino_id IS NOT NULL AND ubicacion_origen_id <> ubicacion_destino_id)
        OR (tipo = 'ajuste' AND num_nonnulls(ubicacion_origen_id, ubicacion_destino_id) = 1)
    )
);

CREATE TABLE detalle_recepcion (
    detalle_recepcion_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    recepcion_id INTEGER NOT NULL,
    linea_orden_id INTEGER NOT NULL,
    lote_id BIGINT NOT NULL,
    ubicacion_id INTEGER NOT NULL,
    movimiento_id BIGINT NOT NULL UNIQUE,
    cantidad_recibida INTEGER NOT NULL CHECK (cantidad_recibida > 0),
    FOREIGN KEY (recepcion_id) REFERENCES recepcion (recepcion_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    FOREIGN KEY (linea_orden_id) REFERENCES linea_orden_compra (linea_orden_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    FOREIGN KEY (lote_id, ubicacion_id)
        REFERENCES existencia_lote (lote_id, ubicacion_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    FOREIGN KEY (movimiento_id) REFERENCES movimiento (movimiento_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT
);

COMMIT;
