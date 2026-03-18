-- ============================================================
--  Skylinks Courier & Logistics Database
--  Database: Ano
--  Company:  Skylinks (Single Mock Courier Company)
--  Compatible: SQL Server Management Studio (SSMS)
-- ============================================================

USE Ano;
GO

-- ============================================================
-- DROP TABLES (safe re-run, respects FK order)
-- ============================================================
IF OBJECT_ID('dbo.Shipments',       'U') IS NOT NULL DROP TABLE dbo.Shipments;
IF OBJECT_ID('dbo.Customers',       'U') IS NOT NULL DROP TABLE dbo.Customers;
IF OBJECT_ID('dbo.CourierServices', 'U') IS NOT NULL DROP TABLE dbo.CourierServices;
GO

-- ============================================================
-- TABLE 1: CourierServices
-- Purpose:  Defines Skylinks' service tiers.
--           Each shipment references one service tier.
-- ============================================================
CREATE TABLE dbo.CourierServices (
    CourierServiceID   INT            IDENTITY(1,1) PRIMARY KEY,
    CompanyName        NVARCHAR(100)  NOT NULL,
    ServiceName        NVARCHAR(100)  NOT NULL,
    ServiceType        NVARCHAR(50)   NOT NULL
        CHECK (ServiceType IN ('Same-Day','Overnight','Economy','Express','Road Freight','Air Freight')),
    MaxWeightKg        DECIMAL(8,2)   NOT NULL,
    BasePriceZAR       DECIMAL(10,2)  NOT NULL,
    PricePerKgZAR      DECIMAL(10,2)  NOT NULL,
    EstimatedDays      TINYINT        NOT NULL,
    IsActive           BIT            NOT NULL DEFAULT 1,
    ContactNumber      NVARCHAR(15)   NULL,
    Website            NVARCHAR(150)  NULL
);
GO

-- ============================================================
-- TABLE 2: Customers
-- Purpose:  Senders and receivers. Each shipment links to
--           this table twice (SenderCustomerID + ReceiverCustomerID).
-- ============================================================
CREATE TABLE dbo.Customers (
    CustomerID      INT            IDENTITY(1,1) PRIMARY KEY,
    CustomerType    NVARCHAR(20)   NOT NULL
        CHECK (CustomerType IN ('Business','Individual')),
    FullName        NVARCHAR(150)  NOT NULL,
    CompanyName     NVARCHAR(150)  NULL,
    EmailAddress    NVARCHAR(200)  NULL,
    PhoneNumber     NVARCHAR(20)   NOT NULL,
    AddressLine1    NVARCHAR(200)  NOT NULL,
    AddressLine2    NVARCHAR(200)  NULL,
    Suburb          NVARCHAR(100)  NOT NULL,
    City            NVARCHAR(100)  NOT NULL,
    Province        NVARCHAR(50)   NOT NULL
        CHECK (Province IN (
            'Gauteng','Western Cape','KwaZulu-Natal','Eastern Cape',
            'Limpopo','Mpumalanga','North West','Free State','Northern Cape'
        )),
    PostalCode      NCHAR(4)       NOT NULL,
    Country         NVARCHAR(50)   NOT NULL DEFAULT 'South Africa',
    CreatedDate     DATE           NOT NULL DEFAULT CAST(GETDATE() AS DATE)
);
GO

-- ============================================================
-- TABLE 3: Shipments  (Primary / Fact table)
-- Purpose:  Tracks every Skylinks parcel from booking to
--           delivery. Powers all Power BI KPIs and reports.
-- ============================================================
CREATE TABLE dbo.Shipments (
    ShipmentID             INT            IDENTITY(1,1) PRIMARY KEY,
    TrackingNumber         NVARCHAR(20)   NOT NULL UNIQUE,
    CourierServiceID       INT            NOT NULL
        CONSTRAINT FK_Shipments_CourierService
        REFERENCES dbo.CourierServices(CourierServiceID),
    SenderCustomerID       INT            NOT NULL
        CONSTRAINT FK_Shipments_Sender
        REFERENCES dbo.Customers(CustomerID),
    ReceiverCustomerID     INT            NOT NULL
        CONSTRAINT FK_Shipments_Receiver
        REFERENCES dbo.Customers(CustomerID),
    -- Parcel details
    WeightKg               DECIMAL(8,2)   NOT NULL,
    LengthCm               DECIMAL(6,1)   NULL,
    WidthCm                DECIMAL(6,1)   NULL,
    HeightCm               DECIMAL(6,1)   NULL,
    ParcelDescription      NVARCHAR(255)  NULL,
    -- Financial
    ShippingCostZAR        DECIMAL(10,2)  NOT NULL,
    InsuranceValueZAR      DECIMAL(12,2)  NULL DEFAULT 0,
    -- Dates & status
    BookingDate            DATE           NOT NULL,
    CollectionDate         DATE           NULL,
    EstimatedDeliveryDate  DATE           NULL,
    ActualDeliveryDate     DATE           NULL,
    ShipmentStatus         NVARCHAR(30)   NOT NULL DEFAULT 'Booked'
        CHECK (ShipmentStatus IN (
            'Booked','Collected','In Transit','Out for Delivery',
            'Delivered','Failed Delivery','Returned','Cancelled'
        )),
    -- Route
    OriginCity             NVARCHAR(100)  NOT NULL,
    OriginProvince         NVARCHAR(50)   NOT NULL,
    DestinationCity        NVARCHAR(100)  NOT NULL,
    DestinationProvince    NVARCHAR(50)   NOT NULL,
    -- Auto-calculated on-time flag for Power BI KPIs
    IsOnTime               AS (CASE
                                  WHEN ActualDeliveryDate IS NULL  THEN NULL
                                  WHEN ActualDeliveryDate <= EstimatedDeliveryDate THEN CAST(1 AS BIT)
                                  ELSE CAST(0 AS BIT)
                               END) PERSISTED,
    SpecialInstructions    NVARCHAR(255)  NULL,
    CreatedDate            DATETIME       NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- INDEXES for Power BI query performance
-- ============================================================
CREATE NONCLUSTERED INDEX IX_Shipments_BookingDate    ON dbo.Shipments(BookingDate);
CREATE NONCLUSTERED INDEX IX_Shipments_Status         ON dbo.Shipments(ShipmentStatus);
CREATE NONCLUSTERED INDEX IX_Shipments_Service        ON dbo.Shipments(CourierServiceID);
CREATE NONCLUSTERED INDEX IX_Shipments_OriginDest     ON dbo.Shipments(OriginCity, DestinationCity);
GO

-- ============================================================
-- INSERT: CourierServices — Skylinks service tiers (6 rows)
-- ============================================================
INSERT INTO dbo.CourierServices
    (CompanyName, ServiceName, ServiceType, MaxWeightKg, BasePriceZAR, PricePerKgZAR, EstimatedDays, ContactNumber, Website)
VALUES
('Skylinks', 'Skylinks Same-Day',     'Same-Day',     20.00,  195.00, 14.50, 1, '0860 759 5465', 'www.skylinks.co.za'),
('Skylinks', 'Skylinks Overnight',    'Overnight',    30.00,  135.00,  9.50, 1, '0860 759 5465', 'www.skylinks.co.za'),
('Skylinks', 'Skylinks Express',      'Express',      50.00,  165.00, 11.00, 2, '0860 759 5465', 'www.skylinks.co.za'),
('Skylinks', 'Skylinks Economy',      'Economy',     100.00,   85.00,  5.50, 4, '0860 759 5465', 'www.skylinks.co.za'),
('Skylinks', 'Skylinks Air Freight',  'Air Freight', 200.00,  420.00, 18.00, 1, '0860 759 5465', 'www.skylinks.co.za'),
('Skylinks', 'Skylinks Road Freight', 'Road Freight',500.00,  310.00,  3.80, 5, '0860 759 5465', 'www.skylinks.co.za');
GO

-- ============================================================
-- INSERT: Customers (50 rows)
-- Mix of businesses and individuals across all 9 provinces
-- ============================================================
INSERT INTO dbo.Customers
    (CustomerType, FullName, CompanyName, EmailAddress, PhoneNumber,
     AddressLine1, AddressLine2, Suburb, City, Province, PostalCode)
VALUES
-- Gauteng (12)
('Business',    'Thabo Nkosi',         'Nkosi Trading Pty Ltd',        'thabo@nkositrading.co.za',      '011 234 5678', '12 Jan Smuts Ave',       NULL,       'Braamfontein',    'Johannesburg',    'Gauteng',        '2001'),
('Business',    'Priya Pillay',        'Pillay Distributors',          'priya@pillaydist.co.za',        '011 876 5432', '45 Industrial Rd',       'Unit 3',   'Isando',          'Kempton Park',    'Gauteng',        '1600'),
('Individual',  'Werner van der Berg', NULL,                           'werner.vdb@gmail.com',          '082 456 7890', '7 Boekenhout St',        NULL,       'Centurion',       'Pretoria',        'Gauteng',        '0157'),
('Business',    'Lerato Dlamini',      'Dlamini Electronics',          'lerato@dlaminitech.co.za',      '010 333 4444', '88 Rivonia Rd',          NULL,       'Sandton',         'Johannesburg',    'Gauteng',        '2196'),
('Individual',  'Ayanda Mthembu',      NULL,                           'ayanda.mthembu@yahoo.com',      '073 987 6543', '33 Berea Rd',            NULL,       'Berea',           'Johannesburg',    'Gauteng',        '2198'),
('Business',    'Pieter Grobler',      'Grobler Auto Parts',           'info@groblerauto.co.za',        '012 654 3210', '5 Lynnwood Rd',          NULL,       'Lynnwood',        'Pretoria',        'Gauteng',        '0081'),
('Individual',  'Nomvula Sithole',     NULL,                           'nomvula.sithole@outlook.com',   '076 111 2233', '102 Pretoria Ave',       'Apt 4B',   'Hatfield',        'Pretoria',        'Gauteng',        '0083'),
('Business',    'Rajan Naidoo',        'Naidoo Pharma Supplies',       'rajan@naidoopharma.co.za',      '011 555 6677', '20 Germiston Rd',        NULL,       'Germiston',       'Ekurhuleni',      'Gauteng',        '1401'),
('Business',    'Musa Ndlovu',         'Ndlovu Furniture Mfg',         'musa@ndlovufurniture.co.za',    '011 491 3322', '40 Elandsfontein Rd',    NULL,       'Elandsfontein',   'Ekurhuleni',      'Gauteng',        '1406'),
('Business',    'Zanele Khumalo',      'Khumalo Confectionery',        'zanele@khumalochoc.co.za',      '011 864 5533', '15 Confectionery Park',  NULL,       'Alberton',        'Johannesburg',    'Gauteng',        '1449'),
('Individual',  'Magriet Potgieter',   NULL,                           'magriet.potgieter@gmail.com',   '078 654 3210', '6 Tambotieboom St',      NULL,       'Doringkloof',     'Pretoria',        'Gauteng',        '0154'),
('Business',    'Tshepo Molapo',       'Molapo IT Solutions',          'tshepo@molapo-it.co.za',        '012 348 7766', '99 Menlyn Dr',           NULL,       'Menlyn',          'Pretoria',        'Gauteng',        '0181'),
-- Western Cape (9)
('Business',    'Celeste du Plessis',  'Cape Gourmet Foods',           'celeste@capegourmet.co.za',     '021 448 7788', '77 Buitenkant St',       NULL,       'Gardens',         'Cape Town',       'Western Cape',   '8001'),
('Individual',  'Sipho Botha',         NULL,                           'sipho.botha@icloud.com',        '083 222 3344', '15 Long St',             'Unit 6',   'CBD',             'Cape Town',       'Western Cape',   '8000'),
('Business',    'Anwar Daniels',       'Daniels Fashion House',        'anwar@danielsfashion.co.za',    '021 987 1122', '3 Waterfront Dr',        NULL,       'V&A Waterfront',  'Cape Town',       'Western Cape',   '8002'),
('Individual',  'Helga Steenkamp',     NULL,                           'helga.s@telkomsa.net',          '072 654 9870', '28 Main Rd',             NULL,       'Paarl',           'Paarl',           'Western Cape',   '7646'),
('Business',    'Fatima Cassiem',      'Cassiem Textiles',             'fatima@cassiemtex.co.za',       '021 876 3344', '50 Industrial Crescent', NULL,       'Bellville',       'Cape Town',       'Western Cape',   '7530'),
('Individual',  'Grant Fourie',        NULL,                           'grant.fourie@gmail.com',        '084 777 8899', '9 Strand St',            NULL,       'Stellenbosch',    'Stellenbosch',    'Western Cape',   '7600'),
('Business',    'Ashraf Meer',         'Meer Medical Devices',         'ashraf@meermed.co.za',          '021 555 9900', '3 Paarden Eiland Rd',    NULL,       'Paarden Eiland',  'Cape Town',       'Western Cape',   '7405'),
('Individual',  'Kobus Venter',        NULL,                           'kobus.venter@mweb.co.za',       '082 999 1122', '11 Joubert St',          NULL,       'George',          'George',          'Western Cape',   '6529'),
('Business',    'Liezel Olivier',      'Olivier Nurseries',            'liezel@oliviernursery.co.za',   '044 874 5566', '7 Gericke St',           NULL,       'Wilderness',      'George',          'Western Cape',   '6560'),
-- KwaZulu-Natal (8)
('Business',    'Sanele Zulu',         'Zulu Logistics',               'sanele@zululogistics.co.za',    '031 456 1234', '12 Old Main Rd',         NULL,       'Pinetown',        'Durban',          'KwaZulu-Natal',  '3610'),
('Individual',  'Kavitha Reddy',       NULL,                           'kavitha.r@gmail.com',           '071 333 4455', '45 Bluff Rd',            NULL,       'Bluff',           'Durban',          'KwaZulu-Natal',  '4052'),
('Business',    'Bruce Govender',      'Govender Marine Supplies',     'bruce@govmarine.co.za',         '031 205 6677', '8 Lighthouse Rd',        NULL,       'Point',           'Durban',          'KwaZulu-Natal',  '4001'),
('Individual',  'Zodwa Cele',          NULL,                           'zodwa.cele@webmail.co.za',      '079 876 5432', '21 Umbilo Rd',           NULL,       'Umbilo',          'Durban',          'KwaZulu-Natal',  '4001'),
('Business',    'Suren Chetty',        'Chetty Wholesale',             'info@chettywholesale.co.za',    '031 309 8877', '60 Overport Dr',         NULL,       'Overport',        'Durban',          'KwaZulu-Natal',  '4091'),
('Business',    'Velile Madlala',      'Madlala Agri Exports',         'velile@madlalaagri.co.za',      '033 345 1122', '8 New England Rd',       NULL,       'PMB CBD',         'Pietermaritzburg','KwaZulu-Natal',  '3201'),
('Individual',  'Ronel Joubert',       NULL,                           'ronel.joubert@gmail.com',       '073 345 6780', '3 Amajuba St',           NULL,       'Newcastle CBD',   'Newcastle',       'KwaZulu-Natal',  '2940'),
('Individual',  'Andile Ngcobo',       NULL,                           'andile.ngcobo@yahoo.com',       '076 456 3211', '18 Umlazi Rd',           NULL,       'Umlazi',          'Durban',          'KwaZulu-Natal',  '4066'),
-- Eastern Cape (5)
('Business',    'Monwabisi Magwaza',   'Magwaza Hardware',             'mono@magwazahw.co.za',          '041 566 7788', '14 Govan Mbeki Ave',     NULL,       'PE Central',      'Gqeberha',        'Eastern Cape',   '6001'),
('Individual',  'Theresa Lötter',      NULL,                           'theresa.lotter@mweb.co.za',     '082 111 0099', '3 Settlers Way',         NULL,       'Summerstrand',    'Gqeberha',        'Eastern Cape',   '6001'),
('Business',    'Lungelo Ntshinga',    'Ntshinga Agri',                'lungelo@ntshingaagri.co.za',    '043 722 3344', '5 Fleet St',             NULL,       'EL CBD',          'East London',     'Eastern Cape',   '5201'),
('Business',    'Lungisa Tshaki',      'Tshaki Cleaning Supplies',     'lungisa@tshakiclean.co.za',     '041 452 8899', '12 Algoa Park Rd',       NULL,       'Algoa Park',      'Gqeberha',        'Eastern Cape',   '6059'),
('Business',    'Dinesh Maharaj',      'Maharaj Construction',         'dinesh@maharajcon.co.za',       '031 700 4433', '66 Sarnia Rd',           NULL,       'Pinetown',        'Durban',          'KwaZulu-Natal',  '3600'),
-- Limpopo (3)
('Business',    'Mulalo Ramavhoya',    'Ramavhoya Mining Supplies',    'mulalo@ramavhoya.co.za',        '015 291 4455', '18 Rabe St',             NULL,       'Polokwane CBD',   'Polokwane',       'Limpopo',        '0700'),
('Individual',  'Elrita Botha',        NULL,                           'elrita.botha@gmail.com',        '073 432 1100', '9 Hans van Rensburg St', NULL,       'Polokwane CBD',   'Polokwane',       'Limpopo',        '0699'),
('Individual',  'Tinyiko Maluleke',    NULL,                           'tinyiko.m@gmail.com',           '073 819 2200', '4 Kruger Park Rd',       NULL,       'Phalaborwa',      'Phalaborwa',      'Limpopo',        '1390'),
-- Mpumalanga (3)
('Business',    'Siphamandla Khumalo', 'Khumalo Timber',               'siphamandla@khumalotimber.co.za','013 243 5566','33 Samora Machel Dr',    NULL,       'Nelspruit CBD',   'Mbombela',        'Mpumalanga',     '1200'),
('Individual',  'Adri van Tonder',     NULL,                           'adri.vantonder@telkomsa.net',   '076 543 2100', '7 Kiaat St',             NULL,       'White River',     'White River',     'Mpumalanga',     '1240'),
('Business',    'Jacky Ngwenya',       'Ngwenya Steel Fabricators',    'jacky@ngwenyasteel.co.za',      '013 690 1122', '22 Steel Rd',            NULL,       'Secunda',         'Secunda',         'Mpumalanga',     '2302'),
-- North West (3)
('Business',    'Boipelo Modise',      'Modise Cattle Auctions',       'boipelo@modisecattle.co.za',    '018 381 7788', '22 Provident St',        NULL,       'Rustenburg CBD',  'Rustenburg',      'North West',     '0299'),
('Individual',  'Cornelius Swartz',    NULL,                           'cornelius.s@gmail.com',         '084 999 0011', '15 Beyers Naude Dr',     NULL,       'Klerksdorp',      'Klerksdorp',      'North West',     '2570'),
('Business',    'Kabelo Sithole',      'Sithole Transport',            'kabelo@sitholetrans.co.za',     '014 592 3311', '50 Phokeng Rd',          NULL,       'Phokeng',         'Rustenburg',      'North West',     '0335'),
-- Free State (3)
('Business',    'Nthabiseng Mokoena',  'Mokoena Office Solutions',     'nthabiseng@mokenaofc.co.za',    '051 430 6655', '10 Maitland St',         NULL,       'BFN CBD',         'Bloemfontein',    'Free State',     '9301'),
('Individual',  'Frik Oberholzer',     NULL,                           'frik.o@webmail.co.za',          '072 777 6655', '8 Parfitt Ave',          NULL,       'Westdene',        'Bloemfontein',    'Free State',     '9301'),
('Individual',  'Charmaine Wessels',   NULL,                           'charmaine.w@webmail.co.za',     '082 334 5521', '3 Murray St',            NULL,       'Welkom CBD',      'Welkom',          'Free State',     '9459'),
-- Northern Cape (3)
('Business',    'Deidre Engelbrecht',  'Engelbrecht Diesel & Gas',     'deidre@engdiesel.co.za',        '053 831 4422', '4 Barkly Rd',            NULL,       'Kimberley CBD',   'Kimberley',       'Northern Cape',  '8301'),
('Individual',  'Jacobus Marais',      NULL,                           'jacobus.marais@outlook.com',    '082 345 6789', '27 Long St',             NULL,       'Upington',        'Upington',        'Northern Cape',  '8800'),
('Business',    'Olivia Bosman',       'Bosman Gemstone Exports',      'olivia@bosmangemstones.co.za',  '053 832 9900', '9 Du Toitspan Rd',       NULL,       'Kimberley CBD',   'Kimberley',       'Northern Cape',  '8301');
GO

-- ============================================================
-- INSERT: Shipments (75 rows) — all via Skylinks
-- ServiceIDs: 1=Same-Day, 2=Overnight, 3=Express,
--             4=Economy,  5=Air Freight, 6=Road Freight
-- ============================================================
INSERT INTO dbo.Shipments
    (TrackingNumber, CourierServiceID, SenderCustomerID, ReceiverCustomerID,
     WeightKg, LengthCm, WidthCm, HeightCm, ParcelDescription,
     ShippingCostZAR, InsuranceValueZAR,
     BookingDate, CollectionDate, EstimatedDeliveryDate, ActualDeliveryDate,
     ShipmentStatus, OriginCity, OriginProvince, DestinationCity, DestinationProvince,
     SpecialInstructions)
VALUES
('SKL-2024-000001', 2,  1, 13,  3.50, 40, 30, 20, 'Electronic Components',          168.25,    500.00, '2024-01-05', '2024-01-06', '2024-01-07', '2024-01-07', 'Delivered',         'Johannesburg',    'Gauteng',        'Cape Town',       'Western Cape',  NULL),
('SKL-2024-000002', 4,  13, 21,  8.20, 60, 40, 30, 'Clothing Samples',              130.10,      0.00, '2024-01-07', '2024-01-08', '2024-01-12', '2024-01-12', 'Delivered',         'Cape Town',       'Western Cape',   'Durban',          'KwaZulu-Natal', NULL),
('SKL-2024-000003', 3, 21, 29,  1.00, 25, 20, 10, 'Legal Documents',               176.00,      0.00, '2024-01-09', '2024-01-09', '2024-01-11', '2024-01-11', 'Delivered',         'Durban',          'KwaZulu-Natal',  'Gqeberha',        'Eastern Cape',  'Signature required'),
('SKL-2024-000004', 1,  1, 12,  0.50, 20, 15, 10, 'Medical Samples',               202.25,   1000.00, '2024-01-10', '2024-01-10', '2024-01-10', '2024-01-10', 'Delivered',         'Johannesburg',    'Gauteng',        'Johannesburg',    'Gauteng',       'Fragile - handle with care'),
('SKL-2024-000005', 3,  9, 22,  5.00, 50, 40, 25, 'Cosmetic Products',             220.00,   2500.00, '2024-01-12', '2024-01-13', '2024-01-15', '2024-01-15', 'Delivered',         'Johannesburg',    'Gauteng',        'Durban',          'KwaZulu-Natal', NULL),
('SKL-2024-000006', 1,  6, 43,  2.00, 30, 25, 15, 'Office Stationery',             224.00,    250.00, '2024-01-15', '2024-01-15', '2024-01-15', '2024-01-15', 'Delivered',         'Pretoria',        'Gauteng',        'Bloemfontein',    'Free State',    NULL),
('SKL-2024-000007', 4, 17, 31, 4.50,  45, 35, 30, 'Textile Fabric Rolls',          109.75,    500.00, '2024-01-18', '2024-01-19', '2024-01-23', '2024-01-24', 'Delivered',         'Cape Town',       'Western Cape',   'East London',     'Eastern Cape',  NULL),
('SKL-2024-000008', 6, 29, 38, 55.00, 110,90, 70, 'Hardware Tools',                518.90,   1500.00, '2024-01-20', '2024-01-21', '2024-01-26', '2024-01-26', 'Delivered',         'Gqeberha',        'Eastern Cape',   'Mbombela',        'Mpumalanga',    NULL),
('SKL-2024-000009', 3,  4, 40, 15.00, 80, 60, 50, 'Auto Spare Parts',              330.00,   3000.00, '2024-01-22', '2024-01-22', '2024-01-24', '2024-01-24', 'Delivered',         'Johannesburg',    'Gauteng',        'Rustenburg',      'North West',    NULL),
('SKL-2024-000010', 6,  2, 37,100.00, 140,110,85, 'Industrial Machinery Part',      690.00,  15000.00, '2024-01-25', '2024-01-26', '2024-01-31', '2024-02-01', 'Delivered',         'Kempton Park',    'Gauteng',        'Johannesburg',    'Gauteng',       'Forklift offload required'),
('SKL-2024-000011', 2, 15, 43,  2.20, 35, 25, 15, 'Electrical Cables',             155.95,    400.00, '2024-02-01', '2024-02-02', '2024-02-03', '2024-02-03', 'Delivered',         'Cape Town',       'Western Cape',   'Cape Town',       'Western Cape',  NULL),
('SKL-2024-000012', 3, 41, 26,  6.50, 55, 40, 35, 'Security Camera Kit',           236.50,   2000.00, '2024-02-04', '2024-02-04', '2024-02-06', '2024-02-07', 'Delivered',         'Rustenburg',      'North West',     'Newcastle',       'KwaZulu-Natal', 'Do not leave unattended'),
('SKL-2024-000013', 4, 23, 26, 22.00, 90, 60, 50, 'Marine Equipment',              206.00,   5000.00, '2024-02-06', '2024-02-07', '2024-02-11', '2024-02-11', 'Delivered',         'Durban',          'KwaZulu-Natal',  'Pietermaritzburg','KwaZulu-Natal', NULL),
('SKL-2024-000014', 4, 13, 36,  3.80, 40, 30, 25, 'Agricultural Seeds',             106.90,    200.00, '2024-02-10', '2024-02-11', '2024-02-15', NULL,         'Failed Delivery',   'Cape Town',       'Western Cape',   'Cape Town',       'Western Cape',  NULL),
('SKL-2024-000015', 2, 34, 47,  1.20, 22, 18, 12, 'Mining Assay Reports',           146.40,     50.00, '2024-02-12', '2024-02-12', '2024-02-13', '2024-02-13', 'Delivered',         'Polokwane',       'Limpopo',        'Kimberley',       'Northern Cape', 'Confidential documents'),
('SKL-2024-000016', 3,  2, 26, 50.00, 100,80, 70, 'Packaged Food Goods',            715.00,   1000.00, '2024-02-14', '2024-02-15', '2024-02-17', '2024-02-18', 'Delivered',         'Kempton Park',    'Gauteng',        'Pietermaritzburg','KwaZulu-Natal', 'Keep upright'),
('SKL-2024-000017', 3, 43, 34, 10.00, 65, 50, 40, 'Office Furniture Parts',         275.00,   1800.00, '2024-02-18', '2024-02-19', '2024-02-21', '2024-02-21', 'Delivered',         'Bloemfontein',    'Free State',     'Polokwane',       'Limpopo',       NULL),
('SKL-2024-000018', 5, 28, 12,  0.80, 20, 15, 10, 'High-Value Jewellery',           431.60,   5000.00, '2024-02-20', '2024-02-20', '2024-02-21', '2024-02-21', 'Delivered',         'Durban',          'KwaZulu-Natal',  'Johannesburg',    'Gauteng',       'High value - insured'),
('SKL-2024-000019', 6, 38, 11, 200.00,160,120,100, 'Timber Planks Bundle',         1070.00,   8000.00, '2024-02-22', '2024-02-23', '2024-02-28', '2024-02-28', 'Delivered',         'Mbombela',        'Mpumalanga',     'Johannesburg',    'Gauteng',       'Heavy load'),
('SKL-2024-000020', 5, 20, 48,  4.00, 45, 35, 28, 'Nursery Seedling Kits',          490.00,    600.00, '2024-03-01', '2024-03-01', '2024-03-02', '2024-03-02', 'Delivered',         'George',          'Western Cape',   'Welkom',          'Free State',    'Perishable - urgent'),
('SKL-2024-000021', 2,  5, 22,  2.40, 32, 22, 18, 'Clothing',                       157.80,    300.00, '2024-03-04', '2024-03-05', '2024-03-06', '2024-03-07', 'Delivered',         'Johannesburg',    'Gauteng',        'Durban',          'KwaZulu-Natal', NULL),
('SKL-2024-000022', 4, 24, 41,  5.50, 50, 40, 30, 'Traditional Craft Items',        115.25,    800.00, '2024-03-06', '2024-03-07', '2024-03-11', '2024-03-11', 'Delivered',         'Durban',          'KwaZulu-Natal',  'Rustenburg',      'North West',    NULL),
('SKL-2024-000023', 3, 11, 49,  1.50, 28, 20, 15, 'IT Hardware',                    231.50,   3500.00, '2024-03-08', '2024-03-08', '2024-03-10', '2024-03-10', 'Delivered',         'Pretoria',        'Gauteng',        'Johannesburg',    'Gauteng',       NULL),
('SKL-2024-000024', 1, 14, 39,  0.40, 15, 10,  8, 'Passport & Documents',           197.00,     50.00, '2024-03-11', '2024-03-11', '2024-03-11', NULL,         'Failed Delivery',   'Cape Town',       'Western Cape',   'Johannesburg',    'Gauteng',       'ID verification required'),
('SKL-2024-000025', 4, 15, 29,  9.00, 60, 50, 35, 'Ceramic Tiles Sample',           134.50,    400.00, '2024-03-13', '2024-03-14', '2024-03-18', '2024-03-19', 'Delivered',         'Cape Town',       'Western Cape',   'Gqeberha',        'Eastern Cape',  'Fragile'),
('SKL-2024-000026', 4, 31, 46,  14.00,70, 55, 40, 'Agri Equipment Parts',           162.00,   2500.00, '2024-03-15', '2024-03-16', '2024-03-20', '2024-03-20', 'Delivered',         'East London',     'Eastern Cape',   'Kimberley',       'Northern Cape', NULL),
('SKL-2024-000027', 3, 41,  6,  18.00,85, 65, 55, 'Diesel Generator Parts',         363.00,   7500.00, '2024-03-18', '2024-03-18', '2024-03-20', '2024-03-20', 'Delivered',         'Rustenburg',      'North West',     'Pretoria',        'Gauteng',       NULL),
('SKL-2024-000028', 2, 32, 11,  2.80, 35, 28, 20, 'Dental Supplies',                161.60,    500.00, '2024-03-20', '2024-03-21', '2024-03-22', '2024-03-22', 'Delivered',         'Gqeberha',        'Eastern Cape',   'Pretoria',        'Gauteng',       'Handle carefully - medical'),
('SKL-2024-000029', 6,  2, 41, 350.00,180,140,110, 'Steel I-Beams',                1640.00,  25000.00, '2024-03-22', '2024-03-23', '2024-03-28', '2024-03-29', 'Delivered',         'Kempton Park',    'Gauteng',        'Rustenburg',      'North West',    'Crane required for offload'),
('SKL-2024-000030', 3, 25, 43,  7.00, 55, 42, 35, 'Wholesale Spices',               242.00,    800.00, '2024-04-01', '2024-04-01', '2024-04-03', '2024-04-03', 'Delivered',         'Durban',          'KwaZulu-Natal',  'Bloemfontein',    'Free State',    'Keep dry'),
('SKL-2024-000031', 1,  7,  2,  0.60, 22, 16, 12, 'SIM Cards & Vouchers',           203.70,    100.00, '2024-04-03', '2024-04-03', '2024-04-03', '2024-04-03', 'Delivered',         'Pretoria',        'Gauteng',        'Kempton Park',    'Gauteng',       NULL),
('SKL-2024-000032', 2, 17, 20,  1.80, 28, 20, 15, 'Design Portfolio Prints',        152.10,    300.00, '2024-04-05', '2024-04-06', '2024-04-07', '2024-04-08', 'Delivered',         'Cape Town',       'Western Cape',   'George',          'Western Cape',  'Do not bend'),
('SKL-2024-000033', 3, 34, 24,  11.00,65, 50, 42, 'Pump Components',                376.00,   4000.00, '2024-04-08', '2024-04-09', '2024-04-11', '2024-04-11', 'Delivered',         'Polokwane',       'Limpopo',        'Durban',          'KwaZulu-Natal', NULL),
('SKL-2024-000034', 4, 14, 34,  6.20, 52, 40, 32, 'Clothing Returns',               119.10,    600.00, '2024-04-10', '2024-04-11', '2024-04-15', NULL,         'Returned',          'Cape Town',       'Western Cape',   'Polokwane',       'Limpopo',       'Return to sender requested'),
('SKL-2024-000035', 3, 26,  5,  2.00, 30, 22, 18, 'Electronics Repair Parts',       187.00,   1000.00, '2024-04-12', '2024-04-12', '2024-04-14', '2024-04-14', 'Delivered',         'Newcastle',       'KwaZulu-Natal',  'Johannesburg',    'Gauteng',       NULL),
('SKL-2024-000036', 3, 38, 48,  7.50, 58, 44, 36, 'White River Citrus Crates',      247.50,   1200.00, '2024-04-15', '2024-04-15', '2024-04-17', '2024-04-17', 'Delivered',         'White River',     'Mpumalanga',     'Welkom',          'Free State',    'Perishable'),
('SKL-2024-000037', 2,  8, 28,  3.20, 38, 28, 22, 'Pharmaceutical Samples',         165.40,    750.00, '2024-04-18', '2024-04-19', '2024-04-20', '2024-04-20', 'Delivered',         'Ekurhuleni',      'Gauteng',        'Umlazi',          'KwaZulu-Natal', 'Cold chain - urgent'),
('SKL-2024-000038', 3, 49, 43,  1.10, 24, 18, 14, 'Security Badges & Tags',         177.10,    200.00, '2024-04-20', '2024-04-20', '2024-04-22', '2024-04-22', 'Delivered',         'Johannesburg',    'Gauteng',        'Bloemfontein',    'Free State',    NULL),
('SKL-2024-000039', 6, 26, 11, 420.00,200,150,120, 'Construction Aggregate',       1905.60,  10000.00, '2024-04-22', '2024-04-23', '2024-04-28', '2024-04-30', 'Delivered',         'Pietermaritzburg','KwaZulu-Natal',  'Johannesburg',    'Gauteng',       'Tipping truck required'),
('SKL-2024-000040', 4, 47, 15,  10.50,65, 50, 40, 'Kimberley Diamond Samples',      142.75,   5000.00, '2024-05-02', '2024-05-03', '2024-05-07', '2024-05-07', 'Delivered',         'Kimberley',       'Northern Cape',  'Cape Town',       'Western Cape',  'Insured - secure facility only'),
('SKL-2024-000041', 4, 26, 23,  4.80, 48, 36, 28, 'Baby Products',                  111.40,    600.00, '2024-05-05', '2024-05-06', '2024-05-10', '2024-05-10', 'Delivered',         'Pietermaritzburg','KwaZulu-Natal',  'Durban',          'KwaZulu-Natal', NULL),
('SKL-2024-000042', 2, 19, 30,  2.50, 34, 26, 20, 'Law Firm Documents',             158.75,    100.00, '2024-05-07', '2024-05-07', '2024-05-08', NULL,         'Returned',          'George',          'Western Cape',   'Gqeberha',        'Eastern Cape',  'Signature required - return if absent'),
('SKL-2024-000043', 2,  3, 44,  1.80, 30, 22, 16, 'Home Décor Items',               152.10,    400.00, '2024-05-09', '2024-05-10', '2024-05-11', '2024-05-12', 'Delivered',         'Pretoria',        'Gauteng',        'Pietermaritzburg','KwaZulu-Natal', NULL),
('SKL-2024-000044', 4, 41, 17,  8.00, 58, 45, 38, 'Wine Case',                      129.00,   1500.00, '2024-05-12', '2024-05-13', '2024-05-17', '2024-05-17', 'Delivered',         'Rustenburg',      'North West',     'Cape Town',       'Western Cape',  'Fragile - this side up'),
('SKL-2024-000045', 3, 25, 20, 13.50, 70, 55, 45, 'Catering Equipment',             313.50,   3000.00, '2024-05-14', '2024-05-14', '2024-05-16', '2024-05-16', 'Delivered',         'Durban',          'KwaZulu-Natal',  'George',          'Western Cape',  NULL),
('SKL-2024-000046', 1, 12, 13,  0.30, 18, 12,  8, 'USB Drives & Accessories',       199.35,    500.00, '2024-05-16', '2024-05-16', '2024-05-16', '2024-05-17', 'Delivered',         'Johannesburg',    'Gauteng',        'Cape Town',       'Western Cape',  NULL),
('SKL-2024-000047', 2,  6, 49,  7.50, 58, 44, 36, 'IT Server Components',           206.25,   8000.00, '2024-05-18', '2024-05-19', '2024-05-20', '2024-05-20', 'Delivered',         'Pretoria',        'Gauteng',        'Johannesburg',    'Gauteng',       'Do not stack'),
('SKL-2024-000048', 3, 15, 31,  9.00, 62, 48, 40, 'Craft Beer Cases',               264.00,    900.00, '2024-05-20', '2024-05-21', '2024-05-23', '2024-05-23', 'Delivered',         'Cape Town',       'Western Cape',   'East London',     'Eastern Cape',  'Fragile - bottles'),
('SKL-2024-000049', 6, 38, 40, 180.00,140,110, 90, 'Timber Doors & Windows',       994.40,   12000.00, '2024-05-22', '2024-05-23', '2024-05-28', '2024-05-29', 'Delivered',         'Mbombela',        'Mpumalanga',     'Rustenburg',      'North West',    NULL),
('SKL-2024-000050', 2, 28, 32,  2.00, 32, 24, 18, 'Art Prints',                     154.00,    600.00, '2024-05-24', '2024-05-25', '2024-05-26', '2024-05-26', 'Delivered',         'Durban',          'KwaZulu-Natal',  'Gqeberha',        'Eastern Cape',  'Do not bend'),
('SKL-2024-000051', 3,  4, 34,  1.20, 25, 18, 14, 'Lab Reagent Samples',            178.20,    300.00, '2024-06-01', '2024-06-01', '2024-06-03', '2024-06-03', 'Delivered',         'Johannesburg',    'Gauteng',        'Polokwane',       'Limpopo',       'Temperature sensitive'),
('SKL-2024-000052', 3, 33, 23, 30.00, 90, 70, 60, 'Plumbing Fittings',              415.00,   3500.00, '2024-06-03', '2024-06-04', '2024-06-06', '2024-06-06', 'Delivered',         'Pietermaritzburg','KwaZulu-Natal',  'Durban',          'KwaZulu-Natal', NULL),
('SKL-2024-000053', 2, 43, 22,  3.40, 38, 28, 22, 'Gift Hamper',                    167.30,    800.00, '2024-06-05', '2024-06-06', '2024-06-07', '2024-06-07', 'Delivered',         'Bloemfontein',    'Free State',     'Durban',          'KwaZulu-Natal', 'Gift - do not open'),
('SKL-2024-000054', 1, 11, 41,  0.50, 18, 12,  8, 'SIM Card Activation Packs',      202.75,     50.00, '2024-06-07', '2024-06-07', '2024-06-07', '2024-06-07', 'Delivered',         'Pretoria',        'Gauteng',        'Rustenburg',      'North West',    NULL),
('SKL-2024-000055', 5, 14, 49,  6.50, 54, 42, 34, 'Wedding Photography Album',      538.75,   3000.00, '2024-06-10', '2024-06-10', '2024-06-11', '2024-06-11', 'Delivered',         'Cape Town',       'Western Cape',   'Johannesburg',    'Gauteng',       'Extremely fragile - handle with care'),
('SKL-2024-000056', 2,  7, 28,  4.10, 42, 32, 26, 'Automotive Sensors',             173.95,   1200.00, '2024-06-12', '2024-06-13', '2024-06-14', '2024-06-15', 'Delivered',         'Pretoria',        'Gauteng',        'Durban',          'KwaZulu-Natal', NULL),
('SKL-2024-000057', 6,  2, 38, 250.00,160,130,100, 'HVAC Units (x2)',              1260.00,  30000.00, '2024-06-15', '2024-06-16', '2024-06-21', '2024-06-22', 'Delivered',         'Kempton Park',    'Gauteng',        'Mbombela',        'Mpumalanga',    'Specialist installation team on site'),
('SKL-2024-000058', 4, 31, 11, 20.00, 80, 60, 50, 'School Furniture',               195.00,   2500.00, '2024-06-18', '2024-06-19', '2024-06-23', '2024-06-24', 'Delivered',         'East London',     'Eastern Cape',   'Pretoria',        'Gauteng',       NULL),
('SKL-2024-000059', 4, 47, 26, 5.20,  50, 38, 28, 'Mining Safety Equipment',        113.60,   2000.00, '2024-06-20', '2024-06-21', '2024-06-25', NULL,         'Failed Delivery',   'Kimberley',       'Northern Cape',  'Newcastle',       'KwaZulu-Natal', 'Recipient unavailable'),
('SKL-2024-000060', 3, 23, 12,  2.50, 32, 24, 18, 'Marine Navigation Charts',       192.50,    500.00, '2024-06-22', '2024-06-22', '2024-06-24', '2024-06-24', 'Delivered',         'Durban',          'KwaZulu-Natal',  'Johannesburg',    'Gauteng',       NULL),
('SKL-2024-000061', 3, 20, 25,  9.00, 62, 48, 38, 'Nursery Pot Supplies',            264.00,    700.00, '2024-07-01', '2024-07-01', '2024-07-03', '2024-07-03', 'Delivered',         'George',          'Western Cape',   'Durban',          'KwaZulu-Natal', NULL),
('SKL-2024-000062', 5,  5, 14,  1.50, 28, 20, 14, 'Luxury Watch',                   434.75,  15000.00, '2024-07-04', '2024-07-05', '2024-07-06', '2024-07-06', 'Delivered',         'Johannesburg',    'Gauteng',        'Cape Town',       'Western Cape',  'High value - signature only'),
('SKL-2024-000063', 3, 34, 26,  4.60, 46, 36, 28, 'Limpopo Biltong Order',           215.60,    500.00, '2024-07-07', '2024-07-07', '2024-07-09', '2024-07-10', 'Delivered',         'Polokwane',       'Limpopo',        'Pietermaritzburg','KwaZulu-Natal', 'Perishable'),
('SKL-2024-000064', 4, 44, 19,  3.10, 38, 28, 22, 'Handmade Leather Goods',         102.05,    900.00, '2024-07-09', '2024-07-10', '2024-07-14', '2024-07-14', 'Delivered',         'Bloemfontein',    'Free State',     'George',          'Western Cape',  NULL),
('SKL-2024-000065', 1, 49, 38,  0.70, 20, 14, 10, 'Corporate Cheque Book',           205.35,     50.00, '2024-07-11', '2024-07-11', '2024-07-11', '2024-07-11', 'Delivered',         'Johannesburg',    'Gauteng',        'White River',     'Mpumalanga',    'Strictly confidential'),
('SKL-2024-000066', 6, 41, 38,  95.00,125,100, 80, 'Scaffolding Pipes Bundle',       671.00,   6000.00, '2024-07-14', '2024-07-15', '2024-07-20', '2024-07-20', 'Delivered',         'Rustenburg',      'North West',     'Mbombela',        'Mpumalanga',    'Long load flag required'),
('SKL-2024-000067', 3, 11, 43,  35.00,95, 75, 65, 'Motorcycle Parts',                550.00,   4000.00, '2024-07-16', '2024-07-17', '2024-07-19', '2024-07-21', 'Delivered',         'Johannesburg',    'Gauteng',        'Bloemfontein',    'Free State',    NULL),
('SKL-2024-000068', 4,  8, 42,  4.30, 44, 34, 26, 'Medical Prosthetics',             108.65,   8000.00, '2024-07-18', '2024-07-19', '2024-07-23', '2024-07-23', 'Delivered',         'Ekurhuleni',      'Gauteng',        'Klerksdorp',      'North West',    'Urgent medical delivery'),
('SKL-2024-000069', 3, 21, 47,  1.40, 26, 19, 13, 'Export Compliance Docs',          165.40,     50.00, '2024-07-21', '2024-07-21', '2024-07-23', '2024-07-23', 'Delivered',         'Durban',          'KwaZulu-Natal',  'Kimberley',       'Northern Cape', NULL),
('SKL-2024-000070', 2, 48, 24,  3.90, 42, 30, 24, 'Garden Products',                 172.05,    400.00, '2024-07-23', '2024-07-24', '2024-07-25', '2024-07-26', 'Delivered',         'Welkom',          'Free State',     'Durban',          'KwaZulu-Natal', NULL),
('SKL-2024-000071', 1, 15, 4,   1.20, 24, 16, 12, 'Software License Keys',           212.40,    200.00, '2024-07-25', '2024-07-25', '2024-07-25', '2024-07-25', 'Delivered',         'Cape Town',       'Western Cape',   'Johannesburg',    'Gauteng',       'Urgent - software deployment'),
('SKL-2024-000072', 5, 17, 41,  16.00,78, 60, 50, 'Solar Panel Components',          578.00,   5500.00, '2024-07-28', '2024-07-29', '2024-07-30', '2024-07-30', 'Delivered',         'Cape Town',       'Western Cape',   'Rustenburg',      'North West',    'Fragile photovoltaic cells'),
('SKL-2024-000073', 1, 40, 47,  0.40, 16, 12,  8, 'Blood Test Results',              195.00,      0.00, '2024-07-30', '2024-07-30', '2024-07-30', '2024-07-30', 'Delivered',         'Rustenburg',      'North West',     'Kimberley',       'Northern Cape', 'Medical records - confidential'),
('SKL-2024-000074', 4, 29, 20,  18.50,82, 62, 52, 'Restaurant Kitchen Equipment',    186.75,   6000.00, '2024-08-01', '2024-08-02', '2024-08-06', NULL,         'In Transit',        'Gqeberha',        'Eastern Cape',   'George',          'Western Cape',  NULL),
('SKL-2024-000075', 2, 28, 12,  2.70, 36, 26, 20, 'Printed Brochures',               160.65,    100.00, '2024-08-03', NULL,          '2024-08-05', NULL,         'Booked',            'Durban',          'KwaZulu-Natal',  'Johannesburg',    'Gauteng',       NULL);
GO

-- ============================================================
-- VERIFICATION
-- ============================================================
SELECT 'CourierServices' AS TableName, COUNT(*) AS TotalRows FROM dbo.CourierServices
UNION ALL
SELECT 'Customers',                     COUNT(*)               FROM dbo.Customers
UNION ALL
SELECT 'Shipments',                     COUNT(*)               FROM dbo.Shipments;
GO

-- Power BI-ready summary: Revenue & performance by service tier
SELECT
    cs.ServiceName,
    cs.ServiceType,
    COUNT(s.ShipmentID)                                      AS TotalShipments,
    SUM(s.ShippingCostZAR)                                   AS TotalRevenueZAR,
    ROUND(AVG(s.WeightKg), 2)                                AS AvgWeightKg,
    SUM(CASE WHEN s.IsOnTime = 1 THEN 1 ELSE 0 END)         AS OnTimeDeliveries,
    SUM(CASE WHEN s.ShipmentStatus = 'Delivered' THEN 1 ELSE 0 END) AS TotalDelivered
FROM dbo.Shipments s
JOIN dbo.CourierServices cs ON s.CourierServiceID = cs.CourierServiceID
GROUP BY cs.ServiceName, cs.ServiceType
ORDER BY TotalRevenueZAR DESC;
--Reitrivieng info from tables
SELECT * FROM customers;
SELECT * FROM Shipments;
SELECT * FROM CourierServices;

EXEC sp_rename 'Shipments.[Service type]', 'service_type', 'COLUMN';
--Total shipments By  Service type




