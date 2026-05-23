-- ============================================================
-- COCO Salón de Belleza · SalonBelleza_CBB
-- Archivo: CBB_03_indices.sql
-- Descripción: Índices
-- ============================================================

USE SalonBelleza_CBB;
GO

-- Login
CREATE INDEX IX_Persona_Email        ON Personas.Persona(Email);
CREATE INDEX IX_Persona_Telefono     ON Personas.Persona(Telefono);
CREATE INDEX IX_Usuario_Username     ON Seguridad.Usuario(Username);
CREATE INDEX IX_Usuario_PersonaID    ON Seguridad.Usuario(PersonaID);
CREATE INDEX IX_UsuarioRol_UsuarioID ON Seguridad.UsuarioRol(UsuarioID);
GO

-- Agenda
CREATE INDEX IX_Cita_FechaEstado        ON Agenda.Cita(FechaInicio, EstadoID);
CREATE INDEX IX_Cita_ClienteID          ON Agenda.Cita(ClienteID);
CREATE INDEX IX_Cita_FechaInicio        ON Agenda.Cita(FechaInicio);
CREATE INDEX IX_Cita_EstadoID           ON Agenda.Cita(EstadoID);
CREATE INDEX IX_CitaEmpleado_CitaID     ON Agenda.CitaEmpleado(CitaID);
CREATE INDEX IX_CitaServicio_CitaID     ON Agenda.CitaServicio(CitaID);
CREATE INDEX IX_CitaServicio_EmpleadoID ON Agenda.CitaServicio(EmpleadoID);
CREATE INDEX IX_CitaServicio_FechaInicio ON Agenda.CitaServicio(FechaInicioServicio);
CREATE INDEX IX_CitaServicio_EmpleadoFecha ON Agenda.CitaServicio(EmpleadoID, FechaInicioServicio);
CREATE INDEX IX_SolicitudEspecial_Estado   ON Agenda.SolicitudEspecial(Estado);
CREATE INDEX IX_SolicitudEspecial_ClienteID ON Agenda.SolicitudEspecial(ClienteID);
GO

-- Ventas
CREATE INDEX IX_Venta_FechaEstado         ON Ventas.Venta(Fecha, Estado);
CREATE INDEX IX_Venta_ClienteID           ON Ventas.Venta(ClienteID);
CREATE INDEX IX_Venta_Fecha               ON Ventas.Venta(Fecha);
CREATE INDEX IX_Venta_EmpleadoID          ON Ventas.Venta(EmpleadoID);
CREATE INDEX IX_VentaDetalleServicio_VentaID ON Ventas.VentaDetalleServicio(VentaID);
CREATE INDEX IX_VentaDetalleProducto_VentaID ON Ventas.VentaDetalleProducto(VentaID);
CREATE INDEX IX_Pago_VentaID              ON Ventas.Pago(VentaID);
GO

-- Inventario
CREATE INDEX IX_Producto_Activo           ON Inventario.Producto(Activo);
CREATE INDEX IX_ProductoPrecio_Vigente    ON Inventario.ProductoPrecio(ProductoID, FechaFin);
CREATE INDEX IX_MovimientoInventario_Producto ON Inventario.MovimientoInventario(ProductoID, Fecha);
CREATE INDEX IX_MovimientoInventario_Fecha    ON Inventario.MovimientoInventario(Fecha);
GO

-- Servicios
CREATE INDEX IX_Servicio_Activo           ON Servicios.Servicio(Activo);
CREATE INDEX IX_Servicio_SubcategoriaID   ON Servicios.Servicio(SubcategoriaID);
CREATE INDEX IX_ServicioPrecio_Vigente    ON Servicios.ServicioPrecio(ServicioID, FechaFin);
GO

-- Marketing
CREATE INDEX IX_Promocion_Activa          ON Marketing.Promocion(FechaInicio, FechaFin);
CREATE INDEX IX_Promocion_Fechas          ON Marketing.Promocion(FechaInicio, FechaFin, Activo);
CREATE INDEX IX_PromocionServicio_PromocionID ON Marketing.PromocionServicio(PromocionID);
GO

-- RRHH
CREATE INDEX IX_EmpleadoRol_RolID         ON RRHH.EmpleadoRol(RolID);
CREATE INDEX IX_HorarioEmpleado_EmpleadoID ON RRHH.HorarioEmpleado(EmpleadoID, DiaSemana);
CREATE INDEX IX_HorarioExcepcion_EmpleadoFecha ON RRHH.HorarioExcepcion(EmpleadoID, Fecha);
CREATE INDEX IX_HorarioExcepcion_Aprobado ON RRHH.HorarioExcepcion(Aprobado, Fecha);
CREATE INDEX IX_HorarioExcepcion_Empleado ON RRHH.HorarioExcepcion(EmpleadoID, Aprobado);
CREATE INDEX IX_EmpleadoSueldo_Vigente    ON RRHH.EmpleadoSueldo(EmpleadoID, FechaFin);
CREATE INDEX IX_EmpleadoComision_Vigente  ON RRHH.EmpleadoComision(EmpleadoID, FechaFin);
CREATE INDEX IX_PagoNomina_Periodo        ON RRHH.PagoNomina(Periodo);
CREATE INDEX IX_PagoNomina_EmpleadoPeriodo ON RRHH.PagoNomina(EmpleadoID, Periodo);
GO

-- Facturacion
CREATE INDEX IX_Factura_Estado   ON Facturacion.Factura(Estado);
CREATE INDEX IX_Factura_VentaID  ON Facturacion.Factura(VentaID);
GO

-- Notificaciones
CREATE INDEX IX_Notificacion_PersonaID    ON Notificaciones.Notificacion(PersonaID, Leido);
GO

-- Personas
CREATE INDEX IX_Persona_Nombre   ON Personas.Persona(Nombre, Apellido);
GO

PRINT 'CBB_03_indices.sql ejecutado correctamente';
GO