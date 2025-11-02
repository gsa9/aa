# schema-definitions.ps1
# Database Schema Definitions for Clinical Patient Data Management System
# PowerShell + Access 2003 (Jet 4.0)
#
# PURPOSE: Centralize all SQL DDL statements for tables and indexes
# USAGE: Sourced by Initialize-DatabaseSchema in database-helpers.ps1
#
# ENCODING: UTF-8 no BOM (ASCII content only - no Unicode symbols)

# ========================================
# Table: Config
# ========================================
# Stores system configuration including KEK verification hash
# VBA equivalent: tblMasterKeys (PowerShell simplification - single Config table)

$script:TABLE_CONFIG = @"
CREATE TABLE Config (
    ConfigID AUTOINCREMENT PRIMARY KEY,
    ConfigKey TEXT(50) NOT NULL,
    ConfigValue MEMO NOT NULL,
    Description TEXT(255),
    ModifiedDate DATETIME DEFAULT Now()
)
"@

$script:INDEX_CONFIG_KEY = @"
CREATE UNIQUE INDEX idx_Config_ConfigKey ON Config (ConfigKey)
"@

# ========================================
# Table: Users
# ========================================
# User accounts with password hashing (PBKDF2)
# VBA equivalent: tblUsers

$script:TABLE_USERS = @"
CREATE TABLE Users (
    UserID AUTOINCREMENT PRIMARY KEY,
    Username TEXT(50) NOT NULL,
    PasswordHash MEMO NOT NULL,
    PasswordSalt MEMO NOT NULL,
    FullName TEXT(100),
    Role TEXT(20) NOT NULL,
    IsActive YESNO NOT NULL,
    CreatedDate DATETIME NOT NULL,
    LastLogin DATETIME,
    PasswordChangedAt DATETIME NOT NULL,
    FailedLoginAttempts LONG DEFAULT 0,
    ForcePasswordChange YESNO DEFAULT 0
)
"@

$script:INDEX_USERS_USERNAME = @"
CREATE UNIQUE INDEX idx_Users_Username ON Users (Username)
"@

# ========================================
# Table: Patients
# ========================================
# Patient records with encrypted names (AES-256-CBC)
# VBA equivalent: tblPatients

$script:TABLE_PATIENTS = @"
CREATE TABLE Patients (
    PatientID AUTOINCREMENT PRIMARY KEY,
    EncryptedName MEMO NOT NULL,
    EncryptedNameIV MEMO NOT NULL,
    DateOfBirth DATE,
    Gender TEXT(10),
    CreatedDate DATETIME NOT NULL,
    ModifiedDate DATETIME
)
"@

# ========================================
# Table: ClinicalRecords
# ========================================
# Clinical records linked to patients
# VBA equivalent: tblWaitingListEntries (generalized for broader use cases)

$script:TABLE_CLINICAL_RECORDS = @"
CREATE TABLE ClinicalRecords (
    RecordID AUTOINCREMENT PRIMARY KEY,
    PatientID LONG NOT NULL,
    RecordType TEXT(50),
    RecordDate DATE NOT NULL,
    Diagnosis MEMO,
    Treatment MEMO,
    Notes MEMO,
    CreatedDate DATETIME NOT NULL,
    CreatedBy LONG NOT NULL,
    ModifiedDate DATETIME,
    ModifiedBy LONG
)
"@

$script:INDEX_CLINICAL_RECORDS_PATIENT = @"
CREATE INDEX idx_ClinicalRecords_Patient ON ClinicalRecords (PatientID)
"@

# ========================================
# Schema Summary
# ========================================
# Tables: 4 (Config, Users, Patients, ClinicalRecords)
# Indexes: 3 (unique on ConfigKey, unique on Username, index on PatientID)
#
# Creation order (dependency-safe):
# 1. Config (independent)
# 2. Users (independent)
# 3. Patients (independent)
# 4. ClinicalRecords (references Patients via PatientID)
#
# All indexes created after tables
