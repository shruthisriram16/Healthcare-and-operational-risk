USE mysql;

CREATE DATABASE hospital_db;
USE hospital_db;
SHOW DATABASES;

DROP DATABASE hospital_db;

SET GLOBAL local_infile = 1;

-- creating a patients table with patient_id as primary key.
CREATE TABLE patients(
 patient_id INT PRIMARY KEY,
 age INTEGER,
 gender VARCHAR(50),
 city VARCHAR(100),
 insurance_provider VARCHAR(50),
 chronic_flag BOOLEAN,
 registration_date DATE
);

-- creating a visit table with visit_id as primary key and patients_id as foreign key
CREATE TABLE visit(
  visit_id INT PRIMARY KEY,
  patient_id INT,
  visit_date DATE,
  department VARCHAR(50),
  visit_type VARCHAR(50),
  length_of_stay_hours DECIMAL,
  risk_score VARCHAR(50),
  doctor_id INT,
  
FOREIGN KEY (patient_id)
REFERENCES patients(patient_id)
);

-- creating a billing table with bill_id as primary key and visit_id as foreign key
CREATE TABLE bills(
 bill_id INT PRIMARY KEY,
 visit_id INT,
 billed_amount DECIMAL,
 approved_amount DECIMAL,
 claim_status VARCHAR(50),
 payment_days INTEGER,
 billing_date DATE,
 
FOREIGN KEY (visit_id)
REFERENCES visit(visit_id)
);
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE bills;
TRUNCATE TABLE visit;
TRUNCATE TABLE patients;

SET FOREIGN_KEY_CHECKS = 1;

-- loading raw csv files to sql tables
LOAD DATA LOCAL INFILE 'C:/ml_projects/capstone_project/patients.csv' 
INTO TABLE patients 
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\r\n'  -- This is the critical change
IGNORE 1 ROWS;


LOAD DATA LOCAL INFILE 'C:/ml_projects/capstone_project/visits.csv' 
INTO TABLE visit
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\r\n'  -- This is the critical change
IGNORE 1 ROWS;


LOAD DATA LOCAL INFILE 'C:/ml_projects/capstone_project/billing.csv'
INTO TABLE bills
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
  bill_id,
  visit_id,
  @billed_amount,
  @approved_amount,
  claim_status,
  @payment_days,
  billing_date
)
SET
  billed_amount = NULLIF(@billed_amount, ''),
  approved_amount = NULLIF(@approved_amount, ''),
  payment_days = NULLIF(@payment_days, '');



-- create indexes on visit_date,department, insurance_provider, and claim_status.
CREATE INDEX idx_visit_date
ON visit(visit_date);

CREATE INDEX idx_department
ON visit(department);

CREATE INDEX idx_insurance_provider
ON patients(insurance_provider);

CREATE INDEX idx_claim_status
ON bills(claim_status);

DROP TABLE bills;
DROP TABLE visit;
DROP TABLE patients;


ALTER TABLE visit MODIFY length_of_stay_hours FLOAT;










