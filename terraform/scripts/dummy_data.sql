USE HospitalManagement;

-- Check if data already exists before inserting
SET @hospital_count = (SELECT COUNT(*) FROM Hospitals);

-- Only insert dummy data if tables are empty
-- Using INSERT IGNORE to skip duplicates gracefully

-- Insert Hospitals (only if no hospitals exist)
INSERT IGNORE INTO Hospitals (name, cancer_type, address, phone_number) 
SELECT * FROM (
  SELECT 'Hope Oncology Center' as name, 'Breast Cancer' as cancer_type, '123 Hope St' as address, '123-456-7890' as phone_number
  UNION ALL
  SELECT 'Sunrise Cancer Institute', 'Lung Cancer', '456 Sunrise Ave', '234-567-8901'
  UNION ALL  
  SELECT 'River Valley Clinic', 'Skin Cancer', '789 River Rd', '345-678-9012'
  UNION ALL
  SELECT 'Pineview Oncology', 'Colon Cancer', '321 Pineview Dr', '456-789-0123'
) AS tmp
WHERE @hospital_count = 0;

-- Insert Employees (only if no employees exist)
SET @employee_count = (SELECT COUNT(*) FROM Employees);

INSERT IGNORE INTO Employees (first_name, last_name, role, specialization, email, password_hash, phone_number, address, hospital_id)
SELECT * FROM (
  -- Doctors
  SELECT 'John' as first_name, 'Doe' as last_name, 'Doctor' as role, 'Oncology' as specialization, 'jdoe1@example.com' as email, 'hash' as password_hash, '111-111-1111' as phone_number, '12 Elm St' as address, 1 as hospital_id
  UNION ALL
  SELECT 'Jane', 'Smith', 'Doctor', 'Hematology', 'jsmith@example.com', 'hash', '222-222-2222', '34 Oak St', 2
  UNION ALL
  SELECT 'Alan', 'Grant', 'Doctor', 'Surgical Oncology', 'agrant@example.com', 'hash', '333-333-3333', '56 Maple St', 3
  UNION ALL
  SELECT 'Ellie', 'Sattler', 'Doctor', 'Radiation Oncology', 'esattler@example.com', 'hash', '444-444-4444', '78 Pine St', 4
  UNION ALL
  -- Nurses
  SELECT 'Nina', 'Singh', 'Nurse', NULL, 'nina@example.com', 'hash', '555-111-1111', '400 Wellness Blvd', 1
  UNION ALL
  SELECT 'Leo', 'Morris', 'Nurse', NULL, 'leo@example.com', 'hash', '555-222-2222', '500 Healthway Dr', 2
  UNION ALL
  SELECT 'Tina', 'Chow', 'Nurse', NULL, 'tina@example.com', 'hash', '555-333-3333', '600 Care Ln', 3
  UNION ALL
  SELECT 'Emma', 'Williams', 'Nurse', NULL, 'emma.williams@example.com', 'hash', '800-000-8765', '123 Random St', 2
  UNION ALL
  SELECT 'Ethan', 'Jones', 'Doctor', 'Pathology', 'ethan.jones@example.com', 'hash', '800-000-9483', '456 Random St', 1
  UNION ALL
  SELECT 'Ava', 'Smith', 'Doctor', 'Oncology', 'ava.smith@example.com', 'hash', '800-000-3567', '789 Random St', 3
  UNION ALL
  SELECT 'Noah', 'Brown', 'Nurse', NULL, 'noah.brown@example.com', 'hash', '800-000-1123', '101 Random St', 4
  UNION ALL
  SELECT 'Mia', 'Johnson', 'Doctor', 'Radiology', 'mia.johnson@example.com', 'hash', '800-000-2234', '202 Random St', 1
  UNION ALL
  -- Admin user
  SELECT 'Admin', 'User', 'Admin', NULL, 'admin@cpms.com', '$2b$12$oJUpjmjQSEPqLT94x7BkluHJ97AUq963OWLVnjlJvHgnckw/IDb3y', '999-999-9999', 'Admin HQ', 1
) AS tmp
WHERE @employee_count = 0;

-- Insert Patients (only if no patients exist)
SET @patient_count = (SELECT COUNT(*) FROM Patients);

INSERT IGNORE INTO Patients (first_name, last_name, age, email, phone_number, address, tobacco)
SELECT * FROM (
  SELECT 'Alice' as first_name, 'Johnson' as last_name, 45 as age, 'alice@example.com' as email, '800-000-0001' as phone_number, '1 Patient Rd' as address, 'No' as tobacco
  UNION ALL
  SELECT 'Bob', 'Williams', 60, 'bob@example.com', '800-000-0002', '2 Patient Rd', 'Yes'
  UNION ALL
  SELECT 'Cathy', 'Brown', 50, 'cathy@example.com', '800-000-0003', '3 Patient Rd', 'No'
  UNION ALL
  SELECT 'David', 'Lee', 38, 'david@example.com', '800-000-0004', '4 Patient Rd', 'Yes'
  UNION ALL
  SELECT 'Eva', 'Martinez', 55, 'eva@example.com', '800-000-0005', '5 Patient Rd', 'No'
  UNION ALL
  SELECT 'Frank', 'Garcia', 47, 'frank@example.com', '800-000-0006', '6 Patient Rd', 'Yes'
  UNION ALL
  SELECT 'Grace', 'Harris', 70, 'grace@example.com', '800-000-0007', '7 Patient Rd', 'No'
  UNION ALL
  SELECT 'Henry', 'Clark', 66, 'henry@example.com', '800-000-0008', '8 Patient Rd', 'Yes'
  UNION ALL
  SELECT 'Ivy', 'Lewis', 59, 'ivy@example.com', '800-000-0009', '9 Patient Rd', 'No'
  UNION ALL
  SELECT 'Jack', 'Walker', 40, 'jack@example.com', '800-000-0010', '10 Patient Rd', 'No'
  UNION ALL
  SELECT 'Lucas', 'Wilson', 65, 'lucas.wilson@example.com', '800-000-8012', '121 Patient Ave', 'No'
  UNION ALL
  SELECT 'Amelia', 'Davis', 59, 'amelia.davis@example.com', '800-000-8456', '322 Patient Ave', 'Yes'
  UNION ALL
  SELECT 'Mason', 'Garcia', 70, 'mason.garcia@example.com', '800-000-9564', '523 Patient Ave', 'No'
  UNION ALL
  SELECT 'Logan', 'Rodriguez', 50, 'logan.rodriguez@example.com', '800-000-6542', '624 Patient Ave', 'Yes'
  UNION ALL
  SELECT 'Liam', 'Martinez', 72, 'liam.martinez@example.com', '800-000-7854', '725 Patient Ave', 'No'
) AS tmp
WHERE @patient_count = 0;

-- Insert PatientEmployeeAssignment (only if no assignments exist)
SET @assignment_count = (SELECT COUNT(*) FROM PatientEmployeeAssignment);

INSERT IGNORE INTO PatientEmployeeAssignment (patient_id, employee_id)
SELECT * FROM (
  SELECT 1 as patient_id, 1 as employee_id UNION ALL SELECT 1, 5
  UNION ALL SELECT 2, 2 UNION ALL SELECT 2, 6
  UNION ALL SELECT 3, 3 UNION ALL SELECT 3, 7
  UNION ALL SELECT 4, 4 UNION ALL SELECT 4, 5
  UNION ALL SELECT 5, 1 UNION ALL SELECT 5, 6
  UNION ALL SELECT 6, 2 UNION ALL SELECT 6, 7
  UNION ALL SELECT 7, 3 UNION ALL SELECT 7, 5
  UNION ALL SELECT 8, 4 UNION ALL SELECT 8, 6
  UNION ALL SELECT 9, 1 UNION ALL SELECT 9, 7
  UNION ALL SELECT 10, 2 UNION ALL SELECT 10, 5
  UNION ALL SELECT 11, 2 UNION ALL SELECT 11, 5
  UNION ALL SELECT 12, 3 UNION ALL SELECT 12, 6
  UNION ALL SELECT 13, 1 UNION ALL SELECT 13, 7
  UNION ALL SELECT 14, 4 UNION ALL SELECT 14, 5
  UNION ALL SELECT 15, 3 UNION ALL SELECT 15, 6
) AS tmp
WHERE @assignment_count = 0;

-- Insert Appointments (only if no appointments exist)
SET @appointment_count = (SELECT COUNT(*) FROM Appointments);

INSERT IGNORE INTO Appointments (patient_employee_assignment_id, date, time, status, comments)
SELECT * FROM (
  SELECT 1 as patient_employee_assignment_id, '2025-04-01' as date, '09:00:00' as time, 'Scheduled' as status, 'Initial consultation' as comments
  UNION ALL SELECT 2, '2025-04-02', '10:30:00', 'Completed', 'Follow-up'
  UNION ALL SELECT 3, '2025-04-03', '11:00:00', 'Scheduled', 'Checkup'
  UNION ALL SELECT 4, '2025-04-10', '09:00:00', 'Scheduled', 'Routine checkup'
  UNION ALL SELECT 5, '2025-04-12', '10:00:00', 'Completed', 'Follow-up'
  UNION ALL SELECT 6, '2025-04-15', '11:00:00', 'Scheduled', 'Initial screening'
) AS tmp
WHERE @appointment_count = 0;

-- Insert Diagnoses (only if no diagnoses exist)
SET @diagnosis_count = (SELECT COUNT(*) FROM Diagnoses);

INSERT IGNORE INTO Diagnoses (patient_employee_assignment_id, name, date, tumor_site, nature_dx, treatment_plan, comments, documents)
SELECT * FROM (
  SELECT 1 as patient_employee_assignment_id, 'Breast Cancer' as name, '2025-03-01' as date, 'Left Breast' as tumor_site, 'Invasive' as nature_dx, 'Surgery and chemo' as treatment_plan, 'Stage II' as comments, NULL as documents
  UNION ALL SELECT 2, 'Lung Cancer', '2025-02-15', 'Right Lung', 'Non-small cell', 'Radiation therapy', 'Stage III', NULL
  UNION ALL SELECT 3, 'Breast Cancer', '2025-04-05', 'Left Breast', 'Benign', 'Observation', 'Annual scan', NULL
  UNION ALL SELECT 4, 'Lung Cancer', '2025-04-08', 'Right Lung', 'NSCLC', 'Chemotherapy', 'Urgent attention', NULL
) AS tmp
WHERE @diagnosis_count = 0;

-- Insert Medical Tests (only if no tests exist)
SET @test_count = (SELECT COUNT(*) FROM MedicalTests);

INSERT IGNORE INTO MedicalTests (patient_employee_assignment_id, name, date_requested, date_performed, date_results_ready, status, report, comments)
SELECT * FROM (
  SELECT 1 as patient_employee_assignment_id, 'MRI Scan' as name, '2025-02-10' as date_requested, '2025-02-12' as date_performed, '2025-02-14' as date_results_ready, 'Completed' as status, NULL as report, 'Initial MRI scan' as comments
  UNION ALL SELECT 2, 'Blood Test', '2025-02-20', '2025-02-21', '2025-02-22', 'Completed', NULL, 'Baseline bloodwork'
  UNION ALL SELECT 3, 'Blood Test', '2025-03-30', '2025-03-31', '2025-04-01', 'Completed', NULL, 'Routine panel'
  UNION ALL SELECT 4, 'CT Scan', '2025-04-01', '2025-04-02', '2025-04-03', 'Completed', NULL, 'Pre-diagnosis imaging'
) AS tmp
WHERE @test_count = 0;

-- Display summary of what was inserted
SELECT 
  (SELECT COUNT(*) FROM Hospitals) as total_hospitals,
  (SELECT COUNT(*) FROM Employees) as total_employees,
  (SELECT COUNT(*) FROM Patients) as total_patients,
  (SELECT COUNT(*) FROM PatientEmployeeAssignment) as total_assignments,
  (SELECT COUNT(*) FROM Appointments) as total_appointments,
  (SELECT COUNT(*) FROM Diagnoses) as total_diagnoses,
  (SELECT COUNT(*) FROM MedicalTests) as total_tests;

SELECT 'Database initialization completed - all data is idempotent' as status;