create database hospitaldb;
go

use hospitaldb;
go

create table department
(
    departmentid int identity(1,1) primary key,
    departmentname varchar(100) not null unique
);

create table doctors
(
    doctorid int identity(1,1) primary key,
    firstname varchar(100) not null,
    lastname varchar(100) not null,
    phoneno varchar(20),
    email varchar(50),
    departmentid int not null,
    specialization varchar(100),
    constraint fk_doctors_department foreign key (departmentid)
    references department(departmentid)
);

create table patients
(
    patientid int identity(1,1) primary key,
    firstname varchar(50) not null,
    lastname varchar(50) not null,
    gender char(1) check (gender in ('m','f','o')),
    phoneno varchar(20),
    email varchar(100),
    addressline1 varchar(200),
    city varchar(100),
    createdat datetime2 default sysdatetime()
);

create table rooms
(
    roomid int identity(1,1) primary key,
    roomno varchar(15) not null unique,
    roomtype varchar(50) not null,
    dailyrate decimal(10,2) not null,
    status varchar(20) not null default 'available',
    constraint chk_room_status check (status in ('available','occupied','maintenance'))
);

create table appointment
(
    appointmentid int identity(1,1) primary key,
    patientid int not null,
    doctorid int not null,
    appointmentdate datetime2 not null,
    status varchar(20) not null default 'scheduled',
    reason varchar(200),
    constraint fk_appointment_patient foreign key (patientid)
    references patients(patientid),
    constraint fk_appointment_doctor foreign key (doctorid)
    references doctors(doctorid),
    constraint chk_appointment_status check (status in ('scheduled','completed','cancelled'))
);

create unique index ux_doctor_appointment
on appointment (doctorid, appointmentdate)
where status = 'scheduled';

create table admission
(
    admissionid int identity(1,1) primary key,
    patientid int not null,
    roomid int not null,
    doctorid int not null,
    admitdate datetime2 not null default sysdatetime(),
    dischargedate datetime2 null,
    diagnosis varchar(300),
    status varchar(20) not null default 'admitted',
    constraint fk_admission_patient foreign key (patientid)
    references patients(patientid),
    constraint fk_admission_room foreign key (roomid)
    references rooms(roomid),
    constraint fk_admission_doctor foreign key (doctorid)
    references doctors(doctorid),
    constraint chk_admission_status check (status in ('admitted','discharged'))
);

create table treatments
(
    treatmentid int identity(1,1) primary key,
    patientid int not null,
    doctorid int not null,
    treatmentdate datetime2 default sysdatetime(),
    diagnosis varchar(300),
    notes varchar(200),
    admissionid int null,
    constraint fk_treatment_patient foreign key (patientid)
    references patients(patientid),
    constraint fk_treatment_doctor foreign key (doctorid)
    references doctors(doctorid),
    constraint fk_treatment_admission foreign key (admissionid)
    references admission(admissionid)
);

create table bills
(
    billid int identity(1,1) primary key,
    patientid int not null,
    admissionid int not null,
    billdate datetime2 default sysdatetime(),
    amount decimal(10,2) not null,
    billtype varchar(20) not null,
    paymentstatus varchar(20) default 'unpaid',
    constraint fk_bill_patient foreign key (patientid)
    references patients(patientid),
    constraint fk_bill_admission foreign key (admissionid)
    references admission(admissionid),
    constraint chk_bill_type check (billtype in ('ipd','opd')),
    constraint chk_payment_status check (paymentstatus in ('paid','unpaid'))
);

create or alter procedure usp_scheduleappointment
@patientid int,
@doctorid int,
@appointmentdate datetime2,
@reason varchar(200)
as
begin
    set nocount on;

    if not exists (select 1 from patients where patientid = @patientid)
    begin
        raiserror ('invalid patient id',16,1);
        return;
    end

    if not exists (select 1 from doctors where doctorid = @doctorid)
    begin
        raiserror ('invalid doctor id',16,1);
        return;
    end

    if exists (
        select 1 from appointment
        where doctorid = @doctorid
        and appointmentdate = @appointmentdate
        and status = 'scheduled'
    )
    begin
        raiserror ('doctor already has appointment',16,1);
        return;
    end

    insert into appointment (patientid, doctorid, appointmentdate, reason)
    values (@patientid, @doctorid, @appointmentdate, @reason);

    select scope_identity() as appointmentid;
end;
go

create or alter procedure usp_admitpatient
@patientid int,
@roomid int,
@doctorid int,
@diagnosis varchar(300)
as
begin
    set nocount on;

    if not exists (select 1 from patients where patientid = @patientid)
    begin
        raiserror ('invalid patient id',16,1);
        return;
    end

    if not exists (select 1 from doctors where doctorid = @doctorid)
    begin
        raiserror ('invalid doctor id',16,1);
        return;
    end

    if not exists (select 1 from rooms where roomid = @roomid and status = 'available')
    begin
        raiserror ('room not available',16,1);
        return;
    end

    begin transaction;

        insert into admission (patientid, roomid, doctorid, diagnosis)
        values (@patientid, @roomid, @doctorid, @diagnosis);

        update rooms
        set status = 'occupied'
        where roomid = @roomid;

        select scope_identity() as admissionid;

    commit transaction;
end;
go

create or alter procedure usp_dischargepatient
@admissionid int
as
begin
    set nocount on;

    declare @patientid int,
            @roomid int,
            @admitdate datetime2,
            @dischargedate datetime2,
            @dailyrate decimal(10,2),
            @days int,
            @amount decimal(10,2);

    select 
        @patientid = patientid,
        @roomid = roomid,
        @admitdate = admitdate
    from admission
    where admissionid = @admissionid
    and status = 'admitted';

    if @patientid is null
    begin
        raiserror ('invalid admission id',16,1);
        return;
    end

    set @dischargedate = sysdatetime();

    select @dailyrate = dailyrate from rooms where roomid = @roomid;

    set @days = datediff(day, @admitdate, @dischargedate);
    if @days < 1 set @days = 1;

    set @amount = @days * @dailyrate;

    begin transaction;

        update admission
        set dischargedate = @dischargedate,
            status = 'discharged'
        where admissionid = @admissionid;

        update rooms
        set status = 'available'
        where roomid = @roomid;

        insert into bills (patientid, admissionid, amount, billtype)
        values (@patientid, @admissionid, @amount, 'ipd');

    commit transaction;
end;
go

create or alter view v_doctor_schedule
as
select
    d.doctorid,
    d.firstname as doctorfirstname,
    d.lastname as doctorlastname,
    dept.departmentname,
    a.appointmentid,
    a.appointmentdate,
    a.status as appointmentstatus,
    p.firstname as patientfirstname,
    p.lastname as patientlastname
from doctors d
join department dept
    on d.departmentid = dept.departmentid
left join appointment a
    on d.doctorid = a.doctorid
left join patients p
    on a.patientid = p.patientid;
go

create or alter view v_patient_total_ipd
as
select
    p.patientid,
    p.firstname,
    p.lastname,
    count(a.admissionid) as totalipd
from patients p
left join admission a
    on p.patientid = a.patientid
group by p.patientid, p.firstname, p.lastname;
go



--sample data

insert into department (departmentname) values
('cardiology'),
('neurology'),
('orthopedics'),
('general medicine');

insert into doctors (firstname, lastname, phoneno, email, departmentid, specialization) values
('arun','kumar','9876543210','arun@hosp.com',1,'heart specialist'),
('meena','sharma','9876543222','meena@hosp.com',2,'neuro specialist'),
('rajesh','rao','9876543333','rajesh@hosp.com',3,'bone specialist');


insert into patients (firstname, lastname, gender, phoneno, email, addressline1, city) values
('karthik','r','m','9000001111','karthik@gmail.com','1st street','chennai'),
('priya','s','f','9000002222','priya@gmail.com','2nd street','vellore'),
('rahul','k','m','9000003333','rahul@gmail.com','3rd street','tiruvannamalai');


insert into rooms (roomno, roomtype, dailyrate) values
('r101','general',1500),
('r102','semi deluxe',2500),
('r103','deluxe',4000);


--schedule appointment

exec usp_scheduleappointment
    @patientid = 1,
    @doctorid = 1,
    @appointmentdate = '2025-01-20 10:30',
    @reason = 'chest pain';

exec usp_scheduleappointment
    @patientid = 2,
    @doctorid = 2,
    @appointmentdate = '2025-01-20 11:00',
    @reason = 'migraine';

    --admit patient (ipd)

    exec usp_admitpatient
    @patientid = 1,
    @roomid = 1,
    @doctorid = 1,
    @diagnosis = 'heart blockage';

exec usp_admitpatient
    @patientid = 3,
    @roomid = 2,
    @doctorid = 3,
    @diagnosis = 'fracture';

    --discharge patient (bill will auto generate)
    exec usp_dischargepatient
    @admissionid = 1;

    --view generated bills

    select * from bills;

    --doctor schedule view

    select * from v_doctor_schedule;

    select * from v_doctor_schedule
where doctorfirstname = 'arun';


--total ipd count by patient
select * from v_patient_total_ipd;

select * from v_patient_total_ipd
where firstname = 'karthik';


--currently admitted patients

select a.admissionid, p.firstname, r.roomno, a.admitdate
from admission a
join patients p on a.patientid = p.patientid
join rooms r on a.roomid = r.roomid
where a.status = 'admitted';


--available rooms

select * from rooms where status = 'available';

--doctor wise patient count

select d.firstname, d.lastname, count(a.admissionid) as totalpatients
from doctors d
left join admission a on d.doctorid = a.doctorid
group by d.firstname, d.lastname;
