USE SalonBelleza_CBB;
GO
-- ============================================================
-- MÓDULO SEGURIDAD
-- Seguridad.Rol        → REPLICADA
-- Seguridad.Usuario    → FRAGMENTADA
-- Seguridad.UsuarioRol → FRAGMENTADA
-- ============================================================

CREATE TABLE Seguridad.Rol (
    RolID  INT         IDENTITY PRIMARY KEY,
    Nombre VARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE Seguridad.Usuario (
    UsuarioID     INT          IDENTITY PRIMARY KEY,
    PersonaID     INT          NOT NULL UNIQUE,
    Username      VARCHAR(50)  NOT NULL UNIQUE,
    PasswordHash  VARCHAR(255) NOT NULL,
    Activo        BIT          NOT NULL DEFAULT 1,
    FechaCreacion DATETIME     NOT NULL DEFAULT GETDATE(),
    Sucursal      CHAR(3)      NOT NULL DEFAULT 'CBB',
    FOREIGN KEY (PersonaID) REFERENCES Personas.Persona(PersonaID)
);
GO

CREATE TABLE Seguridad.UsuarioRol (
    UsuarioID INT NOT NULL,
    RolID     INT NOT NULL,
    PRIMARY KEY (UsuarioID, RolID),
    FOREIGN KEY (UsuarioID) REFERENCES Seguridad.Usuario(UsuarioID),
    FOREIGN KEY (RolID)     REFERENCES Seguridad.Rol(RolID)
);
GO