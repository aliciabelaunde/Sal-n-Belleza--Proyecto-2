USE SalonBelleza_CBB;
GO
-- ============================================================
-- MÓDULO AGENDA
-- Agenda.EstadoCita        → REPLICADA
-- Agenda.Cita              → FRAGMENTADA
-- Agenda.CitaServicio      → FRAGMENTADA
-- Agenda.CitaEmpleado      → FRAGMENTADA
-- Agenda.SolicitudEspecial → FRAGMENTADA
-- ============================================================

CREATE TABLE Agenda.EstadoCita (
    EstadoID INT         IDENTITY PRIMARY KEY,
    Nombre   VARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE Agenda.Cita (
    CitaID      INT      IDENTITY PRIMARY KEY,
    ClienteID   INT      NOT NULL,
    FechaInicio DATETIME NOT NULL,
    EstadoID    INT      NOT NULL,
    Sucursal    CHAR(3)  NOT NULL DEFAULT 'CBB',
    FOREIGN KEY (ClienteID) REFERENCES Ventas.Cliente(ClienteID),
    FOREIGN KEY (EstadoID)  REFERENCES Agenda.EstadoCita(EstadoID)
);
GO

CREATE TABLE Agenda.CitaServicio (
    CitaServicioID      INT      IDENTITY PRIMARY KEY,
    CitaID              INT      NOT NULL,
    ServicioID          INT      NOT NULL,
    EmpleadoID          INT      NULL,
    Orden               INT      NOT NULL DEFAULT 1,
    EsParalelo          BIT      NOT NULL DEFAULT 0,
    FechaInicioServicio DATETIME NULL,
    FechaFinServicio    DATETIME NULL,
    Sucursal            CHAR(3)  NOT NULL DEFAULT 'CBB',
    FOREIGN KEY (CitaID)     REFERENCES Agenda.Cita(CitaID),
    FOREIGN KEY (ServicioID) REFERENCES Servicios.Servicio(ServicioID),
    FOREIGN KEY (EmpleadoID) REFERENCES RRHH.Empleado(EmpleadoID)
);
GO

CREATE TABLE Agenda.CitaEmpleado (
    CitaEmpleadoID INT         IDENTITY PRIMARY KEY,
    CitaID         INT         NOT NULL,
    EmpleadoID     INT         NULL,
    TipoAsignacion VARCHAR(10) NOT NULL DEFAULT 'manual'
                   CHECK (TipoAsignacion IN ('manual','automatica')),
    Sucursal       CHAR(3)     NOT NULL DEFAULT 'CBB',
    FOREIGN KEY (CitaID)     REFERENCES Agenda.Cita(CitaID),
    FOREIGN KEY (EmpleadoID) REFERENCES RRHH.Empleado(EmpleadoID)
);
GO

CREATE TABLE Agenda.SolicitudEspecial (
    SolicitudID     INT          IDENTITY PRIMARY KEY,
    ClienteID       INT          NOT NULL,
    FechaSolicitada DATETIME     NOT NULL,
    Motivo          VARCHAR(200),
    Estado          VARCHAR(20)  NOT NULL DEFAULT 'Pendiente',
    FechaCreacion   DATETIME     NOT NULL DEFAULT GETDATE(),
    TipoSolicitud   VARCHAR(30)  NULL,
    ServicioIDs     VARCHAR(500) NULL,
    MotivoRechazo   VARCHAR(300) NULL,
    CitaID          INT          NULL,
    Sucursal        CHAR(3)      NOT NULL DEFAULT 'CBB',
    FOREIGN KEY (ClienteID) REFERENCES Ventas.Cliente(ClienteID)
);
GO