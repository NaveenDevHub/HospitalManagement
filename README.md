Hospital Management System

SQL Server Database Project

A complete Hospital Management System built using SQL Server to manage patients, doctors, appointments, admissions (IPD), rooms, and billing using tables, views, and stored procedures.

This project is designed for college projects, mini projects, and final year database systems.

Features

Patient registration

Doctor and department management

Appointment scheduling (OPD)

In-patient admission (IPD)

Room allocation

Automatic billing on discharge

Views for reports

Stored procedures for secure operations

Technologies Used

SQL Server

T-SQL

SSMS (SQL Server Management Studio)

Database Structure
Tables

department

doctors

patients

appointment

rooms

admission

bills

Views

v_doctor_schedule

v_patient_total_ipd

Stored Procedures

usp_scheduleappointment

usp_admitpatient

usp_dischargepatient

How the System Works

Patients register

Appointments are booked with doctors

If required, the patient is admitted (IPD)

A room is allocated

On discharge, the bill is generated automatically

Sample Stored Procedure Usage
Schedule Appointment
exec usp_scheduleappointment
    @patientid = 1,
    @doctorid = 2,
    @appointmentdate = '2025-01-20 10:30',
    @reason = 'fever';

Admit Patient
exec usp_admitpatient
    @patientid = 1,
    @roomid = 2,
    @doctorid = 1,
    @diagnosis = 'heart problem';

Discharge Patient
exec usp_dischargepatient
    @admissionid = 1;

Reports Using Views
Doctor Schedule
select * from v_doctor_schedule;

Patient IPD History
select * from v_patient_total_ipd;

Project Objectives

To automate hospital operations

To ensure accurate patient records

To reduce manual billing errors

To improve hospital data management
