-- ============================================================
-- COCO Salón de Belleza · SalonBelleza_CBB
-- Archivo: CBB_04_vistas.sql
-- Descripción: Vistas
-- ============================================================

USE SalonBelleza_CBB;
GO

-- Módulo Clientes
CREATE VIEW Servicios.VW_ServiciosConPrecio AS
SELECT s.ServicioID, s.Nombre, s.Descripcion, s.DuracionMin, s.Activo,
    sc.SubcategoriaID, sc.Nombre AS Subcategoria,
    c.CategoriaID, c.Nombre AS Categoria, sp.Precio
FROM Servicios.Servicio s
JOIN Servicios.SubcategoriaServicio sc ON sc.SubcategoriaID = s.SubcategoriaID
JOIN Servicios.CategoriaServicio    c  ON c.CategoriaID     = sc.CategoriaID
JOIN Servicios.ServicioPrecio       sp ON sp.ServicioID     = s.ServicioID
WHERE s.Activo = 1 AND sp.FechaFin IS NULL;
GO

CREATE VIEW Agenda.VW_CitasCompletas AS
SELECT c.CitaID, c.ClienteID, c.FechaInicio,
    cs.CitaServicioID, cs.ServicioID, s.Nombre AS Servicio, s.DuracionMin,
    cs.Orden, cs.EsParalelo, cs.FechaInicioServicio, cs.FechaFinServicio,
    cs.EmpleadoID, e.Nombre AS NombreEmpleado, e.Apellido AS ApellidoEmpleado,
    ec.EstadoID, ec.Nombre AS Estado, sp.Precio
FROM Agenda.Cita c
JOIN Agenda.CitaServicio      cs ON cs.CitaID     = c.CitaID
JOIN Servicios.Servicio       s  ON s.ServicioID  = cs.ServicioID
JOIN Personas.Persona         e  ON e.PersonaID   = cs.EmpleadoID
JOIN Agenda.EstadoCita        ec ON ec.EstadoID   = c.EstadoID
JOIN Servicios.ServicioPrecio sp ON sp.ServicioID = s.ServicioID AND sp.FechaFin IS NULL;
GO

CREATE VIEW Marketing.VW_PromocionesActivas AS
SELECT pr.PromocionID, pr.Nombre, pr.Descripcion, pr.Descuento,
    pr.FechaInicio, pr.FechaFin, s.ServicioID, s.Nombre AS ServicioAplicable,
    sp.Precio AS PrecioOriginal,
    sp.Precio * (1 - pr.Descuento / 100.0) AS PrecioConDescuento
FROM Marketing.Promocion         pr
JOIN Marketing.PromocionServicio ps ON ps.PromocionID = pr.PromocionID
JOIN Servicios.Servicio          s  ON s.ServicioID   = ps.ServicioID
JOIN Servicios.ServicioPrecio    sp ON sp.ServicioID  = s.ServicioID AND sp.FechaFin IS NULL
WHERE pr.Activo = 1
  AND pr.FechaInicio <= CAST(GETDATE() AS DATE)
  AND pr.FechaFin    >= CAST(GETDATE() AS DATE);
GO

CREATE VIEW Ventas.VW_PerfilCliente AS
SELECT p.PersonaID, p.Nombre, p.Apellido, p.Email, p.Telefono,
    p.FechaNacimiento, p.FechaRegistro, p.Activo,
    cd.Alergias, cd.Contraindicaciones, cd.NotasTecnicas
FROM Personas.Persona          p
JOIN Ventas.Cliente             c  ON c.ClienteID  = p.PersonaID
LEFT JOIN Ventas.ClienteDetalle cd ON cd.ClienteID = c.ClienteID;
GO

CREATE VIEW Ventas.VW_ComprasCliente AS
SELECT v.VentaID, v.ClienteID, v.Fecha, v.Estado AS EstadoVenta,
    s.Nombre AS Item, 'Servicio' AS Tipo,
    vds.Cantidad, vds.PrecioUnitario,
    vds.PrecioUnitario * vds.Cantidad AS Total,
    f.NumeroFactura, f.Estado AS EstadoFactura
FROM Ventas.Venta v
JOIN Ventas.VentaDetalleServicio vds ON vds.VentaID  = v.VentaID
JOIN Servicios.Servicio          s   ON s.ServicioID = vds.ServicioID
LEFT JOIN Facturacion.Factura    f   ON f.VentaID    = v.VentaID
UNION ALL
SELECT v.VentaID, v.ClienteID, v.Fecha, v.Estado AS EstadoVenta,
    p.Nombre AS Item, 'Producto' AS Tipo,
    vdp.Cantidad, vdp.PrecioUnitario,
    vdp.PrecioUnitario * vdp.Cantidad AS Total,
    f.NumeroFactura, f.Estado AS EstadoFactura
FROM Ventas.Venta v
JOIN Ventas.VentaDetalleProducto vdp ON vdp.VentaID  = v.VentaID
JOIN Inventario.Producto         p   ON p.ProductoID = vdp.ProductoID
LEFT JOIN Facturacion.Factura    f   ON f.VentaID    = v.VentaID;
GO

CREATE VIEW Notificaciones.VW_NoLeidas AS
SELECT n.NotificacionID, n.PersonaID, n.Mensaje, n.Fecha,
    tn.Nombre AS TipoNotificacion
FROM Notificaciones.Notificacion     n
JOIN Notificaciones.TipoNotificacion tn ON tn.TipoNotificacionID = n.TipoNotificacionID
WHERE n.Leido = 0;
GO

CREATE VIEW RRHH.VW_EmpleadosActivos AS
SELECT e.EmpleadoID, p.Nombre, p.Apellido,
    r.RolID, r.NombreRol, e.FechaContratacion
FROM RRHH.Empleado   e
JOIN Personas.Persona p  ON p.PersonaID   = e.EmpleadoID
JOIN RRHH.EmpleadoRol er ON er.EmpleadoID = e.EmpleadoID
JOIN RRHH.Rol         r  ON r.RolID       = er.RolID
WHERE e.Activo = 1 AND r.RolID IN (3, 4, 5, 6);
GO

-- Módulo Admin
CREATE VIEW Inventario.VW_StockBajo AS
SELECT p.ProductoID, p.Nombre, p.StockActual, p.StockMinimo,
    p.StockActual - p.StockMinimo AS Diferencia,
    ISNULL(pp.Precio, 0) AS Precio, pv.Nombre AS Proveedor
FROM Inventario.Producto          p
LEFT JOIN Inventario.ProductoPrecio    pp  ON pp.ProductoID  = p.ProductoID AND pp.FechaFin IS NULL
LEFT JOIN Inventario.ProductoProveedor ppv ON ppv.ProductoID = p.ProductoID
LEFT JOIN Inventario.Proveedor         pv  ON pv.ProveedorID = ppv.ProveedorID
WHERE p.StockActual <= p.StockMinimo AND p.Activo = 1;
GO

CREATE VIEW Admin.VW_VentasPorMes AS
SELECT YEAR(v.Fecha) AS Anio, MONTH(v.Fecha) AS Mes,
    COUNT(DISTINCT v.VentaID) AS TotalVentas,
    ISNULL(SUM(pg.Monto), 0) AS TotalIngresos,
    ISNULL(AVG(pg.Monto), 0) AS TicketPromedio
FROM Ventas.Venta v JOIN Ventas.Pago pg ON pg.VentaID = v.VentaID
GROUP BY YEAR(v.Fecha), MONTH(v.Fecha);
GO

CREATE VIEW Admin.VW_NominaVigente AS
SELECT e.EmpleadoID, p.Nombre, p.Apellido, r.NombreRol,
    ISNULL(es.SueldoBase, 0) AS SueldoBase,
    ISNULL(ec.Porcentaje, 0) AS PorcentajeComision,
    e.FechaContratacion, e.Activo
FROM RRHH.Empleado            e
JOIN Personas.Persona          p  ON p.PersonaID   = e.EmpleadoID
JOIN RRHH.EmpleadoRol          er ON er.EmpleadoID = e.EmpleadoID
JOIN RRHH.Rol                  r  ON r.RolID       = er.RolID
LEFT JOIN RRHH.EmpleadoSueldo  es ON es.EmpleadoID = e.EmpleadoID AND es.FechaFin IS NULL
LEFT JOIN RRHH.EmpleadoComision ec ON ec.EmpleadoID = e.EmpleadoID AND ec.FechaFin IS NULL
WHERE e.Activo = 1 AND r.RolID IN (3, 4, 5, 6);
GO

-- Módulo Atención
CREATE VIEW Agenda.VW_CitasHoy AS
SELECT c.CitaID, c.ClienteID,
    p.Nombre AS NombreCliente, p.Apellido AS ApellidoCliente, p.Telefono AS TelefonoCliente,
    cd.Alergias, c.FechaInicio,
    cs.CitaServicioID, cs.ServicioID, s.Nombre AS Servicio, s.DuracionMin,
    cs.FechaInicioServicio, cs.FechaFinServicio, cs.EmpleadoID,
    emp.Nombre AS NombreEmpleado, emp.Apellido AS ApellidoEmpleado,
    ec.EstadoID, ec.Nombre AS Estado, sp.Precio
FROM Agenda.Cita              c
JOIN Personas.Persona         p   ON p.PersonaID   = c.ClienteID
JOIN Agenda.CitaServicio      cs  ON cs.CitaID     = c.CitaID
JOIN Servicios.Servicio       s   ON s.ServicioID  = cs.ServicioID
JOIN Personas.Persona         emp ON emp.PersonaID = cs.EmpleadoID
JOIN Agenda.EstadoCita        ec  ON ec.EstadoID   = c.EstadoID
JOIN Servicios.ServicioPrecio sp  ON sp.ServicioID = s.ServicioID AND sp.FechaFin IS NULL
LEFT JOIN Ventas.ClienteDetalle cd ON cd.ClienteID = c.ClienteID
WHERE CAST(c.FechaInicio AS DATE) = CAST(GETDATE() AS DATE)
  AND c.EstadoID NOT IN (12, 13);
GO

CREATE VIEW Agenda.VW_SolicitudesPendientes AS
SELECT s.SolicitudID, s.ClienteID,
    p.Nombre AS NombreCliente, p.Apellido AS ApellidoCliente, p.Telefono,
    s.FechaSolicitada, s.Motivo, s.Estado, s.FechaCreacion
FROM Agenda.SolicitudEspecial s
JOIN Ventas.Cliente            c ON c.ClienteID = s.ClienteID
JOIN Personas.Persona          p ON p.PersonaID = s.ClienteID
WHERE s.Estado = 'Pendiente';
GO

CREATE VIEW RRHH.VW_ExcepcionesPendientes AS
SELECT he.ExcepcionID, he.EmpleadoID,
    p.Nombre AS NombreEmpleado, p.Apellido AS ApellidoEmpleado,
    r.NombreRol, he.Fecha, he.Disponible, he.Motivo, he.TipoSolicitud
FROM RRHH.HorarioExcepcion he
JOIN Personas.Persona       p  ON p.PersonaID   = he.EmpleadoID
JOIN RRHH.EmpleadoRol       er ON er.EmpleadoID = he.EmpleadoID
JOIN RRHH.Rol               r  ON r.RolID       = er.RolID
WHERE he.Aprobado = 0 AND he.Fecha >= CAST(GETDATE() AS DATE);
GO

-- Módulo Dueña
CREATE VIEW Duena.VW_ResumenFinanciero AS
SELECT YEAR(v.Fecha) AS Anio, MONTH(v.Fecha) AS Mes,
    ISNULL(SUM(pg.Monto), 0) AS Ingresos,
    ISNULL((SELECT SUM(pn2.SueldoBase + pn2.Comision) FROM RRHH.PagoNomina pn2
            WHERE LEFT(pn2.Periodo,4) = CAST(YEAR(v.Fecha) AS VARCHAR)
              AND CAST(RIGHT(pn2.Periodo,2) AS INT) = MONTH(v.Fecha)), 0) AS CostoNomina,
    ISNULL(SUM(pg.Monto),0) - ISNULL((SELECT SUM(pn3.SueldoBase+pn3.Comision) FROM RRHH.PagoNomina pn3
            WHERE LEFT(pn3.Periodo,4) = CAST(YEAR(v.Fecha) AS VARCHAR)
              AND CAST(RIGHT(pn3.Periodo,2) AS INT) = MONTH(v.Fecha)), 0) AS Utilidad
FROM Ventas.Venta v JOIN Ventas.Pago pg ON pg.VentaID = v.VentaID
GROUP BY YEAR(v.Fecha), MONTH(v.Fecha);
GO

CREATE VIEW Duena.VW_KPIs AS
SELECT
    ISNULL(AVG(CASE WHEN MONTH(v.Fecha)=MONTH(GETDATE()) AND YEAR(v.Fecha)=YEAR(GETDATE())
                THEN pg.Monto END), 0) AS TicketPromedio,
    CAST(SUM(CASE WHEN MONTH(c.FechaInicio)=MONTH(GETDATE()) AND YEAR(c.FechaInicio)=YEAR(GETDATE())
                   AND c.EstadoID=12 THEN 1 ELSE 0 END) * 100.0 /
         NULLIF(SUM(CASE WHEN MONTH(c.FechaInicio)=MONTH(GETDATE()) AND YEAR(c.FechaInicio)=YEAR(GETDATE())
                    THEN 1 ELSE 0 END), 0) AS DECIMAL(5,2)) AS TasaCancelacion,
    COUNT(DISTINCT CASE WHEN MONTH(cs.FechaInicioServicio)=MONTH(GETDATE())
                         AND YEAR(cs.FechaInicioServicio)=YEAR(GETDATE())
                         AND c2.EstadoID=11 THEN cs.CitaServicioID END) AS ServiciosCompletados
FROM Ventas.Venta v
JOIN Ventas.Pago              pg ON pg.VentaID = v.VentaID
CROSS JOIN Agenda.Cita        c
LEFT JOIN Agenda.CitaServicio cs ON cs.CitaID  = c.CitaID
LEFT JOIN Agenda.Cita         c2 ON c2.CitaID  = cs.CitaID;
GO

-- Módulo Personal
CREATE VIEW Agenda.VW_AgendaHoyEmpleado AS
SELECT cs.EmpleadoID, c.CitaID, c.ClienteID,
    p.Nombre AS NombreCliente, p.Apellido AS ApellidoCliente,
    s.ServicioID, s.Nombre AS Servicio, s.DuracionMin,
    cs.FechaInicioServicio, cs.FechaFinServicio, cs.Orden, cs.EsParalelo,
    ec.EstadoID, ec.Nombre AS Estado, sp.Precio,
    cd.Alergias, cd.Contraindicaciones, cd.NotasTecnicas
FROM Agenda.CitaServicio      cs
JOIN Agenda.Cita              c  ON c.CitaID     = cs.CitaID
JOIN Personas.Persona         p  ON p.PersonaID  = c.ClienteID
JOIN Servicios.Servicio       s  ON s.ServicioID = cs.ServicioID
JOIN Agenda.EstadoCita        ec ON ec.EstadoID  = c.EstadoID
JOIN Servicios.ServicioPrecio sp ON sp.ServicioID= s.ServicioID AND sp.FechaFin IS NULL
LEFT JOIN Ventas.ClienteDetalle cd ON cd.ClienteID = c.ClienteID
WHERE CAST(cs.FechaInicioServicio AS DATE) = CAST(GETDATE() AS DATE)
  AND c.EstadoID NOT IN (12, 13);
GO

CREATE VIEW RRHH.VW_SueldoVigente AS
SELECT e.EmpleadoID, p.Nombre, p.Apellido, r.NombreRol,
    es.SueldoBase, es.FechaInicio AS SueldoDesde,
    ec.Porcentaje AS PorcentajeComision, ec.FechaInicio AS ComisionDesde
FROM RRHH.Empleado           e
JOIN Personas.Persona         p  ON p.PersonaID   = e.EmpleadoID
JOIN RRHH.EmpleadoRol         er ON er.EmpleadoID = e.EmpleadoID
JOIN RRHH.Rol                 r  ON r.RolID       = er.RolID
JOIN RRHH.EmpleadoSueldo      es ON es.EmpleadoID = e.EmpleadoID AND es.FechaFin IS NULL
JOIN RRHH.EmpleadoComision    ec ON ec.EmpleadoID = e.EmpleadoID AND ec.FechaFin IS NULL
WHERE e.Activo = 1;
GO

PRINT 'CBB_04_vistas.sql ejecutado correctamente';
GO



/*USE SalonBelleza_CBB;
GO

SELECT 
    SCHEMA_NAME(schema_id) AS Esquema,
    name AS Vista
FROM sys.views
ORDER BY Esquema, Vista;*/
