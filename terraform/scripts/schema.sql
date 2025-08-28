CREATE DATABASE IF NOT EXISTS HospitalManagement;
USE HospitalManagement;

-- Hospitals Table
CREATE TABLE IF NOT EXISTS Hospitals (
    hospital_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) UNIQUE NOT NULL,
    cancer_type VARCHAR(255) NOT NULL,
    address VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE
);

-- Employees Table (Doctors, Nurses, Admins, Nurse's Boss, Assistant)
CREATE TABLE IF NOT EXISTS Employees (
    employee_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role ENUM('Doctor', 'Nurse', 'Admin', 'Nurse_Boss', 'Assistant') NOT NULL,
    specialization VARCHAR(255) NULL,
    email VARCHAR(255) UNIQUE NOT NULL, -- Used as the username
    password_hash VARCHAR(255) NOT NULL, -- Hashed password for security
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    address VARCHAR(255) NOT NULL,
    hospital_id INT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (hospital_id) REFERENCES Hospitals(hospital_id)
);

-- Patients Table
CREATE TABLE IF NOT EXISTS Patients (
    patient_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    age INT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    address VARCHAR(255) NOT NULL,
    tobacco ENUM('Yes', 'No') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Patient Employee Assignment (Junction Table for Doctor/Nurse Assignments)
CREATE TABLE IF NOT EXISTS PatientEmployeeAssignment (
    patient_employee_assignment_id INT PRIMARY KEY AUTO_INCREMENT,
    patient_id INT NOT NULL,
    employee_id INT NOT NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES Patients(patient_id),
    FOREIGN KEY (employee_id) REFERENCES Employees(employee_id)
);

-- Appointments Table
CREATE TABLE IF NOT EXISTS Appointments (
    appointment_id INT PRIMARY KEY AUTO_INCREMENT,
    patient_employee_assignment_id INT NOT NULL,
    date DATE NOT NULL,
    time TIME NOT NULL,
    status ENUM('Scheduled', 'Completed', 'Cancelled') NOT NULL,
    comments MEDIUMTEXT NULL,
    FOREIGN KEY (patient_employee_assignment_id) REFERENCES PatientEmployeeAssignment(patient_employee_assignment_id)
);

-- Medical Tests Table
CREATE TABLE IF NOT EXISTS MedicalTests (
    test_id INT PRIMARY KEY AUTO_INCREMENT,
    patient_employee_assignment_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    date_requested DATE NOT NULL,
    date_performed DATE NULL,
    date_results_ready DATE NULL,
    status ENUM('Pending', 'Completed', 'Cancelled') NOT NULL,
    report MEDIUMTEXT NULL,
    comments MEDIUMTEXT NULL,
    FOREIGN KEY (patient_employee_assignment_id) REFERENCES PatientEmployeeAssignment(patient_employee_assignment_id)
);

-- Diagnoses Table
CREATE TABLE IF NOT EXISTS Diagnoses (
    diagnosis_id INT PRIMARY KEY AUTO_INCREMENT,
    patient_employee_assignment_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    date DATE NOT NULL,
    tumor_site VARCHAR(255) NULL,
    nature_dx VARCHAR(255) NULL,
    treatment_plan MEDIUMTEXT NULL,
    comments MEDIUMTEXT NULL,
    documents MEDIUMTEXT NULL,
    FOREIGN KEY (patient_employee_assignment_id) REFERENCES PatientEmployeeAssignment(patient_employee_assignment_id)
);