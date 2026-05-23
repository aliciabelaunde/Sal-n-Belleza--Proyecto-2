USE SalonBelleza_CBB;
GO
-- ============================================================
-- MÓDULO PERSONAS · FRAGMENTADA
-- ============================================================

CREATE TABLE Personas.Persona (
    PersonaID       INT          IDENTITY PRIMARY KEY,
    Nombre          VARCHAR(100) NOT NULL,
    Apellido        VARCHAR(100) NOT NULL,
    Telefono        VARCHAR(20)  NOT NULL UNIQUE,
    Email           VARCHAR(100) UNIQUE,
    FechaNacimiento DATE,
    Activo          BIT          NOT NULL DEFAULT 1,
    FechaRegistro   DATETIME     NOT NULL DEFAULT GETDATE(),
    Sucursal        CHAR(3)      NOT NULL DEFAULT 'CBB'
);
GO


