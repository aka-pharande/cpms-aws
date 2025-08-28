USE HospitalManagement;

-- Insert Hospitals
INSERT INTO Hospitals (name, cancer_type, address, phone_number) VALUES
('Hope Oncology Center', 'Breast Cancer', '123 Hope St', '123-456-7890'),
('Sunrise Cancer Institute', 'Lung Cancer', '456 Sunrise Ave', '234-567-8901'),
('River Valley Clinic', 'Skin Cancer', '789 River Rd', '345-678-9012'),
('Pineview Oncology', 'Colon Cancer', '321 Pineview Dr', '456-789-0123');

-- Insert Employees (Doctors and Nurses)
INSERT INTO Employees (first_name, last_name, role, specialization, email, password_hash, phone_number, address, hospital_id) VALUES
-- Doctors
('John', 'Doe', 'Doctor', 'Oncology', 'jdoe1@example.com', 'hash', '111-111-1111', '12 Elm St', 1),
('Jane', 'Smith', 'Doctor', 'Hematology', 'jsmith@example.com', 'hash', '222-222-2222', '34 Oak St', 2),
('Alan', 'Grant', 'Doctor', 'Surgical Oncology', 'agrant@example.com', 'hash', '333-333-3333', '56 Maple St', 3),
('Ellie', 'Sattler', 'Doctor', 'Radiation Oncology', 'esattler@example.com', 'hash', '444-444-4444', '78 Pine St', 4),
('Nina', 'Singh', 'Nurse', NULL, 'nina@example.com', 'hash', '555-111-1111', '400 Wellness Blvd', 1),
('Leo', 'Morris', 'Nurse', NULL, 'leo@example.com', 'hash', '555-222-2222', '500 Healthway Dr', 2),
('Tina', 'Chow', 'Nurse', NULL, 'tina@example.com', 'hash', '555-333-3333', '600 Care Ln', 3),
('Emma', 'Williams', 'Nurse', NULL, 'emma.williams@example.com', 'hash', '800-000-8765', '123 Random St', 2),
('Ethan', 'Jones', 'Doctor', 'Pathology', 'ethan.jones@example.com', 'hash', '800-000-9483', '456 Random St', 1),
('Ava', 'Smith', 'Doctor', 'Oncology', 'ava.smith@example.com', 'hash', '800-000-3567', '789 Random St', 3),
('Noah', 'Brown', 'Nurse', NULL, 'noah.brown@example.com', 'hash', '800-000-1123', '101 Random St', 4),
('Mia', 'Johnson', 'Doctor', 'Radiology', 'mia.johnson@example.com', 'hash', '800-000-2234', '202 Random St', 1);

-- Add Admin user
INSERT INTO Employees (first_name, last_name, role, specialization, email, password_hash, phone_number, address, hospital_id) VALUES
('Admin', 'User', 'Admin', NULL, 'admin@cpms.com', '$2b$12$oJUpjmjQSEPqLT94x7BkluHJ97AUq963OWLVnjlJvHgnckw/IDb3y', '999-999-9999', 'Admin HQ', 1);

-- Insert Patients
INSERT INTO Patients (first_name, last_name, age, email, phone_number, address, tobacco) VALUES
('Alice', 'Johnson', 45, 'alice@example.com', '800-000-0001', '1 Patient Rd', 'No'),
('Bob', 'Williams', 60, 'bob@example.com', '800-000-0002', '2 Patient Rd', 'Yes'),
('Cathy', 'Brown', 50, 'cathy@example.com', '800-000-0003', '3 Patient Rd', 'No'),
('David', 'Lee', 38, 'david@example.com', '800-000-0004', '4 Patient Rd', 'Yes'),
('Eva', 'Martinez', 55, 'eva@example.com', '800-000-0005', '5 Patient Rd', 'No'),
('Frank', 'Garcia', 47, 'frank@example.com', '800-000-0006', '6 Patient Rd', 'Yes'),
('Grace', 'Harris', 70, 'grace@example.com', '800-000-0007', '7 Patient Rd', 'No'),
('Henry', 'Clark', 66, 'henry@example.com', '800-000-0008', '8 Patient Rd', 'Yes'),
('Ivy', 'Lewis', 59, 'ivy@example.com', '800-000-0009', '9 Patient Rd', 'No'),
('Jack', 'Walker', 40, 'jack@example.com', '800-000-0010', '10 Patient Rd', 'No'),
('Lucas', 'Wilson', 65, 'lucas.wilson@example.com', '800-000-8012', '121 Patient Ave', 'No'),
('Amelia', 'Davis', 59, 'amelia.davis@example.com', '800-000-8456', '322 Patient Ave', 'Yes'),
('Mason', 'Garcia', 70, 'mason.garcia@example.com', '800-000-9564', '523 Patient Ave', 'No'),
('Logan', 'Rodriguez', 50, 'logan.rodriguez@example.com', '800-000-6542', '624 Patient Ave', 'Yes'),
('Liam', 'Martinez', 72, 'liam.martinez@example.com', '800-000-7854', '725 Patient Ave', 'No');

INSERT INTO PatientEmployeeAssignment (patient_id, employee_id) VALUES
(1, 1), (1, 5),
(2, 2), (2, 6),
(3, 3), (3, 7),
(4, 4), (4, 5), 
(5, 1), (5, 6), 
(6, 2), (6, 7),
(7, 3), (7, 5), 
(8, 4), (8, 6),
(9, 1), (9, 7),
(10, 2), (10, 5),
(11, 2), (11, 5),
(12, 3), (12, 6),
(13, 1), (13, 7),
(14, 4), (14, 5),
(15, 3), (15, 6);

-- Insert Appointments (assignments assumed to be IDs 1–10 for doctor assignments)
INSERT INTO Appointments (patient_employee_assignment_id, date, time, status, comments) VALUES
(1, '2025-04-01', '09:00:00', 'Scheduled', 'Initial consultation'),
(2, '2025-04-02', '10:30:00', 'Completed', 'Follow-up'),
(3, '2025-04-03', '11:00:00', 'Scheduled', 'Checkup'),
(4, '2025-04-10', '09:00:00', 'Scheduled', 'Routine checkup'),
(5, '2025-04-12', '10:00:00', 'Completed', 'Follow-up'),
(6, '2025-04-15', '11:00:00', 'Scheduled', 'Initial screening');

-- Insert Diagnoses
INSERT INTO Diagnoses (patient_employee_assignment_id, name, date, tumor_site, nature_dx, treatment_plan, comments, documents) VALUES
(1, 'Breast Cancer', '2025-03-01', 'Left Breast', 'Invasive', 'Surgery and chemo', 'Stage II', NULL),
(2, 'Lung Cancer', '2025-02-15', 'Right Lung', 'Non-small cell', 'Radiation therapy', 'Stage III', NULL),
(3, 'Breast Cancer', '2025-04-05', 'Left Breast', 'Benign', 'Observation', 'Annual scan', NULL),
(4, 'Lung Cancer', '2025-04-08', 'Right Lung', 'NSCLC', 'Chemotherapy', 'Urgent attention', NULL);

-- Insert Medical Tests
INSERT INTO MedicalTests (patient_employee_assignment_id, name, date_requested, date_performed, date_results_ready, status, report, comments) VALUES
(1, 'MRI Scan', '2025-02-10', '2025-02-12', '2025-02-14', 'Completed', NULL, 'Initial MRI scan'),
(2, 'Blood Test', '2025-02-20', '2025-02-21', '2025-02-22', 'Completed', NULL, 'Baseline bloodwork'),
(3, 'Blood Test', '2025-03-30', '2025-03-31', '2025-04-01', 'Completed', NULL, 'Routine panel'),
(4, 'CT Scan', '2025-04-01', '2025-04-02', '2025-04-03', 'Completed', NULL, 'Pre-diagnosis imaging');