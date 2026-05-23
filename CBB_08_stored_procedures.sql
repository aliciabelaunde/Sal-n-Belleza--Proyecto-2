-- ============================================================
-- COCO Salón de Belleza · SalonBelleza_CBB
-- Archivo: CBB_08_stored_procedures.sql
-- Descripción: Todos los stored procedures
-- ============================================================

USE SalonBelleza_CBB;
GO

-- ============================================================
-- LOGIN / REGISTRO
-- ============================================================

CREATE OR ALTER PROCEDURE Seguridad.SP_RegistrarCliente
    @Nombre   VARCHAR(100),
    @Apellido VARCHAR(100),
    @Telefono VARCHAR(20),
    @Email    VARCHAR(100),
    @PassHash VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Email = @Email)
    BEGIN RAISERROR('Este correo ya esta registrado', 16, 1); RETURN; END
    IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Telefono = @Telefono)
    BEGIN RAISERROR('Este telefono ya esta registrado', 16, 1); RETURN; END
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @PersonaID INT;
        INSERT INTO Personas.Persona (Nombre, Apellido, Telefono, Email)
        VALUES (@Nombre, @Apellido, @Telefono, @Email);
        SET @PersonaID = SCOPE_IDENTITY();
        INSERT INTO Ventas.Cliente (ClienteID) VALUES (@PersonaID);
        DECLARE @UsuarioID INT;
        INSERT INTO Seguridad.Usuario (PersonaID, Username, PasswordHash)
        VALUES (@PersonaID, @Email, @PassHash);
        SET @UsuarioID = SCOPE_IDENTITY();
        INSERT INTO Seguridad.UsuarioRol (UsuarioID, RolID) VALUES (@UsuarioID, 3);
        COMMIT;
        SELECT @PersonaID AS PersonaID, 'Cuenta creada exitosamente' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        RAISERROR('Error al crear la cuenta', 16, 1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Seguridad.SP_Login
    @Email VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UsuarioID, u.PasswordHash, p.Nombre, p.Apellido,
           p.PersonaID, r.RolID, r.Nombre AS Rol
    FROM Seguridad.Usuario    u
    JOIN Personas.Persona     p  ON p.PersonaID  = u.PersonaID
    JOIN Seguridad.UsuarioRol ur ON ur.UsuarioID = u.UsuarioID
    JOIN Seguridad.Rol        r  ON r.RolID      = ur.RolID
    WHERE u.Username = @Email AND u.Activo = 1;
END;
GO

-- ============================================================
-- ADMIN
-- ============================================================

CREATE OR ALTER PROCEDURE Admin.SP_ResumenGeneral
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(*) AS TotalVentas, ISNULL(SUM(p.Monto),0) AS TotalIngresos,
           ISNULL(AVG(p.Monto),0) AS TicketPromedio
    FROM Ventas.Venta v JOIN Ventas.Pago p ON p.VentaID = v.VentaID
    WHERE MONTH(v.Fecha)=MONTH(GETDATE()) AND YEAR(v.Fecha)=YEAR(GETDATE());

    SELECT COUNT(*) AS TotalCitas,
        SUM(CASE WHEN EstadoID=11 THEN 1 ELSE 0 END) AS Completadas,
        SUM(CASE WHEN EstadoID=12 THEN 1 ELSE 0 END) AS Canceladas
    FROM Agenda.Cita
    WHERE MONTH(FechaInicio)=MONTH(GETDATE()) AND YEAR(FechaInicio)=YEAR(GETDATE());

    SELECT COUNT(*) AS TotalClientes FROM Ventas.Cliente;

    SELECT COUNT(*) AS ProductosBajoStock FROM Inventario.Producto
    WHERE StockActual <= StockMinimo AND Activo = 1;

    SELECT YEAR(v.Fecha) AS Anio, MONTH(v.Fecha) AS Mes,
           ISNULL(SUM(p.Monto),0) AS Ingresos, COUNT(v.VentaID) AS Ventas
    FROM Ventas.Venta v JOIN Ventas.Pago p ON p.VentaID = v.VentaID
    WHERE v.Fecha >= DATEADD(MONTH,-6,GETDATE())
    GROUP BY YEAR(v.Fecha), MONTH(v.Fecha) ORDER BY Anio ASC, Mes ASC;

    SELECT TOP 5 s.Nombre AS Servicio,
        SUM(vds.Cantidad) AS TotalVeces,
        ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad),0) AS TotalIngresos
    FROM Ventas.VentaDetalleServicio vds
    JOIN Ventas.Venta v ON v.VentaID=vds.VentaID
    JOIN Servicios.Servicio s ON s.ServicioID=vds.ServicioID
    WHERE MONTH(v.Fecha)=MONTH(GETDATE()) AND YEAR(v.Fecha)=YEAR(GETDATE())
    GROUP BY vds.ServicioID, s.Nombre ORDER BY TotalVeces DESC;
END;
GO

CREATE OR ALTER PROCEDURE Admin.SP_ReporteVentas
    @FechaInicio DATE = NULL,
    @FechaFin    DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @FI DATE = ISNULL(@FechaInicio, DATEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),1));
    DECLARE @FF DATE = ISNULL(@FechaFin, GETDATE());

    SELECT p.Nombre AS NombreEmpleado, p.Apellido AS ApellidoEmpleado,
        COUNT(DISTINCT vds.VentaID) AS TotalVentas,
        ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad),0) AS TotalIngresos,
        ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad*ec.Porcentaje/100.0),0) AS TotalComision
    FROM Ventas.VentaDetalleServicio vds
    JOIN Ventas.Venta v ON v.VentaID=vds.VentaID
    JOIN Personas.Persona p ON p.PersonaID=vds.EmpleadoID
    LEFT JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID=vds.EmpleadoID AND ec.FechaFin IS NULL
    WHERE CAST(v.Fecha AS DATE) BETWEEN @FI AND @FF AND vds.EmpleadoID IS NOT NULL
    GROUP BY vds.EmpleadoID, p.Nombre, p.Apellido ORDER BY TotalIngresos DESC;

    SELECT s.Nombre AS Servicio, SUM(vds.Cantidad) AS TotalVeces,
        ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad),0) AS TotalIngresos
    FROM Ventas.VentaDetalleServicio vds
    JOIN Ventas.Venta v ON v.VentaID=vds.VentaID
    JOIN Servicios.Servicio s ON s.ServicioID=vds.ServicioID
    WHERE CAST(v.Fecha AS DATE) BETWEEN @FI AND @FF
    GROUP BY vds.ServicioID, s.Nombre ORDER BY TotalVeces DESC;

    SELECT ISNULL(SUM(pg.Monto),0) AS TotalIngresos,
        COUNT(DISTINCT v.VentaID) AS TotalVentas,
        ISNULL(AVG(pg.Monto),0) AS TicketPromedio
    FROM Ventas.Venta v JOIN Ventas.Pago pg ON pg.VentaID=v.VentaID
    WHERE CAST(v.Fecha AS DATE) BETWEEN @FI AND @FF;
END;
GO

-- ============================================================
-- RRHH
-- ============================================================

CREATE OR ALTER PROCEDURE RRHH.SP_ListarEmpleados
AS
BEGIN
    SET NOCOUNT ON;
    SELECT e.EmpleadoID, p.Nombre, p.Apellido, p.Email, p.Telefono,
        p.FechaNacimiento, p.Activo AS PersonaActiva,
        STRING_AGG(r.NombreRol,', ') WITHIN GROUP (ORDER BY r.RolID) AS Roles,
        STRING_AGG(CAST(r.RolID AS VARCHAR),',') WITHIN GROUP (ORDER BY r.RolID) AS RoleIDs,
        MIN(r.RolID) AS RolID, MIN(r.NombreRol) AS NombreRol,
        e.FechaContratacion, e.Activo,
        ISNULL(es.SueldoBase,0) AS SueldoBase,
        ISNULL(ec.Porcentaje,0) AS PorcentajeComision
    FROM RRHH.Empleado e
    JOIN Personas.Persona p ON p.PersonaID=e.EmpleadoID
    JOIN RRHH.EmpleadoRol er ON er.EmpleadoID=e.EmpleadoID
    JOIN RRHH.Rol r ON r.RolID=er.RolID
    LEFT JOIN RRHH.EmpleadoSueldo es ON es.EmpleadoID=e.EmpleadoID AND es.FechaFin IS NULL
    LEFT JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID=e.EmpleadoID AND ec.FechaFin IS NULL
    GROUP BY e.EmpleadoID,p.Nombre,p.Apellido,p.Email,p.Telefono,
        p.FechaNacimiento,p.Activo,e.FechaContratacion,e.Activo,es.SueldoBase,ec.Porcentaje
    ORDER BY MIN(r.RolID), p.Nombre;
END;
GO

CREATE OR ALTER PROCEDURE RRHH.SP_ListarEmpleadosSinAdmin
AS
BEGIN
    SET NOCOUNT ON;
    SELECT e.EmpleadoID, p.Nombre, p.Apellido, p.Email, p.Telefono,
        STRING_AGG(r.NombreRol,', ') WITHIN GROUP (ORDER BY r.RolID) AS Roles,
        MIN(r.RolID) AS RolID, e.FechaContratacion, e.Activo,
        ISNULL(es.SueldoBase,0) AS SueldoBase,
        ISNULL(ec.Porcentaje,0) AS PorcentajeComision
    FROM RRHH.Empleado e
    JOIN Personas.Persona p ON p.PersonaID=e.EmpleadoID
    JOIN RRHH.EmpleadoRol er ON er.EmpleadoID=e.EmpleadoID
    JOIN RRHH.Rol r ON r.RolID=er.RolID
    LEFT JOIN RRHH.EmpleadoSueldo es ON es.EmpleadoID=e.EmpleadoID AND es.FechaFin IS NULL
    LEFT JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID=e.EmpleadoID AND ec.FechaFin IS NULL
    WHERE e.EmpleadoID NOT IN (SELECT er2.EmpleadoID FROM RRHH.EmpleadoRol er2 WHERE er2.RolID=2)
    GROUP BY e.EmpleadoID,p.Nombre,p.Apellido,p.Email,p.Telefono,
        p.FechaNacimiento,e.FechaContratacion,e.Activo,es.SueldoBase,ec.Porcentaje
    ORDER BY MIN(r.RolID), p.Nombre;
END;
GO

CREATE OR ALTER PROCEDURE RRHH.SP_ListarRolesPersonal
AS
BEGIN
    SET NOCOUNT ON;
    SELECT RolID, NombreRol FROM RRHH.Rol WHERE RolID NOT IN (1,2) ORDER BY RolID;
END;
GO

CREATE OR ALTER PROCEDURE RRHH.SP_RegistrarEmpleado
    @Nombre VARCHAR(100), @Apellido VARCHAR(100), @Telefono VARCHAR(20),
    @Email VARCHAR(100), @PassHash VARCHAR(255), @RolID INT,
    @FechaContrato DATE, @SueldoBase DECIMAL(10,2), @PctComision DECIMAL(5,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Email=@Email)
        BEGIN ROLLBACK; RAISERROR('Este correo ya esta registrado.',16,1); RETURN; END
        DECLARE @PersonaID INT;
        INSERT INTO Personas.Persona (Nombre,Apellido,Telefono,Email) VALUES (@Nombre,@Apellido,@Telefono,@Email);
        SET @PersonaID = SCOPE_IDENTITY();
        INSERT INTO RRHH.Empleado (EmpleadoID,FechaContratacion,Activo) VALUES (@PersonaID,@FechaContrato,1);
        INSERT INTO RRHH.EmpleadoRol (EmpleadoID,RolID) VALUES (@PersonaID,@RolID);
        DECLARE @UsuarioID INT;
        INSERT INTO Seguridad.Usuario (PersonaID,Username,PasswordHash) VALUES (@PersonaID,@Email,@PassHash);
        SET @UsuarioID = SCOPE_IDENTITY();
        IF @RolID=7 INSERT INTO Seguridad.UsuarioRol (UsuarioID,RolID) VALUES (@UsuarioID,4);
        ELSE INSERT INTO Seguridad.UsuarioRol (UsuarioID,RolID) VALUES (@UsuarioID,5);
        INSERT INTO RRHH.EmpleadoSueldo (EmpleadoID,SueldoBase,FechaInicio) VALUES (@PersonaID,@SueldoBase,@FechaContrato);
        INSERT INTO RRHH.EmpleadoComision (EmpleadoID,Porcentaje,FechaInicio) VALUES (@PersonaID,@PctComision,@FechaContrato);
        INSERT INTO RRHH.HorarioEmpleado (EmpleadoID,DiaSemana,HoraEntrada,HoraSalida,Activo) VALUES
            (@PersonaID,1,'09:00','19:00',1),(@PersonaID,2,'09:00','19:00',1),
            (@PersonaID,3,'09:00','19:00',1),(@PersonaID,4,'09:00','19:00',1),
            (@PersonaID,5,'09:00','19:00',1),(@PersonaID,6,'09:00','14:00',1);
        COMMIT;
        SELECT @PersonaID AS EmpleadoID, 'Empleado registrado correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        DECLARE @Error VARCHAR(500)=ERROR_MESSAGE();
        RAISERROR(@Error,16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE RRHH.SP_ActualizarEmpleado
    @EmpleadoID INT, @Nombre VARCHAR(100), @Apellido VARCHAR(100),
    @Telefono VARCHAR(20), @Email VARCHAR(100), @FechaNacimiento DATE=NULL,
    @Activo BIT, @NuevoSueldo DECIMAL(10,2)=NULL,
    @NuevoPct DECIMAL(5,2)=NULL, @RoleIDs VARCHAR(100)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Email=@Email AND PersonaID<>@EmpleadoID)
        BEGIN ROLLBACK; RAISERROR('Este correo ya esta en uso.',16,1); RETURN; END
        UPDATE Personas.Persona SET Nombre=@Nombre,Apellido=@Apellido,Telefono=@Telefono,
            Email=@Email,FechaNacimiento=@FechaNacimiento WHERE PersonaID=@EmpleadoID;
        UPDATE RRHH.Empleado SET Activo=@Activo WHERE EmpleadoID=@EmpleadoID;
        UPDATE Seguridad.Usuario SET Username=@Email,Activo=@Activo WHERE PersonaID=@EmpleadoID;
        IF @NuevoSueldo IS NOT NULL
        BEGIN
            UPDATE RRHH.EmpleadoSueldo SET FechaFin=GETDATE() WHERE EmpleadoID=@EmpleadoID AND FechaFin IS NULL;
            INSERT INTO RRHH.EmpleadoSueldo (EmpleadoID,SueldoBase,FechaInicio) VALUES (@EmpleadoID,@NuevoSueldo,GETDATE());
        END
        IF @NuevoPct IS NOT NULL
        BEGIN
            UPDATE RRHH.EmpleadoComision SET FechaFin=GETDATE() WHERE EmpleadoID=@EmpleadoID AND FechaFin IS NULL;
            INSERT INTO RRHH.EmpleadoComision (EmpleadoID,Porcentaje,FechaInicio) VALUES (@EmpleadoID,@NuevoPct,GETDATE());
        END
        IF @RoleIDs IS NOT NULL
        BEGIN
            DELETE FROM RRHH.EmpleadoRol WHERE EmpleadoID=@EmpleadoID;
            INSERT INTO RRHH.EmpleadoRol (EmpleadoID,RolID)
            SELECT @EmpleadoID,CAST(value AS INT) FROM STRING_SPLIT(@RoleIDs,',')
            WHERE LTRIM(RTRIM(value))<>'';
        END
        COMMIT;
        SELECT 'Empleado actualizado correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        DECLARE @Error VARCHAR(500)=ERROR_MESSAGE();
        RAISERROR(@Error,16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE RRHH.SP_ObtenerRolesEmpleado
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT r.RolID, r.NombreRol FROM RRHH.EmpleadoRol er
    JOIN RRHH.Rol r ON r.RolID=er.RolID WHERE er.EmpleadoID=@EmpleadoID ORDER BY r.RolID;
END;
GO

CREATE OR ALTER PROCEDURE RRHH.SP_ActualizarSueldo
    @EmpleadoID INT, @NuevoSueldo DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE RRHH.EmpleadoSueldo SET FechaFin=CAST(GETDATE() AS DATE) WHERE EmpleadoID=@EmpleadoID AND FechaFin IS NULL;
        INSERT INTO RRHH.EmpleadoSueldo (EmpleadoID,SueldoBase,FechaInicio) VALUES (@EmpleadoID,@NuevoSueldo,CAST(GETDATE() AS DATE));
        COMMIT;
        SELECT 'Sueldo actualizado correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al actualizar el sueldo.',16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE RRHH.SP_ActualizarComision
    @EmpleadoID INT, @NuevoPct DECIMAL(5,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE RRHH.EmpleadoComision SET FechaFin=CAST(GETDATE() AS DATE) WHERE EmpleadoID=@EmpleadoID AND FechaFin IS NULL;
        INSERT INTO RRHH.EmpleadoComision (EmpleadoID,Porcentaje,FechaInicio) VALUES (@EmpleadoID,@NuevoPct,CAST(GETDATE() AS DATE));
        COMMIT;
        SELECT 'Comision actualizada correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al actualizar la comision.',16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE RRHH.SP_NominaDelMes
    @Anio INT=NULL, @Mes INT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @AnioFiltro INT=ISNULL(@Anio,YEAR(GETDATE()));
    DECLARE @MesFiltro INT=ISNULL(@Mes,MONTH(GETDATE()));
    DECLARE @Periodo VARCHAR(7)=CAST(@AnioFiltro AS VARCHAR)+'-'+RIGHT('0'+CAST(@MesFiltro AS VARCHAR),2);
    SELECT e.EmpleadoID, p.Nombre, p.Apellido, r.NombreRol, r.RolID,
        ISNULL(es.SueldoBase,0) AS SueldoBase, ISNULL(ec.Porcentaje,0) AS PorcentajeComision,
        ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad),0) AS TotalVentas,
        ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad*ec.Porcentaje/100.0),0) AS TotalComision,
        ISNULL(es.SueldoBase,0)+ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad*ec.Porcentaje/100.0),0) AS TotalNomina,
        CASE WHEN pn.PagoNominaID IS NOT NULL THEN 1 ELSE 0 END AS YaPagado,
        pn.FechaPago, pn.Total AS MontoPagado, @Periodo AS Periodo
    FROM RRHH.Empleado e
    JOIN Personas.Persona p ON p.PersonaID=e.EmpleadoID
    JOIN RRHH.EmpleadoRol er ON er.EmpleadoID=e.EmpleadoID
    JOIN RRHH.Rol r ON r.RolID=er.RolID
    LEFT JOIN RRHH.EmpleadoSueldo es ON es.EmpleadoID=e.EmpleadoID AND es.FechaFin IS NULL
    LEFT JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID=e.EmpleadoID AND ec.FechaFin IS NULL
    LEFT JOIN Ventas.VentaDetalleServicio vds ON vds.EmpleadoID=e.EmpleadoID
        AND EXISTS (SELECT 1 FROM Ventas.Venta v WHERE v.VentaID=vds.VentaID
                    AND MONTH(v.Fecha)=@MesFiltro AND YEAR(v.Fecha)=@AnioFiltro)
    LEFT JOIN RRHH.PagoNomina pn ON pn.EmpleadoID=e.EmpleadoID AND pn.Periodo=@Periodo
    WHERE e.Activo=1 AND r.RolID IN (3,4,5,6)
    GROUP BY e.EmpleadoID,p.Nombre,p.Apellido,r.NombreRol,r.RolID,
        es.SueldoBase,ec.Porcentaje,pn.PagoNominaID,pn.FechaPago,pn.Total
    ORDER BY r.RolID, p.Nombre;
END;
GO

CREATE OR ALTER PROCEDURE RRHH.SP_RegistrarPagoNomina
    @EmpleadoID INT, @Periodo VARCHAR(7), @MontoPagado DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM RRHH.EmpleadoRol WHERE EmpleadoID=@EmpleadoID AND RolID IN (3,4,5,6,7))
        BEGIN ROLLBACK; RAISERROR('Solo puedes pagar al personal tecnico y de atencion.',16,1); RETURN; END
        IF EXISTS (SELECT 1 FROM RRHH.PagoNomina WHERE EmpleadoID=@EmpleadoID AND Periodo=@Periodo)
        BEGIN ROLLBACK; RAISERROR('Este periodo ya fue pagado.',16,1); RETURN; END
        DECLARE @SueldoBase DECIMAL(10,2);
        SELECT @SueldoBase=ISNULL(SueldoBase,0) FROM RRHH.EmpleadoSueldo WHERE EmpleadoID=@EmpleadoID AND FechaFin IS NULL;
        DECLARE @Comision DECIMAL(10,2);
        SELECT @Comision=ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad*ec.Porcentaje/100.0),0)
        FROM Ventas.VentaDetalleServicio vds
        JOIN Ventas.Venta v ON v.VentaID=vds.VentaID
        JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID=vds.EmpleadoID AND ec.FechaFin IS NULL
        WHERE vds.EmpleadoID=@EmpleadoID AND LEFT(CONVERT(VARCHAR,v.Fecha,120),7)=@Periodo;
        INSERT INTO RRHH.PagoNomina (EmpleadoID,Periodo,SueldoBase,Comision,FechaPago,Pagado)
        VALUES (@EmpleadoID,@Periodo,@SueldoBase,@Comision,GETDATE(),1);
        COMMIT;
        SELECT 'Pago registrado correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al registrar el pago.',16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE RRHH.SP_ObtenerHorarioEmpleado
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DiaSemana, HoraEntrada, HoraSalida, Activo FROM RRHH.HorarioEmpleado
    WHERE EmpleadoID=@EmpleadoID ORDER BY DiaSemana;
    SELECT ExcepcionID, CONVERT(NVARCHAR(10),Fecha,120) AS Fecha,
        Disponible, Motivo, ISNULL(Estado,'Pendiente') AS Estado, Aprobado
    FROM RRHH.HorarioExcepcion WHERE EmpleadoID=@EmpleadoID ORDER BY Fecha DESC;
END;
GO

CREATE OR ALTER PROCEDURE RRHH.SP_SolicitarExcepcion
    @EmpleadoID INT, @Fecha DATE, @Disponible BIT, @Motivo VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM RRHH.HorarioExcepcion WHERE EmpleadoID=@EmpleadoID AND Fecha=@Fecha)
    BEGIN RAISERROR('Ya existe una solicitud para esa fecha.',16,1); RETURN; END
    INSERT INTO RRHH.HorarioExcepcion (EmpleadoID,Fecha,Disponible,Motivo,Aprobado,Estado,TipoSolicitud)
    VALUES (@EmpleadoID,@Fecha,@Disponible,@Motivo,NULL,'Pendiente','empleado');
    SELECT SCOPE_IDENTITY() AS ExcepcionID, 'Solicitud enviada correctamente.' AS Mensaje;
END;
GO

CREATE OR ALTER PROCEDURE RRHH.SP_ListarExcepcionesPendientes
AS
BEGIN
    SET NOCOUNT ON;
    SELECT he.ExcepcionID, he.EmpleadoID, p.Nombre, p.Apellido,
        STRING_AGG(r.NombreRol,', ') WITHIN GROUP (ORDER BY r.RolID) AS NombreRol,
        CONVERT(NVARCHAR(10),he.Fecha,120) AS Fecha,
        he.Disponible, he.Motivo, he.Aprobado, he.Estado, he.TipoSolicitud
    FROM RRHH.HorarioExcepcion he
    JOIN Personas.Persona p ON p.PersonaID=he.EmpleadoID
    JOIN RRHH.EmpleadoRol er ON er.EmpleadoID=he.EmpleadoID
    JOIN RRHH.Rol r ON r.RolID=er.RolID
    WHERE he.Estado='Pendiente' OR he.Estado IS NULL
    GROUP BY he.ExcepcionID,he.EmpleadoID,p.Nombre,p.Apellido,
        he.Fecha,he.Disponible,he.Motivo,he.Aprobado,he.Estado,he.TipoSolicitud
    ORDER BY he.Fecha;
END;
GO

CREATE OR ALTER PROCEDURE RRHH.SP_AprobarExcepcion
    @ExcepcionID INT, @Aprobado BIT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @EmpleadoID INT, @Disponible BIT, @Fecha DATE;
    SELECT @EmpleadoID=EmpleadoID,@Disponible=Disponible,@Fecha=Fecha
    FROM RRHH.HorarioExcepcion WHERE ExcepcionID=@ExcepcionID;
    UPDATE RRHH.HorarioExcepcion
    SET Aprobado=@Aprobado, Estado=CASE WHEN @Aprobado=1 THEN 'Aprobada' ELSE 'Rechazada' END
    WHERE ExcepcionID=@ExcepcionID;
    IF @Aprobado=1 AND @Disponible=0
    BEGIN
        UPDATE Agenda.Cita SET EstadoID=12
        WHERE CitaID IN (
            SELECT DISTINCT c.CitaID FROM Agenda.CitaServicio cs
            JOIN Agenda.Cita c ON c.CitaID=cs.CitaID
            WHERE cs.EmpleadoID=@EmpleadoID AND CAST(cs.FechaInicioServicio AS DATE)=@Fecha
              AND c.EstadoID NOT IN (11,12,13)
        );
        INSERT INTO Notificaciones.Notificacion (PersonaID,TipoNotificacionID,Mensaje,Leido,Fecha)
        SELECT DISTINCT c.ClienteID, 7,
            'Tu cita del '+CONVERT(VARCHAR,@Fecha,103)+' fue cancelada por ausencia del personal. Por favor contactanos para reagendar.',
            0, GETDATE()
        FROM Agenda.CitaServicio cs JOIN Agenda.Cita c ON c.CitaID=cs.CitaID
        WHERE cs.EmpleadoID=@EmpleadoID AND CAST(cs.FechaInicioServicio AS DATE)=@Fecha AND c.EstadoID=12;
    END
    DECLARE @Msg VARCHAR(300);
    IF @Aprobado=1
        SET @Msg='Tu solicitud de '+CASE WHEN @Disponible=1 THEN 'turno extra' ELSE 'dia libre' END+
            ' para el '+CONVERT(VARCHAR,@Fecha,103)+' fue aprobada.';
    ELSE
        SET @Msg='Tu solicitud de '+CASE WHEN @Disponible=1 THEN 'turno extra' ELSE 'dia libre' END+
            ' para el '+CONVERT(VARCHAR,@Fecha,103)+' fue rechazada.';
    INSERT INTO Notificaciones.Notificacion (PersonaID,TipoNotificacionID,Mensaje,Leido,Fecha)
    VALUES (@EmpleadoID,4,@Msg,0,GETDATE());
    SELECT CASE WHEN @Aprobado=1 THEN 'Excepcion aprobada correctamente.' ELSE 'Excepcion rechazada correctamente.' END AS Mensaje;
END;
GO

CREATE OR ALTER PROCEDURE RRHH.SP_ObtenerPerfilEmpleado
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.PersonaID, p.Nombre, p.Apellido, p.Email, p.Telefono,
        e.FechaContratacion, r.NombreRol,
        es.SueldoBase, es.FechaInicio AS SueldoDesde,
        ec.Porcentaje AS PorcentajeComision, ec.FechaInicio AS ComisionDesde
    FROM Personas.Persona p
    JOIN RRHH.Empleado e ON e.EmpleadoID=p.PersonaID
    JOIN RRHH.EmpleadoRol er ON er.EmpleadoID=p.PersonaID
    JOIN RRHH.Rol r ON r.RolID=er.RolID
    JOIN RRHH.EmpleadoSueldo es ON es.EmpleadoID=p.PersonaID AND es.FechaFin IS NULL
    JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID=p.PersonaID AND ec.FechaFin IS NULL
    WHERE p.PersonaID=@EmpleadoID;
END;
GO

CREATE OR ALTER PROCEDURE RRHH.SP_ActualizarPerfilEmpleado
    @EmpleadoID INT, @Nombre VARCHAR(100), @Apellido VARCHAR(100),
    @Telefono VARCHAR(20), @Email VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Email=@Email AND PersonaID<>@EmpleadoID)
    BEGIN RAISERROR('Este correo ya esta en uso.',16,1); RETURN; END
    IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Telefono=@Telefono AND PersonaID<>@EmpleadoID)
    BEGIN RAISERROR('Este telefono ya esta en uso.',16,1); RETURN; END
    UPDATE Personas.Persona SET Nombre=@Nombre,Apellido=@Apellido,Telefono=@Telefono,Email=@Email WHERE PersonaID=@EmpleadoID;
    UPDATE Seguridad.Usuario SET Username=@Email WHERE PersonaID=@EmpleadoID;
    SELECT 'Perfil actualizado correctamente.' AS Mensaje;
END;
GO

CREATE OR ALTER PROCEDURE RRHH.SP_ObtenerSueldoComisiones
    @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT es.SueldoBase, es.FechaInicio AS SueldoDesde,
        ec.Porcentaje AS PorcentajeComision, ec.FechaInicio AS ComisionDesde
    FROM RRHH.EmpleadoSueldo es
    JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID=es.EmpleadoID AND ec.FechaFin IS NULL
    WHERE es.EmpleadoID=@EmpleadoID AND es.FechaFin IS NULL;

    SELECT ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad),0) AS VentasMes,
        ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad*ec.Porcentaje/100.0),0) AS ComisionMes,
        COUNT(DISTINCT vds.VentaDetalleServicioID) AS ServiciosMes
    FROM Ventas.VentaDetalleServicio vds
    JOIN Ventas.Venta v ON v.VentaID=vds.VentaID
    JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID=vds.EmpleadoID AND ec.FechaFin IS NULL
    WHERE vds.EmpleadoID=@EmpleadoID AND MONTH(v.Fecha)=MONTH(GETDATE()) AND YEAR(v.Fecha)=YEAR(GETDATE());

    SELECT TOP 4 YEAR(v.Fecha) AS Anio, MONTH(v.Fecha) AS Mes,
        ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad),0) AS Ventas,
        ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad*ec.Porcentaje/100.0),0) AS Comision,
        es.SueldoBase
    FROM Ventas.VentaDetalleServicio vds
    JOIN Ventas.Venta v ON v.VentaID=vds.VentaID
    JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID=vds.EmpleadoID AND ec.FechaFin IS NULL
    JOIN RRHH.EmpleadoSueldo es ON es.EmpleadoID=vds.EmpleadoID AND es.FechaFin IS NULL
    WHERE vds.EmpleadoID=@EmpleadoID
    GROUP BY YEAR(v.Fecha),MONTH(v.Fecha),es.SueldoBase ORDER BY Anio DESC, Mes DESC;
END;
GO

CREATE OR ALTER PROCEDURE RRHH.SP_SincronizarRolesSeguridad
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @EmpleadoID INT, @UsuarioID INT;
    DECLARE cur CURSOR FOR
        SELECT e.EmpleadoID, u.UsuarioID FROM RRHH.Empleado e
        JOIN Seguridad.Usuario u ON u.PersonaID=e.EmpleadoID WHERE e.Activo=1;
    OPEN cur;
    FETCH NEXT FROM cur INTO @EmpleadoID, @UsuarioID;
    WHILE @@FETCH_STATUS=0
    BEGIN
        DELETE FROM Seguridad.UsuarioRol WHERE UsuarioID=@UsuarioID AND RolID IN (4,5);
        IF EXISTS (SELECT 1 FROM RRHH.EmpleadoRol WHERE EmpleadoID=@EmpleadoID AND RolID IN (3,4,5,6))
            INSERT INTO Seguridad.UsuarioRol (UsuarioID,RolID) VALUES (@UsuarioID,5);
        IF EXISTS (SELECT 1 FROM RRHH.EmpleadoRol WHERE EmpleadoID=@EmpleadoID AND RolID=7)
            INSERT INTO Seguridad.UsuarioRol (UsuarioID,RolID) VALUES (@UsuarioID,4);
        FETCH NEXT FROM cur INTO @EmpleadoID, @UsuarioID;
    END
    CLOSE cur; DEALLOCATE cur;
    SELECT 'Roles sincronizados correctamente.' AS Mensaje;
END;
GO

-- ============================================================
-- INVENTARIO
-- ============================================================

CREATE OR ALTER PROCEDURE Inventario.SP_ObtenerInventario
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.ProductoID, p.Nombre, p.StockActual, p.StockMinimo, p.Activo,
        pv.Nombre AS Proveedor, ISNULL(pp.Precio,0) AS Precio,
        CASE WHEN p.StockActual<=0 THEN 'Sin stock'
             WHEN p.StockActual<=p.StockMinimo THEN 'Stock bajo'
             ELSE 'Normal' END AS EstadoStock
    FROM Inventario.Producto p
    LEFT JOIN Inventario.ProductoPrecio pp ON pp.ProductoID=p.ProductoID AND pp.FechaFin IS NULL
    LEFT JOIN Inventario.ProductoProveedor ppv ON ppv.ProductoID=p.ProductoID
    LEFT JOIN Inventario.Proveedor pv ON pv.ProveedorID=ppv.ProveedorID
    WHERE p.Activo=1
    ORDER BY CASE WHEN p.StockActual<=p.StockMinimo THEN 0 ELSE 1 END, p.Nombre;
END;
GO

CREATE OR ALTER PROCEDURE Inventario.SP_AjustarStock
    @ProductoID INT, @Cantidad INT, @Tipo VARCHAR(20), @Motivo VARCHAR(200)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @EsEntrada BIT=CASE WHEN @Tipo IN ('entrada','ajuste') THEN 1 ELSE 0 END;
        IF @Tipo='entrada'
            UPDATE Inventario.Producto SET StockActual=StockActual+@Cantidad WHERE ProductoID=@ProductoID;
        ELSE IF @Tipo='ajuste'
            UPDATE Inventario.Producto SET StockActual=@Cantidad WHERE ProductoID=@ProductoID;
        ELSE IF @Tipo='salida'
        BEGIN
            IF (SELECT StockActual FROM Inventario.Producto WHERE ProductoID=@ProductoID)<@Cantidad
            BEGIN ROLLBACK; RAISERROR('Stock insuficiente.',16,1); RETURN; END
            UPDATE Inventario.Producto SET StockActual=StockActual-@Cantidad WHERE ProductoID=@ProductoID;
        END
        INSERT INTO Inventario.MovimientoInventario (ProductoID,EsEntrada,Cantidad,Fecha)
        VALUES (@ProductoID,@EsEntrada,@Cantidad,GETDATE());
        COMMIT;
        SELECT 'Stock actualizado correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al ajustar el stock.',16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Inventario.SP_ListarProveedores
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ProveedorID, Nombre, Telefono, Email, Activo FROM Inventario.Proveedor ORDER BY Nombre;
END;
GO

CREATE OR ALTER PROCEDURE Inventario.SP_CrearProveedor
    @Nombre VARCHAR(100), @Telefono VARCHAR(20)=NULL, @Email VARCHAR(100)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Inventario.Proveedor (Nombre,Telefono,Email) VALUES (@Nombre,@Telefono,@Email);
    SELECT SCOPE_IDENTITY() AS ProveedorID, 'Proveedor creado.' AS Mensaje;
END;
GO

CREATE OR ALTER PROCEDURE Inventario.SP_EditarProveedor
    @ProveedorID INT, @Nombre VARCHAR(100), @Telefono VARCHAR(20)=NULL, @Email VARCHAR(100)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Inventario.Proveedor SET Nombre=@Nombre,Telefono=@Telefono,Email=@Email WHERE ProveedorID=@ProveedorID;
    SELECT 'Proveedor actualizado.' AS Mensaje;
END;
GO

CREATE OR ALTER PROCEDURE Inventario.SP_CrearProducto
    @Nombre VARCHAR(100), @StockActual INT=0, @StockMinimo INT=5,
    @UnidadMedida VARCHAR(20)=NULL, @Precio DECIMAL(10,2), @ProveedorID INT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @ProductoID INT;
        INSERT INTO Inventario.Producto (Nombre,StockActual,StockMinimo,UnidadMedida,Activo)
        VALUES (@Nombre,@StockActual,@StockMinimo,@UnidadMedida,1);
        SET @ProductoID=SCOPE_IDENTITY();
        INSERT INTO Inventario.ProductoPrecio (ProductoID,Precio,FechaInicio) VALUES (@ProductoID,@Precio,GETDATE());
        IF @ProveedorID IS NOT NULL
            INSERT INTO Inventario.ProductoProveedor (ProductoID,ProveedorID) VALUES (@ProductoID,@ProveedorID);
        IF @StockActual>0
            INSERT INTO Inventario.MovimientoInventario (ProductoID,EsEntrada,Cantidad,Fecha)
            VALUES (@ProductoID,1,@StockActual,GETDATE());
        COMMIT;
        SELECT @ProductoID AS ProductoID, 'Producto creado.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al crear el producto.',16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Inventario.SP_EditarProducto
    @ProductoID INT, @Nombre VARCHAR(100), @StockMinimo INT,
    @UnidadMedida VARCHAR(20)=NULL, @NuevoPrecio DECIMAL(10,2)=NULL, @ProveedorID INT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE Inventario.Producto SET Nombre=@Nombre,StockMinimo=@StockMinimo,UnidadMedida=@UnidadMedida WHERE ProductoID=@ProductoID;
        DELETE FROM Inventario.ProductoProveedor WHERE ProductoID=@ProductoID;
        IF @ProveedorID IS NOT NULL
            INSERT INTO Inventario.ProductoProveedor (ProductoID,ProveedorID) VALUES (@ProductoID,@ProveedorID);
        IF @NuevoPrecio IS NOT NULL
        BEGIN
            UPDATE Inventario.ProductoPrecio SET FechaFin=GETDATE() WHERE ProductoID=@ProductoID AND FechaFin IS NULL;
            INSERT INTO Inventario.ProductoPrecio (ProductoID,Precio,FechaInicio) VALUES (@ProductoID,@NuevoPrecio,GETDATE());
        END
        COMMIT;
        SELECT 'Producto actualizado.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al editar el producto.',16,1);
    END CATCH
END;
GO

-- ============================================================
-- SERVICIOS
-- ============================================================

CREATE OR ALTER PROCEDURE Servicios.SP_ListarServicios
AS
BEGIN
    SET NOCOUNT ON;
    SELECT s.ServicioID, s.Nombre, s.Descripcion, s.DuracionMin, s.Activo,
        cat.Nombre AS Categoria, sc.Nombre AS Subcategoria,
        ISNULL(sp.Precio,0) AS Precio, sp.FechaInicio AS PrecioDesde
    FROM Servicios.Servicio s
    JOIN Servicios.SubcategoriaServicio sc ON sc.SubcategoriaID=s.SubcategoriaID
    JOIN Servicios.CategoriaServicio cat ON cat.CategoriaID=sc.CategoriaID
    LEFT JOIN Servicios.ServicioPrecio sp ON sp.ServicioID=s.ServicioID AND sp.FechaFin IS NULL
    ORDER BY cat.Nombre, sc.Nombre, s.Nombre;
END;
GO

CREATE OR ALTER PROCEDURE Servicios.SP_ActualizarPrecio
    @ServicioID INT, @NuevoPrecio DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE Servicios.ServicioPrecio SET FechaFin=CAST(GETDATE() AS DATE) WHERE ServicioID=@ServicioID AND FechaFin IS NULL;
        INSERT INTO Servicios.ServicioPrecio (ServicioID,Precio,FechaInicio) VALUES (@ServicioID,@NuevoPrecio,CAST(GETDATE() AS DATE));
        COMMIT;
        SELECT 'Precio actualizado correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al actualizar el precio.',16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Servicios.SP_ObtenerCatalogo
    @CategoriaID INT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT s.ServicioID, s.Nombre, s.Descripcion, s.DuracionMin,
        c.CategoriaID, c.Nombre AS Categoria,
        sc.SubcategoriaID, sc.Nombre AS Subcategoria, sp.Precio
    FROM Servicios.Servicio s
    JOIN Servicios.SubcategoriaServicio sc ON sc.SubcategoriaID=s.SubcategoriaID
    JOIN Servicios.CategoriaServicio c ON c.CategoriaID=sc.CategoriaID
    JOIN Servicios.ServicioPrecio sp ON sp.ServicioID=s.ServicioID
    WHERE s.Activo=1 AND sp.FechaFin IS NULL
      AND (@CategoriaID IS NULL OR c.CategoriaID=@CategoriaID)
    ORDER BY c.Nombre, sc.Nombre, s.Nombre;
END;
GO

CREATE OR ALTER PROCEDURE Servicios.SP_CrearServicio
    @Nombre VARCHAR(100), @Descripcion VARCHAR(300)=NULL,
    @DuracionMin INT, @SubcategoriaID INT, @Precio DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @ServicioID INT;
        INSERT INTO Servicios.Servicio (Nombre,Descripcion,DuracionMin,SubcategoriaID,Activo)
        VALUES (@Nombre,@Descripcion,@DuracionMin,@SubcategoriaID,1);
        SET @ServicioID=SCOPE_IDENTITY();
        INSERT INTO Servicios.ServicioPrecio (ServicioID,Precio,FechaInicio) VALUES (@ServicioID,@Precio,GETDATE());
        COMMIT;
        SELECT @ServicioID AS ServicioID, 'Servicio creado.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al crear el servicio.',16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Servicios.SP_EditarServicio
    @ServicioID INT, @Nombre VARCHAR(100), @Descripcion VARCHAR(300)=NULL,
    @DuracionMin INT, @Activo BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Servicios.Servicio SET Nombre=@Nombre,Descripcion=@Descripcion,
        DuracionMin=@DuracionMin,Activo=@Activo WHERE ServicioID=@ServicioID;
    SELECT 'Servicio actualizado.' AS Mensaje;
END;
GO

CREATE OR ALTER PROCEDURE Servicios.SP_ListarSubcategorias
AS
BEGIN
    SET NOCOUNT ON;
    SELECT sc.SubcategoriaID, sc.Nombre, cat.Nombre AS Categoria, cat.CategoriaID
    FROM Servicios.SubcategoriaServicio sc
    JOIN Servicios.CategoriaServicio cat ON cat.CategoriaID=sc.CategoriaID
    ORDER BY cat.Nombre, sc.Nombre;
END;
GO

-- ============================================================
-- MARKETING
-- ============================================================

CREATE OR ALTER PROCEDURE Marketing.SP_ListarPromociones
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.PromocionID, p.Nombre, p.Descripcion, p.Descuento,
        p.FechaInicio, p.FechaFin, p.Activo,
        CASE WHEN GETDATE() BETWEEN p.FechaInicio AND p.FechaFin THEN 'Activa'
             WHEN GETDATE()<p.FechaInicio THEN 'Proxima' ELSE 'Vencida' END AS Estado,
        COUNT(ps.ServicioID) AS TotalServicios
    FROM Marketing.Promocion p
    LEFT JOIN Marketing.PromocionServicio ps ON ps.PromocionID=p.PromocionID
    GROUP BY p.PromocionID,p.Nombre,p.Descripcion,p.Descuento,p.FechaInicio,p.FechaFin,p.Activo
    ORDER BY p.FechaInicio DESC;
END;
GO

CREATE OR ALTER PROCEDURE Marketing.SP_CrearPromocion
    @Nombre VARCHAR(100), @Descripcion VARCHAR(300), @Descuento DECIMAL(5,2),
    @FechaInicio DATE, @FechaFin DATE, @ServicioIDs VARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @PromocionID INT;
        INSERT INTO Marketing.Promocion (Nombre,Descripcion,Descuento,FechaInicio,FechaFin,Activo)
        VALUES (@Nombre,@Descripcion,@Descuento,@FechaInicio,@FechaFin,1);
        SET @PromocionID=SCOPE_IDENTITY();
        IF @ServicioIDs IS NOT NULL
            INSERT INTO Marketing.PromocionServicio (PromocionID,ServicioID)
            SELECT @PromocionID,CAST(value AS INT) FROM STRING_SPLIT(@ServicioIDs,',')
            WHERE LTRIM(RTRIM(value))<>'';
        COMMIT;
        SELECT @PromocionID AS PromocionID, 'Promocion creada correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al crear la promocion.',16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Marketing.SP_EditarPromocion
    @PromocionID INT, @Nombre VARCHAR(100), @Descripcion VARCHAR(300)=NULL,
    @Descuento DECIMAL(5,2), @FechaInicio DATE, @FechaFin DATE,
    @Activo BIT=1, @ServicioIDs VARCHAR(500)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE Marketing.Promocion SET Nombre=@Nombre,Descripcion=@Descripcion,Descuento=@Descuento,
            FechaInicio=@FechaInicio,FechaFin=@FechaFin,Activo=@Activo WHERE PromocionID=@PromocionID;
        IF @ServicioIDs IS NOT NULL
        BEGIN
            DELETE FROM Marketing.PromocionServicio WHERE PromocionID=@PromocionID;
            INSERT INTO Marketing.PromocionServicio (PromocionID,ServicioID)
            SELECT @PromocionID,CAST(value AS INT) FROM STRING_SPLIT(@ServicioIDs,',')
            WHERE LTRIM(RTRIM(value))<>'';
        END
        COMMIT;
        SELECT 'Promocion actualizada.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al actualizar promocion.',16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Marketing.SP_ObtenerPromocionesActivas
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.PromocionID, p.Nombre, p.Descuento, p.Descripcion,
        p.FechaInicio, p.FechaFin, ISNULL(p.TipoPromocion,'general') AS TipoPromocion,
        COUNT(ps.ServicioID) AS TotalServicios
    FROM Marketing.Promocion p
    LEFT JOIN Marketing.PromocionServicio ps ON ps.PromocionID=p.PromocionID
    WHERE p.Activo=1 AND GETDATE() BETWEEN p.FechaInicio AND p.FechaFin
      AND ISNULL(p.TipoPromocion,'general')<>'cumpleanos'
    GROUP BY p.PromocionID,p.Nombre,p.Descuento,p.Descripcion,p.FechaInicio,p.FechaFin,p.TipoPromocion
    ORDER BY p.Nombre;

    SELECT ps.PromocionID, ps.ServicioID, s.Nombre AS NombreServicio
    FROM Marketing.PromocionServicio ps
    JOIN Marketing.Promocion p ON p.PromocionID=ps.PromocionID
    JOIN Servicios.Servicio s ON s.ServicioID=ps.ServicioID
    WHERE p.Activo=1 AND GETDATE() BETWEEN p.FechaInicio AND p.FechaFin
      AND ISNULL(p.TipoPromocion,'general')<>'cumpleanos';

    SELECT p.PromocionID, p.Nombre, p.Descuento, p.Descripcion,
        p.FechaInicio, p.FechaFin, 'cumpleanos' AS TipoPromocion,
        COUNT(ps.ServicioID) AS TotalServicios
    FROM Marketing.Promocion p
    LEFT JOIN Marketing.PromocionServicio ps ON ps.PromocionID=p.PromocionID
    WHERE p.Activo=1 AND p.TipoPromocion='cumpleanos'
    GROUP BY p.PromocionID,p.Nombre,p.Descuento,p.Descripcion,p.FechaInicio,p.FechaFin,p.TipoPromocion;
END;
GO

-- ============================================================
-- AGENDA
-- ============================================================

CREATE OR ALTER PROCEDURE Agenda.SP_PanelRecepcion
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(*) AS TotalCitas,
        SUM(CASE WHEN c.EstadoID=8 THEN 1 ELSE 0 END) AS Programadas,
        SUM(CASE WHEN c.EstadoID=9 THEN 1 ELSE 0 END) AS Confirmadas,
        SUM(CASE WHEN c.EstadoID=10 THEN 1 ELSE 0 END) AS EnCurso,
        SUM(CASE WHEN c.EstadoID=11 THEN 1 ELSE 0 END) AS Completadas
    FROM Agenda.Cita c
    WHERE CAST(c.FechaInicio AS DATE)=CAST(GETDATE() AS DATE) AND c.EstadoID NOT IN (12,13);

    SELECT TOP 1 c.CitaID, c.FechaInicio,
        p.Nombre AS NombreCliente, p.Apellido AS ApellidoCliente,
        s.Nombre AS Servicio, emp.Nombre AS NombreEmpleado, emp.Apellido AS ApellidoEmpleado,
        ec.Nombre AS Estado
    FROM Agenda.Cita c
    JOIN Personas.Persona p ON p.PersonaID=c.ClienteID
    JOIN Agenda.CitaServicio cs ON cs.CitaID=c.CitaID
    JOIN Servicios.Servicio s ON s.ServicioID=cs.ServicioID
    LEFT JOIN Personas.Persona emp ON emp.PersonaID=cs.EmpleadoID
    JOIN Agenda.EstadoCita ec ON ec.EstadoID=c.EstadoID
    WHERE CAST(c.FechaInicio AS DATE)=CAST(GETDATE() AS DATE) AND c.EstadoID IN (8,9)
    ORDER BY c.FechaInicio ASC;

    SELECT COUNT(*) AS TotalVentas, ISNULL(SUM(pg.Monto),0) AS TotalMonto
    FROM Ventas.Venta v JOIN Ventas.Pago pg ON pg.VentaID=v.VentaID
    WHERE CAST(v.Fecha AS DATE)=CAST(GETDATE() AS DATE);

    SELECT COUNT(*) AS TotalClientes,
        SUM(CASE WHEN CAST(p.FechaRegistro AS DATE)>=DATEADD(DAY,-7,GETDATE()) THEN 1 ELSE 0 END) AS NuevosEstaSemana
    FROM Ventas.Cliente c JOIN Personas.Persona p ON p.PersonaID=c.ClienteID;

    SELECT c.CitaID, c.FechaInicio, cs.FechaInicioServicio, cs.FechaFinServicio,
        cs.EsParalelo, cs.Orden,
        p.Nombre AS NombreCliente, p.Apellido AS ApellidoCliente,
        s.Nombre AS Servicio, emp.Nombre AS NombreEmpleado, emp.Apellido AS ApellidoEmpleado,
        ec.EstadoID, ec.Nombre AS Estado, sp.Precio
    FROM Agenda.Cita c
    JOIN Personas.Persona p ON p.PersonaID=c.ClienteID
    JOIN Agenda.CitaServicio cs ON cs.CitaID=c.CitaID
    JOIN Servicios.Servicio s ON s.ServicioID=cs.ServicioID
    LEFT JOIN Personas.Persona emp ON emp.PersonaID=cs.EmpleadoID
    JOIN Agenda.EstadoCita ec ON ec.EstadoID=c.EstadoID
    JOIN Servicios.ServicioPrecio sp ON sp.ServicioID=s.ServicioID AND sp.FechaFin IS NULL
    WHERE CAST(c.FechaInicio AS DATE)=CAST(GETDATE() AS DATE) AND c.EstadoID NOT IN (12,13)
    ORDER BY c.FechaInicio ASC, cs.Orden ASC;

    SELECT e.EmpleadoID, p.Nombre, p.Apellido,
        STRING_AGG(r.NombreRol,' / ') AS NombreRol,
        COUNT(DISTINCT cs.CitaServicioID) AS CitasHoy,
        CASE WHEN EXISTS (
            SELECT 1 FROM Agenda.CitaServicio cs2 JOIN Agenda.Cita c2 ON c2.CitaID=cs2.CitaID
            WHERE cs2.EmpleadoID=e.EmpleadoID AND c2.EstadoID IN (9,10)
              AND cs2.FechaInicioServicio<=GETDATE() AND cs2.FechaFinServicio>=GETDATE()
        ) THEN 'Ocupada' ELSE 'Libre' END AS EstadoActual
    FROM RRHH.Empleado e
    JOIN Personas.Persona p ON p.PersonaID=e.EmpleadoID
    JOIN RRHH.EmpleadoRol er ON er.EmpleadoID=e.EmpleadoID
    JOIN RRHH.Rol r ON r.RolID=er.RolID
    LEFT JOIN Agenda.CitaServicio cs ON cs.EmpleadoID=e.EmpleadoID
        AND CAST(cs.FechaInicioServicio AS DATE)=CAST(GETDATE() AS DATE)
    WHERE e.Activo=1 AND r.RolID IN (3,4,5,6)
    GROUP BY e.EmpleadoID, p.Nombre, p.Apellido ORDER BY p.Nombre;
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_GestionCitas
    @Fecha DATE=NULL, @EmpleadoID INT=NULL, @EstadoID INT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.CitaID, c.FechaInicio, cs.FechaInicioServicio, cs.FechaFinServicio,
        cs.EsParalelo, cs.Orden,
        p.Nombre AS NombreCliente, p.Apellido AS ApellidoCliente, fc.Alergias,
        s.Nombre AS Servicio, s.DuracionMin, sp.Precio,
        emp.Nombre AS NombreEmpleado, emp.Apellido AS ApellidoEmpleado,
        ec.EstadoID, ec.Nombre AS Estado
    FROM Agenda.Cita c
    JOIN Personas.Persona p ON p.PersonaID=c.ClienteID
    JOIN Agenda.CitaServicio cs ON cs.CitaID=c.CitaID
    JOIN Servicios.Servicio s ON s.ServicioID=cs.ServicioID
    LEFT JOIN Personas.Persona emp ON emp.PersonaID=cs.EmpleadoID
    JOIN Agenda.EstadoCita ec ON ec.EstadoID=c.EstadoID
    JOIN Servicios.ServicioPrecio sp ON sp.ServicioID=s.ServicioID AND sp.FechaFin IS NULL
    LEFT JOIN Ventas.ClienteDetalle fc ON fc.ClienteID=c.ClienteID
    WHERE (@Fecha IS NULL OR CAST(c.FechaInicio AS DATE)=@Fecha)
      AND (@EmpleadoID IS NULL OR cs.EmpleadoID=@EmpleadoID)
      AND (@EstadoID IS NULL OR c.EstadoID=@EstadoID)
      AND c.EstadoID NOT IN (12,13)
    ORDER BY c.FechaInicio ASC, cs.Orden ASC;
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_ConfirmarCita @CitaID INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Agenda.Cita SET EstadoID=9 WHERE CitaID=@CitaID;
    SELECT 'Cita confirmada.' AS Mensaje;
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_CancelarCitaRecepcion @CitaID INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Agenda.Cita SET EstadoID=12 WHERE CitaID=@CitaID;
    SELECT 'Cita cancelada.' AS Mensaje;
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_CrearCitaRecepcion
    @ClienteID INT, @FechaInicio NVARCHAR(30), @Servicios VARCHAR(MAX),
    @EstadoID INT=8, @Notas VARCHAR(200)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @FechaInicioD DATETIME=CONVERT(DATETIME,REPLACE(@FechaInicio,'T',' '),120);
        DECLARE @CitaID INT;
        INSERT INTO Agenda.Cita (ClienteID,FechaInicio,EstadoID) VALUES (@ClienteID,@FechaInicioD,@EstadoID);
        SET @CitaID=SCOPE_IDENTITY();
        DECLARE @List VARCHAR(MAX)=@Servicios+',';
        DECLARE @Pos INT=1,@Next INT,@Item VARCHAR(100);
        DECLARE @SrvID INT,@EmpID INT,@Paralelo BIT,@Dur INT;
        DECLARE @FecAct DATETIME=@FechaInicioD,@FecIniAnt DATETIME=@FechaInicioD,@FecFin DATETIME;
        DECLARE @Orden INT=1,@EsPrimero BIT=1;
        WHILE CHARINDEX(',',@List,@Pos)>0
        BEGIN
            SET @Next=CHARINDEX(',',@List,@Pos);
            SET @Item=SUBSTRING(@List,@Pos,@Next-@Pos);
            DECLARE @P1 INT=CHARINDEX(':',@Item);
            DECLARE @P2 INT=CHARINDEX(':',@Item,@P1+1);
            SET @SrvID=CAST(SUBSTRING(@Item,1,@P1-1) AS INT);
            SET @EmpID=CAST(SUBSTRING(@Item,@P1+1,@P2-@P1-1) AS INT);
            SET @Paralelo=CAST(SUBSTRING(@Item,@P2+1,LEN(@Item)) AS BIT);
            SELECT @Dur=DuracionMin FROM Servicios.Servicio WHERE ServicioID=@SrvID;
            IF @Paralelo=1 AND @EsPrimero=0 SET @FecAct=@FecIniAnt;
            SET @FecFin=DATEADD(MINUTE,@Dur,@FecAct);
            INSERT INTO Agenda.CitaServicio (CitaID,ServicioID,EmpleadoID,Orden,EsParalelo,FechaInicioServicio,FechaFinServicio)
            VALUES (@CitaID,@SrvID,@EmpID,@Orden,@Paralelo,@FecAct,@FecFin);
            IF NOT EXISTS (SELECT 1 FROM Agenda.CitaEmpleado WHERE CitaID=@CitaID AND EmpleadoID=@EmpID)
                INSERT INTO Agenda.CitaEmpleado (CitaID,EmpleadoID,TipoAsignacion) VALUES (@CitaID,@EmpID,'manual');
            SET @FecIniAnt=@FecAct;
            IF @Paralelo=0 SET @FecAct=DATEADD(MINUTE,@Dur+5,@FecAct);
            SET @Orden=@Orden+1; SET @EsPrimero=0; SET @Pos=@Next+1;
        END
        COMMIT;
        SELECT @CitaID AS CitaID, 'Cita creada correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        DECLARE @Error VARCHAR(500)=ERROR_MESSAGE();
        RAISERROR(@Error,16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_EditarCitaRecepcion
    @CitaID INT, @EstadoID INT=NULL, @NuevaFecha NVARCHAR(30)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF @EstadoID IS NOT NULL UPDATE Agenda.Cita SET EstadoID=@EstadoID WHERE CitaID=@CitaID;
        IF @NuevaFecha IS NOT NULL
        BEGIN
            DECLARE @NuevaFechaD DATETIME=CONVERT(DATETIME,REPLACE(@NuevaFecha,'T',' '),120);
            UPDATE Agenda.Cita SET FechaInicio=@NuevaFechaD WHERE CitaID=@CitaID;
        END
        COMMIT;
        SELECT 'Cita actualizada.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        DECLARE @Error VARCHAR(500)=ERROR_MESSAGE();
        RAISERROR(@Error,16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_ObtenerSolicitudes
    @Estado VARCHAR(20)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT s.SolicitudID, s.ClienteID, p.Nombre AS NombreCliente, p.Apellido AS ApellidoCliente,
        p.Telefono, CONVERT(NVARCHAR(19),s.FechaSolicitada,120) AS FechaSolicitada,
        s.TipoSolicitud, s.ServicioIDs,
        (SELECT STRING_AGG(sv.Nombre,', ') FROM STRING_SPLIT(ISNULL(s.ServicioIDs,''),',') sp
         JOIN Servicios.Servicio sv ON sv.ServicioID=TRY_CAST(sp.value AS INT)) AS NombresServicios,
        s.Motivo, s.Estado, s.MotivoRechazo, s.CitaID, s.FechaCreacion
    FROM Agenda.SolicitudEspecial s JOIN Personas.Persona p ON p.PersonaID=s.ClienteID
    WHERE (@Estado IS NULL OR s.Estado=@Estado) ORDER BY s.FechaCreacion DESC;
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_AprobarSolicitud
    @SolicitudID INT, @FechaConfirmada NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @ClienteID INT, @ServicioIDs VARCHAR(500);
        SELECT @ClienteID=ClienteID, @ServicioIDs=ServicioIDs FROM Agenda.SolicitudEspecial WHERE SolicitudID=@SolicitudID;
        DECLARE @FechaD DATETIME=CONVERT(DATETIME,REPLACE(@FechaConfirmada,'T',' '),120);
        DECLARE @CitaID INT;
        INSERT INTO Agenda.Cita (ClienteID,FechaInicio,EstadoID) VALUES (@ClienteID,@FechaD,9);
        SET @CitaID=SCOPE_IDENTITY();
        IF @ServicioIDs IS NOT NULL
        BEGIN
            DECLARE @SrvList VARCHAR(500)=@ServicioIDs+',';
            DECLARE @Pos INT=1,@Next INT,@SrvID INT,@Orden INT=1,@Dur INT,@FIni DATETIME=@FechaD,@FFin DATETIME;
            WHILE CHARINDEX(',',@SrvList,@Pos)>0
            BEGIN
                SET @Next=CHARINDEX(',',@SrvList,@Pos);
                SET @SrvID=CAST(SUBSTRING(@SrvList,@Pos,@Next-@Pos) AS INT);
                SELECT @Dur=DuracionMin FROM Servicios.Servicio WHERE ServicioID=@SrvID;
                SET @FFin=DATEADD(MINUTE,@Dur,@FIni);
                INSERT INTO Agenda.CitaServicio (CitaID,ServicioID,EmpleadoID,Orden,EsParalelo,FechaInicioServicio,FechaFinServicio)
                VALUES (@CitaID,@SrvID,NULL,@Orden,0,@FIni,@FFin);
                SET @FIni=DATEADD(MINUTE,5,@FFin); SET @Orden=@Orden+1; SET @Pos=@Next+1;
            END
        END
        UPDATE Agenda.SolicitudEspecial SET Estado='Aprobada', CitaID=@CitaID WHERE SolicitudID=@SolicitudID;
        INSERT INTO Notificaciones.Notificacion (PersonaID,TipoNotificacionID,Mensaje,Leido,Fecha)
        VALUES (@ClienteID,8,'Tu solicitud de horario especial fue aprobada. Tu cita esta confirmada para el '+
            CONVERT(VARCHAR,@FechaD,103)+' a las '+CONVERT(VARCHAR(5),@FechaD,108)+'.',0,GETDATE());
        COMMIT;
        SELECT @CitaID AS CitaID, 'Solicitud aprobada' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        DECLARE @Err VARCHAR(500)=ERROR_MESSAGE();
        RAISERROR(@Err,16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_RechazarSolicitud
    @SolicitudID INT, @MotivoRechazo VARCHAR(300)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ClienteID INT;
    SELECT @ClienteID=ClienteID FROM Agenda.SolicitudEspecial WHERE SolicitudID=@SolicitudID;
    UPDATE Agenda.SolicitudEspecial SET Estado='Rechazada', MotivoRechazo=@MotivoRechazo WHERE SolicitudID=@SolicitudID;
    INSERT INTO Notificaciones.Notificacion (PersonaID,TipoNotificacionID,Mensaje,Leido,Fecha)
    VALUES (@ClienteID,9,'Tu solicitud de horario especial fue rechazada.'+ISNULL(' Motivo: '+@MotivoRechazo,''),0,GETDATE());
    SELECT 'Solicitud rechazada' AS Mensaje;
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_ObtenerCitasCliente
    @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.CitaID, c.FechaInicio, cs.CitaServicioID, cs.ServicioID,
        s.Nombre AS Servicio, s.DuracionMin, cs.FechaInicioServicio, cs.FechaFinServicio,
        cs.EsParalelo, cs.Orden, p.Nombre AS Empleado, p.Apellido AS EmpleadoApellido,
        ec.EstadoID, ec.Nombre AS Estado, sp.Precio
    FROM Agenda.Cita c
    JOIN Agenda.CitaServicio cs ON cs.CitaID=c.CitaID
    JOIN Servicios.Servicio s ON s.ServicioID=cs.ServicioID
    LEFT JOIN Personas.Persona p ON p.PersonaID=cs.EmpleadoID
    JOIN Agenda.EstadoCita ec ON ec.EstadoID=c.EstadoID
    JOIN Servicios.ServicioPrecio sp ON sp.ServicioID=s.ServicioID AND sp.FechaFin IS NULL
    WHERE c.ClienteID=@ClienteID AND c.FechaInicio>=GETDATE() AND c.EstadoID NOT IN (12,13)
    ORDER BY c.FechaInicio ASC, cs.Orden ASC;

    SELECT c.CitaID, c.FechaInicio, cs.ServicioID, s.Nombre AS Servicio,
        s.DuracionMin, cs.FechaInicioServicio, cs.FechaFinServicio,
        cs.EsParalelo, cs.Orden, p.Nombre AS Empleado, p.Apellido AS EmpleadoApellido,
        ec.EstadoID, ec.Nombre AS Estado, sp.Precio
    FROM Agenda.Cita c
    JOIN Agenda.CitaServicio cs ON cs.CitaID=c.CitaID
    JOIN Servicios.Servicio s ON s.ServicioID=cs.ServicioID
    LEFT JOIN Personas.Persona p ON p.PersonaID=cs.EmpleadoID
    JOIN Agenda.EstadoCita ec ON ec.EstadoID=c.EstadoID
    JOIN Servicios.ServicioPrecio sp ON sp.ServicioID=s.ServicioID AND sp.FechaFin IS NULL
    WHERE c.ClienteID=@ClienteID AND (c.FechaInicio<GETDATE() OR c.EstadoID IN (11,12,13))
    ORDER BY c.FechaInicio DESC, cs.Orden ASC;
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_EstadisticasCliente @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 c.CitaID, c.FechaInicio, cs.ServicioID,
        s.Nombre AS Servicio, p.Nombre AS Estilista, ec.Nombre AS Estado
    FROM Agenda.Cita c
    JOIN Agenda.CitaServicio cs ON cs.CitaID=c.CitaID
    JOIN Servicios.Servicio s ON s.ServicioID=cs.ServicioID
    JOIN Agenda.CitaEmpleado ce ON ce.CitaID=c.CitaID
    JOIN Personas.Persona p ON p.PersonaID=ce.EmpleadoID
    JOIN Agenda.EstadoCita ec ON ec.EstadoID=c.EstadoID
    WHERE c.ClienteID=@ClienteID AND c.FechaInicio>=GETDATE() AND c.EstadoID IN (8,9)
    ORDER BY c.FechaInicio ASC;

    SELECT COUNT(DISTINCT v.VentaID) AS VisitasAnio
    FROM Ventas.Venta v JOIN Ventas.VentaDetalleServicio vds ON vds.VentaID=v.VentaID
    WHERE v.ClienteID=@ClienteID AND YEAR(v.Fecha)=YEAR(GETDATE());

    SELECT ISNULL(SUM(pg.Monto),0) AS TotalGastado
    FROM Ventas.Venta v JOIN Ventas.Pago pg ON pg.VentaID=v.VentaID WHERE v.ClienteID=@ClienteID;

    SELECT (SELECT COUNT(*) FROM Marketing.Promocion WHERE Activo=1
            AND ISNULL(TipoPromocion,'general')<>'cumpleanos'
            AND FechaInicio<=CAST(GETDATE() AS DATE) AND FechaFin>=CAST(GETDATE() AS DATE))
           +(SELECT COUNT(*) FROM Personas.Persona WHERE PersonaID=@ClienteID AND FechaNacimiento IS NOT NULL
             AND MONTH(FechaNacimiento)=MONTH(GETDATE()) AND DAY(FechaNacimiento)=DAY(GETDATE()))
           AS PromocionesActivas;
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_ObtenerEmpleadosDisponibles
    @ServicioID INT, @FechaInicio NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @FechaInicioD DATETIME=CONVERT(DATETIME,REPLACE(@FechaInicio,'T',' '),120);
    DECLARE @DuracionMin INT, @SubcategoriaID INT;
    SELECT @DuracionMin=DuracionMin, @SubcategoriaID=SubcategoriaID FROM Servicios.Servicio WHERE ServicioID=@ServicioID AND Activo=1;
    IF @DuracionMin IS NULL BEGIN RAISERROR('Servicio no encontrado o inactivo',16,1); RETURN; END
    DECLARE @FechaFin DATETIME=DATEADD(MINUTE,@DuracionMin,@FechaInicioD);
    DECLARE @DiaSemana TINYINT=DATEPART(WEEKDAY,@FechaInicioD);
    DECLARE @DiaConvertido TINYINT=CASE @DiaSemana WHEN 1 THEN 7 WHEN 2 THEN 1 WHEN 3 THEN 2
        WHEN 4 THEN 3 WHEN 5 THEN 4 WHEN 6 THEN 5 WHEN 7 THEN 6 END;
    SELECT e.EmpleadoID, p.Nombre, p.Apellido, r.RolID, r.NombreRol
    FROM RRHH.Empleado e
    JOIN Personas.Persona p ON p.PersonaID=e.EmpleadoID
    JOIN RRHH.EmpleadoRol er ON er.EmpleadoID=e.EmpleadoID
    JOIN RRHH.Rol r ON r.RolID=er.RolID
    JOIN Servicios.SubcategoriaRol sr ON sr.RolID=er.RolID
    WHERE sr.SubcategoriaID=@SubcategoriaID AND e.Activo=1 AND r.RolID IN (3,4,5,6)
      AND EXISTS (SELECT 1 FROM RRHH.HorarioEmpleado h WHERE h.EmpleadoID=e.EmpleadoID
                  AND h.DiaSemana=@DiaConvertido AND h.HoraEntrada<=CAST(@FechaInicioD AS TIME)
                  AND h.HoraSalida>=CAST(@FechaFin AS TIME) AND h.Activo=1)
      AND NOT EXISTS (SELECT 1 FROM RRHH.HorarioExcepcion ex WHERE ex.EmpleadoID=e.EmpleadoID
                      AND ex.Fecha=CAST(@FechaInicioD AS DATE) AND ex.Disponible=0 AND ex.Estado='Aprobada')
      AND e.EmpleadoID NOT IN (SELECT cs.EmpleadoID FROM Agenda.CitaServicio cs
                               JOIN Agenda.Cita c ON c.CitaID=cs.CitaID
                               WHERE cs.EmpleadoID IS NOT NULL AND c.EstadoID NOT IN (12,13)
                                 AND cs.FechaInicioServicio<@FechaFin AND cs.FechaFinServicio>@FechaInicioD)
    ORDER BY p.Nombre;
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_CrearSolicitudEspecial
    @ClienteID INT, @FechaSolicitada NVARCHAR(30), @TipoSolicitud VARCHAR(30)=NULL,
    @ServicioIDs VARCHAR(500)=NULL, @Motivo VARCHAR(200)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @FechaD DATETIME=CONVERT(DATETIME,REPLACE(@FechaSolicitada,'T',' '),120);
    INSERT INTO Agenda.SolicitudEspecial (ClienteID,FechaSolicitada,TipoSolicitud,ServicioIDs,Motivo,Estado,FechaCreacion)
    VALUES (@ClienteID,@FechaD,@TipoSolicitud,@ServicioIDs,@Motivo,'Pendiente',GETDATE());
    SELECT SCOPE_IDENTITY() AS SolicitudID, 'Solicitud enviada' AS Mensaje;
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_ObtenerSolicitudesCliente @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SolicitudID, FechaSolicitada, TipoSolicitud, ServicioIDs, Motivo,
        Estado, MotivoRechazo, CitaID, FechaCreacion
    FROM Agenda.SolicitudEspecial WHERE ClienteID=@ClienteID ORDER BY FechaCreacion DESC;
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_SlotsOcupados
    @Fecha DATE, @ServicioIDs VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(cs.FechaInicioServicio AS TIME(0)) AS HoraInicio,
        COUNT(DISTINCT cs.EmpleadoID) AS EmpleadosOcupados
    FROM Agenda.CitaServicio cs JOIN Agenda.Cita c ON c.CitaID=cs.CitaID
    WHERE CAST(cs.FechaInicioServicio AS DATE)=@Fecha AND c.EstadoID NOT IN (12,13) AND cs.EmpleadoID IS NOT NULL
    GROUP BY CAST(cs.FechaInicioServicio AS TIME(0)) ORDER BY HoraInicio;
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_CompletarCita
    @CitaID INT, @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM Agenda.CitaServicio WHERE CitaID=@CitaID AND EmpleadoID=@EmpleadoID)
        BEGIN ROLLBACK; RAISERROR('No tienes permiso para completar esta cita.',16,1); RETURN; END
        UPDATE Agenda.Cita SET EstadoID=11 WHERE CitaID=@CitaID;
        COMMIT;
        SELECT 'Cita marcada como completada.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al completar la cita.',16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_AgendaDelDia @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(*) AS TotalCitas,
        SUM(CASE WHEN c.EstadoID=9 THEN 1 ELSE 0 END) AS Confirmadas,
        SUM(CASE WHEN c.EstadoID=8 THEN 1 ELSE 0 END) AS Pendientes,
        SUM(CASE WHEN c.EstadoID=11 THEN 1 ELSE 0 END) AS Completadas,
        ISNULL((SELECT SUM(vds.PrecioUnitario*vds.Cantidad) FROM Ventas.VentaDetalleServicio vds
                JOIN Ventas.Venta v ON v.VentaID=vds.VentaID
                WHERE vds.EmpleadoID=@EmpleadoID AND CAST(v.Fecha AS DATE)=CAST(GETDATE() AS DATE)),0) AS IngresosDia,
        ISNULL((SELECT SUM(vds.PrecioUnitario*vds.Cantidad*ec.Porcentaje/100.0)
                FROM Ventas.VentaDetalleServicio vds JOIN Ventas.Venta v ON v.VentaID=vds.VentaID
                JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID=vds.EmpleadoID AND ec.FechaFin IS NULL
                WHERE vds.EmpleadoID=@EmpleadoID AND CAST(v.Fecha AS DATE)=CAST(GETDATE() AS DATE)),0) AS ComisionDia
    FROM Agenda.CitaServicio cs JOIN Agenda.Cita c ON c.CitaID=cs.CitaID
    WHERE cs.EmpleadoID=@EmpleadoID AND CAST(cs.FechaInicioServicio AS DATE)=CAST(GETDATE() AS DATE)
      AND c.EstadoID NOT IN (12,13);

    SELECT c.CitaID, c.ClienteID, p.Nombre AS NombreCliente, p.Apellido AS ApellidoCliente,
        s.ServicioID, s.Nombre AS Servicio,
        CONVERT(NVARCHAR(19),cs.FechaInicioServicio,120) AS FechaInicioServicio,
        CONVERT(NVARCHAR(19),cs.FechaFinServicio,120) AS FechaFinServicio,
        ec.EstadoID, ec.Nombre AS Estado, sp.Precio, cd.Alergias, cd.Contraindicaciones
    FROM Agenda.CitaServicio cs
    JOIN Agenda.Cita c ON c.CitaID=cs.CitaID
    JOIN Personas.Persona p ON p.PersonaID=c.ClienteID
    JOIN Servicios.Servicio s ON s.ServicioID=cs.ServicioID
    JOIN Agenda.EstadoCita ec ON ec.EstadoID=c.EstadoID
    JOIN Servicios.ServicioPrecio sp ON sp.ServicioID=s.ServicioID AND sp.FechaFin IS NULL
    LEFT JOIN Ventas.ClienteDetalle cd ON cd.ClienteID=c.ClienteID
    WHERE cs.EmpleadoID=@EmpleadoID AND CAST(cs.FechaInicioServicio AS DATE)=CAST(GETDATE() AS DATE)
      AND c.EstadoID NOT IN (12,13) ORDER BY cs.FechaInicioServicio ASC;
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_ObtenerPerfilRecepcion @PersonaID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.PersonaID, p.Nombre, p.Apellido, p.Email, p.Telefono, p.FechaNacimiento, r.Nombre AS NombreRol
    FROM Personas.Persona p
    JOIN Seguridad.Usuario u ON u.PersonaID=p.PersonaID
    JOIN Seguridad.UsuarioRol ur ON ur.UsuarioID=u.UsuarioID
    JOIN Seguridad.Rol r ON r.RolID=ur.RolID WHERE p.PersonaID=@PersonaID;
END;
GO

CREATE OR ALTER PROCEDURE Agenda.SP_ActualizarPerfilRecepcion
    @PersonaID INT, @Nombre VARCHAR(100), @Apellido VARCHAR(100),
    @Telefono VARCHAR(20), @Email VARCHAR(100), @FechaNacimiento DATE=NULL
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

-- ============================================================
-- VENTAS
-- ============================================================

CREATE OR ALTER PROCEDURE Ventas.SP_ObtenerClientes
    @Busqueda VARCHAR(100)=NULL, @Filtro VARCHAR(20)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.PersonaID AS ClienteID, p.Nombre, p.Apellido, p.Telefono, p.Email, p.FechaRegistro,
        cd.Alergias, cd.Contraindicaciones,
        COUNT(DISTINCT v.VentaID) AS TotalVisitas, MAX(v.Fecha) AS UltimaCita
    FROM Personas.Persona p
    JOIN Ventas.Cliente cl ON cl.ClienteID=p.PersonaID
    LEFT JOIN Ventas.ClienteDetalle cd ON cd.ClienteID=p.PersonaID
    LEFT JOIN Ventas.Venta v ON v.ClienteID=p.PersonaID
    WHERE (@Busqueda IS NULL OR p.Nombre LIKE '%'+@Busqueda+'%' OR p.Apellido LIKE '%'+@Busqueda+'%'
        OR p.Telefono LIKE '%'+@Busqueda+'%' OR p.Email LIKE '%'+@Busqueda+'%')
    AND (@Filtro IS NULL OR (@Filtro='alergias' AND cd.Alergias IS NOT NULL)
        OR (@Filtro='nuevos' AND p.FechaRegistro>=DATEADD(MONTH,-1,GETDATE())))
    GROUP BY p.PersonaID,p.Nombre,p.Apellido,p.Telefono,p.Email,p.FechaRegistro,cd.Alergias,cd.Contraindicaciones
    HAVING (@Filtro IS NULL OR @Filtro<>'frecuentes' OR COUNT(DISTINCT v.VentaID)>=3)
    ORDER BY p.Nombre ASC;
END;
GO

CREATE OR ALTER PROCEDURE Ventas.SP_RegistrarVenta
    @ClienteID INT, @EmpleadoID INT=NULL, @MetodoPagoID INT, @Monto DECIMAL(10,2),
    @Referencia VARCHAR(100)=NULL, @Servicios VARCHAR(MAX)=NULL, @Productos VARCHAR(MAX)=NULL,
    @DescuentoPct DECIMAL(5,2)=0, @PromocionID INT=NULL, @DescuentoMonto DECIMAL(10,2)=0
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF @Servicios IS NULL AND @Productos IS NULL
        BEGIN ROLLBACK; RAISERROR('Debe incluir al menos un servicio o producto.',16,1); RETURN; END
        DECLARE @VentaID INT;
        INSERT INTO Ventas.Venta (ClienteID,EmpleadoID,Estado,DescuentoPct,DescuentoMonto,PromocionID)
        VALUES (@ClienteID,@EmpleadoID,'pendiente',@DescuentoPct,@DescuentoMonto,@PromocionID);
        SET @VentaID=SCOPE_IDENTITY();
        IF @Servicios IS NOT NULL
        BEGIN
            DECLARE @SrvList VARCHAR(MAX)=@Servicios+',';
            DECLARE @SrvPos INT=1,@SrvNext INT,@SrvItem VARCHAR(200);
            DECLARE @P1 VARCHAR(50),@P2 VARCHAR(50),@P3 VARCHAR(50),@P4 VARCHAR(50);
            DECLARE @SrvID INT,@SrvQty INT,@SrvPrice DECIMAL(10,2),@SrvEmpID INT;
            WHILE CHARINDEX(',',@SrvList,@SrvPos)>0
            BEGIN
                SET @SrvNext=CHARINDEX(',',@SrvList,@SrvPos);
                SET @SrvItem=SUBSTRING(@SrvList,@SrvPos,@SrvNext-@SrvPos);
                SET @P1=SUBSTRING(@SrvItem,1,CHARINDEX(':',@SrvItem)-1);
                SET @SrvItem=SUBSTRING(@SrvItem,CHARINDEX(':',@SrvItem)+1,LEN(@SrvItem));
                SET @P2=SUBSTRING(@SrvItem,1,CHARINDEX(':',@SrvItem)-1);
                SET @SrvItem=SUBSTRING(@SrvItem,CHARINDEX(':',@SrvItem)+1,LEN(@SrvItem));
                SET @P3=SUBSTRING(@SrvItem,1,CHARINDEX(':',@SrvItem)-1);
                SET @P4=SUBSTRING(@SrvItem,CHARINDEX(':',@SrvItem)+1,LEN(@SrvItem));
                SET @SrvID=CAST(@P1 AS INT); SET @SrvQty=CAST(@P2 AS INT); SET @SrvPrice=CAST(@P3 AS DECIMAL(10,2));
                SET @SrvEmpID=CASE WHEN ISNUMERIC(@P4)=1 AND CAST(@P4 AS INT)>0 THEN CAST(@P4 AS INT) ELSE NULL END;
                INSERT INTO Ventas.VentaDetalleServicio (VentaID,ServicioID,Cantidad,PrecioUnitario,EmpleadoID)
                VALUES (@VentaID,@SrvID,@SrvQty,@SrvPrice,@SrvEmpID);
                SET @SrvPos=@SrvNext+1;
            END
        END
        IF @Productos IS NOT NULL
        BEGIN
            DECLARE @PrdList VARCHAR(MAX)=@Productos+',';
            DECLARE @PrdPos INT=1,@PrdNext INT,@PrdItem VARCHAR(200);
            DECLARE @Q1 VARCHAR(50),@Q2 VARCHAR(50),@Q3 VARCHAR(50);
            DECLARE @PrdID INT,@PrdQty INT,@PrdPrice DECIMAL(10,2);
            WHILE CHARINDEX(',',@PrdList,@PrdPos)>0
            BEGIN
                SET @PrdNext=CHARINDEX(',',@PrdList,@PrdPos);
                SET @PrdItem=SUBSTRING(@PrdList,@PrdPos,@PrdNext-@PrdPos);
                SET @Q1=SUBSTRING(@PrdItem,1,CHARINDEX(':',@PrdItem)-1);
                SET @PrdItem=SUBSTRING(@PrdItem,CHARINDEX(':',@PrdItem)+1,LEN(@PrdItem));
                SET @Q2=SUBSTRING(@PrdItem,1,CHARINDEX(':',@PrdItem)-1);
                SET @Q3=SUBSTRING(@PrdItem,CHARINDEX(':',@PrdItem)+1,LEN(@PrdItem));
                SET @PrdID=CAST(@Q1 AS INT); SET @PrdQty=CAST(@Q2 AS INT); SET @PrdPrice=CAST(@Q3 AS DECIMAL(10,2));
                INSERT INTO Ventas.VentaDetalleProducto (VentaID,ProductoID,Cantidad,PrecioUnitario)
                VALUES (@VentaID,@PrdID,@PrdQty,@PrdPrice);
                UPDATE Inventario.Producto SET StockActual=StockActual-@PrdQty WHERE ProductoID=@PrdID;
                INSERT INTO Inventario.MovimientoInventario (ProductoID,EsEntrada,Cantidad) VALUES (@PrdID,0,@PrdQty);
                SET @PrdPos=@PrdNext+1;
            END
        END
        UPDATE Ventas.Venta SET Estado='pagado' WHERE VentaID=@VentaID;
        DECLARE @NumeroFactura VARCHAR(50)='COCO-CBB-'+RIGHT('000'+CAST(@VentaID AS VARCHAR),4);
        DECLARE @FacturaID INT;
        INSERT INTO Facturacion.Factura (VentaID,NumeroFactura,Estado) VALUES (@VentaID,@NumeroFactura,'emitida');
        SET @FacturaID=SCOPE_IDENTITY();
        INSERT INTO Ventas.Pago (VentaID,MetodoPagoID,Monto) VALUES (@VentaID,@MetodoPagoID,@Monto);
        UPDATE Facturacion.Factura SET Estado='pagada' WHERE FacturaID=@FacturaID;
        COMMIT;
        SELECT @VentaID AS VentaID, @NumeroFactura AS NumeroFactura,
            @Monto AS Total, 'Venta registrada y factura generada.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        DECLARE @ErrMsg VARCHAR(500)=ERROR_MESSAGE();
        RAISERROR(@ErrMsg,16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Ventas.SP_ObtenerComprasCliente
    @ClienteID INT, @FechaDesde DATE=NULL, @FechaHasta DATE=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.VentaID, v.Fecha, v.Estado AS EstadoVenta, f.FacturaID,
        s.Nombre AS Item, 'Servicio' AS Tipo, vds.Cantidad, vds.PrecioUnitario,
        vds.PrecioUnitario*vds.Cantidad AS Total, f.NumeroFactura, f.Estado AS EstadoFactura
    FROM Ventas.Venta v
    JOIN Ventas.VentaDetalleServicio vds ON vds.VentaID=v.VentaID
    JOIN Servicios.Servicio s ON s.ServicioID=vds.ServicioID
    LEFT JOIN Facturacion.Factura f ON f.VentaID=v.VentaID
    WHERE v.ClienteID=@ClienteID
      AND (@FechaDesde IS NULL OR CAST(v.Fecha AS DATE)>=@FechaDesde)
      AND (@FechaHasta IS NULL OR CAST(v.Fecha AS DATE)<=@FechaHasta)
    UNION ALL
    SELECT v.VentaID, v.Fecha, v.Estado AS EstadoVenta, f.FacturaID,
        p.Nombre AS Item, 'Producto' AS Tipo, vdp.Cantidad, vdp.PrecioUnitario,
        vdp.PrecioUnitario*vdp.Cantidad AS Total, f.NumeroFactura, f.Estado AS EstadoFactura
    FROM Ventas.Venta v
    JOIN Ventas.VentaDetalleProducto vdp ON vdp.VentaID=v.VentaID
    JOIN Inventario.Producto p ON p.ProductoID=vdp.ProductoID
    LEFT JOIN Facturacion.Factura f ON f.VentaID=v.VentaID
    WHERE v.ClienteID=@ClienteID
      AND (@FechaDesde IS NULL OR CAST(v.Fecha AS DATE)>=@FechaDesde)
      AND (@FechaHasta IS NULL OR CAST(v.Fecha AS DATE)<=@FechaHasta)
    ORDER BY Fecha DESC;
END;
GO

CREATE OR ALTER PROCEDURE Ventas.SP_ObtenerPagosCliente
    @ClienteID INT, @FechaDesde DATE=NULL, @FechaHasta DATE=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT pg.PagoID, v.Fecha, pg.Monto, mp.Nombre AS MetodoPago,
        f.NumeroFactura, f.Estado AS EstadoFactura, v.VentaID
    FROM Ventas.Pago pg
    JOIN Ventas.Venta v ON v.VentaID=pg.VentaID
    JOIN Ventas.MetodoPago mp ON mp.MetodoPagoID=pg.MetodoPagoID
    LEFT JOIN Facturacion.Factura f ON f.VentaID=v.VentaID
    WHERE v.ClienteID=@ClienteID
      AND (@FechaDesde IS NULL OR CAST(v.Fecha AS DATE)>=@FechaDesde)
      AND (@FechaHasta IS NULL OR CAST(v.Fecha AS DATE)<=@FechaHasta)
    ORDER BY v.Fecha DESC;
END;
GO

CREATE OR ALTER PROCEDURE Ventas.SP_ObtenerClientesEmpleado @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DISTINCT p.PersonaID AS ClienteID, p.Nombre, p.Apellido, p.Telefono, p.Email,
        cd.Alergias, cd.Contraindicaciones, cd.NotasTecnicas,
        COUNT(c.CitaID) OVER (PARTITION BY c.ClienteID) AS TotalVisitas,
        MAX(cs.FechaInicioServicio) OVER (PARTITION BY c.ClienteID) AS UltimaVisita
    FROM Agenda.CitaServicio cs
    JOIN Agenda.Cita c ON c.CitaID=cs.CitaID
    JOIN Personas.Persona p ON p.PersonaID=c.ClienteID
    LEFT JOIN Ventas.ClienteDetalle cd ON cd.ClienteID=c.ClienteID
    WHERE cs.EmpleadoID=@EmpleadoID AND c.EstadoID=11 ORDER BY UltimaVisita DESC;
END;
GO

CREATE OR ALTER PROCEDURE Ventas.SP_ObtenerFichaCliente
    @ClienteID INT, @EmpleadoID INT
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
    GROUP BY p.PersonaID,p.Nombre,p.Apellido,p.Telefono,p.Email,p.FechaRegistro,cd.Alergias,cd.Contraindicaciones,cd.NotasTecnicas;

    SELECT c.CitaID, cs.FechaInicioServicio, s.Nombre AS Servicio, ec.Nombre AS Estado, sp.Precio
    FROM Agenda.CitaServicio cs
    JOIN Agenda.Cita c ON c.CitaID=cs.CitaID
    JOIN Servicios.Servicio s ON s.ServicioID=cs.ServicioID
    JOIN Agenda.EstadoCita ec ON ec.EstadoID=c.EstadoID
    JOIN Servicios.ServicioPrecio sp ON sp.ServicioID=s.ServicioID AND sp.FechaFin IS NULL
    WHERE c.ClienteID=@ClienteID AND cs.EmpleadoID=@EmpleadoID ORDER BY cs.FechaInicioServicio DESC;
END;
GO

CREATE OR ALTER PROCEDURE Ventas.SP_ActualizarNotasTecnicas
    @ClienteID INT, @NotasTecnicas VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM Ventas.ClienteDetalle WHERE ClienteID=@ClienteID)
            UPDATE Ventas.ClienteDetalle SET NotasTecnicas=@NotasTecnicas WHERE ClienteID=@ClienteID;
        ELSE
            INSERT INTO Ventas.ClienteDetalle (ClienteID,NotasTecnicas) VALUES (@ClienteID,@NotasTecnicas);
        COMMIT;
        SELECT 'Notas actualizadas correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al actualizar notas.',16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Ventas.SP_ObtenerVentasEmpleado @EmpleadoID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.Fecha, p.Nombre AS NombreCliente, p.Apellido AS ApellidoCliente,
        s.Nombre AS Servicio, 'Servicio' AS Tipo, vds.PrecioUnitario AS Precio,
        vds.PrecioUnitario*vds.Cantidad*ec.Porcentaje/100.0 AS Comision
    FROM Ventas.VentaDetalleServicio vds
    JOIN Ventas.Venta v ON v.VentaID=vds.VentaID
    JOIN Personas.Persona p ON p.PersonaID=v.ClienteID
    JOIN Servicios.Servicio s ON s.ServicioID=vds.ServicioID
    JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID=vds.EmpleadoID AND ec.FechaFin IS NULL
    WHERE vds.EmpleadoID=@EmpleadoID ORDER BY v.Fecha DESC;
END;
GO

-- ============================================================
-- FACTURACION
-- ============================================================

CREATE OR ALTER PROCEDURE Facturacion.SP_ObtenerFacturas
    @Estado VARCHAR(20)=NULL, @FechaDesde DATE=NULL, @FechaHasta DATE=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT f.FacturaID, f.NumeroFactura, f.Fecha, f.Estado, f.VentaID,
        p.Nombre AS NombreCliente, p.Apellido AS ApellidoCliente,
        emp.Nombre AS NombreEmpleado, emp.Apellido AS ApellidoEmpleado,
        ISNULL((SELECT SUM(PrecioUnitario*Cantidad) FROM Ventas.VentaDetalleServicio WHERE VentaID=v.VentaID),0)+
        ISNULL((SELECT SUM(PrecioUnitario*Cantidad) FROM Ventas.VentaDetalleProducto WHERE VentaID=v.VentaID),0) AS Total
    FROM Facturacion.Factura f
    JOIN Ventas.Venta v ON v.VentaID=f.VentaID
    JOIN Personas.Persona p ON p.PersonaID=v.ClienteID
    LEFT JOIN Personas.Persona emp ON emp.PersonaID=v.EmpleadoID
    WHERE (@Estado IS NULL OR f.Estado=@Estado)
      AND (@FechaDesde IS NULL OR CAST(f.Fecha AS DATE)>=@FechaDesde)
      AND (@FechaHasta IS NULL OR CAST(f.Fecha AS DATE)<=@FechaHasta)
    ORDER BY f.Fecha DESC;
END;
GO

CREATE OR ALTER PROCEDURE Facturacion.SP_DetalleFactura @FacturaID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT f.FacturaID, f.NumeroFactura, f.Fecha, f.Estado,
        p.Nombre AS NombreCliente, p.Apellido AS ApellidoCliente,
        mp.Nombre AS MetodoPago, pg.Monto AS Total,
        ISNULL(v.DescuentoPct,0) AS DescuentoPct, ISNULL(v.DescuentoMonto,0) AS DescuentoMonto
    FROM Facturacion.Factura f
    JOIN Ventas.Venta v ON v.VentaID=f.VentaID
    JOIN Personas.Persona p ON p.PersonaID=v.ClienteID
    LEFT JOIN Ventas.Pago pg ON pg.VentaID=v.VentaID
    LEFT JOIN Ventas.MetodoPago mp ON mp.MetodoPagoID=pg.MetodoPagoID
    WHERE f.FacturaID=@FacturaID;

    SELECT s.Nombre AS Item, 'Servicio' AS Tipo, vds.Cantidad,
        ISNULL(sp.Precio,vds.PrecioUnitario) AS PrecioUnitario,
        vds.PrecioUnitario*vds.Cantidad AS Subtotal,
        emp.Nombre AS NombreEmpleado, emp.Apellido AS ApellidoEmpleado
    FROM Ventas.VentaDetalleServicio vds
    JOIN Ventas.Venta v ON v.VentaID=vds.VentaID
    JOIN Facturacion.Factura f ON f.VentaID=v.VentaID
    JOIN Servicios.Servicio s ON s.ServicioID=vds.ServicioID
    LEFT JOIN Servicios.ServicioPrecio sp ON sp.ServicioID=vds.ServicioID AND sp.FechaFin IS NULL
    LEFT JOIN Personas.Persona emp ON emp.PersonaID=vds.EmpleadoID
    WHERE f.FacturaID=@FacturaID;

    SELECT pr.Nombre AS Item, 'Producto' AS Tipo, vdp.Cantidad, vdp.PrecioUnitario,
        vdp.Cantidad*vdp.PrecioUnitario AS Subtotal, NULL AS NombreEmpleado, NULL AS ApellidoEmpleado
    FROM Ventas.VentaDetalleProducto vdp
    JOIN Ventas.Venta v ON v.VentaID=vdp.VentaID
    JOIN Facturacion.Factura f ON f.VentaID=v.VentaID
    JOIN Inventario.Producto pr ON pr.ProductoID=vdp.ProductoID
    WHERE f.FacturaID=@FacturaID;
END;
GO

-- ============================================================
-- NOTIFICACIONES
-- ============================================================

CREATE OR ALTER PROCEDURE Notificaciones.SP_ObtenerNotificaciones @PersonaID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT n.NotificacionID, n.Mensaje, n.Fecha, n.Leido, tn.Nombre AS TipoNotificacion
    FROM Notificaciones.Notificacion n
    JOIN Notificaciones.TipoNotificacion tn ON tn.TipoNotificacionID=n.TipoNotificacionID
    WHERE n.PersonaID=@PersonaID ORDER BY n.Leido ASC, n.Fecha DESC;
END;
GO

CREATE OR ALTER PROCEDURE Notificaciones.SP_MarcarNotificacionLeida
    @NotificacionID INT, @PersonaID INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Notificaciones.Notificacion SET Leido=1 WHERE NotificacionID=@NotificacionID AND PersonaID=@PersonaID;
    IF @@ROWCOUNT=0 RAISERROR('Notificacion no encontrada.',16,1);
    ELSE SELECT 'Notificacion marcada como leida.' AS Mensaje;
END;
GO

-- ============================================================
-- DUENA
-- ============================================================

CREATE OR ALTER PROCEDURE Duena.SP_ResumenEjecutivo
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ISNULL(SUM(CASE WHEN MONTH(v.Fecha)=MONTH(GETDATE()) AND YEAR(v.Fecha)=YEAR(GETDATE()) THEN pg.Monto ELSE 0 END),0) AS IngresosMesActual,
        ISNULL(SUM(CASE WHEN MONTH(v.Fecha)=MONTH(DATEADD(MONTH,-1,GETDATE())) AND YEAR(v.Fecha)=YEAR(DATEADD(MONTH,-1,GETDATE())) THEN pg.Monto ELSE 0 END),0) AS IngresosMesAnterior,
        ISNULL(SUM(CASE WHEN YEAR(v.Fecha)=YEAR(GETDATE()) THEN pg.Monto ELSE 0 END),0) AS IngresosAnio,
        COUNT(DISTINCT CASE WHEN MONTH(v.Fecha)=MONTH(GETDATE()) AND YEAR(v.Fecha)=YEAR(GETDATE()) THEN v.VentaID END) AS VentasMes,
        ISNULL(AVG(CASE WHEN YEAR(v.Fecha)=YEAR(GETDATE()) THEN pg.Monto END),0) AS TicketPromedio
    FROM Ventas.Venta v JOIN Ventas.Pago pg ON pg.VentaID=v.VentaID;

    SELECT SUM(CASE WHEN MONTH(FechaInicio)=MONTH(GETDATE()) AND YEAR(FechaInicio)=YEAR(GETDATE()) AND EstadoID=11 THEN 1 ELSE 0 END) AS CitasMesActual,
        SUM(CASE WHEN YEAR(FechaInicio)=YEAR(GETDATE()) AND EstadoID=11 THEN 1 ELSE 0 END) AS CitasAnio
    FROM Agenda.Cita;

    SELECT COUNT(*) AS TotalClientes,
        SUM(CASE WHEN MONTH(p.FechaRegistro)=MONTH(GETDATE()) AND YEAR(p.FechaRegistro)=YEAR(GETDATE()) THEN 1 ELSE 0 END) AS NuevosMes
    FROM Ventas.Cliente c JOIN Personas.Persona p ON p.PersonaID=c.ClienteID;

    SELECT r.NombreRol, COUNT(*) AS Total
    FROM RRHH.Empleado e JOIN RRHH.EmpleadoRol er ON er.EmpleadoID=e.EmpleadoID
    JOIN RRHH.Rol r ON r.RolID=er.RolID WHERE e.Activo=1 GROUP BY r.RolID,r.NombreRol ORDER BY r.RolID;

    SELECT YEAR(v.Fecha) AS Anio, MONTH(v.Fecha) AS Mes,
        ISNULL(SUM(pg.Monto),0) AS Ingresos, COUNT(DISTINCT v.VentaID) AS Ventas
    FROM Ventas.Venta v JOIN Ventas.Pago pg ON pg.VentaID=v.VentaID
    WHERE v.Fecha>=DATEADD(MONTH,-12,GETDATE())
    GROUP BY YEAR(v.Fecha),MONTH(v.Fecha) ORDER BY Anio ASC, Mes ASC;

    SELECT TOP 3 p.Nombre, p.Apellido, r.NombreRol,
        COUNT(DISTINCT vds.VentaID) AS TotalVentas,
        ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad),0) AS TotalIngresos
    FROM Ventas.VentaDetalleServicio vds
    JOIN Ventas.Venta v ON v.VentaID=vds.VentaID
    JOIN Personas.Persona p ON p.PersonaID=vds.EmpleadoID
    JOIN RRHH.EmpleadoRol er ON er.EmpleadoID=vds.EmpleadoID
    JOIN RRHH.Rol r ON r.RolID=er.RolID
    WHERE MONTH(v.Fecha)=MONTH(GETDATE()) AND YEAR(v.Fecha)=YEAR(GETDATE()) AND vds.EmpleadoID IS NOT NULL
    GROUP BY vds.EmpleadoID,p.Nombre,p.Apellido,r.NombreRol ORDER BY TotalIngresos DESC;
END;
GO

CREATE OR ALTER PROCEDURE Duena.SP_ReporteAnual @Anio INT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @AnioFiltro INT=ISNULL(@Anio,YEAR(GETDATE()));
    SELECT MONTH(v.Fecha) AS Mes, ISNULL(SUM(pg.Monto),0) AS Ingresos,
        COUNT(DISTINCT v.VentaID) AS Ventas, ISNULL(AVG(pg.Monto),0) AS TicketPromedio
    FROM Ventas.Venta v JOIN Ventas.Pago pg ON pg.VentaID=v.VentaID
    WHERE YEAR(v.Fecha)=@AnioFiltro GROUP BY MONTH(v.Fecha) ORDER BY Mes ASC;

    SELECT ISNULL(SUM(pg.Monto),0) AS TotalIngresos, COUNT(DISTINCT v.VentaID) AS TotalVentas,
        ISNULL(AVG(pg.Monto),0) AS TicketPromedio
    FROM Ventas.Venta v JOIN Ventas.Pago pg ON pg.VentaID=v.VentaID WHERE YEAR(v.Fecha)=@AnioFiltro;
END;
GO

CREATE OR ALTER PROCEDURE Duena.SP_VerTodosLosSueldos
    @Anio INT=NULL, @Mes INT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @AnioFiltro INT=ISNULL(@Anio,YEAR(GETDATE()));
    DECLARE @MesFiltro INT=ISNULL(@Mes,MONTH(GETDATE()));
    DECLARE @Periodo VARCHAR(7)=CAST(@AnioFiltro AS VARCHAR)+'-'+RIGHT('0'+CAST(@MesFiltro AS VARCHAR),2);
    SELECT e.EmpleadoID, p.Nombre, p.Apellido,
        ISNULL(es.SueldoBase,0) AS SueldoBase, ISNULL(ec.Porcentaje,0) AS PorcentajeComision,
        ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad),0) AS TotalVentas,
        ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad*ec.Porcentaje/100.0),0) AS TotalComision,
        ISNULL(es.SueldoBase,0)+ISNULL(SUM(vds.PrecioUnitario*vds.Cantidad*ec.Porcentaje/100.0),0) AS TotalNomina,
        CASE WHEN pn.PagoNominaID IS NOT NULL THEN 1 ELSE 0 END AS YaPagado,
        pn.FechaPago, pn.Total AS MontoPagado, @Periodo AS Periodo
    FROM RRHH.Empleado e
    JOIN Personas.Persona p ON p.PersonaID=e.EmpleadoID
    LEFT JOIN RRHH.EmpleadoSueldo es ON es.EmpleadoID=e.EmpleadoID AND es.FechaFin IS NULL
    LEFT JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID=e.EmpleadoID AND ec.FechaFin IS NULL
    LEFT JOIN Ventas.VentaDetalleServicio vds ON vds.EmpleadoID=e.EmpleadoID
        AND EXISTS (SELECT 1 FROM Ventas.Venta v WHERE v.VentaID=vds.VentaID
                    AND MONTH(v.Fecha)=@MesFiltro AND YEAR(v.Fecha)=@AnioFiltro)
    LEFT JOIN RRHH.PagoNomina pn ON pn.EmpleadoID=e.EmpleadoID AND pn.Periodo=@Periodo
    WHERE e.Activo=1 AND EXISTS (SELECT 1 FROM RRHH.EmpleadoRol WHERE EmpleadoID=e.EmpleadoID AND RolID IN (2,3,4,5,6,7))
    GROUP BY e.EmpleadoID,p.Nombre,p.Apellido,es.SueldoBase,ec.Porcentaje,pn.PagoNominaID,pn.FechaPago,pn.Total
    ORDER BY p.Nombre;
END;
GO

CREATE OR ALTER PROCEDURE Duena.SP_ObtenerPerfil @PersonaID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.PersonaID, p.Nombre, p.Apellido, p.Email, p.Telefono, p.FechaNacimiento, r.Nombre AS NombreRol
    FROM Personas.Persona p
    JOIN Seguridad.Usuario u ON u.PersonaID=p.PersonaID
    JOIN Seguridad.UsuarioRol ur ON ur.UsuarioID=u.UsuarioID
    JOIN Seguridad.Rol r ON r.RolID=ur.RolID WHERE p.PersonaID=@PersonaID;
END;
GO

CREATE OR ALTER PROCEDURE Duena.SP_CambiarEstadoEmpleado @EmpleadoID INT, @Activo BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE RRHH.Empleado SET Activo=@Activo WHERE EmpleadoID=@EmpleadoID;
    UPDATE Seguridad.Usuario SET Activo=@Activo WHERE PersonaID=@EmpleadoID;
    SELECT 'Estado actualizado correctamente.' AS Mensaje;
END;
GO

CREATE OR ALTER PROCEDURE Duena.SP_RegistrarAdmin
    @Nombre VARCHAR(100), @Apellido VARCHAR(100), @Telefono VARCHAR(20),
    @Email VARCHAR(100), @PassHash VARCHAR(255), @FechaContrato DATE, @SueldoBase DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM Personas.Persona WHERE Email=@Email)
        BEGIN ROLLBACK; RAISERROR('Este correo ya esta registrado.',16,1); RETURN; END
        DECLARE @PersonaID INT;
        INSERT INTO Personas.Persona (Nombre,Apellido,Telefono,Email) VALUES (@Nombre,@Apellido,@Telefono,@Email);
        SET @PersonaID=SCOPE_IDENTITY();
        INSERT INTO RRHH.Empleado (EmpleadoID,FechaContratacion,Activo) VALUES (@PersonaID,@FechaContrato,1);
        INSERT INTO RRHH.EmpleadoRol (EmpleadoID,RolID) VALUES (@PersonaID,2);
        INSERT INTO RRHH.EmpleadoSueldo (EmpleadoID,SueldoBase,FechaInicio) VALUES (@PersonaID,@SueldoBase,@FechaContrato);
        INSERT INTO RRHH.EmpleadoComision (EmpleadoID,Porcentaje,FechaInicio) VALUES (@PersonaID,0.00,@FechaContrato);
        DECLARE @UsuarioID INT;
        INSERT INTO Seguridad.Usuario (PersonaID,Username,PasswordHash) VALUES (@PersonaID,@Email,@PassHash);
        SET @UsuarioID=SCOPE_IDENTITY();
        INSERT INTO Seguridad.UsuarioRol (UsuarioID,RolID) VALUES (@UsuarioID,2);
        COMMIT;
        SELECT @PersonaID AS EmpleadoID, 'Administrador registrado correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        DECLARE @Error VARCHAR(500)=ERROR_MESSAGE();
        RAISERROR(@Error,16,1);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE RRHH.SP_RegistrarPagoNominaDuena
    @EmpleadoID INT, @Periodo VARCHAR(7), @MontoPagado DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM RRHH.EmpleadoRol WHERE EmpleadoID=@EmpleadoID AND RolID=2)
        BEGIN ROLLBACK; RAISERROR('Solo puedes pagar al Administrador.',16,1); RETURN; END
        IF EXISTS (SELECT 1 FROM RRHH.PagoNomina WHERE EmpleadoID=@EmpleadoID AND Periodo=@Periodo)
        BEGIN ROLLBACK; RAISERROR('Este periodo ya fue pagado.',16,1); RETURN; END
        DECLARE @SueldoBase DECIMAL(10,2);
        SELECT @SueldoBase=ISNULL(SueldoBase,0) FROM RRHH.EmpleadoSueldo WHERE EmpleadoID=@EmpleadoID AND FechaFin IS NULL;
        INSERT INTO RRHH.PagoNomina (EmpleadoID,Periodo,SueldoBase,Comision,FechaPago,Pagado)
        VALUES (@EmpleadoID,@Periodo,@SueldoBase,0,GETDATE(),1);
        COMMIT;
        SELECT 'Pago del Administrador registrado.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        RAISERROR('Error al registrar el pago.',16,1);
    END CATCH
END;
GO

-- ============================================================
-- CLIENTE (schema)
-- ============================================================

CREATE OR ALTER PROCEDURE Cliente.SP_MisCompras
    @ClienteID INT, @FechaDesde DATE=NULL, @FechaHasta DATE=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.VentaID, v.Fecha, f.FacturaID, f.NumeroFactura, f.Estado AS EstadoFactura,
        s.Nombre AS Item, 'Servicio' AS Tipo, vds.Cantidad, vds.PrecioUnitario,
        vds.Cantidad*vds.PrecioUnitario AS Total
    FROM Ventas.Venta v
    JOIN Facturacion.Factura f ON f.VentaID=v.VentaID
    JOIN Ventas.VentaDetalleServicio vds ON vds.VentaID=v.VentaID
    JOIN Servicios.Servicio s ON s.ServicioID=vds.ServicioID
    WHERE v.ClienteID=@ClienteID
      AND (@FechaDesde IS NULL OR CAST(v.Fecha AS DATE)>=@FechaDesde)
      AND (@FechaHasta IS NULL OR CAST(v.Fecha AS DATE)<=@FechaHasta)
    UNION ALL
    SELECT v.VentaID, v.Fecha, f.FacturaID, f.NumeroFactura, f.Estado AS EstadoFactura,
        p.Nombre AS Item, 'Producto' AS Tipo, vdp.Cantidad, vdp.PrecioUnitario,
        vdp.Cantidad*vdp.PrecioUnitario AS Total
    FROM Ventas.Venta v
    JOIN Facturacion.Factura f ON f.VentaID=v.VentaID
    JOIN Ventas.VentaDetalleProducto vdp ON vdp.VentaID=v.VentaID
    JOIN Inventario.Producto p ON p.ProductoID=vdp.ProductoID
    WHERE v.ClienteID=@ClienteID
      AND (@FechaDesde IS NULL OR CAST(v.Fecha AS DATE)>=@FechaDesde)
      AND (@FechaHasta IS NULL OR CAST(v.Fecha AS DATE)<=@FechaHasta)
    ORDER BY v.Fecha DESC;
END;
GO

CREATE OR ALTER PROCEDURE Cliente.SP_MisPagos
    @ClienteID INT, @FechaDesde DATE=NULL, @FechaHasta DATE=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT pg.PagoID, v.Fecha, pg.Monto, mp.Nombre AS MetodoPago, f.NumeroFactura, f.Estado AS EstadoFactura
    FROM Ventas.Pago pg
    JOIN Ventas.Venta v ON v.VentaID=pg.VentaID
    JOIN Ventas.MetodoPago mp ON mp.MetodoPagoID=pg.MetodoPagoID
    JOIN Facturacion.Factura f ON f.VentaID=v.VentaID
    WHERE v.ClienteID=@ClienteID
      AND (@FechaDesde IS NULL OR CAST(v.Fecha AS DATE)>=@FechaDesde)
      AND (@FechaHasta IS NULL OR CAST(v.Fecha AS DATE)<=@FechaHasta)
    ORDER BY v.Fecha DESC;
END;
GO

PRINT 'CBB_08_stored_procedures.sql ejecutado correctamente';
GO
