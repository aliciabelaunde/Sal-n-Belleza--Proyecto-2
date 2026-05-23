USE SalonBelleza_CBB;
GO
-- ============================================================
-- MÓDULO RRHH
-- RRHH.Rol              → REPLICADA
-- RRHH.Empleado         → FRAGMENTADA
-- RRHH.EmpleadoRol      → FRAGMENTADA
-- RRHH.EmpleadoSueldo   → FRAGMENTADA
-- RRHH.EmpleadoComision → FRAGMENTADA
-- RRHH.HorarioEmpleado  → FRAGMENTADA
-- RRHH.HorarioExcepcion → FRAGMENTADA
-- RRHH.PagoNomina       → FRAGMENTADA
-- ============================================================

CREATE TABLE RRHH.Rol (
    RolID     INT         IDENTITY(1,1) PRIMARY KEY,
    NombreRol VARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE RRHH.Empleado (
    EmpleadoID        INT     PRIMARY KEY,
    FechaContratacion DATE    NOT NULL DEFAULT GETDATE(),
    Activo            BIT     NOT NULL DEFAULT 1,
    Sucursal          CHAR(3) NOT NULL DEFAULT 'CBB',
    CONSTRAINT FK_Empleado_Persona
        FOREIGN KEY (EmpleadoID) REFERENCES Personas.Persona(PersonaID)
);
GO

CREATE TABLE RRHH.EmpleadoRol (
    EmpleadoID INT NOT NULL,
    RolID      INT NOT NULL,
    PRIMARY KEY (EmpleadoID, RolID),
    CONSTRAINT FK_EmpRol_Empleado FOREIGN KEY (EmpleadoID) REFERENCES RRHH.Empleado(EmpleadoID),
    CONSTRAINT FK_EmpRol_Rol      FOREIGN KEY (RolID)      REFERENCES RRHH.Rol(RolID)
);
GO

CREATE TABLE RRHH.EmpleadoSueldo (
    EmpleadoSueldoID INT           IDENTITY PRIMARY KEY,
    EmpleadoID       INT           NOT NULL,
    SueldoBase       DECIMAL(10,2) NOT NULL CHECK (SueldoBase > 0),
    FechaInicio      DATE          NOT NULL,
    FechaFin         DATE          NULL,
    FOREIGN KEY (EmpleadoID) REFERENCES RRHH.Empleado(EmpleadoID),
    CONSTRAINT CK_EmpleadoSueldo_Fechas
        CHECK (FechaFin IS NULL OR FechaFin >= FechaInicio)
);
GO

CREATE TABLE RRHH.EmpleadoComision (
    EmpleadoComisionID INT          IDENTITY PRIMARY KEY,
    EmpleadoID         INT          NOT NULL,
    Porcentaje         DECIMAL(5,2) NOT NULL CHECK (Porcentaje >= 0 AND Porcentaje <= 100),
    FechaInicio        DATE         NOT NULL,
    FechaFin           DATE         NULL,
    FOREIGN KEY (EmpleadoID) REFERENCES RRHH.Empleado(EmpleadoID),
    CHECK (FechaFin IS NULL OR FechaFin > FechaInicio)
);
GO

CREATE TABLE RRHH.HorarioEmpleado (
    HorarioID   INT     IDENTITY PRIMARY KEY,
    EmpleadoID  INT     NOT NULL,
    DiaSemana   TINYINT NOT NULL CHECK (DiaSemana BETWEEN 1 AND 7),
    HoraEntrada TIME    NOT NULL,
    HoraSalida  TIME    NOT NULL,
    Activo      BIT     NOT NULL DEFAULT 1,
    Sucursal    CHAR(3) NOT NULL DEFAULT 'CBB',
    FOREIGN KEY (EmpleadoID) REFERENCES RRHH.Empleado(EmpleadoID),
    CHECK (HoraSalida > HoraEntrada)
);
GO

CREATE TABLE RRHH.HorarioExcepcion (
    ExcepcionID   INT          IDENTITY PRIMARY KEY,
    EmpleadoID    INT          NOT NULL,
    Fecha         DATE         NOT NULL,
    Disponible    BIT          NOT NULL DEFAULT 0,
    Motivo        VARCHAR(200),
    Aprobado      BIT          NULL,
    Estado        VARCHAR(20)  NULL,
    TipoSolicitud VARCHAR(10)  NOT NULL DEFAULT 'empleado'
                  CHECK (TipoSolicitud IN ('empleado','cliente')),
    Sucursal      CHAR(3)      NOT NULL DEFAULT 'CBB',
    FOREIGN KEY (EmpleadoID) REFERENCES RRHH.Empleado(EmpleadoID)
);
GO

CREATE TABLE RRHH.PagoNomina (
    PagoNominaID INT           IDENTITY PRIMARY KEY,
    EmpleadoID   INT           NOT NULL,
    Periodo      VARCHAR(7)    NOT NULL,
    SueldoBase   DECIMAL(10,2) NOT NULL,
    Comision     DECIMAL(10,2) NOT NULL DEFAULT 0,
    Total        AS (SueldoBase + Comision),
    FechaPago    DATETIME      NULL,
    Pagado       BIT           NOT NULL DEFAULT 0,
    Sucursal     CHAR(3)       NOT NULL DEFAULT 'CBB',
    FOREIGN KEY (EmpleadoID) REFERENCES RRHH.Empleado(EmpleadoID)
);
GO
