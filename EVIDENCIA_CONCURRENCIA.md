# Evidencia de transacciones y concurrencia — Sprint 3

## Estado de ejecución

El script `04_transactions.sql` implementa una función de reserva FEFO con bloqueo `SELECT ... FOR UPDATE` y prepara dos líneas sintéticas de 6 unidades cada una. El caso tiene 10 unidades vigentes (4 en `CONC-PRIMERO`, 6 en `CONC-SEGUNDO`) y 99 unidades en un lote vencido que debe excluirse.

**No se registra aquí una ejecución observada de dos sesiones.** Los resultados de abajo son los resultados esperados por el diseño y deben sustituirse o confirmarse con capturas de DBeaver antes de presentar la prueba como ejecutada.

## Ejecución reproducible

1. Ejecutar `04_transactions.sql` en `deber02DB`. Anotar los dos `linea_pedido_id` que devuelve la consulta del apartado 3.
2. Para validar FEFO aislado, en una sesión ejecutar `BEGIN; SELECT * FROM reservar_fefo(ID_1); COMMIT;`. Resultado esperado: 4 unidades de `CONC-PRIMERO` y 2 de `CONC-SEGUNDO`; el lote vencido no aparece.
3. Restablecer los datos sintéticos volviendo a ejecutar el bloque de preparación de `04_transactions.sql`.
4. En sesión A: `BEGIN; SELECT * FROM reservar_fefo(ID_1);` y dejar la transacción abierta.
5. En sesión B: `BEGIN; SELECT * FROM reservar_fefo(ID_2);`. Debe esperar el bloqueo. Confirmar la sesión A con `COMMIT`.
6. Resultado esperado en B: error `23514` por stock insuficiente. Ejecutar `ROLLBACK` en B.
7. Ejecutar la consulta de verificación al final del script.

## Resultado esperado y criterio

La sesión A confirma 6 unidades y la B no confirma ninguna; quedan 4 disponibles. La suma reservada no excede el stock elegible de 10 y `CONC-VENCIDO` permanece sin reserva. El error en B revierte la operación completa, incluso si habría iniciado una asignación parcial.

La función toma los locks antes de volver a calcular el saldo. Con `READ COMMITTED`, una lectura simple de saldo seguida de una escritura no basta para evitar sobreventa; el bloqueo serializa las solicitudes que comparten filas. Esperas largas reducen concurrencia. Deadlocks o fallos de serialización requieren rollback y reintento de la transacción completa.

## Evidencia pendiente

Guardar capturas de las dos sesiones mostrando la espera, el `COMMIT` de A, el error de B y el resultado de verificación. No se midió duración de espera ni se observó un deadlock; no deben reportarse como resultados.
