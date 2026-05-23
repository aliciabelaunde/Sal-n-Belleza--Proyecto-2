-- ============================================================
-- COCO Salón de Belleza · SalonBelleza_CBB
-- Archivo: CBB_09_sps_faltantes.sql
-- Descripción: SPs que faltaban en Cochabamba
-- ============================================================

USE SalonBelleza_CBB;
GO

CREATE OR ALTER PROCEDURE Admin.SP_ObtenerPerfil
    @PersonaID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.PersonaID, p.Nombre, p.Apellido, p.Email, p.Telefono, p.FechaNacimiento, r.Nombre
    FROM Personas.Persona p
    JOIN Seguridad.Usuario u ON u.PersonaID = p.PersonaID
    JOIN Seguridad.UsuarioRol ur ON ur.UsuarioID = u.UsuarioID
    JOIN Seguridad.Rol r ON r.RolID = ur.RolID
    WHERE p.PersonaID = @PersonaID;
END;
GO

CREATE OR ALTER PROCEDURE Admin.SP_ActualizarPerfil
    @PersonaID INT, @Nombre VARCHAR(100), @Apellido VARCHAR(100),
    @Telefono VARCHAR(20), @Email VARCHAR(100), @FechaNacimiento DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Email=@Email AND PersonaID<>@PersonaID)
        BEGIN ROLLBACK; RAISERROR('Este correo ya esta en uso.',16,1); RETURN; END
        UPDATE Personas.Persona SET Nombre=@Nombre,Apellido=@Apellido,Telefono=@Telefono,
            Email=@Email,FechaNacimiento=@FechaNacimiento WHERE PersonaID=@PersonaID;
        UPDATE Seguridad.Usuario SET Username=@Email WHERE PersonaID=@PersonaID;
        COMMIT;
        SELECT 'Perfil actualizado.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al actualizar perfil.',16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_AprobarSolicitudEspecial
    @SolicitudID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE Agenda.SolicitudEspecial SET Estado='aprobada'
        WHERE SolicitudID=@SolicitudID AND Estado='pendiente';
        DECLARE @TipoID INT;
        SELECT @TipoID=TipoNotificacionID FROM Notificaciones.TipoNotificacion WHERE Nombre='solicitud_aprobada';
        INSERT INTO Notificaciones.Notificacion (PersonaID,TipoNotificacionID,Mensaje)
        SELECT s.ClienteID, @TipoID,
            'Tu solicitud de horario especial para el '+FORMAT(s.FechaSolicitada,'dd/MM/yyyy HH:mm')+'h fue aprobada.'
        FROM Agenda.SolicitudEspecial s WHERE s.SolicitudID=@SolicitudID;
        COMMIT;
        SELECT 'Solicitud aprobada y cliente notificado.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al aprobar la solicitud.',16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_CancelarCita
    @CitaID INT, @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM Agenda.Cita WHERE CitaID=@CitaID AND ClienteID=@ClienteID)
        BEGIN ROLLBACK; RAISERROR('No tienes permiso para cancelar esta cita.',16,1); RETURN; END
        IF EXISTS (SELECT 1 FROM Agenda.Cita WHERE CitaID=@CitaID AND FechaInicio<GETDATE())
        BEGIN ROLLBACK; RAISERROR('No puedes cancelar una cita que ya paso.',16,1); RETURN; END
        IF EXISTS (SELECT 1 FROM Agenda.Cita WHERE CitaID=@CitaID AND EstadoID IN (11,12,13))
        BEGIN ROLLBACK; RAISERROR('Esta cita ya fue cancelada o completada.',16,1); RETURN; END
        UPDATE Agenda.Cita SET EstadoID=12 WHERE CitaID=@CitaID;
        COMMIT;
        SELECT 'Cita cancelada correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al cancelar la cita.',16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_EditarCita
    @CitaID INT, @ClienteID INT, @NuevaFecha DATETIME,
    @NuevosEmpleados VARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM Agenda.Cita WHERE CitaID=@CitaID AND ClienteID=@ClienteID)
        BEGIN ROLLBACK; RAISERROR('No tienes permiso para editar esta cita.',16,1); RETURN; END
        IF EXISTS (SELECT 1 FROM Agenda.Cita WHERE CitaID=@CitaID AND FechaInicio<GETDATE())
        BEGIN ROLLBACK; RAISERROR('No puedes editar una cita que ya paso.',16,1); RETURN; END
        IF EXISTS (SELECT 1 FROM Agenda.Cita WHERE CitaID=@CitaID AND EstadoID IN (11,12,13))
        BEGIN ROLLBACK; RAISERROR('No puedes editar una cita cancelada o completada.',16,1); RETURN; END
        UPDATE Agenda.Cita SET FechaInicio=@NuevaFecha WHERE CitaID=@CitaID;
        COMMIT;
        SELECT 'Cita actualizada correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        DECLARE @Error VARCHAR(500)=ERROR_MESSAGE();
        RAISERROR(@Error,16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_ObtenerSolicitudesEspeciales
    @Estado VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT se.SolicitudID, se.FechaSolicitada, se.Motivo, se.Estado, se.FechaCreacion,
        p.Nombre AS NombreCliente, p.Apellido AS ApellidoCliente
    FROM Agenda.SolicitudEspecial se
    JOIN Ventas.Cliente cl ON cl.ClienteID=se.ClienteID
    JOIN Personas.Persona p ON p.PersonaID=se.ClienteID
    WHERE (@Estado IS NULL OR se.Estado=@Estado)
    ORDER BY se.FechaCreacion DESC;
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_ResolverSolicitudEspecial
    @SolicitudID INT, @Estado VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Agenda.SolicitudEspecial SET Estado=@Estado WHERE SolicitudID=@SolicitudID;
    SELECT 'Solicitud actualizada.' AS Mensaje;
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_VerificarDisponibilidadEmpleado
    @EmpleadoID INT, @Fecha DATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM RRHH.HorarioExcepcion
               WHERE EmpleadoID=@EmpleadoID AND Fecha=@Fecha AND Disponible=0 AND Estado='Aprobada')
    BEGIN RAISERROR('El empleado tiene dia libre aprobado para esa fecha.',16,1); RETURN; END
    SELECT 1 AS Disponible;
END;
GO

CREATE OR ALTER PROCEDURE Duena.SP_ActualizarPerfil
    @PersonaID INT, @Nombre VARCHAR(100), @Apellido VARCHAR(100),
    @Telefono VARCHAR(20), @Email VARCHAR(100), @FechaNacimiento DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Email=@Email AND PersonaID<>@PersonaID)
        BEGIN ROLLBACK; RAISERROR('Este correo ya esta en uso.',16,1); RETURN; END
        UPDATE Personas.Persona SET Nombre=@Nombre,Apellido=@Apellido,Telefono=@Telefono,
            Email=@Email,FechaNacimiento=@FechaNacimiento WHERE PersonaID=@PersonaID;
        UPDATE Seguridad.Usuario SET Username=@Email WHERE PersonaID=@PersonaID;
        COMMIT;
        SELECT 'Perfil actualizado correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al actualizar perfil.',16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Facturacion.SP_AnularFactura
    @FacturaID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE Facturacion.Factura SET Estado='anulada'
        WHERE FacturaID=@FacturaID AND Estado IN ('emitida');
        UPDATE Ventas.Venta SET Estado='cancelado'
        WHERE VentaID=(SELECT VentaID FROM Facturacion.Factura WHERE FacturaID=@FacturaID);
        COMMIT;
        SELECT 'Factura anulada correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al anular la factura.',16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Facturacion.SP_MarcarFacturaPagada
    @FacturaID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE Facturacion.Factura SET Estado='pagada'
        WHERE FacturaID=@FacturaID AND Estado='emitida';
        UPDATE Ventas.Venta SET Estado='pagado'
        WHERE VentaID=(SELECT VentaID FROM Facturacion.Factura WHERE FacturaID=@FacturaID);
        COMMIT;
        SELECT 'Factura marcada como pagada.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al actualizar la factura.',16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Inventario.SP_ObtenerProductosVenta
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.ProductoID, p.Nombre, p.StockActual, p.UnidadMedida,
        ISNULL(pp.Precio,0) AS Precio
    FROM Inventario.Producto p
    LEFT JOIN Inventario.ProductoPrecio pp ON pp.ProductoID=p.ProductoID AND pp.FechaFin IS NULL
    WHERE p.Activo=1 AND p.StockActual>0 ORDER BY p.Nombre;
END;
GO

CREATE OR ALTER PROCEDURE Notificaciones.SP_ObtenerNotificacionesRecepcion
    @PersonaID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT n.NotificacionID, n.Mensaje, n.Fecha, n.Leido, tn.Nombre AS TipoNotificacion
    FROM Notificaciones.Notificacion n
    JOIN Notificaciones.TipoNotificacion tn ON tn.TipoNotificacionID=n.TipoNotificacionID
    WHERE n.PersonaID=@PersonaID AND tn.Nombre<>'stock_minimo'
    ORDER BY n.Leido ASC, n.Fecha DESC;
END;
GO

CREATE OR ALTER PROCEDURE Ventas.SP_ObtenerPerfilCliente
    @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.PersonaID, p.Nombre, p.Apellido, p.Email, p.Telefono,
        p.FechaNacimiento, p.FechaRegistro,
        cd.Alergias, cd.Contraindicaciones, cd.NotasTecnicas
    FROM Personas.Persona p
    JOIN Ventas.Cliente c ON c.ClienteID=p.PersonaID
    LEFT JOIN Ventas.ClienteDetalle cd ON cd.ClienteID=c.ClienteID
    WHERE p.PersonaID=@ClienteID;
END;
GO

CREATE OR ALTER PROCEDURE Ventas.SP_ActualizarPerfilCliente
    @ClienteID INT, @Nombre VARCHAR(100), @Apellido VARCHAR(100),
    @Telefono VARCHAR(20), @Email VARCHAR(100), @FechaNacimiento DATE=NULL,
    @Alergias VARCHAR(MAX)=NULL, @Contraindicaciones VARCHAR(MAX)=NULL,
    @NotasTecnicas VARCHAR(MAX)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Email=@Email AND PersonaID<>@ClienteID)
    BEGIN RAISERROR('Este correo ya esta en uso por otro cliente',16,1); RETURN; END
    IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Telefono=@Telefono AND PersonaID<>@ClienteID)
    BEGIN RAISERROR('Este telefono ya esta en uso por otro cliente',16,1); RETURN; END
    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE Personas.Persona SET Nombre=@Nombre,Apellido=@Apellido,Telefono=@Telefono,
            Email=@Email,FechaNacimiento=@FechaNacimiento WHERE PersonaID=@ClienteID;
        IF EXISTS (SELECT 1 FROM Ventas.ClienteDetalle WHERE ClienteID=@ClienteID)
            UPDATE Ventas.ClienteDetalle SET Alergias=@Alergias,Contraindicaciones=@Contraindicaciones,
                NotasTecnicas=@NotasTecnicas WHERE ClienteID=@ClienteID;
        ELSE
            INSERT INTO Ventas.ClienteDetalle (ClienteID,Alergias,Contraindicaciones,NotasTecnicas)
            VALUES (@ClienteID,@Alergias,@Contraindicaciones,@NotasTecnicas);
        COMMIT;
        SELECT 'Perfil actualizado correctamente' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al actualizar el perfil',16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Ventas.SP_DetalleCliente
    @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.PersonaID, p.Nombre, p.Apellido, p.Telefono, p.Email, p.FechaRegistro,
        cd.Alergias, cd.Contraindicaciones, cd.NotasTecnicas, COUNT(c.CitaID) AS TotalVisitas
    FROM Personas.Persona p
    JOIN Ventas.Cliente cl ON cl.ClienteID=p.PersonaID
    LEFT JOIN Ventas.ClienteDetalle cd ON cd.ClienteID=p.PersonaID
    LEFT JOIN Agenda.Cita c ON c.ClienteID=p.PersonaID AND c.EstadoID=11
    WHERE p.PersonaID=@ClienteID
    GROUP BY p.PersonaID,p.Nombre,p.Apellido,p.Telefono,p.Email,
        p.FechaRegistro,cd.Alergias,cd.Contraindicaciones,cd.NotasTecnicas;

    SELECT TOP 5 ci.CitaID, ci.FechaInicio, s.Nombre AS Servicio,
        emp.Nombre AS Empleado, emp.Apellido AS EmpleadoApellido,
        ec.Nombre AS Estado, sp.Precio
    FROM Agenda.Cita ci
    JOIN Agenda.CitaServicio cs ON cs.CitaID=ci.CitaID
    JOIN Servicios.Servicio s ON s.ServicioID=cs.ServicioID
    JOIN Personas.Persona emp ON emp.PersonaID=cs.EmpleadoID
    JOIN Agenda.EstadoCita ec ON ec.EstadoID=ci.EstadoID
    JOIN Servicios.ServicioPrecio sp ON sp.ServicioID=s.ServicioID AND sp.FechaFin IS NULL
    WHERE ci.ClienteID=@ClienteID ORDER BY ci.FechaInicio DESC;
END;
GO

CREATE OR ALTER PROCEDURE Ventas.SP_ObtenerFacturasCliente
    @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT f.FacturaID, f.NumeroFactura, f.Fecha, f.VentaID, f.Estado,
        ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad),0)+
        ISNULL(SUM(vdp.PrecioUnitario*vdp.Cantidad),0) AS Total
    FROM Facturacion.Factura f
    JOIN Ventas.Venta v ON v.VentaID=f.VentaID
    LEFT JOIN Ventas.VentaDetalleServicio vds ON vds.VentaID=v.VentaID
    LEFT JOIN Ventas.VentaDetalleProducto vdp ON vdp.VentaID=v.VentaID
    WHERE v.ClienteID=@ClienteID
    GROUP BY f.FacturaID,f.NumeroFactura,f.Fecha,f.VentaID,f.Estado
    ORDER BY f.Fecha DESC;
END;
GO

CREATE OR ALTER PROCEDURE Ventas.SP_RegistrarClienteRecepcion
    @Nombre VARCHAR(100), @Apellido VARCHAR(100), @Telefono VARCHAR(20),
    @Email VARCHAR(100), @PassHash VARCHAR(255),
    @Alergias VARCHAR(MAX)=NULL, @Contraindicaciones VARCHAR(MAX)=NULL,
    @NotasTecnicas VARCHAR(MAX)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Email=@Email)
    BEGIN RAISERROR('Este correo ya esta registrado.',16,1); RETURN; END
    IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Telefono=@Telefono)
    BEGIN RAISERROR('Este telefono ya esta registrado.',16,1); RETURN; END
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @PersonaID INT;
        INSERT INTO Personas.Persona (Nombre,Apellido,Telefono,Email) VALUES (@Nombre,@Apellido,@Telefono,@Email);
        SET @PersonaID=SCOPE_IDENTITY();
        INSERT INTO Ventas.Cliente (ClienteID) VALUES (@PersonaID);
        IF @Alergias IS NOT NULL OR @Contraindicaciones IS NOT NULL OR @NotasTecnicas IS NOT NULL
            INSERT INTO Ventas.ClienteDetalle (ClienteID,Alergias,Contraindicaciones,NotasTecnicas)
            VALUES (@PersonaID,@Alergias,@Contraindicaciones,@NotasTecnicas);
        DECLARE @UsuarioID INT;
        INSERT INTO Seguridad.Usuario (PersonaID,Username,PasswordHash) VALUES (@PersonaID,@Email,@PassHash);
        SET @UsuarioID=SCOPE_IDENTITY();
        INSERT INTO Seguridad.UsuarioRol (UsuarioID,RolID) VALUES (@UsuarioID,3);
        COMMIT;
        SELECT @PersonaID AS ClienteID, 'Cliente registrado.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al registrar el cliente.',16,1);
    END CATCH
END;
GO

PRINT 'CBB_09_sps_faltantes.sql ejecutado correctamente';
GO



USE SalonBelleza_CBB;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_ObtenerSolicitudesEspeciales
    @Estado VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT se.SolicitudID, se.FechaSolicitada, se.Motivo, se.Estado, se.FechaCreacion,
        p.Nombre AS NombreCliente, p.Apellido AS ApellidoCliente
    FROM Agenda.SolicitudEspecial se
    JOIN Ventas.Cliente cl ON cl.ClienteID=se.ClienteID
    JOIN Personas.Persona p ON p.PersonaID=se.ClienteID
    WHERE (@Estado IS NULL OR se.Estado=@Estado)
    ORDER BY se.FechaCreacion DESC;
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_ResolverSolicitudEspecial
    @SolicitudID INT, @Estado VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Agenda.SolicitudEspecial SET Estado=@Estado WHERE SolicitudID=@SolicitudID;
    SELECT 'Solicitud actualizada.' AS Mensaje;
END;
GO