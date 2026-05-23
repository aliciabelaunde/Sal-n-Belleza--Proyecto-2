-- ============================================================
-- COCO Salón de Belleza · SalonBelleza_CBB
-- Archivo: CBB_05_triggers.sql
-- Descripción: Triggers
-- ============================================================

USE SalonBelleza_CBB;
GO

-- 1. Alerta de stock bajo
DROP TRIGGER IF EXISTS Inventario.TR_AlertaStockBajo;
GO
CREATE TRIGGER Inventario.TR_AlertaStockBajo
ON Inventario.Producto AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(StockActual) RETURN;
    IF NOT EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.ProductoID = i.ProductoID
                   WHERE i.StockActual <= i.StockMinimo AND d.StockActual > d.StockMinimo AND i.Activo = 1) RETURN;
    DECLARE @TipoID INT;
    SELECT @TipoID = TipoNotificacionID FROM Notificaciones.TipoNotificacion WHERE Nombre = 'stock_minimo';
    INSERT INTO Notificaciones.Notificacion (PersonaID, TipoNotificacionID, Mensaje)
    SELECT u.PersonaID, @TipoID,
        'Stock bajo: ' + i.Nombre + ' · Stock actual: ' + CAST(i.StockActual AS VARCHAR) + ' · Minimo: ' + CAST(i.StockMinimo AS VARCHAR)
    FROM inserted i JOIN deleted d ON d.ProductoID = i.ProductoID
    CROSS JOIN Seguridad.Usuario u JOIN Seguridad.UsuarioRol ur ON ur.UsuarioID = u.UsuarioID
    WHERE ur.RolID = 2 AND u.Activo = 1 AND i.StockActual <= i.StockMinimo AND d.StockActual > d.StockMinimo AND i.Activo = 1;
END;
GO

-- 2. Notificacion al actualizar sueldo
CREATE TRIGGER RRHH.TR_NotificarActualizacionSueldo
ON RRHH.EmpleadoSueldo AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TipoID INT;
    SELECT @TipoID = TipoNotificacionID FROM Notificaciones.TipoNotificacion WHERE Nombre = 'actualizacion_sueldo';
    INSERT INTO Notificaciones.Notificacion (PersonaID, TipoNotificacionID, Mensaje)
    SELECT i.EmpleadoID, @TipoID,
        'Tu sueldo base fue actualizado a Bs ' + CAST(i.SueldoBase AS VARCHAR) +
        ' a partir del ' + FORMAT(i.FechaInicio, 'dd/MM/yyyy') + '.'
    FROM inserted i;
END;
GO

-- 3. Notificacion al crear cita
CREATE TRIGGER Agenda.TR_NotificarNuevaCita
ON Agenda.Cita AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TipoID INT;
    SELECT @TipoID = TipoNotificacionID FROM Notificaciones.TipoNotificacion WHERE Nombre = 'recordatorio_cita';
    INSERT INTO Notificaciones.Notificacion (PersonaID, TipoNotificacionID, Mensaje)
    SELECT i.ClienteID, @TipoID,
        'Tu cita fue reservada para el ' + FORMAT(i.FechaInicio,'dd/MM/yyyy') +
        ' a las ' + FORMAT(i.FechaInicio,'HH:mm') + 'h. Te esperamos!'
    FROM inserted i;
END;
GO

-- 4. Notificacion al confirmar cita
CREATE TRIGGER Agenda.TR_NotificarCitaConfirmada
ON Agenda.Cita AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(EstadoID) RETURN;
    DECLARE @TipoID INT;
    SELECT @TipoID = TipoNotificacionID FROM Notificaciones.TipoNotificacion WHERE Nombre = 'recordatorio_cita';
    INSERT INTO Notificaciones.Notificacion (PersonaID, TipoNotificacionID, Mensaje)
    SELECT i.ClienteID, @TipoID,
        'Tu cita del ' + FORMAT(i.FechaInicio,'dd/MM/yyyy') +
        ' a las ' + FORMAT(i.FechaInicio,'HH:mm') + 'h fue confirmada. Te esperamos!'
    FROM inserted i JOIN deleted d ON d.CitaID = i.CitaID
    WHERE i.EstadoID = 9 AND d.EstadoID = 8;
END;
GO

-- 5. Notificacion al cancelar cita
CREATE TRIGGER Agenda.TR_NotificarCancelacionCita
ON Agenda.Cita AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(EstadoID) RETURN;
    DECLARE @TipoID INT;
    SELECT @TipoID = TipoNotificacionID FROM Notificaciones.TipoNotificacion WHERE Nombre = 'recordatorio_cita';
    INSERT INTO Notificaciones.Notificacion (PersonaID, TipoNotificacionID, Mensaje)
    SELECT i.ClienteID, @TipoID,
        'Tu cita del ' + FORMAT(i.FechaInicio,'dd/MM/yyyy') +
        ' a las ' + FORMAT(i.FechaInicio,'HH:mm') + 'h ha sido cancelada.'
    FROM inserted i JOIN deleted d ON d.CitaID = i.CitaID
    WHERE i.EstadoID = 12 AND d.EstadoID <> 12;
END;
GO

-- 6. Notificacion al completar cita
CREATE TRIGGER Agenda.TR_NotificarCitaCompletada
ON Agenda.Cita AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(EstadoID) RETURN;
    DECLARE @TipoID INT;
    SELECT @TipoID = TipoNotificacionID FROM Notificaciones.TipoNotificacion WHERE Nombre = 'recordatorio_cita';
    INSERT INTO Notificaciones.Notificacion (PersonaID, TipoNotificacionID, Mensaje)
    SELECT i.ClienteID, @TipoID,
        'Tu servicio del ' + FORMAT(i.FechaInicio,'dd/MM/yyyy') + ' fue completado. Gracias por visitarnos!'
    FROM inserted i JOIN deleted d ON d.CitaID = i.CitaID
    WHERE i.EstadoID = 11 AND d.EstadoID <> 11;
END;
GO

-- 7. Notificacion al editar cita
CREATE TRIGGER Agenda.TR_NotificarEdicionCita
ON Agenda.Cita AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(FechaInicio) RETURN;
    DECLARE @TipoID INT;
    SELECT @TipoID = TipoNotificacionID FROM Notificaciones.TipoNotificacion WHERE Nombre = 'recordatorio_cita';
    INSERT INTO Notificaciones.Notificacion (PersonaID, TipoNotificacionID, Mensaje)
    SELECT i.ClienteID, @TipoID,
        'Tu cita fue reprogramada para el ' + FORMAT(i.FechaInicio,'dd/MM/yyyy') +
        ' a las ' + FORMAT(i.FechaInicio,'HH:mm') + 'h.'
    FROM inserted i JOIN deleted d ON d.CitaID = i.CitaID
    WHERE i.FechaInicio <> d.FechaInicio AND i.EstadoID NOT IN (12, 13);
END;
GO

-- 8. Notificacion al registrar nuevo cliente
CREATE TRIGGER Ventas.TR_NotificarNuevoCliente
ON Ventas.Cliente AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TipoID INT;
    SELECT @TipoID = TipoNotificacionID FROM Notificaciones.TipoNotificacion WHERE Nombre = 'nuevo_cliente';
    INSERT INTO Notificaciones.Notificacion (PersonaID, TipoNotificacionID, Mensaje)
    SELECT u.PersonaID, @TipoID,
        'Nueva clienta registrada: ' + p.Nombre + ' ' + p.Apellido + ' · ' + p.Telefono
    FROM inserted i
    JOIN Personas.Persona p ON p.PersonaID = i.ClienteID
    CROSS JOIN Seguridad.Usuario u JOIN Seguridad.UsuarioRol ur ON ur.UsuarioID = u.UsuarioID
    WHERE ur.RolID = 4 AND u.Activo = 1;
END;
GO

-- 9. Notificacion al aprobar excepcion
CREATE TRIGGER RRHH.TR_NotificarExcepcionAprobada
ON RRHH.HorarioExcepcion AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(Aprobado) RETURN;
    DECLARE @TipoID INT;
    SELECT @TipoID = TipoNotificacionID FROM Notificaciones.TipoNotificacion WHERE Nombre = 'aprobacion_excepcion';
    INSERT INTO Notificaciones.Notificacion (PersonaID, TipoNotificacionID, Mensaje)
    SELECT i.EmpleadoID, @TipoID,
        CASE i.Disponible
            WHEN 1 THEN 'Tu turno extra del ' + FORMAT(i.Fecha,'dd/MM/yyyy') + ' fue aprobado.'
            ELSE 'Tu dia libre del ' + FORMAT(i.Fecha,'dd/MM/yyyy') + ' fue aprobado.'
        END
    FROM inserted i JOIN deleted d ON d.ExcepcionID = i.ExcepcionID
    WHERE i.Aprobado = 1 AND d.Aprobado = 0;
END;
GO

PRINT 'CBB_05_triggers.sql ejecutado correctamente';
GO