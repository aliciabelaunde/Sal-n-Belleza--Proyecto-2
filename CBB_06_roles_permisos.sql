-- ============================================================
-- COCO Salón de Belleza · SalonBelleza_CBB
-- Archivo: CBB_06_roles_permisos.sql
-- Descripción: Roles de base de datos y permisos
-- ============================================================

USE SalonBelleza_CBB;
GO

CREATE ROLE rol_auth;
CREATE ROLE rol_admin;
CREATE ROLE rol_recepcion;
CREATE ROLE rol_cliente;
CREATE ROLE rol_tecnico;
CREATE ROLE rol_duena;
GO

-- Auth
GRANT EXECUTE ON Seguridad.SP_RegistrarCliente TO rol_auth;
GRANT EXECUTE ON Seguridad.SP_Login            TO rol_auth;
GRANT SELECT  ON Seguridad.Rol                 TO rol_auth;
GRANT SELECT  ON Seguridad.UsuarioRol          TO rol_auth;
GO

-- Admin
GRANT EXECUTE ON Admin.SP_ResumenGeneral           TO rol_admin;
GRANT EXECUTE ON Admin.SP_ReporteVentas            TO rol_admin;
GRANT EXECUTE ON RRHH.SP_ListarEmpleados           TO rol_admin;
GRANT EXECUTE ON RRHH.SP_ActualizarSueldo          TO rol_admin;
GRANT EXECUTE ON RRHH.SP_ActualizarComision        TO rol_admin;
GRANT EXECUTE ON RRHH.SP_RegistrarEmpleado         TO rol_admin;
GRANT EXECUTE ON RRHH.SP_NominaDelMes              TO rol_admin;
GRANT EXECUTE ON RRHH.SP_RegistrarPagoNomina       TO rol_admin;
GRANT EXECUTE ON RRHH.SP_ListarEmpleadosSinAdmin   TO rol_admin;
GRANT EXECUTE ON RRHH.SP_ListarRolesPersonal       TO rol_admin;
GRANT EXECUTE ON Inventario.SP_ObtenerInventario   TO rol_admin;
GRANT EXECUTE ON Inventario.SP_AjustarStock        TO rol_admin;
GRANT EXECUTE ON Servicios.SP_ListarServicios      TO rol_admin;
GRANT EXECUTE ON Servicios.SP_ActualizarPrecio     TO rol_admin;
GRANT EXECUTE ON Marketing.SP_ListarPromociones    TO rol_admin;
GRANT EXECUTE ON Marketing.SP_CrearPromocion       TO rol_admin;
GO

-- Recepcion
GRANT EXECUTE ON Agenda.SP_PanelRecepcion          TO rol_recepcion;
GRANT EXECUTE ON Agenda.SP_GestionCitas            TO rol_recepcion;
GRANT EXECUTE ON Agenda.SP_ConfirmarCita           TO rol_recepcion;
GRANT EXECUTE ON Agenda.SP_CrearCitaRecepcion      TO rol_recepcion;
GRANT EXECUTE ON Agenda.SP_EditarCitaRecepcion     TO rol_recepcion;
GRANT EXECUTE ON Agenda.SP_CancelarCitaRecepcion   TO rol_recepcion;
GRANT EXECUTE ON Ventas.SP_ObtenerClientes         TO rol_recepcion;
GRANT EXECUTE ON Facturacion.SP_ObtenerFacturas    TO rol_recepcion;
GRANT EXECUTE ON Facturacion.SP_DetalleFactura     TO rol_recepcion;
GRANT EXECUTE ON Agenda.SP_ObtenerSolicitudes      TO rol_recepcion;
GRANT EXECUTE ON Agenda.SP_AprobarSolicitud        TO rol_recepcion;
GRANT EXECUTE ON Agenda.SP_RechazarSolicitud       TO rol_recepcion;
GRANT EXECUTE ON RRHH.SP_ListarExcepcionesPendientes TO rol_recepcion;
GRANT EXECUTE ON RRHH.SP_AprobarExcepcion          TO rol_recepcion;
GRANT EXECUTE ON Ventas.SP_RegistrarVenta          TO rol_recepcion;
GRANT EXECUTE ON Notificaciones.SP_ObtenerNotificaciones  TO rol_recepcion;
GRANT EXECUTE ON Notificaciones.SP_MarcarNotificacionLeida TO rol_recepcion;
GO

-- Cliente
GRANT EXECUTE ON Agenda.SP_EstadisticasCliente     TO rol_cliente;
GRANT EXECUTE ON Agenda.SP_ReservarCita            TO rol_cliente;
GRANT EXECUTE ON Agenda.SP_ObtenerCitasCliente     TO rol_cliente;
GRANT EXECUTE ON Agenda.SP_CrearSolicitudEspecial  TO rol_cliente;
GRANT EXECUTE ON Agenda.SP_ObtenerEmpleadosDisponibles TO rol_cliente;
GRANT EXECUTE ON Servicios.SP_ObtenerCatalogo      TO rol_cliente;
GRANT EXECUTE ON Ventas.SP_ObtenerComprasCliente   TO rol_cliente;
GRANT EXECUTE ON Ventas.SP_ObtenerPagosCliente     TO rol_cliente;
GRANT EXECUTE ON Marketing.SP_ObtenerPromocionesActivas TO rol_cliente;
GRANT EXECUTE ON Notificaciones.SP_ObtenerNotificaciones   TO rol_cliente;
GRANT EXECUTE ON Notificaciones.SP_MarcarNotificacionLeida TO rol_cliente;
GO

-- Tecnico
GRANT EXECUTE ON Agenda.SP_AgendaDelDia            TO rol_tecnico;
GRANT EXECUTE ON Agenda.SP_CompletarCita           TO rol_tecnico;
GRANT EXECUTE ON RRHH.SP_ObtenerHorarioEmpleado    TO rol_tecnico;
GRANT EXECUTE ON RRHH.SP_SolicitarExcepcion        TO rol_tecnico;
GRANT EXECUTE ON Ventas.SP_ObtenerClientesEmpleado TO rol_tecnico;
GRANT EXECUTE ON Ventas.SP_ObtenerFichaCliente     TO rol_tecnico;
GRANT EXECUTE ON Ventas.SP_ActualizarNotasTecnicas TO rol_tecnico;
GRANT EXECUTE ON Ventas.SP_ObtenerVentasEmpleado   TO rol_tecnico;
GRANT EXECUTE ON RRHH.SP_ObtenerSueldoComisiones   TO rol_tecnico;
GRANT EXECUTE ON RRHH.SP_ObtenerPerfilEmpleado     TO rol_tecnico;
GRANT EXECUTE ON RRHH.SP_ActualizarPerfilEmpleado  TO rol_tecnico;
GO

-- Duena
GRANT EXECUTE ON Duena.SP_ResumenEjecutivo         TO rol_duena;
GRANT EXECUTE ON Duena.SP_ReporteAnual             TO rol_duena;
GRANT EXECUTE ON Duena.SP_VerTodosLosSueldos       TO rol_duena;
GRANT EXECUTE ON Admin.SP_ReporteVentas            TO rol_duena;
GRANT EXECUTE ON Inventario.SP_ObtenerInventario   TO rol_duena;
GRANT EXECUTE ON Marketing.SP_ListarPromociones    TO rol_duena;
GRANT EXECUTE ON Servicios.SP_ListarServicios      TO rol_duena;
GRANT EXECUTE ON RRHH.SP_ListarEmpleados           TO rol_duena;
GRANT EXECUTE ON Notificaciones.SP_ObtenerNotificaciones   TO rol_duena;
GRANT EXECUTE ON Notificaciones.SP_MarcarNotificacionLeida TO rol_duena;
GO

PRINT 'CBB_06_roles_permisos.sql ejecutado correctamente';
GO