# Plan de trabajo para Smart Inventory

## Sprint 1 — Diseñar y normalizar la base de datos

1. **Definir las reglas del inventario.** Acordar cómo se calcula el stock disponible por lote y ubicación, qué lotes pueden reservarse y cómo se manejan las recepciones parciales, las reservas liberadas, los ajustes y las transferencias.
2. **Elegir cómo se obtiene el saldo.** Decidir si se calcula desde el libro de movimientos o si se guarda como balance. Si se guardan ambos, documentar cómo se actualizan juntos y cómo comprobar que coinciden.
3. **Normalizar una relación de recepción o picking.** Partir de una tabla con datos repetidos, identificar claves y dependencias funcionales, mostrar las anomalías de inserción, actualización y borrado, y documentar la descomposición hasta 3FN. Evaluar BCNF en al menos dos relaciones.
4. **Cerrar el modelo.** Dibujar el ER con cardinalidades y opcionalidad. Pasarlo a un esquema relacional, completar el diccionario con tipos y restricciones, y registrar cada regla en la matriz con su restricción o mecanismo SQL y la prueba correspondiente.

**Entregables de la semana:** diagrama ER, esquema relacional, diccionario, matriz y análisis de normalización. El modelo debe permitir seguir una cifra de stock hasta los lotes y ubicaciones que la componen.

## Sprint 2 — Implementar el esquema y las consultas en PostgreSQL

1. **Crear `01_schema.sql`.** Implementar tablas, PK, FK, `CHECK` y `UNIQUE`. Definir la nulabilidad y qué ocurre al eliminar o actualizar registros referenciados.
2. **Crear `02_seed.sql`.** Cargar datos que incluyan varias bodegas, lotes vigentes, vencidos y agotados, un pedido que necesite más de un lote y una orden de compra con recepción parcial.
3. **Ejecutar las pruebas de integridad.** Probar una FK inválida, una cantidad negativa, una clave duplicada, una fecha inconsistente y un estado o transición no permitido. Registrar el resultado observado en la matriz.
4. **Crear `03_queries.sql`.** Implementar las ocho consultas: stock disponible, lotes por vencer, picking FEFO, reposición, trazabilidad de pedidos, recepciones parciales, rotación y nivel de servicio con quiebres. Al menos tres deben unir tres o más tablas y agregar datos, y al menos una debe usar una función de ventana. Guardar el resultado de prueba y una explicación breve de cada consulta.

**Entregables de la semana:** tres scripts ejecutables, evidencia de al menos cinco pruebas de integridad y resultados reproducibles de las ocho consultas.

## Sprint 3 — Validar concurrencia, medir rendimiento y entregar

1. **Crear `04_transactions.sql`.** Implementar la reserva FEFO con `COMMIT` y `ROLLBACK`. Verificar que toma primero el lote elegible que vence antes, que puede repartir una reserva entre lotes y que revierte todos los cambios si falla después de una asignación parcial.
2. **Probar la reserva con dos sesiones.** Hacer que ambas pidan cantidades cuya suma supere el stock disponible. Repetir el caso con `READ COMMITTED` sin bloqueo explícito y con `SELECT … FOR UPDATE` o `SERIALIZABLE`. Registrar qué pudo confirmar cada sesión y justificar la estrategia elegida, incluidos el costo de las esperas o reintentos y el manejo de deadlocks.
3. **Crear `05_indexes_views.sql`.** Implementar dos vistas para el dashboard. Elegir tres consultas críticas, ejecutar `EXPLAIN (ANALYZE, BUFFERS)` antes y después de crear los índices y explicar qué cambió en el plan con los mismos datos.
4. **Preparar la entrega.** Verificar que el README permita reproducir los scripts y las pruebas desde una base vacía. Cerrar el informe PDF y preparar una exposición de 8–10 minutos sobre el modelo, una consulta avanzada y el experimento de concurrencia.

**Entregables de la semana:** repositorio versionado con los cinco scripts y el README, evidencia de concurrencia y rendimiento, informe PDF y exposición.

En cada sprint, asignen un **responsable por tarea** y registren el backlog, la revisión de los entregables y la retrospectiva. [Enunciado del deber](https://chatgpt.com/library?file_id=libfile_37c1f5a7ce8481919d04e7bc48b486aa&account_id=personal)
