


--Checks System for database named Library and drops it
If Exists (Select * From sys.sysdatabases Where [name] = 'LibraryDB')
Drop Database LibraryDB
Go



--Creating Database: LibraryDB
CREATE DATABASE LibraryDB;         
go

--Command lets us use current database
USE LibraryDB;
GO

create schema Library;
go

/*
Tables Creations.All Normalised to 3NF 
*/


-- Address table
CREATE TABLE Library.Address (
address_id INT PRIMARY KEY IDENTITY(1,1),
street_address NVARCHAR(100) NOT NULL, 
city NVARCHAR(50) NOT NULL,
state NVARCHAR(50) NOT NULL,
postal_code NVARCHAR(10) NOT NULL,
country NVARCHAR(50) NOT NULL
);

-- Item_types table
CREATE TABLE Library.Item_types (
item_type_id INT PRIMARY KEY,
item_type_name NVARCHAR(50) NOT NULL
);

-- Members table 
CREATE TABLE Library.Members (
    member_id INT PRIMARY KEY IDENTITY(1001,1),
    username NVARCHAR(50) UNIQUE NOT NULL,
    password VARBINARY(256) NOT NULL,
    first_name NVARCHAR(50) NOT NULL,
    last_name NVARCHAR(50) NOT NULL,
    date_of_birth DATE NOT NULL,
    email NVARCHAR(100),
    telephone_number NVARCHAR(20) UNIQUE,
    address_id INT,
    Membership_End_Date DATE,
    CONSTRAINT FK_Members_Address FOREIGN KEY (address_id) REFERENCES Library.Address(address_id),
    CONSTRAINT CK_Members_Email CHECK (email LIKE '%@%')
);

-- Function to hash password
go
CREATE FUNCTION Library.Hashing_password(@password NVARCHAR(4000))
RETURNS VARBINARY(256)
AS BEGIN
    RETURN HASHBYTES('SHA2_256', @password);
END;
go
-- Update existing password values to hashed values
UPDATE Library.Members SET password = Library.Hashing_password(password);



-- Item table
CREATE TABLE Library.Item (
item_id INT PRIMARY KEY IDENTITY(101,1),
item_title NVARCHAR(100) NOT NULL,
item_type_id INT NOT NULL,
author NVARCHAR(100) NOT NULL,
year_of_publication INT NOT NULL,
date_added DATE NOT NULL,
current_status NVARCHAR(20) NOT NULL, --avilable,loaned
lost_or_removed_date DATE,
isbn NVARCHAR(50),
CONSTRAINT FK_Item_ItemTypes FOREIGN KEY (item_type_id) 
REFERENCES Library.Item_types(item_type_id)
);

-- Book table
CREATE TABLE Library.Book (
item_id INT PRIMARY KEY,
publisher NVARCHAR(100) NOT NULL,
edition INT NOT NULL,
CONSTRAINT FK_Book_Item FOREIGN KEY 
(item_id) REFERENCES Library.Item(item_id)
);

-- Journal table
CREATE TABLE Library.Journal (
item_id INT PRIMARY KEY,
publisher NVARCHAR(100) NOT NULL,
volume INT NOT NULL,
issue INT NOT NULL,
CONSTRAINT FK_Journal_Item FOREIGN KEY 
(item_id) REFERENCES Library.Item(item_id)
);

-- DVD table
CREATE TABLE Library.DVD (
item_id INT PRIMARY KEY,
director NVARCHAR(100) NOT NULL,
duration INT NOT NULL,
CONSTRAINT FK_DVD_Item FOREIGN KEY (item_id) REFERENCES Library.Item(item_id)
);

-- Other Media table
CREATE TABLE Library.Other_Media (
item_id INT PRIMARY KEY,
media_type NVARCHAR(50) NOT NULL,
CONSTRAINT FK_Other_Media_Item FOREIGN KEY 
(item_id) REFERENCES Library.Item(item_id)
);

-- Loans table
CREATE TABLE Library.Loans (
loan_id INT PRIMARY KEY IDENTITY (1,1),
member_id INT NOT NULL,
item_id INT NOT NULL,
loan_date DATE NOT NULL,
due_date DATE NOT NULL,
return_date DATE,
overdue_fee MONEY,
CONSTRAINT FK_Loans_Members FOREIGN KEY (member_id) REFERENCES Library.Members(member_id),
CONSTRAINT FK_Loans_Item FOREIGN KEY (item_id) REFERENCES Library.Item(item_id)
);



CREATE TABLE Library.Repayments (
    repayment_id INT PRIMARY KEY IDENTITY(1,1),
    member_id INT NOT NULL,
    repayment_date DATETIME NOT NULL,
    amount_repaid MONEY NOT NULL,
    repayment_method NVARCHAR(20) NOT NULL CHECK (repayment_method IN ('cash', 'card')),
    CONSTRAINT FK_Repayments_Members FOREIGN KEY (member_id) REFERENCES Library.Members(member_id)
);





-------------------------

/*2a
Procedure Searches the catalogue for matching character strings by title. 
Results are sorted with most recent publication date first. 
This will allow them to query the catalogue looking for a specific item.
*/
GO

--Search Catalogue
		GO
		CREATE PROCEDURE Library.search_catalogue_by_title
			@title_keyword NVARCHAR(100)
		AS
		BEGIN
			SELECT Item.item_id, Item.item_title, Item.author, Item.year_of_publication, Item.date_added, Item.current_status
			FROM Library.Item
			WHERE Library.Item.item_title LIKE '%' + @title_keyword + '%'
			ORDER BY Item.year_of_publication DESC;
		END



 /*2b
 Procedure to list of all items currently on loan which have a 
 due date of lessthan five days from the current date
 */
 
GO
---Overdue Loans
CREATE PROCEDURE Library.list_overdue_loans
AS
BEGIN
    SELECT Loans.loan_id, Members.username, Item.item_title, Loans.due_date, DATEDIFF(day, 
	Loans.due_date, GETDATE()) AS days_overdue
    FROM Loans
    JOIN Members ON Loans.member_id = Members.member_id
    JOIN Item ON Loans.item_id = Item.item_id
    WHERE Loans.return_date IS NULL AND Loans.due_date < DATEADD(day, 5, GETDATE())
    ORDER BY Loans.due_date;
END


/*2c
Insert a new member into the database
*/
---Inserting new member into the database

go
CREATE PROCEDURE Library.insert_new_member
    @username NVARCHAR(50),
    @password NVARCHAR(50),
    @first_name NVARCHAR(50),
    @last_name NVARCHAR(50),
    @date_of_birth DATE,
    @email NVARCHAR(100),
    @telephone_number NVARCHAR(20),
    @street_address NVARCHAR(100),
    @city NVARCHAR(50),
    @state NVARCHAR(50),
    @postal_code NVARCHAR(10),
    @country VARCHAR(50),
    @membership_end_date DATE
AS
BEGIN
    DECLARE @address_id INT
    
    -- Check if address already exists in Address table
    SELECT @address_id = address_id FROM Address WHERE street_address = @street_address AND city = @city AND state = @state 
	AND postal_code = @postal_code AND country = @country
     -- If address does not exist, insert new address record
    IF @address_id IS NULL
    BEGIN
        INSERT INTO Address (street_address, city, state, postal_code, country)
        VALUES (@street_address, @city, @state, @postal_code, @country)
        
        SET @address_id = SCOPE_IDENTITY() -- Get newly generated address_id
    END
    -- Convert password to VARBINARY before inserting new member record with the address_id
    DECLARE @password_varbinary VARBINARY(256)
    SET @password_varbinary = CONVERT(VARBINARY(256), @password)
    
    INSERT INTO Members (username, password, first_name, last_name, date_of_birth, email, telephone_number, address_id, Membership_End_Date)
    VALUES (@username, @password_varbinary, @first_name, @last_name, @date_of_birth, @email, @telephone_number, @address_id, @membership_end_date);
END



-------------------------
/*2d
Update the details for an existing member

*/

GO
CREATE PROCEDURE Library.update_existing_member
    @username VARCHAR(50),
    @password VARCHAR(50) = NULL,
    @first_name VARCHAR(50) = NULL,
    @last_name VARCHAR(50) = NULL,
    @date_of_birth DATE = NULL,
    @email VARCHAR(100) = NULL,
    @telephone_number VARCHAR(20) = NULL,
    @address_id INT = NULL,
    @membership_end_date DATE = NULL
AS
BEGIN
    DECLARE @password_varbinary VARBINARY(256) = NULL
    IF @password IS NOT NULL
        SET @password_varbinary = CONVERT(VARBINARY(256), @password)

    UPDATE Members
    SET password = ISNULL(@password_varbinary, password), 
        first_name = ISNULL(@first_name, first_name), 
        last_name = ISNULL(@last_name, last_name), 
        date_of_birth = ISNULL(@date_of_birth, date_of_birth), 
        email = ISNULL(@email, email), 
        telephone_number = ISNULL(@telephone_number, telephone_number), 
        address_id = ISNULL(@address_id, address_id), 
        Membership_End_Date = ISNULL(@membership_end_date, Membership_End_Date)
    WHERE username = @username;
END





------------------------

/*3
 View to show the loan history, showing all previous and currentloans, 
 and including details of the item borrowed, borrowed date, 
 due date and anyassociated fines for each loan.
*/

GO
CREATE VIEW Library.Loan_History 
AS
SELECT Loans.loan_id, Members.username, Item.item_title, Loans.loan_date, Loans.due_date,
Loans.return_date, Loans.overdue_fee
FROM Library.Loans
INNER JOIN Library.Members ON Loans.member_id = Members.member_id
INNER JOIN Library.Item ON Loans.item_id = Item.item_id;
GO


-----------------------

/*4
 Trigger to change current status of an item automatically updates toAvailable when the book is returned

*/

GO
CREATE TRIGGER Library.item_returned
ON Library.Loans
AFTER INSERT
AS
BEGIN
  UPDATE Library.Item
  SET current_status = CASE 
                          WHEN inserted.return_date IS NOT NULL THEN 'Available'
                          ELSE 'On loan'
                      END
  FROM Library.Item
  INNER JOIN inserted ON Item.item_id = inserted.item_id
END;
GO 


--------------------

/*5
Function which allows the Library to identify 
the total number of loans made on a specified date.

*/
--total loans on specific date

GO
CREATE FUNCTION Library.loans_on_date (@loan_date DATE)
RETURNS table
AS
return
    (
    SELECT loan_date, COUNT(*) as loan_count
    FROM Library.Loans
    WHERE loan_date = @loan_date
	group by loan_date
    )
GO



-----------------

/*6
Inserting some records into each of the tables. Data inputed allows us to adequately test that 
all SELECT queries, user-defined functions, stored procedures, and triggers are working as expected 

*/

BEGIN TRANSACTION;

-- Inserting Into Address table
INSERT INTO Library.Address (street_address, city, state, postal_code, country)
VALUES
( '123 Main St', 'New York', 'NY', '10001', 'USA'),
( '456 Elm St', 'Los Angeles', 'CA', '90001', 'USA'),
('789 Oak St', 'Chicago', 'IL', '60601', 'USA');

--Insert Into Members table
INSERT INTO Library.Members (username, password, first_name, last_name, date_of_birth, email, telephone_number, address_id, Membership_End_Date)
VALUES
('jdberker',CONVERT(varbinary(256), 'qwerty'), 'John', 'Berker', '1990-01-24', 'jberks4real@yahoo.com', '123-456-7890', '1', NULL),
('ronaldo', CONVERT(varbinary(256), 'goat'), 'Cristiano', 'Ronaldo', '1988-06-06', 'ronaldo@gmail.com', '987-654-3210', '2', '2022-12-31'),
('chrisbrown', CONVERT(varbinary(256), 'mypasswordy'), 'Chris', 'Brown', '2000-03-20', 'chrissybrown@gmail.com', '555-555-5555', '3', NULL);

--Inserting Into Item_types table
INSERT INTO Library.Item_types (item_type_id, item_type_name)
VALUES
(1, 'Book'),
(2, 'Journal'),
(3, 'DVD'),
(4, 'Other Media');

--Inserting Into Item table
INSERT INTO Library.Item (item_title, item_type_id, author, year_of_publication, date_added, current_status, lost_or_removed_date, isbn)
VALUES
( 'Six of Crows', 1, 'Leigh Bardugo', 1925, '2022-01-01', 'available', NULL, '978-0-7475-3268-3'),
('National Geographic', 2, 'Various', 2022, '2022-02-01', 'On Loan', NULL, NULL),
('The Dark Knight', 3, 'Christopher Nolan', 2008, '2022-03-01', 'available', NULL, NULL),
( 'Sherlock Holmes',1,'Arthur Conan Doyle','1987','2023-04-15','available',NULL,'0987644556' ),
('Sherlock Holmes 2',1,'Arthur Conan Doyle','1988','2023-08-15','available',NULL,'0987667756' ),
( 'Nature Research', 2, 'Biology Dpt UoS',2022,'2023-04-20','available',NULL,NULL),
('Science News',2, 'CNN',2020,'2023-11-20','available',NULL,NULL),
('Kill Bill' , 3, 'Quentin Tarantino', 2007, '2022-03-01', 'available', NULL, NULL),
('The Mist Documentary',3, 'Steven Spielberg', 2018, '2022-03-01', 'available', NULL, NULL),
('The Complete works of Author Conan Doyle',4, 'Arthur Conan Doyle', 1980, '2022-03-01', 'available', NULL, NULL),
('Harry potter complete E-book',4, 'JK-Rowling', 2000, '2022-03-11', 'available', NULL, NULL),
('Rihanna Complete discography',3, 'Robyn Rihanna Fenty', 2010, '2012-03-01', 'available', NULL, NULL);

-- Inserting Into Book table
INSERT INTO Library.Book (item_id, publisher, edition)
VALUES
(101, 'Charles Scribners Sons', 2),
(104, 'Penguin Books', 1),
(105, 'Penguin Books', 2);

--Inserting Into Journal table
INSERT INTO Library.Journal (item_id, publisher, volume, issue)
VALUES
(102, 'National Geographic Society', 241, 4),
(106, 'Nature Research', 595, 7867),
(107, 'Science News', 189, 2);

--Inserting Into DVD table
INSERT INTO Library.DVD (item_id, director, duration)
VALUES
(103, 'Christopher Nolan', 152),
(108, 'Quentin Tarantino', 154),
(109, 'Steven Spielberg', 195);

-- Inserting Into Other Media table
INSERT INTO Library.Other_Media (item_id, media_type)
VALUES
(110, 'Audiobook'),
(111, 'E-book'),
(112, 'Music CD');

--Inserting Into loans
INSERT INTO Library.loans (member_id, item_id, loan_date, due_date, return_date, overdue_fee)
VALUES ( '1001', '102', '2023-03-01', '2023-04-04', NULL, NULL),
       ('1002', '103', '2022-03-01', '2023-04-01', '2023-04-04', 0.50),
       ('1003', '104', '2022-03-01', '2023-04-01', NULL, NULL);


IF @@ERROR <> 0
BEGIN
    ROLLBACK TRANSACTION;
    PRINT 'Error Transaction rolled back.';
END
ELSE
BEGIN
    COMMIT TRANSACTION;
    PRINT 'Transaction committed.';
END


GO

/*
Testing Library Procedures,Functions and Views

*/
-- 2a Search catalogue by title
Exec Library.search_catalogue_by_title @title_keyword = 'Harry Potter';


GO
--2b Show Overdue Loans
Exec Library.list_overdue_loans;

GO
--2c testing inserting members
EXEC Library.insert_new_member 
    @username = 'patwatts',
    @password = 'pattywatty',
    @first_name = 'Patrick',
    @last_name = 'Watts',
    @date_of_birth = '1990-01-01',
    @email = 'pattywatts@yahoomail.com',
    @telephone_number = '07427369944',
    @street_address = '22 Boulevard St',
    @city = 'Anytown',
    @state = 'CA',
    @postal_code = '12345',
    @country = 'USA',
    @membership_end_date = '2024-03-31';
GO
--2d testing update
EXEC Library.update_existing_member  @username = 'ronaldo',
@email = 'cristianoronaldosemail@gmail.com';

---3 Testing Loan View
Select * from Library.Loan_History 
GO
--4Testing Trigger
insert into Library.Item ( item_title, item_type_id, author, year_of_publication, date_added, current_status, lost_or_removed_date, isbn)
values
( 'Complete Books of William ',1, 'William Shakespear', 1987, '2012-03-01', ' On Loan ', NULL, NULL);

select * from Library.Item; -- show table before trigger
INSERT INTO Library.loans (member_id, item_id, loan_date, due_date, return_date, overdue_fee)
VALUES (1002,113, '2023-03-01', '2022-01-15', '2023-01-11', NULL);
Select * from Library.Item;    ---show table after trigger
GO

--5Testing Function to find total loans on specific date	 
SELECT* from Library.loans_on_date ('2022-03-01')


GO
/* Additional Functionalities

*/
---Calculate overdue fee
 

go
CREATE PROCEDURE Library.CalculateOverdueFees
AS
BEGIN
    DECLARE @today DATE
    SET @today = GETDATE()
    
    UPDATE Library.Loans
    SET overdue_fee = DATEDIFF(DAY, due_date, @today) * 0.1
    WHERE return_date IS NULL AND @today > due_date;
END;


exec Library.CalculateOverdueFees;

--Check Item Availability
--Update repayments and overdue fine

GO
CREATE PROCEDURE Library.ProcessRepayment
@member_id INT,
@repayment_amount MONEY,
@repayment_method NVARCHAR(20)
AS
BEGIN
-- Calculate the current overdue fee for the member
DECLARE @overdue_fee MONEY = (SELECT SUM(overdue_fee) FROM Library.Loans 
	WHERE member_id = @member_id AND return_date IS NULL)
-- Check if the repayment amount is greater than or equal to the overdue fee
IF @repayment_amount >= @overdue_fee
BEGIN
    -- Update all open loans for the member with the returned items
    UPDATE Library.Loans SET return_date = GETDATE(), overdue_fee = 0 
    WHERE member_id = @member_id AND return_date IS NULL

    -- Insert a new repayment record for the member
    INSERT INTO Library.Repayments (member_id, repayment_date, amount_repaid, repayment_method)
    VALUES (@member_id, GETDATE(), @overdue_fee, @repayment_method)
END
ELSE
BEGIN
    -- Update the overdue fee for all open loans for the member
    UPDATE Library.Loans SET overdue_fee = @overdue_fee - @repayment_amount
    WHERE member_id = @member_id AND return_date IS NULL

    -- Insert a new repayment record for the member
    INSERT INTO Library.Repayments (member_id, repayment_date, amount_repaid, repayment_method)
    VALUES (@member_id, GETDATE(), @repayment_amount, @repayment_method)
 END
END

EXEC Library.ProcessRepayment @member_id = 1001, @repayment_amount = 1.00, @repayment_method = 'card'


