DROP DATABASE IF EXISTS trgovina;
CREATE DATABASE trgovina;
USE trgovina;

-- STVARANJE KORISNIKA
CREATE USER IF NOT EXISTS 'web'@'localhost' IDENTIFIED BY 'web';
GRANT ALL PRIVILEGES ON trgovina.* TO 'web'@'localhost';
REVOKE DROP ON trgovina.* FROM 'web'@'localhost';
FLUSH PRIVILEGES;

/*******************************************************************************
		STVARANJE TABLICA
*******************************************************************************/

CREATE TABLE klub (
	id INT AUTO_INCREMENT PRIMARY KEY,
    razina VARCHAR(50) NOT NULL,
    popust INT NOT NULL
);

CREATE TABLE lokacija (
	id INT AUTO_INCREMENT PRIMARY KEY,
    grad VARCHAR(50) NOT NULL
);

CREATE TABLE odjel (
	id INT AUTO_INCREMENT PRIMARY KEY,
    naziv VARCHAR(100) NOT NULL
);

CREATE TABLE odjel_na_lokaciji (
	id INT AUTO_INCREMENT PRIMARY KEY,
    odjel_id INT NOT NULL,
    lokacija_id INT NOT NULL,
    FOREIGN KEY (odjel_id) REFERENCES odjel(id),
    FOREIGN KEY (lokacija_id) REFERENCES lokacija(id)
);

CREATE TABLE zaposlenik (
	id INT AUTO_INCREMENT PRIMARY KEY,
    ime VARCHAR(50) NOT NULL,
    prezime VARCHAR(50) NOT NULL,
    mjesto_rada INT NOT NULL, -- (odjel_na_lokaciji id)
    placa DECIMAL(10, 2) NOT NULL,
    spol CHAR(1) NOT NULL,
    CONSTRAINT zaposlenik_spol_provjera CHECK (spol = "M" OR spol = "Ž"),
    FOREIGN KEY (mjesto_rada) REFERENCES odjel_na_lokaciji(id)
);

CREATE TABLE kupac (
	id INT AUTO_INCREMENT PRIMARY KEY,
    ime VARCHAR(50) NOT NULL,
    prezime VARCHAR(50) NOT NULL,
    spol CHAR(1) NOT NULL,
    adresa VARCHAR(100) NOT NULL,
    email VARCHAR(50) NOT NULL,
    tip VARCHAR(50) NOT NULL,
    oib_firme CHAR(11),
    klub_id INT DEFAULT 1,
    FOREIGN KEY (klub_id) REFERENCES klub(id),
    CONSTRAINT kupac_spol_provjera CHECK (spol = "M" OR spol = "Ž"),
    CONSTRAINT tip_kupca_check CHECK (tip = 'privatni' OR tip = 'poslovni')
);

CREATE TABLE kategorija (
	id INT AUTO_INCREMENT PRIMARY KEY,
    naziv VARCHAR(50),
    odjel_id INT,
    FOREIGN KEY (odjel_id) REFERENCES odjel(id)
);

CREATE TABLE proizvod (
	id INT AUTO_INCREMENT PRIMARY KEY,
    naziv VARCHAR(100) NOT NULL,
    nabavna_cijena DECIMAL(10, 2) NOT NULL,
    prodajna_cijena DECIMAL(10, 2) NOT NULL,
    kategorija_id INT,
    popust_tip VARCHAR(30) DEFAULT NULL,
    FOREIGN KEY (kategorija_id) REFERENCES kategorija(id),
    CONSTRAINT provjera_cijene CHECK (nabavna_cijena > 0 AND prodajna_cijena > 0),
    CONSTRAINT popust_tip_provjera CHECK (popust_tip IS NULL OR popust_tip = "klub" OR popust_tip = "kolicina"),
    CONSTRAINT greska_ime_proizvoda UNIQUE (naziv)
);

CREATE TABLE predracun (
	id INT AUTO_INCREMENT PRIMARY KEY,
    kupac_id INT,
    zaposlenik_id INT NOT NULL,
    datum DATETIME NOT NULL DEFAULT NOW(),
    status VARCHAR(30) NOT NULL DEFAULT "na cekanju",
    FOREIGN KEY (kupac_id) REFERENCES kupac(id),
    FOREIGN KEY (zaposlenik_id) REFERENCES zaposlenik(id),
    CONSTRAINT provjera_statusa_predracuna CHECK(status = "na cekanju" OR status = "izvrseno" OR status = "ponisteno")
);

CREATE TABLE racun (
	id INT AUTO_INCREMENT PRIMARY KEY,
    kupac_id INT,
    zaposlenik_id INT NOT NULL,
    datum DATETIME NOT NULL DEFAULT NOW(),
    nacin_placanja VARCHAR(30) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT "na cekanju",
    FOREIGN KEY (kupac_id) REFERENCES kupac(id),
    FOREIGN KEY (zaposlenik_id) REFERENCES zaposlenik(id),
    CONSTRAINT provjera_nacina_placanja CHECK (nacin_placanja = "POS" OR nacin_placanja = "gotovina"),
    CONSTRAINT provjera_statusa_racuna CHECK (status = "izvrseno" OR status = "na cekanju" OR status = "ponisteno")
);

CREATE TABLE nabava (
	id INT AUTO_INCREMENT PRIMARY KEY,
    lokacija_id INT,
    datum DATETIME DEFAULT NOW(),
    status VARCHAR(50) DEFAULT 'na cekanju',
    CONSTRAINT provjera_statusa_nabave CHECK (status = 'na cekanju' OR status = 'izvrseno' OR status = 'ponisteno'),
    FOREIGN KEY (lokacija_id) REFERENCES lokacija(id)
);

CREATE TABLE narudzba (
	id INT AUTO_INCREMENT PRIMARY KEY,
    datum DATETIME DEFAULT NOW(),
    lokacija_id INT,
    kupac_id INT,
    status VARCHAR(50) DEFAULT 'na cekanju', -- status je dozvoljena rijec za naziv atributa, iako je highlightana
    FOREIGN KEY (kupac_id) REFERENCES kupac(id),
    FOREIGN KEY (lokacija_id) REFERENCES lokacija(id),
    CONSTRAINT provjera_statusa_narudzbe CHECK (status = "na cekanju" OR status = "izvrseno" OR status = "ponisteno")
);

CREATE TABLE stavka (
	predracun_id INT DEFAULT NULL,
    racun_id INT DEFAULT NULL,
    nabava_id INT DEFAULT NULL,
    narudzba_id INT DEFAULT NULL,
    proizvod_id INT NOT NULL,
    proizvod_naziv VARCHAR(100),
    cijena DECIMAL(10, 2) NOT NULL,
    kolicina INT NOT NULL,
    ukupan_iznos DECIMAL(10, 2) NOT NULL,
    popust DECIMAL(10, 2) DEFAULT NULL,
    nakon_popusta DECIMAL(10, 2) DEFAULT NULL,
    CONSTRAINT kolicina_provjera CHECK (kolicina > 0),
    FOREIGN KEY (predracun_id) REFERENCES predracun(id),
    FOREIGN KEY (racun_id) REFERENCES racun(id),
    FOREIGN KEY (nabava_id) REFERENCES nabava(id),
    FOREIGN KEY (narudzba_id) REFERENCES narudzba(id),
    FOREIGN KEY (proizvod_id) REFERENCES proizvod(id)
);

CREATE TABLE inventar (
	lokacija_id INT NOT NULL,
    proizvod_id INT NOT NULL,
    kolicina INT NOT NULL,
    CONSTRAINT provjera_kolicine_inventara CHECK (kolicina >= 0),
    FOREIGN KEY (lokacija_id) REFERENCES lokacija(id),
    FOREIGN KEY (proizvod_id) REFERENCES proizvod(id)
);

CREATE TABLE evidencija(
	opis VARCHAR(255),
    vrijeme DATETIME DEFAULT NOW()
);
        
/*******************************************************************************
		FUNKCIJE / FUNCTIONS
*******************************************************************************/
        
-- FUNKCIJA ZA DOBIVANJE LOKACIJE OD ZAPOSLENIKA
DELIMITER //
CREATE FUNCTION lokacija_zaposlenika(z_id INT)
RETURNS INT
DETERMINISTIC
BEGIN
	DECLARE l_id INT;
	SET l_id = (SELECT lokacija_id 
					FROM odjel_na_lokaciji 
					WHERE id = (SELECT mjesto_rada 
									FROM zaposlenik 
                                    WHERE id = z_id));
	RETURN l_id;
END //
DELIMITER ;

/*******************************************************************************
		POGLEDI / VIEWS
*******************************************************************************/

-- POGLEDI ZA STAVKE ODREĐENOG TIPA

CREATE OR REPLACE VIEW predracun_stavke AS
	SELECT predracun_id, proizvod_id, proizvod_naziv, cijena, kolicina, ukupan_iznos, popust, nakon_popusta
		FROM stavka
        WHERE predracun_id IS NOT NULL;

CREATE OR REPLACE VIEW racun_stavke AS
	SELECT racun_id, proizvod_id, proizvod_naziv, cijena, kolicina, ukupan_iznos, popust, nakon_popusta
		FROM stavka
        WHERE racun_id IS NOT NULL;

CREATE OR REPLACE VIEW nabava_stavke AS
	SELECT nabava_id, proizvod_id, proizvod_naziv, cijena, kolicina, ukupan_iznos
		FROM stavka
        WHERE nabava_id IS NOT NULL;

CREATE OR REPLACE VIEW narudzba_stavke AS
	SELECT narudzba_id, proizvod_id, proizvod_naziv, cijena, kolicina, ukupan_iznos, popust, nakon_popusta 
		FROM stavka
        WHERE narudzba_id IS NOT NULL;

-- DETALJNIJI PREGLED PREDRACUNA

-- DETALJNIJI PREGLED PREDRACUNA
CREATE OR REPLACE VIEW pregled_predracuna AS
SELECT p.id AS predracun_id, 
			CONCAT(k.ime, ' ', k.prezime) AS kupac, 
			CONCAT(z.ime, ' ', z.prezime) AS zaposlenik, 
			datum, status, 
			SUM(nakon_popusta) AS ukupan_iznos
		FROM predracun AS p
		INNER JOIN zaposlenik AS z ON p.zaposlenik_id = z.id
		LEFT JOIN kupac AS k ON p.kupac_id = k.id
		LEFT JOIN stavka AS s ON s.predracun_id = p.id
		GROUP BY p.id;

-- DETALJNIJI PREGLED RACUNA

CREATE OR REPLACE VIEW pregled_racuna AS
	SELECT r.id AS racun_id, 
			CONCAT(k.ime, ' ', k.prezime) AS kupac, 
			CONCAT(z.ime, ' ', z.prezime) AS zaposlenik, 
			datum, nacin_placanja, status, 
			SUM(nakon_popusta) AS ukupan_iznos
		FROM racun AS r
		INNER JOIN zaposlenik AS z ON r.zaposlenik_id = z.id
		LEFT JOIN kupac AS k ON r.kupac_id = k.id
		LEFT JOIN stavka AS s ON s.racun_id = r.id
		GROUP BY r.id;

-- POGLED ZA KUPCE SA NAJVECIM BROJEM RACUNA

CREATE OR REPLACE VIEW najcesci_kupci AS
	SELECT kupac_id, CONCAT(ime, " ", prezime) AS kupac, COUNT(r.id) AS broj_racuna
		FROM racun AS r
		INNER JOIN kupac AS k ON r.kupac_id = k.id
        WHERE r.status = "izvrseno"
		GROUP BY kupac_id
        ORDER BY broj_racuna DESC;
   
-- POGLED ZA KUPCA SA NAJVISE POTROSENOG NOVCA

CREATE OR REPLACE VIEW najbolji_kupci AS
	SELECT kupac_id, kupac, SUM(ukupan_iznos) AS ukupan_iznos
		FROM pregled_racuna AS pr
		INNER JOIN racun AS r ON pr.racun_id = r.id
		WHERE kupac_id IS NOT NULL AND r.status = "izvrseno"
		GROUP BY kupac_id, kupac
		ORDER BY ukupan_iznos DESC;
        
-- POGLED ZA ZAPOSLENIKA SA NAJVISE IZDANIH RACUNA

CREATE OR REPLACE VIEW najbolji_zaposlenik_racuni AS
	SELECT CONCAT(ime, " ", prezime) AS zaposlenik, spol, COUNT(r.id) AS broj_racuna
		FROM racun AS r
		INNER JOIN zaposlenik AS z ON r.zaposlenik_id = z.id
        WHERE r.status = "izvrseno"
		GROUP BY z.id
		ORDER BY broj_racuna DESC;
        
-- POGLED ZA ZAPOSLENIKA SA NAJVISE ZARADE NA PRODANIM ARTIKLIMA

CREATE VIEW najbolji_zaposlenik_zarada AS
	SELECT CONCAT(z.ime, ' ', z.prezime) AS zaposlenik, spol, SUM(ukupan_iznos) AS ukupan_iznos
		FROM pregled_racuna AS pr
		INNER JOIN racun AS r ON pr.racun_id = r.id
		INNER JOIN zaposlenik AS z ON r.zaposlenik_id = z.id
		GROUP BY z.id
		ORDER BY ukupan_iznos DESC;
    
-- POGLED ZA NAJVISE PRODAVAN PROIZVOD

CREATE OR REPLACE VIEW najprodavaniji_proizvodi AS
	SELECT p.id, p.naziv, SUM(kolicina) AS kolicina
		FROM racun_stavke AS rs
		INNER JOIN proizvod AS p ON rs.proizvod_id = p.id
        INNER JOIN racun AS r ON r.id = rs.racun_id
        WHERE r.status = "izvrseno"
		GROUP BY proizvod_id
		ORDER BY kolicina DESC;
        
-- POGLED ZA PROIZVODE SA NAJVECIM PROFITOM

CREATE OR REPLACE VIEW najbolja_zarada AS
	SELECT p.id, p.naziv, SUM(nakon_popusta) AS zarada
		FROM stavka AS s
		INNER JOIN proizvod AS p ON p.id = s.proizvod_id
        INNER JOIN racun AS r ON r.id = s.racun_id
        WHERE r.status = "izvrseno"
		GROUP BY p.id
		ORDER BY zarada DESC;
    
/*******************************************************************************
		PROCEDURE / PROCEDURES
*******************************************************************************/    

-- PROCEDURA ZA STVARANJE ZAPISA U EVIDENCIJI

DELIMITER //
CREATE PROCEDURE stvori_zapis(IN poruka VARCHAR(255))
BEGIN
	INSERT INTO evidencija VALUES (poruka, NOW());
END //
DELIMITER ;

-- PROCEDURA ZA STVARANJE PREDRACUNA

DELIMITER //
CREATE PROCEDURE stvori_predracun(IN k_id INT, IN z_id INT)
BEGIN
    IF (SELECT tip FROM kupac WHERE id = k_id) != 'poslovni' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Odabrani kupac nije poslovni i nema pravo na predračun';
    END IF;
    INSERT INTO predracun(kupac_id, zaposlenik_id) VALUES (k_id, z_id);
    
    CALL stvori_zapis(CONCAT("Stvoren predracun ID(", LAST_INSERT_ID(), ")"));
END //
DELIMITER ;

-- PROCEDURA ZA STVARANJE RACUNA       
       
DELIMITER //

CREATE PROCEDURE stvori_racun(IN k_id INT, IN z_id INT, IN nacin_placanja VARCHAR(50))
BEGIN
    INSERT INTO racun(kupac_id, zaposlenik_id, datum, nacin_placanja) VALUES 
    (k_id, z_id, NOW(), nacin_placanja);
    
    CALL stvori_zapis(CONCAT("Stvoren racun ID(", LAST_INSERT_ID() , ")"));
    
END //
DELIMITER ;

-- PROCEDURA ZA DODAVANJE NARUDZBE

DELIMITER //
CREATE PROCEDURE stvori_narudzbu(IN l_id INT, IN k_id INT)
BEGIN
	INSERT INTO narudzba(lokacija_id, kupac_id) VALUES (l_id, k_id);
    
    CALL stvori_zapis(CONCAT('Stvorena narudzba ID(', LAST_INSERT_ID() ,')'));
END //
DELIMITER ;

-- PROCEDURA ZA DODAVANJE NABAVE

DELIMITER //
CREATE PROCEDURE stvori_nabavu(IN l_id INT)
BEGIN
	INSERT INTO nabava(lokacija_id) VALUES (l_id);
    
    CALL stvori_zapis(CONCAT('Stvorena nabava ID(', LAST_INSERT_ID(), ')'));
END //
DELIMITER ;

-- PROCEDURA ZA DODAVANJE STAVKI 

DELIMITER //
CREATE PROCEDURE dodaj_stavke(IN json_data JSON)
BEGIN
	
    DECLARE pr_id, r_id, nab_id, nar_id, p_id, l_id, kol INT;
    DECLARE i INT DEFAULT 0;
    DECLARE total_rows INT;    
    
    SET total_rows = JSON_LENGTH(json_data);
	
    START TRANSACTION;
    WHILE i < total_rows DO
		SELECT NULL, NULL, NULL, NULL, NULL INTO pr_id, r_id, nab_id, nar_id, l_id;
		
		SET p_id = JSON_UNQUOTE(JSON_EXTRACT(json_data, CONCAT('$[', i, '].proizvod_id')));
		SET kol = JSON_UNQUOTE(JSON_EXTRACT(json_data, CONCAT('$[', i, '].kolicina')));

		IF JSON_EXTRACT(json_data, CONCAT('$[', i, '].predracun_id')) IS NOT NULL THEN
			SET pr_id = JSON_UNQUOTE(JSON_EXTRACT(json_data, CONCAT('$[', i, '].predracun_id')));
		END IF;

		IF JSON_EXTRACT(json_data, CONCAT('$[', i, '].racun_id')) IS NOT NULL THEN
			SET r_id = JSON_UNQUOTE(JSON_EXTRACT(json_data, CONCAT('$[', i, '].racun_id')));
		END IF;

		IF JSON_EXTRACT(json_data, CONCAT('$[', i, '].nabava_id')) IS NOT NULL THEN
			SET nab_id = JSON_UNQUOTE(JSON_EXTRACT(json_data, CONCAT('$[', i, '].nabava_id')));
		END IF;

		IF JSON_EXTRACT(json_data, CONCAT('$[', i, '].narudzba_id')) IS NOT NULL THEN
			SET nar_id = JSON_UNQUOTE(JSON_EXTRACT(json_data, CONCAT('$[', i, '].narudzba_id')));
		END IF;
        
        IF p_id NOT IN (SELECT id FROM proizvod) THEN
			ROLLBACK;
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Nepojstojeci proizvod ID unesen";
		END IF;
        
        IF r_id IS NOT NULL THEN
			IF l_id IS NULL THEN
				SET @z_id = (SELECT zaposlenik_id FROM racun WHERE id = r_id);
				SET l_id = lokacija_zaposlenika(@z_id);
			END IF;
            SET @inventar = (SELECT kolicina FROM inventar WHERE lokacija_id = l_id AND proizvod_id = p_id);
            IF kol > @inventar THEN
				ROLLBACK;
				UPDATE racun SET status = 'ponisteno' WHERE id = r_id;
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nema dovoljno proizvoda na stanju';
			END IF;
		END IF;
        
		INSERT INTO stavka (predracun_id, racun_id, nabava_id, narudzba_id, proizvod_id, kolicina) 
		VALUES (pr_id, r_id, nab_id, nar_id, p_id, kol);    
        
        SET i = i + 1;
    END WHILE;
    
    IF r_id IS NOT NULL THEN
		UPDATE racun SET status = 'izvrseno' WHERE id = r_id;
    END IF;
    COMMIT;
END //
DELIMITER ;

-- PROCEDURA ZA PONISTAVANJE PREDRACUNA

DELIMITER //
CREATE PROCEDURE ponisti_predracun(IN p_id INT)
BEGIN
	IF (SELECT status FROM predracun WHERE id = p_id) = 'na cekanju' THEN
		UPDATE predracun SET status = "ponisteno" WHERE id = p_id;
    ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Predracun je vec prethodno procesiran';
	END IF;
    
    CALL stvori_zapis(CONCAT("Ponisten predracun ID(", p_id, ")"));
END //
DELIMITER ;

-- PROCEDURA ZA PONISTAVANJE RACUNA

DELIMITER //
CREATE PROCEDURE ponisti_racun(IN r_id INT)
BEGIN
	IF (SELECT status FROM racun WHERE id = r_id) = 'ponisteno' THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Racun je vec prethodno ponisten';
	ELSE
		UPDATE racun SET status = "ponisteno" WHERE id = r_id;
    END IF;
    
    CALL stvori_zapis(CONCAT("Ponisten racun ID(", r_id ,")"));
END //
DELIMITER ;

-- PROCEDURA ZA PONISTAVANJE NARUDZBE
DELIMITER //
CREATE PROCEDURE ponisti_narudzbu(IN n_id INT)
BEGIN
	IF (SELECT status FROM narudzba WHERE id = n_id) = 'na cekanju' THEN
		UPDATE narudzba SET status = "ponisteno" WHERE id = n_id;
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Narudzba je vec prethodno procesirana';
    END IF;
	CALL stvori_zapis(CONCAT("Ponistena narudzba ID(", n_id, ")"));
END //
DELIMITER ;

-- PROCEDURA ZA PONISTAVANJE NABAVE

DELIMITER //
CREATE PROCEDURE ponisti_nabavu(IN n_id INT)
BEGIN
	IF (SELECT status FROM nabava WHERE id = n_id) = 'na cekanju' THEN
		UPDATE nabava SET status = 'ponisteno' WHERE id = n_id;
	ELSE
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nabava je vec prethodno procesirana';
	END IF;
    
    CALL stvori_zapis(CONCAT('Ponistena nabava ID(', n_id, ')'));
END //
DELIMITER ;

-- PROCEDURA ZA DODAVANJE PROIZVODA       
       
DELIMITER //
CREATE PROCEDURE dodaj_proizvod(IN naziv VARCHAR(100), IN n_cijena DECIMAL(10, 2), IN p_cijena DECIMAL(10,2), kategorija_id INT)
BEGIN
    INSERT INTO proizvod VALUES (naziv, n_cijena, p_cijena, kategorija_id);
    
    CALL stvori_zapis(CONCAT("Dodan proizvod '", naziv, "' ID(", LAST_INSERT_ID(), ")"));
END //
DELIMITER ;

-- PROCEDURA ZA DODAVANJE KUPCA

DELIMITER //
CREATE PROCEDURE dodaj_kupca(
	IN ime VARCHAR(50), 
    IN prezime VARCHAR(20), 
    IN spol CHAR(1), 
    IN adresa VARCHAR(100),
    IN email VARCHAR(50), 
    IN tip VARCHAR(50), 
    IN oib_firme CHAR(11)
)
BEGIN
    INSERT INTO kupac(ime, prezime, spol, adresa, email, tip, oib_firme) VALUES (ime, prezime, spol, adresa, email, tip, oib_firme);
    
    CALL stvori_zapis(CONCAT("Dodan kupac ", ime, " ", prezime, " ID(", LAST_INSERT_ID() ,")"));
END //
DELIMITER ;

-- PROCEDURA ZA DODAVANJE ZAPOSLENIKA

DELIMITER //
CREATE PROCEDURE dodaj_zaposlenika(
	IN ime VARCHAR(50),
    IN prezime VARCHAR(50),
    IN mjesto_rada INT,
    IN placa DECIMAL(10, 2),
    IN spol CHAR(1)
)
BEGIN
	INSERT INTO zaposlenik(ime, prezime, mjesto_rada, placa, spol) VALUES (ime, prezime, mjesto_rada, placa, spol);
    
    CALL stvori_zapis(CONCAT("Dodan zaposlenik ", ime, " ", prezime, " ID(", LAST_INSERT_ID(), ")"));
END //
DELIMITER ;

-- PROCEDURA ZA PROCESIRANJE PREDRACUNA
DELIMITER //
CREATE PROCEDURE procesiraj_predracun(IN p_id INT)
BEGIN
	DECLARE l_id, k_id, z_id, pro_id, kol INT;
    DECLARE finished INT DEFAULT 0;
	DECLARE cur CURSOR FOR
		SELECT proizvod_id, kolicina FROM predracun_stavke WHERE p_id = predracun_id;
        
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET finished = 1;
	
	IF((SELECT status FROM predracun WHERE p_id = id) != "na cekanju") THEN 
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Predracun vec procesiran";
    END IF;
    
    SELECT kupac_id, zaposlenik_id FROM predracun WHERE id = p_id 
		INTO k_id, z_id;
	SET l_id = lokacija_zaposlenika(z_id);
        
    START TRANSACTION;
		CALL stvori_racun(k_id, z_id, "POS");
        SET @r_id = LAST_INSERT_ID();
        UPDATE predracun
			SET predracun.status = "izvrseno"
			WHERE id = p_id;
		UPDATE stavka
			SET racun_id = @r_id
			WHERE predracun_id = p_id;
            
		OPEN cur;
			procesiraj_stavke: LOOP
				FETCH cur INTO pro_id, kol;
                
				IF finished = 1 THEN
					LEAVE procesiraj_stavke;
				END IF;
                
				IF (kol > (SELECT kolicina FROM inventar WHERE l_id = lokacija_id AND pro_id = proizvod_id)) THEN
					ROLLBACK;
					SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Nema dovoljno proizvoda na stanju";
                    
				END IF;
			END LOOP;
		CLOSE cur;
        UPDATE racun
			SET status = "izvrseno"
            WHERE id = @r_id;
    COMMIT;
END //
DELIMITER ;

-- PROCEDURA ZA PROCESIRANJE NARUDZBE

DELIMITER //
CREATE PROCEDURE procesiraj_narudzbu(IN n_id INT, IN z_id INT)
BEGIN
	DECLARE l_id, k_id, p_id, kol INT;
    DECLARE narudzba_error CONDITION FOR SQLSTATE '45000';
    DECLARE finished INT DEFAULT 0;
	DECLARE cur CURSOR FOR
		SELECT proizvod_id, kolicina FROM narudzba_stavke WHERE n_id = narudzba_id;
        
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET finished = 1;
	
	IF((SELECT status FROM narudzba WHERE n_id = id) != "na cekanju") THEN 
		SIGNAL narudzba_error SET MESSAGE_TEXT = "Narudzba vec procesirana";
    END IF;
    
    SET l_id = (SELECT lokacija_id FROM narudzba WHERE id = n_id);
    SET k_id = (SELECT kupac_id FROM narudzba WHERE id = n_id);
    
	
    START TRANSACTION;
		CALL stvori_racun(k_id, z_id, "POS");
        SET @r_id = LAST_INSERT_ID();
        UPDATE narudzba
			SET narudzba.status = "izvrseno"
			WHERE id = n_id;
		UPDATE stavka
			SET racun_id = @r_id
			WHERE narudzba_id = n_id;
            
		OPEN cur;
			procesiraj_stavke: LOOP
				FETCH cur INTO p_id, kol;
                
				IF finished = 1 THEN
					LEAVE procesiraj_stavke;
				END IF;
                
				IF (kol > (SELECT kolicina FROM inventar WHERE l_id = lokacija_id AND p_id = proizvod_id)) THEN
					ROLLBACK;
					SIGNAL narudzba_error SET MESSAGE_TEXT = "Nema dovoljno proizvoda na stanju";
                    
				END IF;
			END LOOP;
		CLOSE cur;
        UPDATE racun
			SET status = "izvrseno"
            WHERE id = @r_id;
    COMMIT;
END //
DELIMITER ;

-- PROCEDURA ZA UCITAVANJE PROIZVODA KOJIH JE MALO NA STANJU ZA NABAVU

DELIMITER //
CREATE PROCEDURE nabava_ispis(IN l_id INT)
BEGIN
	
    DECLARE p_id, kol INT;
    DECLARE finished INT DEFAULT 0;
    DECLARE cur CURSOR FOR 
				(SELECT proizvod_id, kolicina
					FROM inventar 
					WHERE l_id = lokacija_id);
                    
	
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET finished = 1;
    
    CREATE TEMPORARY TABLE nabava_podaci(
    proizvod_id INT, 
    na_stanju INT,
    nabavna_cijena DECIMAL(10, 2),
    nabava_kolicina INT
    );
    
    OPEN cur;
		petlja: LOOP
			FETCH cur INTO p_id, kol;
            
			IF finished = 1 THEN
				LEAVE petlja;
			END IF;
            
            SET @cijena = (SELECT prodajna_cijena FROM proizvod WHERE id = p_id);
            SET @nabavna_cijena = (SELECT nabavna_cijena FROM proizvod WHERE id = p_id);
            
            IF @cijena <= 5 THEN
				IF kol <= 50 THEN
					INSERT INTO nabava_podaci VALUES (p_id, kol, @nabavna_cijena, 500);
				END IF;
            END IF;
            
            IF @cijena > 5 AND @cijena <= 20 THEN
				IF kol <= 25 THEN
					INSERT INTO nabava_podaci VALUES (p_id, kol, @nabavna_cijena, 250);
				END IF;
            END IF;
            
            IF @cijena > 20 AND @cijena <= 50 THEN
				IF kol <= 10 THEN
					INSERT INTO nabava_podaci VALUES (p_id, kol, @nabavna_cijena, 100);
				END IF;
            END IF;
            
            IF @cijena > 50 AND @cijena <= 200 THEN
				IF kol <= 10 THEN
					INSERT INTO nabava_podaci VALUES (p_id, kol, @nabavna_cijena, 60);
				END IF;
            END IF;
            
            IF @cijena > 200 AND @cijena <= 100 THEN
				IF kol <= 5 THEN
					INSERT INTO nabava_podaci VALUES (p_id, kol, @nabavna_cijena, 40);
				END IF;
            END IF;
            
            IF @cijena > 1000 THEN
				IF kol <= 5 THEN
					INSERT INTO nabava_podaci VALUES (p_id, kol, @nabavna_cijena, 20);
				END IF;
            END IF;
		END LOOP;
	CLOSE cur;
    
    SELECT * FROM nabava_podaci;
    
    DROP TEMPORARY TABLE nabava_podaci;
END //
DELIMITER ;

-- PROCEDURA ZA PROCESIRANJE NABAVE

DELIMITER //
CREATE PROCEDURE procesiraj_nabavu(IN n_id INT)
BEGIN
	DECLARE p_id, kol INT;
	DECLARE finished INT DEFAULT 0;
    DECLARE cur CURSOR FOR
		SELECT proizvod_id, kolicina 
			FROM nabava_stavke 
			WHERE nabava_id = n_id;
            
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET finished = 1;
    
    SET @l_id = (SELECT lokacija_id FROM nabava WHERE id = n_id); 
    
    IF (SELECT status FROM nabava WHERE id = n_id) != 'na cekanju' THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nabava vec procesirana.';
	ELSE
		OPEN cur;
        petlja: LOOP
			FETCH cur INTO p_id, kol;
            
            IF finished = 1 THEN
				LEAVE petlja;
            END IF;
            
            UPDATE inventar
				SET kolicina = kolicina + kol
				WHERE lokacija_id = @l_id AND proizvod_id = p_id;
		END LOOP;
        CLOSE cur;
    END IF;
    
    UPDATE nabava
		SET status = 'izvrseno'
		WHERE id = n_id;
    
    CALL stvori_zapis(CONCAT('Izvrsena nabava ID(', LAST_INSERT_ID(), ')'));
END //
DELIMITER ;

/*******************************************************************************
		OKIDACI / TRIGGERS
*******************************************************************************/

-- OKIDAC ZA ISPRAVAK UNOSA POSLOVNIH KUPACA (NE MOGU IMATI KLUB KARTICU KOJA JE PO DEFAULTU RAZINA 1)
DELIMITER //
CREATE TRIGGER provjeri_tip
BEFORE INSERT ON kupac
FOR EACH ROW
BEGIN
	IF NEW.tip = "poslovni" THEN
		SET NEW.klub_id = NULL;
	END IF;
END //
DELIMITER ;

-- OKIDAC ZA REGULACIJU STANJA PROIZVODA NAKON NABAVE/KUPNJE

DELIMITER //
CREATE TRIGGER inventar_handler
AFTER UPDATE ON racun
FOR EACH ROW
BEGIN
	DECLARE p_id, kol INT;
    DECLARE finished INT DEFAULT 0;
    DECLARE cur CURSOR FOR
		SELECT proizvod_id, kolicina 
			FROM stavka
            WHERE racun_id = NEW.id;
            
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET finished = 1;
    
    SET @l_id = lokacija_zaposlenika(NEW.zaposlenik_id);
    
    OPEN cur;
		petlja: LOOP
			FETCH cur INTO p_id, kol;
            IF finished = 1 THEN
				LEAVE petlja;
            END IF;
            
			IF NEW.status = 'izvrseno' THEN
				UPDATE inventar
					SET kolicina = kolicina - kol
					WHERE lokacija_id = @l_id AND proizvod_id = p_id;
			END IF;
            
            IF NEW.status = 'ponisteno' THEN
				UPDATE inventar
					SET kolicina = kolicina + kol
					WHERE lokacija_id = @l_id AND proizvod_id = p_id;
			END IF;
		END LOOP;
    CLOSE cur;
END //
DELIMITER ;

-- OKIDAC ZA BILJEZENJE CIJENE STAVKI U TRENUTKU KADA SE DODAJU

DELIMITER //

CREATE TRIGGER stavka_cijene
BEFORE INSERT ON stavka
FOR EACH ROW
BEGIN
    DECLARE kl_id, ku_id INT;
    SET @popust_tip = (SELECT popust_tip FROM proizvod WHERE id = NEW.proizvod_id);
    SET NEW.proizvod_naziv = (SELECT naziv FROM proizvod WHERE id = NEW.proizvod_id);
    
    IF NEW.nabava_id IS NOT NULL THEN
		SET NEW.cijena = (SELECT nabavna_cijena FROM proizvod WHERE id = NEW.proizvod_id);
        SET NEW.ukupan_iznos = NEW.cijena * NEW.kolicina;
    ELSE
		SET NEW.cijena = (SELECT prodajna_cijena FROM proizvod WHERE id = NEW.proizvod_id);
        SET NEW.ukupan_iznos = NEW.cijena * NEW.kolicina;
        
        IF (NEW.predracun_id IS NOT NULL) THEN
			SET ku_id = (SELECT kupac_id FROM predracun WHERE id = NEW.predracun_id); 
        END IF;
        IF (NEW.racun_id IS NOT NULL) THEN
			SET ku_id = (SELECT kupac_id FROM racun WHERE id = NEW.racun_id); 
        END IF;
        IF (NEW.narudzba_id IS NOT NULL) THEN
			SET ku_id = (SELECT kupac_id FROM narudzba WHERE id = NEW.narudzba_id); 
        END IF;
        
        IF @popust_tip = "kolicina" AND NEW.kolicina >=3 THEN
			SET NEW.popust = 15;
		END IF;
		
		IF @popust_tip = "klub" THEN
			SET kl_id = (SELECT klub_id FROM kupac WHERE id = ku_id);
			
			SET NEW.popust = (SELECT popust FROM klub WHERE id = kl_id);
		END IF;
		
		IF (SELECT tip FROM kupac WHERE id = ku_id) = "poslovni" THEN
			SET NEW.popust = 25;
		END IF;
    END IF;
    
    SET NEW.nakon_popusta = IF(NEW.popust IS NULL, NEW.ukupan_iznos, NEW.ukupan_iznos * (1 - NEW.popust/100));
END //

DELIMITER ;

-- OKIDAC ZA PROMOCIJU KLUB KARTICE KUPCA

DELIMITER //
CREATE TRIGGER promocija_kupca
AFTER INSERT ON stavka
FOR EACH ROW
BEGIN
	SET @kupac_id = (SELECT kupac_id FROM racun WHERE id = NEW.racun_id);
	SET @klub_id = (SELECT klub_id FROM kupac WHERE id = @kupac_id);
    SET @ukupan_iznos = (SELECT ukupan_iznos FROM najbolji_kupci WHERE kupac_id = @kupac_id);
	IF @ukupan_iznos > 1000 AND @klub_id = 1 THEN
		UPDATE kupac
        SET klub_id = 2
        WHERE id = @kupac_id;
    END IF;
    IF @ukupan_iznos > 10000 AND @klub_id = 2 THEN
		UPDATE kupac
        SET klub_id = 3
        WHERE id = @kupac_id;
    END IF;
END //
DELIMITER ;

/*******************************************************************************
		KORISNO ZA APLIKACIJU
*******************************************************************************/

-- SVE POTREBNE INFORMACIJE O POJEDINOM RACUNU

DELIMITER //
CREATE PROCEDURE racun_detalji(IN r_id INT)
BEGIN
    SELECT 
        r.id AS racun_id,
        r.datum,
        r.nacin_placanja,
		(SELECT grad FROM lokacija WHERE id = lokacija_zaposlenika(r.zaposlenik_id)) AS lokacija,
        r.status,
        CONCAT(z.ime, ' ', z.prezime) AS zaposlenik_ime,
        IFNULL(CONCAT(k.ime, ' ', k.prezime), 'N/A') AS kupac_ime,
        s.proizvod_naziv,
        s.kolicina,
        s.cijena,
        s.popust,
        s.nakon_popusta,
        (SELECT SUM(s2.nakon_popusta) FROM stavka s2 WHERE s2.racun_id = r.id) AS ukupan_iznos
    FROM racun r
    INNER JOIN zaposlenik z ON r.zaposlenik_id = z.id 
    LEFT JOIN kupac k ON r.kupac_id = k.id
    LEFT JOIN stavka s ON s.racun_id = r.id
    WHERE r.id = r_id;
END //
DELIMITER ;

-- POGLED ZA LOKACIJE I IMENA ODJELA NA TIM LOKACIJAMA

CREATE OR REPLACE VIEW pregled_lokacija_sa_odjelima AS
    SELECT l.grad AS lokacija, GROUP_CONCAT(o.naziv SEPARATOR ', ') AS odjeli
    FROM lokacija l
    JOIN odjel_na_lokaciji ona ON l.id = ona.lokacija_id
    JOIN odjel o ON ona.odjel_id = o.id
    GROUP BY l.grad;
    
-- VIEW ZA ISPIS SVEUKUPNO PROIZVODA U INVERTARU

CREATE OR REPLACE VIEW svi_proizvodi AS
	SELECT p.id, p.naziv, i.kolicina, p.nabavna_cijena, p.prodajna_cijena
	FROM proizvod AS p
	LEFT JOIN inventar AS i ON p.id = i.proizvod_id;
    
-- VIEW ZA ISPIS SVEUKUPNO PROIZVODA U INVERTARU NA TOJ LOKACIJI

CREATE OR REPLACE VIEW svi_proizvodi_lokacija AS
	SELECT p.id, p.naziv, i.kolicina, p.nabavna_cijena, p.prodajna_cijena, l.grad
	FROM proizvod AS p
	LEFT JOIN inventar AS i ON p.id = i.proizvod_id
	LEFT JOIN odjel_na_lokaciji AS onl ON i.lokacija_id = onl.lokacija_id
	LEFT JOIN lokacija AS l ON onl.lokacija_id = l.id;

-- POGLED ZA PROIZVODE I NJIHOVI ODJELI

CREATE OR REPLACE VIEW pregled_proizvoda AS
    SELECT p.*, k.naziv AS kategorija_naziv, o.naziv AS odjel_naziv
    FROM proizvod p
    LEFT JOIN kategorija k ON p.kategorija_id = k.id 
    LEFT JOIN odjel o ON k.odjel_id = o.id;
    
-- POGLED ZA PROIZVODE NA LOKACIJAMA

CREATE OR REPLACE VIEW proizvodi_na_lokacijama AS
    SELECT p.id AS proizvod_id, p.naziv AS proizvod_naziv, l.grad AS lokacija, SUM(i.kolicina) AS kolicina
    FROM proizvod p
    JOIN inventar i ON p.id = i.proizvod_id
    JOIN lokacija l ON i.lokacija_id = l.id
    GROUP BY p.id, l.grad;
 
-- DETALJNIJI PREGLED NABAVE

CREATE OR REPLACE VIEW pregled_nabave AS
    SELECT n.id AS nabava_id,
           l.grad AS lokacija,
           n.datum,
           n.status,
           SUM(s.kolicina * p.nabavna_cijena) AS ukupan_iznos
    FROM nabava n
    INNER JOIN lokacija l ON n.lokacija_id = l.id
    LEFT JOIN stavka s ON s.nabava_id = n.id
    LEFT JOIN proizvod p ON s.proizvod_id = p.id
    GROUP BY n.id;

DELIMITER //
CREATE PROCEDURE nabava_detalji(IN n_id INT)
BEGIN
    SELECT 
        n.id AS nabava_id,
        n.datum,
        l.grad AS lokacija,
        n.status,
        p.naziv AS proizvod_naziv,
        s.kolicina,
        p.nabavna_cijena,
        (s.kolicina * p.nabavna_cijena) AS ukupan_iznos_proizvoda,
        (SELECT SUM(s2.kolicina * p2.nabavna_cijena) 
         FROM stavka s2 
         JOIN proizvod p2 ON s2.proizvod_id = p2.id 
         WHERE s2.nabava_id = n.id) AS sveukupan_iznos
    FROM nabava n
    INNER JOIN lokacija l ON n.lokacija_id = l.id
    LEFT JOIN stavka s ON s.nabava_id = n.id
    LEFT JOIN proizvod p ON s.proizvod_id = p.id
    WHERE n.id = n_id;
END //
DELIMITER ;

-- SVE POTREBNE INFORMACIJE O POJEDINOJ NARUDZBI

DELIMITER //

CREATE PROCEDURE narudzba_detalji(IN n_id INT)
BEGIN
    SELECT 
        n.id AS narudzba_id,
        n.datum,
        n.status, 
        s.proizvod_naziv,
        s.kolicina,
        s.cijena, 
        (SELECT SUM(s2.cijena*s2.kolicina) FROM stavka s2 WHERE s2.narudzba_id = n.id) AS ukupan_iznos
    FROM narudzba n 
    LEFT JOIN kupac k ON n.kupac_id = k.id
    LEFT JOIN stavka s ON s.narudzba_id = n.id
    WHERE n.id = n_id;
END //
DELIMITER ;

-- SVE POTREBNE INFORMACIJE O POJEDINOM PREDRACUNU

DELIMITER //
CREATE PROCEDURE predracun_detalji(IN p_id INT)
BEGIN
    SELECT 
        p.id AS predracun_id,
        p.datum, 
        (SELECT grad
FROM lokacija
            WHERE id =(SELECT lokacija_id 
FROM odjel_na_lokaciji 
WHERE id = (SELECT mjesto_rada FROM zaposlenik WHERE id = z.id))) AS lokacija,
        p.status,
        CONCAT(z.ime, ' ', z.prezime) AS zaposlenik_ime,
        IFNULL(CONCAT(k.ime, ' ', k.prezime), 'N/A') AS kupac_ime,
        s.proizvod_naziv,
        s.kolicina,
        s.cijena,
        s.popust,
        s.nakon_popusta,
        (SELECT SUM(s2.nakon_popusta) FROM stavka s2 WHERE s2.predracun_id = p.id) AS ukupan_iznos
    FROM predracun p
    INNER JOIN zaposlenik z ON p.zaposlenik_id = z.id 
    LEFT JOIN kupac k ON p.kupac_id = k.id
    LEFT JOIN stavka s ON s.predracun_id = p.id
    WHERE p.id = p_id;
END //
DELIMITER ;

CREATE OR REPLACE VIEW najbolja_zarada_lokacija AS
  SELECT grad, SUM(ukupan_iznos) AS ukupan_iznos
      FROM (SELECT r.id AS racun_id, l.grad, datum, SUM(nakon_popusta) AS ukupan_iznos
              FROM racun AS r
              INNER JOIN stavka AS s ON r.id = s.racun_id
              INNER JOIN lokacija AS l ON l.id = lokacija_zaposlenika(r.zaposlenik_id)
              WHERE r.status = 'izvrseno'
              GROUP BY r.id, l.id) AS podupit
      WHERE DATE(datum) BETWEEN '2025-01-10' AND '2025-01-20'
      GROUP BY grad
      ORDER BY ukupan_iznos DESC
      LIMIT 1;

/*******************************************************************************
		UCITAVANJE PODATAKA
*******************************************************************************/

INSERT INTO klub(razina, popust) VALUES 
("Silver", 5),
("Gold", 10),
("Platinum", 15);

INSERT INTO lokacija(grad) VALUES 
("Pula"),
("Zagreb"),
("Split"),
("Zadar"),
("Rijeka"),
("Osijek");

INSERT INTO odjel(naziv) VALUES 
("Kućanski Uređaji"),
("Elektronika"),
("Vrt i sezona"),
("Široka potrošnja");

INSERT INTO odjel_na_lokaciji(odjel_id, lokacija_id) VALUES
(1, 1),
(2, 1),
(3, 1),
(4, 1),
(1, 2),
(2, 2),
(3, 2),
(4, 2),
(1, 3),
(2, 3),
(3, 3),
(4, 3),
(1, 4),
(2, 4),
(4, 4),
(1, 5),
(2, 5),
(4, 5),
(1, 6),
(3, 6),
(4, 6);

INSERT INTO zaposlenik(ime, prezime, mjesto_rada, placa, spol) VALUES
("Zvonimir", "Krtić", 1, 1200, "M"),
("Viktor", "Lovreković", 1, 1200, "M"),
("Klara", "Šimek", 1, 1200, "Ž"),
("Božo", "Prskalo", 2, 1100, "M"),
("Vanesa", "Marijanović", 2, 1100, "Ž"),
("Siniša", "Fabijanić", 3, 1050, "M"),
("Renata", "Pejaković", 3, 1050, "Ž"),
("Dora", "Nikić", 4, 1150, "Ž"),
("Gordana", "Josić", 4, 1150, "Ž"),
("Nika", "Jelinić", 5, 1250, "Ž"),
("Igor", "Žanić", 5, 1250, "M"),
("Mario", "Vedrić", 5, 1250, "M"),
("Dario", "Volarević", 6, 1300, "M"),
("Anica", "Ilić", 6, 1300, "Ž"),
("Božo", "Vrban", 7, 1100, "M"),
("Antonio", "Kuzmić", 7, 1100, "M"),
("Stela", "Tomšić", 8, 1050, "Ž"),
("Matej", "Vrdoljak", 8, 1050, "M"),
("Juraj", "Ivanković", 9, 1200, "M"),
("Darko", "Jušić", 9, 1200, "M"),
("Marta", "Miloš", 9, 1200, "Ž"),
("Miroslav", "Stipanović", 10, 1250, "M"),
("Gorana", "Kutleša", 10, 1250, "Ž"),
("Zdenka", "Majnarić", 11, 1150, "Ž"),
("Goran", "Medved", 11, 1150, "M"),
("Zlatko", "Primorac", 12, 1000, "M"),
("Oliver", "Andrešić", 12, 1000, "M"),
("Irena", "Kadić", 13, 1150, "Ž"),
("Jan", "Buzov", 13, 1150, "M"),
("Katarina", "Pavlinić", 13, 1150, "Ž"),
("Saša", "Jagić", 14, 1200, "M"),
("Domagoj", "Parlov", 14, 1200, "M"),
("Sanja", "Franjić", 15, 1000, "Ž"),
("Đuro", "Vukas", 15, 1000, "M"),
("Filip", "Knežić", 16, 950, "M"),
("Zvonko", "Brgan", 16, 950, "M"),
("Boris", "Lekić", 17, 1200, "M"),
("Lara", "Žunić", 17, 1200, "Ž"),
("Josip", "Vincek", 17, 1200, "M"),
("Ena", "Merlin", 18, 1100, "Ž"),
("Emanuel", "Šimunić", 18, 1100, "M"),
("Patricija", "Bistrović", 19, 1000, "Ž"),
("Krešimir", "Maričić", 19, 1000, "M"),
("Jadranka", "Krznarić", 20, 900, "Ž"),
("Gabrijel", "Stipić", 20, 900, "M"),
("Denis", "Radovanović", 21, 1300, "M"),
("Karolina", "Velić", 21, 1300, "Ž"),
("Mia", "Klaić", 21, 1300, "Ž");

INSERT INTO kupac(ime, prezime, spol, adresa, email, tip, oib_firme, klub_id) VALUES
("Krešimir", "Gavranić", "M", "Splitska 3", "kgavranic@gmail.com", "privatni", NULL, 1),
("Dražen", "Jakšić", "M", "Dubrovačka 12", "djaksic@gmail.com", "privatni", NULL, 1),
("Boris", "Bukovac", "M", "Zagrebačka 33", "bbukovac@gmail.com", "privatni", NULL, 1),
("Tomislav", "Ložančić", "M", "Splitska 19", "tlozancic@gmail.com", "poslovni", "13312150031", NULL),
("Davor", "Husnjak", "M", "Frankopanska 11", "dhusnjak@gmail.com", "privatni", NULL, 1),
("Franjo", "Drašković", "M", "Fišerova 25", "fdraskovic@gmail.com", "privatni", NULL, 1),
("Dominik", "Kumiša", "M", "Zadarska 32", "dkumisa@gmail.com", "privatni", NULL, 2),
("Marko", "Franić", "M", "Đorđićeva 43", "mfranic@gmail.com", "privatni", NULL, 3),
("Teo", "Hužjak", "M", "Jurišićeva 51", "thuzjak@gmail.com", "poslovni", "23773491461", NULL),
("Patricija", "Turkalj", "Ž", "Zadarska 18", "pturkalj@gmail.com", "privatni", NULL, 1),
("Sanja", "Kunica", "Ž", "Mošćenička 62", "skunica@gmail.com", "privatni", NULL, 1),
("Đurđa", "Vujnović", "Ž", "Arsenalska 14", "dvujnovic@gmail.com", "privatni", NULL, 1),
("Irena", "Jurakić", "Ž", "Krajiška 20", "ijurakic@gmail.com", "privatni", NULL, 2),
("Gabrijel", "Mikić", "M", "Gajeva 36", "gmikic@gmail.com", "poslovni", "25374421622", NULL),
("Dubravka", "Burišić", "Ž", "Martićeva 9", "dburisic@gmail.com", "privatni", NULL, 2),
("Karla", "Tomić", "Ž", "Margaretska 7", "ktomic@gmail.com", "privatni", NULL, 3),
("Veronika", "Ivanović", "Ž", "Petrinjska 23", "vivanovic@gmail.com", "privatni", NULL, 2),
("Izabela", "Tutić", "Ž", "Preradovićeva 40", "itutic@gmail.com", "privatni", NULL, 2),
("Suzana", "Vukojević", "Ž", "Praška 15", "svukojevic@gmail.com", "poslovni", "16881329745", NULL),
("Snježana", "Bradić", "Ž", "Rovinjska 16", "sbradic@gmail.com", "privatni", NULL, 3),
("Marin", "Stepić", "M", "Vlaška 31", "mstepic@gmail.com", "privatni", NULL, 1),
("Vedran", "Nekić", "M", "Varšavska 26", "vnekic@gmail.com", "privatni", NULL, 1),
("Gabrijela", "Blažić", "Ž", "Heinzela 29", "gblazic@gmail.com", "privatni", NULL, 1),
("Marijan", "Kostelac", "M", "Savska 63", "mkostelac@gmail.com", "poslovni", "13138867549", NULL),
("Julija", "Hranilović", "Ž", "Klaića 10", "jhranilovic@gmail.com", "privatni", NULL, 1),
("Anja", "Bogdan", "Ž", "Dalmatinska 58", "abogdan@gmail.com", "privatni", NULL, 2),
("Lidija", "Brnetić", "Ž", "Bogovićeva 53", "lbrnetic@gmail.com", "privatni", NULL, 2),
("Jana", "Golubić", "Ž", "Fišerova 41", "jgolubic@gmail.com", "poslovni", "17133516194", NULL),
("Helena", "Gregurek", "Ž", "Ronjgova 33", "hgregurek@gmail.com", "privatni", NULL, 1),
("Igor", "Krauz", "M", "Vukovarska 45", "ikrauz@gmail.com", "privatni", NULL, 1),
("Ivan", "Carek", "M", "Varaždinska 22", "icarek@gmail.com", "privatni", NULL, 1),
("Lucija", "Tanković", "Ž", "Istarska 3", "ltankovic@gmail.com", "privatni", NULL, 1),
("Dinko", "Sporčić", "M", "Šenoina 48", "dsporcic@gmail.com", "poslovni", "29997321284", NULL),
("Mara", "Žitnik", "Ž", "Dravska 91", "mzitnik@gmail.com", "privatni", NULL, 1),
("Petra", "Tadić", "Ž", "Preradovića 9", "ptadic@gmail.com", "privatni", NULL, 1),
("Lidija", "Bačić", "Ž", "Arsenalska 70", "lbacic@gmail.com", "privatni", NULL, 1);

INSERT INTO kategorija(naziv, odjel_id) VALUES
("Bijela tehnika", 1),
("Hlađenje i grijanje", 1),
("Mali kućanski aparati", 1),
("Televizori i dodatci", 2),
("Mobiteli i pametni satovi", 2),
("Audio-video", 2),
("Vrtni namještaj", 3),
("Vrtlarstvo", 3),
("Vrtni alat i oprema", 3),
("Hrana", 4),
("Piće", 4),
("Slatkiši i grickalice", 4),
("Osobna higijena", 4),
("Sredstva za čiščenje i pranje", 4);

INSERT INTO proizvod(naziv, nabavna_cijena, prodajna_cijena, kategorija_id, popust_tip) VALUES
("Perilica rublja Končar", 180, 450, 1, "klub"),
("Perilica rublja Candy", 150, 370, 1, NULL),
("Štednjak Gorenje", 165, 430, 1, NULL),
("Hladnjak Gorenje", 485, 1057, 1, NULL),
("Hladnjak Hisense", 200, 480, 1, NULL),
("Napa Beko", 85, 205, 1, NULL),
("Klima uređaj Vivax", 140, 392, 2, NULL),
("Klima uređaj Mitsubishi", 279.99, 709.99, 2, NULL),
("Peć na drva Alfa-plam", 110, 273, 2, "klub"),
("Električna grijalica Iskra", 8, 18.5, 2, NULL),
("Uljni radijator Blitz", 40, 93, 2, "klub"),
("Usisavač bez vrećice Rowenta", 57, 119, 3, "klub"),
("Štapni usisavač Electrolux", 107, 219, 3, NULL),
("Električno glačalo Tefal", 63.9, 139.9, 3, NULL),
("Mikrovalna pećnica Hisense", 47.5, 109.9, 3, NULL),
("Blender Beko", 19, 45.99, 3, "klub"),
("Preklopni toster Beko", 9, 29.99, 3, NULL),
("LED TV Telefunken", 103, 260, 4, NULL),
("LED TV Grundig", 107, 250, 4, NULL),
("LED TV Philips", 140, 340, 4, NULL),
("OLED TV LG", 400, 1099, 4, NULL),
("Digitalni prijemnik Denver", 11.5, 32.60, 4, "klub"),
("Digitalni prijemnik Manta", 8, 24.40, 4, "klub"),
("Soundbar Sony", 90, 316, 4, NULL),
("Samsung galaxy A25 5G", 152.5, 379.9, 5, NULL),
("Samsung galaxy S24", 299.9, 809.9, 5, NULL),
("Xiaomi Mi 13T", 195, 450, 5, NULL),
("Xiaomi Redmi Note 13 Pro", 130.9, 349.9, 5, NULL),
("Pametni sat Cubot C29", 16.9, 43.9, 5, NULL),
("Pametni sat Amazfit BIP 5", 37.9, 89.99, 5, NULL),
("Pametni sat Huawei Fit", 39.99, 109.99, 5, "klub"),
("Prijenosni radio JBL Tuner2", 44.5, 124.99, 6, "klub"),
("Bluetooth zvučnik LG XL9T", 168, 419.90, 6, NULL),
("In-ear slušalice Panasonic", 16.99, 49.99, 6, NULL),
("Nadzorna kamera Xiaomi C400", 21.7, 59.7, 6, NULL),
("Drvena stolica Wilma", 24.3, 69.99, 7, "kolicina"),
("Drvena vrtna garnitura Xara", 289.9, 799.9, 7, NULL),
("Metalne stolice Bologna", 63.6, 169.8, 7, NULL),
("Metalna ležaljka Tori", 21.9, 59.99, 7, NULL),
("Suncobran Melon 3m", 19.99, 49.99, 7, NULL),
("Suncobran Starfish 2m", 6, 19.99, 7, NULL),
("Kanta za zalijevanje Blumax", 0.6, 2.29, 8, NULL),
("Plastenik Gardentec 4x3m", 240, 648, 8, NULL),
("Plastenik Gardentec 8x3m", 460, 1296, 8, NULL),
("Žardinjera Blumax", 14.99, 39.99, 8, "klub"),
("PVC Tegla Blumax", 0.8, 3.99, 8, NULL),
("Vile čelične 4 roga", 4.3, 12.4, 9, NULL),
("Kosijer veliki", 10.7, 26.9, 9, NULL),
("Motika fočanska", 9.99, 26.9, 9, NULL),
("Motika slavonska", 6.9, 19.9, 9, NULL),
("Vrtne rukavice reciklirane", 0.4, 2.29, 9, "kolicina"),
("Gumene čizme PVC", 4.99, 19.99, 9, NULL),
("Spaghetti Barilla 1kg", 0.59, 2.95, 10, NULL),
("Fusilli Barilla 1kg", 0.59, 2.95, 10, NULL),
("Umak napoletana Barilla 400g", 0.75, 3.25, 10, "klub"),
("Rio Mare tuna u ulju 2x80g", 1.7, 4.99, 10, "klub"),
("Milka čokoladni namaz 600g", 2.8, 6.99, 10, NULL),
("Hell energy 0.5l", 0.35, 1.42, 11, NULL),
("Jana vitamin limun 0.5l", 0.34, 1.4, 11, NULL),
("Jana ledeni čaj breskva 1.5l", 0.6, 1.92, 11, NULL),
("Jana voda 1.5l", 0.28, 1.1, 11, NULL),
("Jamnica gazirana 1.5l", 0.31, 1.1, 11, NULL),
("Jagermeister 0.7l", 5.25, 16.02, 11, NULL),
("Smirnoff red vodka 0.7l", 4.52, 13.02, 11, NULL),
("Bombay sapphire gin 0.7l", 7.22, 22.72, 11, "klub"),
("Milka lješnjak 46g", 0.4, 1.19, 12, "kolicina"),
("Milka oreo 37g", 0.3, 0.99, 12, NULL),
("Mentos cola 38g", 0.19, 0.79, 12, NULL),
("TUC krekeri paprika 100g", 0.36, 1.15, 12, "kolicina"),
("Toblerone 35g", 0.34, 1.09, 12, NULL),
("Bobi flips 90g", 0.29, 0.95, 12, "kolicina"),
("Nivea krema 150ml", 1.19, 3.8, 13, NULL),
("Violeta vlažne maramice", 0.39, 1.99, 13, "kolicina"),
("Palmolive 2u1 šampon 350ml", 1.29, 3, 13, NULL),
("Sanytol dezinfekcijski gel za ruke 75ml", 1.4, 3.25, 13, NULL),
("Persil power kapsule 44kom", 6.39, 15.49, 14, NULL),
("Smac odmašćivač 650ml", 0.99, 3.32, 14, NULL),
("Cif cream lemon 500ml", 0.79, 2.59, 14, NULL),
("Somat sol 1.2kg", 0.6, 1.99, 14, NULL),
("Ornel omekšivač 2.4l", 2.35, 6.63, 14, NULL),
("Čarli classic deterdžent 450ml", 0.42, 1.45, 14, "kolicina");

INSERT INTO racun(kupac_id, zaposlenik_id, nacin_placanja, datum, status) VALUES
(1, 6, 'POS', STR_TO_DATE('2025-01-28 22:41:47', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(6, 4, 'gotovina', STR_TO_DATE('2025-01-12 15:01:39', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(3, 5, 'gotovina', STR_TO_DATE('2025-01-24 20:53:31', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(1, 6, 'POS', STR_TO_DATE('2025-01-08 14:32:55', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(4, 2, 'POS', STR_TO_DATE('2025-01-16 09:05:06', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 9, 'gotovina', STR_TO_DATE('2025-01-10 08:01:57', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 3, 'POS', STR_TO_DATE('2025-01-11 22:47:58', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(6, 5, 'gotovina', STR_TO_DATE('2025-01-14 10:16:44', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(1, 6, 'POS', STR_TO_DATE('2025-01-15 19:19:27', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 9, 'POS', STR_TO_DATE('2025-01-02 09:25:54', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(4, 4, 'gotovina', STR_TO_DATE('2025-01-14 13:11:31', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 5, 'POS', STR_TO_DATE('2025-01-07 09:27:59', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 1, 'gotovina', STR_TO_DATE('2025-01-04 21:33:05', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 3, 'POS', STR_TO_DATE('2025-01-27 19:58:42', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(5, 7, 'POS', STR_TO_DATE('2025-01-05 21:24:22', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 3, 'POS', STR_TO_DATE('2025-01-24 10:15:53', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 4, 'POS', STR_TO_DATE('2025-01-05 16:40:06', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 1, 'POS', STR_TO_DATE('2025-01-27 12:26:48', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(5, 1, 'POS', STR_TO_DATE('2025-01-08 16:03:08', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(6, 3, 'POS', STR_TO_DATE('2025-01-17 11:07:33', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 7, 'POS', STR_TO_DATE('2025-01-06 17:20:53', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(5, 2, 'POS', STR_TO_DATE('2025-01-10 21:27:57', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 3, 'gotovina', STR_TO_DATE('2025-01-24 22:21:24', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 9, 'POS', STR_TO_DATE('2025-01-04 21:57:06', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 1, 'POS', STR_TO_DATE('2025-01-24 09:00:46', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 1, 'gotovina', STR_TO_DATE('2025-01-14 20:34:27', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 5, 'POS', STR_TO_DATE('2025-01-04 22:04:32', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(2, 9, 'POS', STR_TO_DATE('2025-01-24 19:36:00', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 8, 'POS', STR_TO_DATE('2025-01-18 13:30:10', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 1, 'POS', STR_TO_DATE('2025-01-01 18:14:19', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(4, 6, 'POS', STR_TO_DATE('2025-01-12 19:56:28', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 8, 'gotovina', STR_TO_DATE('2025-01-14 12:11:15', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 4, 'POS', STR_TO_DATE('2025-01-26 08:59:50', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 9, 'POS', STR_TO_DATE('2025-01-16 09:16:25', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 6, 'POS', STR_TO_DATE('2025-01-24 18:32:40', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(6, 5, 'POS', STR_TO_DATE('2025-01-09 16:35:43', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 5, 'gotovina', STR_TO_DATE('2025-01-26 17:34:41', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 5, 'POS', STR_TO_DATE('2025-01-26 15:29:02', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 6, 'POS', STR_TO_DATE('2025-01-04 11:55:43', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(4, 7, 'gotovina', STR_TO_DATE('2025-01-04 22:25:19', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 4, 'POS', STR_TO_DATE('2025-01-08 20:25:50', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(4, 9, 'POS', STR_TO_DATE('2025-01-05 21:46:47', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 4, 'POS', STR_TO_DATE('2025-01-11 20:42:42', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 5, 'gotovina', STR_TO_DATE('2025-01-25 09:00:09', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(1, 1, 'POS', STR_TO_DATE('2025-01-15 11:30:57', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 3, 'gotovina', STR_TO_DATE('2025-01-09 11:47:02', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 5, 'POS', STR_TO_DATE('2025-01-06 14:59:25', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 1, 'POS', STR_TO_DATE('2025-01-24 22:55:25', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(1, 8, 'POS', STR_TO_DATE('2025-01-10 18:14:56', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 7, 'POS', STR_TO_DATE('2025-01-24 16:15:14', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 9, 'POS', STR_TO_DATE('2025-01-02 22:03:39', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(1, 6, 'gotovina', STR_TO_DATE('2025-01-02 09:41:54', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 9, 'POS', STR_TO_DATE('2025-01-02 22:35:54', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 9, 'POS', STR_TO_DATE('2025-01-14 20:36:24', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(1, 3, 'gotovina', STR_TO_DATE('2025-01-14 11:08:27', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 1, 'gotovina', STR_TO_DATE('2025-01-04 09:53:21', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 6, 'POS', STR_TO_DATE('2025-01-23 08:53:38', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 7, 'gotovina', STR_TO_DATE('2025-01-28 10:04:16', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(4, 5, 'POS', STR_TO_DATE('2025-01-19 09:10:28', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(3, 6, 'POS', STR_TO_DATE('2025-01-27 16:43:51', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 3, 'POS', STR_TO_DATE('2025-01-11 22:39:04', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 2, 'gotovina', STR_TO_DATE('2025-01-16 16:17:18', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 4, 'gotovina', STR_TO_DATE('2025-01-06 08:52:34', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(1, 9, 'POS', STR_TO_DATE('2025-01-27 08:55:23', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 1, 'POS', STR_TO_DATE('2025-01-28 20:56:02', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(2, 3, 'POS', STR_TO_DATE('2025-01-13 20:15:23', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 2, 'POS', STR_TO_DATE('2025-01-13 10:22:15', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(5, 3, 'POS', STR_TO_DATE('2025-01-10 19:39:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 9, 'POS', STR_TO_DATE('2025-01-24 14:11:19', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 1, 'POS', STR_TO_DATE('2025-01-23 18:46:18', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(1, 4, 'gotovina', STR_TO_DATE('2025-01-24 09:07:23', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 3, 'POS', STR_TO_DATE('2025-01-23 21:58:08', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 5, 'POS', STR_TO_DATE('2025-01-06 12:11:19', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 7, 'POS', STR_TO_DATE('2025-01-10 12:56:35', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(4, 4, 'POS', STR_TO_DATE('2025-01-03 21:05:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(5, 6, 'POS', STR_TO_DATE('2025-01-01 09:17:27', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 6, 'POS', STR_TO_DATE('2025-01-14 18:09:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 5, 'POS', STR_TO_DATE('2025-01-21 14:47:52', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 1, 'POS', STR_TO_DATE('2025-01-08 21:30:31', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 6, 'POS', STR_TO_DATE('2025-01-13 14:29:24', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 7, 'POS', STR_TO_DATE('2025-01-10 21:55:34', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 8, 'POS', STR_TO_DATE('2025-01-12 16:14:53', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 9, 'POS', STR_TO_DATE('2025-01-03 14:34:12', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 7, 'POS', STR_TO_DATE('2025-01-16 09:42:31', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(4, 8, 'gotovina', STR_TO_DATE('2025-01-03 12:23:12', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 4, 'POS', STR_TO_DATE('2025-01-07 22:09:39', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 3, 'POS', STR_TO_DATE('2025-01-07 19:11:38', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 9, 'POS', STR_TO_DATE('2025-01-19 19:57:42', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 3, 'POS', STR_TO_DATE('2025-01-06 09:52:48', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 3, 'gotovina', STR_TO_DATE('2025-01-10 12:56:24', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 9, 'POS', STR_TO_DATE('2025-01-19 20:19:58', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(1, 4, 'POS', STR_TO_DATE('2025-01-18 12:24:57', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 15, 'POS', STR_TO_DATE('2025-01-03 20:09:57', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(12, 14, 'POS', STR_TO_DATE('2025-01-20 08:13:01', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(7, 15, 'POS', STR_TO_DATE('2025-01-18 20:29:40', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(8, 17, 'POS', STR_TO_DATE('2025-01-19 08:41:37', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(12, 15, 'POS', STR_TO_DATE('2025-01-08 22:47:28', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 18, 'POS', STR_TO_DATE('2025-01-05 21:30:11', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 16, 'POS', STR_TO_DATE('2025-01-11 11:43:05', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(7, 12, 'POS', STR_TO_DATE('2025-01-26 20:45:34', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(12, 12, 'POS', STR_TO_DATE('2025-01-21 16:06:54', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 17, 'POS', STR_TO_DATE('2025-01-16 12:58:13', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 11, 'POS', STR_TO_DATE('2025-01-04 16:18:46', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 15, 'POS', STR_TO_DATE('2025-01-28 17:13:52', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 17, 'POS', STR_TO_DATE('2025-01-28 09:27:47', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(9, 18, 'POS', STR_TO_DATE('2025-01-13 21:41:01', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 15, 'POS', STR_TO_DATE('2025-01-19 22:17:31', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 17, 'gotovina', STR_TO_DATE('2025-01-14 14:16:07', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 13, 'POS', STR_TO_DATE('2025-01-20 22:59:22', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 12, 'POS', STR_TO_DATE('2025-01-28 08:45:27', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 16, 'POS', STR_TO_DATE('2025-01-17 22:50:15', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 15, 'POS', STR_TO_DATE('2025-01-20 09:44:01', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(12, 14, 'POS', STR_TO_DATE('2025-01-14 18:32:59', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(9, 10, 'POS', STR_TO_DATE('2025-01-16 14:46:28', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 16, 'POS', STR_TO_DATE('2025-01-03 15:45:54', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 11, 'POS', STR_TO_DATE('2025-01-24 17:43:50', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 16, 'POS', STR_TO_DATE('2025-01-16 16:41:20', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(10, 15, 'POS', STR_TO_DATE('2025-01-24 13:47:08', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 14, 'gotovina', STR_TO_DATE('2025-01-02 17:45:01', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 17, 'POS', STR_TO_DATE('2025-01-17 19:43:36', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 10, 'POS', STR_TO_DATE('2025-01-06 18:42:39', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(11, 12, 'POS', STR_TO_DATE('2025-01-24 08:57:17', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 10, 'POS', STR_TO_DATE('2025-01-22 09:06:36', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 15, 'POS', STR_TO_DATE('2025-01-22 10:03:13', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 18, 'POS', STR_TO_DATE('2025-01-15 13:16:09', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(7, 16, 'POS', STR_TO_DATE('2025-01-03 21:41:39', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(12, 17, 'POS', STR_TO_DATE('2025-01-28 09:31:27', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(9, 15, 'POS', STR_TO_DATE('2025-01-06 14:19:38', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 14, 'POS', STR_TO_DATE('2025-01-27 08:14:40', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 16, 'gotovina', STR_TO_DATE('2025-01-14 15:40:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 15, 'POS', STR_TO_DATE('2025-01-27 16:02:00', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 13, 'POS', STR_TO_DATE('2025-01-25 10:34:13', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(7, 18, 'gotovina', STR_TO_DATE('2025-01-23 13:21:22', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 10, 'POS', STR_TO_DATE('2025-01-05 11:29:08', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 15, 'POS', STR_TO_DATE('2025-01-25 18:11:19', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 17, 'gotovina', STR_TO_DATE('2025-01-28 16:53:56', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(10, 11, 'POS', STR_TO_DATE('2025-01-03 15:38:04', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 16, 'POS', STR_TO_DATE('2025-01-12 20:01:05', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 10, 'gotovina', STR_TO_DATE('2025-01-11 10:12:28', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 17, 'POS', STR_TO_DATE('2025-01-20 21:06:18', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 13, 'POS', STR_TO_DATE('2025-01-02 20:37:01', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(10, 14, 'gotovina', STR_TO_DATE('2025-01-14 18:54:05', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(9, 10, 'POS', STR_TO_DATE('2025-01-02 09:27:11', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(10, 14, 'gotovina', STR_TO_DATE('2025-01-25 13:50:13', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 15, 'POS', STR_TO_DATE('2025-01-14 18:41:15', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 10, 'POS', STR_TO_DATE('2025-01-11 15:14:48', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(11, 12, 'POS', STR_TO_DATE('2025-01-01 12:48:31', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(9, 18, 'POS', STR_TO_DATE('2025-01-19 10:55:04', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(10, 12, 'POS', STR_TO_DATE('2025-01-02 11:49:41', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(11, 11, 'gotovina', STR_TO_DATE('2025-01-19 10:01:19', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(12, 12, 'POS', STR_TO_DATE('2025-01-28 21:04:54', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 15, 'POS', STR_TO_DATE('2025-01-25 16:58:42', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(8, 10, 'POS', STR_TO_DATE('2025-01-02 17:44:27', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(10, 12, 'POS', STR_TO_DATE('2025-01-10 08:32:01', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 15, 'POS', STR_TO_DATE('2025-01-19 19:24:02', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 10, 'POS', STR_TO_DATE('2025-01-03 19:43:42', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 10, 'POS', STR_TO_DATE('2025-01-15 22:09:24', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(8, 11, 'gotovina', STR_TO_DATE('2025-01-23 16:05:35', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 14, 'POS', STR_TO_DATE('2025-01-15 09:36:36', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 10, 'POS', STR_TO_DATE('2025-01-18 10:47:18', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 18, 'POS', STR_TO_DATE('2025-01-04 08:29:47', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(7, 13, 'POS', STR_TO_DATE('2025-01-23 13:39:16', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(9, 18, 'POS', STR_TO_DATE('2025-01-10 21:26:00', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 10, 'POS', STR_TO_DATE('2025-01-13 22:31:41', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(10, 14, 'gotovina', STR_TO_DATE('2025-01-05 19:14:45', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 14, 'gotovina', STR_TO_DATE('2025-01-24 14:07:12', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 11, 'POS', STR_TO_DATE('2025-01-04 11:49:47', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 11, 'POS', STR_TO_DATE('2025-01-18 08:46:31', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 15, 'gotovina', STR_TO_DATE('2025-01-14 22:21:18', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 18, 'POS', STR_TO_DATE('2025-01-09 12:27:29', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 12, 'POS', STR_TO_DATE('2025-01-26 11:38:17', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 12, 'POS', STR_TO_DATE('2025-01-05 18:52:07', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 11, 'POS', STR_TO_DATE('2025-01-13 17:07:55', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(9, 10, 'gotovina', STR_TO_DATE('2025-01-22 11:46:29', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(9, 11, 'POS', STR_TO_DATE('2025-01-13 20:38:58', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(10, 18, 'POS', STR_TO_DATE('2025-01-24 13:17:19', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(7, 17, 'POS', STR_TO_DATE('2025-01-10 18:53:32', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 11, 'gotovina', STR_TO_DATE('2025-01-05 22:57:31', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(12, 18, 'gotovina', STR_TO_DATE('2025-01-04 14:06:32', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 14, 'POS', STR_TO_DATE('2025-01-23 17:41:08', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 13, 'POS', STR_TO_DATE('2025-01-13 21:43:26', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 13, 'POS', STR_TO_DATE('2025-01-12 09:40:34', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(10, 10, 'POS', STR_TO_DATE('2025-01-05 17:06:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(11, 14, 'POS', STR_TO_DATE('2025-01-23 21:25:10', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(8, 17, 'gotovina', STR_TO_DATE('2025-01-24 10:35:40', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 14, 'POS', STR_TO_DATE('2025-01-14 13:24:50', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(8, 12, 'POS', STR_TO_DATE('2025-01-06 22:19:42', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(10, 13, 'POS', STR_TO_DATE('2025-01-09 11:20:56', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 18, 'POS', STR_TO_DATE('2025-01-09 10:20:57', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 17, 'POS', STR_TO_DATE('2025-01-27 12:48:09', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 17, 'POS', STR_TO_DATE('2025-01-27 12:30:19', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 18, 'POS', STR_TO_DATE('2025-01-19 20:19:19', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 13, 'POS', STR_TO_DATE('2025-01-08 19:40:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 15, 'POS', STR_TO_DATE('2025-01-01 18:53:28', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(12, 18, 'POS', STR_TO_DATE('2025-01-21 18:39:08', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(9, 18, 'POS', STR_TO_DATE('2025-01-04 10:35:31', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 21, 'POS', STR_TO_DATE('2025-01-18 13:13:37', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 23, 'gotovina', STR_TO_DATE('2025-01-09 22:41:13', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 26, 'POS', STR_TO_DATE('2025-01-25 14:20:16', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 22, 'gotovina', STR_TO_DATE('2025-01-28 20:29:17', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(14, 20, 'POS', STR_TO_DATE('2025-01-21 14:19:25', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 19, 'POS', STR_TO_DATE('2025-01-24 18:44:24', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 21, 'gotovina', STR_TO_DATE('2025-01-09 11:58:47', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 26, 'POS', STR_TO_DATE('2025-01-02 11:59:57', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 19, 'POS', STR_TO_DATE('2025-01-25 17:48:00', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 22, 'POS', STR_TO_DATE('2025-01-07 10:16:59', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 21, 'POS', STR_TO_DATE('2025-01-28 11:10:53', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(18, 26, 'POS', STR_TO_DATE('2025-01-28 18:33:38', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 25, 'POS', STR_TO_DATE('2025-01-09 17:01:08', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 21, 'POS', STR_TO_DATE('2025-01-03 19:49:24', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(17, 22, 'POS', STR_TO_DATE('2025-01-05 12:06:12', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(17, 23, 'POS', STR_TO_DATE('2025-01-25 11:02:24', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 20, 'POS', STR_TO_DATE('2025-01-27 18:20:44', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(18, 20, 'POS', STR_TO_DATE('2025-01-07 19:06:00', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(15, 20, 'POS', STR_TO_DATE('2025-01-04 18:02:45', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(17, 21, 'POS', STR_TO_DATE('2025-01-02 18:38:35', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 23, 'POS', STR_TO_DATE('2025-01-21 09:24:12', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 21, 'POS', STR_TO_DATE('2025-01-01 11:13:19', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(18, 20, 'gotovina', STR_TO_DATE('2025-01-21 10:58:54', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(15, 22, 'POS', STR_TO_DATE('2025-01-03 16:27:56', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 19, 'POS', STR_TO_DATE('2025-01-16 20:53:58', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 24, 'POS', STR_TO_DATE('2025-01-26 16:44:35', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 23, 'POS', STR_TO_DATE('2025-01-07 13:44:07', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 22, 'POS', STR_TO_DATE('2025-01-25 21:47:04', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 23, 'POS', STR_TO_DATE('2025-01-15 22:13:47', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(15, 22, 'POS', STR_TO_DATE('2025-01-26 19:46:54', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 23, 'POS', STR_TO_DATE('2025-01-16 18:30:47', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 27, 'POS', STR_TO_DATE('2025-01-14 12:04:27', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(18, 22, 'POS', STR_TO_DATE('2025-01-16 12:04:25', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(17, 19, 'POS', STR_TO_DATE('2025-01-04 11:07:29', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(16, 20, 'gotovina', STR_TO_DATE('2025-01-09 16:58:48', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(18, 21, 'POS', STR_TO_DATE('2025-01-28 09:12:54', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 26, 'POS', STR_TO_DATE('2025-01-19 16:48:51', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(15, 25, 'POS', STR_TO_DATE('2025-01-19 12:25:30', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 25, 'POS', STR_TO_DATE('2025-01-25 10:46:48', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(17, 22, 'POS', STR_TO_DATE('2025-01-04 22:53:14', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 24, 'POS', STR_TO_DATE('2025-01-16 15:14:46', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(13, 20, 'POS', STR_TO_DATE('2025-01-22 12:36:46', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(13, 22, 'gotovina', STR_TO_DATE('2025-01-24 09:54:06', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(17, 24, 'POS', STR_TO_DATE('2025-01-09 18:46:19', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 26, 'POS', STR_TO_DATE('2025-01-04 20:33:02', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(17, 23, 'gotovina', STR_TO_DATE('2025-01-12 22:21:31', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 22, 'POS', STR_TO_DATE('2025-01-06 11:56:48', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(17, 23, 'gotovina', STR_TO_DATE('2025-01-13 22:54:26', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(15, 26, 'POS', STR_TO_DATE('2025-01-27 16:19:26', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(13, 24, 'POS', STR_TO_DATE('2025-01-12 09:52:19', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 24, 'POS', STR_TO_DATE('2025-01-27 22:31:28', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 24, 'POS', STR_TO_DATE('2025-01-26 15:54:30', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 25, 'POS', STR_TO_DATE('2025-01-02 19:09:00', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 25, 'POS', STR_TO_DATE('2025-01-06 14:01:52', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(16, 22, 'gotovina', STR_TO_DATE('2025-01-27 08:21:56', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 23, 'POS', STR_TO_DATE('2025-01-02 12:36:30', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(15, 23, 'gotovina', STR_TO_DATE('2025-01-21 17:19:02', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(17, 27, 'POS', STR_TO_DATE('2025-01-05 15:04:11', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(16, 23, 'gotovina', STR_TO_DATE('2025-01-02 12:44:31', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 19, 'gotovina', STR_TO_DATE('2025-01-17 22:55:38', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 22, 'POS', STR_TO_DATE('2025-01-13 17:20:54', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(18, 27, 'POS', STR_TO_DATE('2025-01-02 22:28:34', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(18, 26, 'gotovina', STR_TO_DATE('2025-01-14 20:16:47', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(16, 21, 'gotovina', STR_TO_DATE('2025-01-27 19:06:24', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 20, 'POS', STR_TO_DATE('2025-01-10 17:22:49', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 21, 'POS', STR_TO_DATE('2025-01-11 08:22:09', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(18, 27, 'POS', STR_TO_DATE('2025-01-24 14:48:26', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(13, 19, 'POS', STR_TO_DATE('2025-01-28 11:47:26', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 24, 'gotovina', STR_TO_DATE('2025-01-04 20:11:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(14, 19, 'POS', STR_TO_DATE('2025-01-26 14:32:10', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 21, 'POS', STR_TO_DATE('2025-01-27 15:32:44', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 22, 'POS', STR_TO_DATE('2025-01-21 21:26:59', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 24, 'gotovina', STR_TO_DATE('2025-01-10 18:49:17', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 27, 'POS', STR_TO_DATE('2025-01-17 09:05:20', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 20, 'POS', STR_TO_DATE('2025-01-14 18:23:45', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(15, 20, 'POS', STR_TO_DATE('2025-01-23 14:50:14', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 20, 'gotovina', STR_TO_DATE('2025-01-12 09:06:18', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(17, 19, 'gotovina', STR_TO_DATE('2025-01-08 17:10:32', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 20, 'gotovina', STR_TO_DATE('2025-01-24 20:03:44', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 27, 'POS', STR_TO_DATE('2025-01-19 22:17:17', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(13, 26, 'gotovina', STR_TO_DATE('2025-01-03 13:09:23', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 19, 'gotovina', STR_TO_DATE('2025-01-05 19:57:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 26, 'POS', STR_TO_DATE('2025-01-03 09:52:54', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 27, 'POS', STR_TO_DATE('2025-01-21 14:07:00', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(17, 25, 'POS', STR_TO_DATE('2025-01-20 18:02:34', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(17, 24, 'POS', STR_TO_DATE('2025-01-21 16:41:06', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 22, 'POS', STR_TO_DATE('2025-01-25 08:30:27', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(16, 23, 'POS', STR_TO_DATE('2025-01-20 16:10:21', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 21, 'POS', STR_TO_DATE('2025-01-11 09:33:04', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(13, 27, 'POS', STR_TO_DATE('2025-01-13 14:13:18', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 25, 'gotovina', STR_TO_DATE('2025-01-27 09:06:31', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 20, 'POS', STR_TO_DATE('2025-01-25 17:14:54', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(17, 26, 'POS', STR_TO_DATE('2025-01-05 13:41:07', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 21, 'POS', STR_TO_DATE('2025-01-06 18:48:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(15, 22, 'POS', STR_TO_DATE('2025-01-14 18:49:12', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(18, 19, 'POS', STR_TO_DATE('2025-01-13 08:16:55', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 26, 'POS', STR_TO_DATE('2025-01-07 10:29:30', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 22, 'gotovina', STR_TO_DATE('2025-01-15 16:27:07', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(14, 21, 'POS', STR_TO_DATE('2025-01-25 16:07:07', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(16, 25, 'POS', STR_TO_DATE('2025-01-04 11:14:17', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(16, 27, 'gotovina', STR_TO_DATE('2025-01-21 10:33:35', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 31, 'gotovina', STR_TO_DATE('2025-01-25 09:52:31', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 34, 'gotovina', STR_TO_DATE('2025-01-19 08:09:01', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 28, 'POS', STR_TO_DATE('2025-01-20 16:12:39', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 34, 'POS', STR_TO_DATE('2025-01-15 20:28:16', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 34, 'POS', STR_TO_DATE('2025-01-07 20:44:54', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(22, 31, 'gotovina', STR_TO_DATE('2025-01-23 15:17:58', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 32, 'POS', STR_TO_DATE('2025-01-12 19:58:01', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 33, 'gotovina', STR_TO_DATE('2025-01-12 14:46:08', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(21, 28, 'gotovina', STR_TO_DATE('2025-01-04 22:59:01', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(23, 30, 'POS', STR_TO_DATE('2025-01-27 19:45:23', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(22, 28, 'gotovina', STR_TO_DATE('2025-01-26 08:44:58', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(21, 29, 'POS', STR_TO_DATE('2025-01-17 21:53:01', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(20, 32, 'POS', STR_TO_DATE('2025-01-12 18:31:49', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 33, 'POS', STR_TO_DATE('2025-01-08 18:45:36', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(19, 28, 'gotovina', STR_TO_DATE('2025-01-26 08:31:05', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(23, 30, 'POS', STR_TO_DATE('2025-01-23 16:57:47', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(22, 31, 'POS', STR_TO_DATE('2025-01-01 12:51:40', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 31, 'POS', STR_TO_DATE('2025-01-27 08:57:39', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 34, 'POS', STR_TO_DATE('2025-01-24 15:55:48', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(22, 30, 'gotovina', STR_TO_DATE('2025-01-18 16:52:44', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 34, 'POS', STR_TO_DATE('2025-01-19 21:10:44', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(23, 30, 'POS', STR_TO_DATE('2025-01-19 18:37:17', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(20, 31, 'POS', STR_TO_DATE('2025-01-17 22:47:44', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 31, 'POS', STR_TO_DATE('2025-01-08 18:47:37', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 30, 'POS', STR_TO_DATE('2025-01-28 10:54:07', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 31, 'gotovina', STR_TO_DATE('2025-01-11 21:38:57', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 29, 'gotovina', STR_TO_DATE('2025-01-10 19:19:07', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(21, 28, 'POS', STR_TO_DATE('2025-01-13 21:17:17', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 29, 'POS', STR_TO_DATE('2025-01-19 15:44:19', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(20, 33, 'POS', STR_TO_DATE('2025-01-09 22:39:31', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(24, 34, 'POS', STR_TO_DATE('2025-01-15 17:10:02', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(23, 33, 'POS', STR_TO_DATE('2025-01-11 21:13:10', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 28, 'POS', STR_TO_DATE('2025-01-08 19:50:40', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(20, 28, 'POS', STR_TO_DATE('2025-01-11 13:28:29', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 33, 'gotovina', STR_TO_DATE('2025-01-02 13:56:17', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 30, 'POS', STR_TO_DATE('2025-01-08 16:13:31', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 31, 'POS', STR_TO_DATE('2025-01-13 19:02:41', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 32, 'POS', STR_TO_DATE('2025-01-26 13:23:22', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 28, 'POS', STR_TO_DATE('2025-01-12 08:49:14', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(21, 34, 'POS', STR_TO_DATE('2025-01-26 11:56:05', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(22, 28, 'POS', STR_TO_DATE('2025-01-25 17:21:45', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 31, 'POS', STR_TO_DATE('2025-01-24 12:50:29', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(20, 31, 'POS', STR_TO_DATE('2025-01-15 21:28:55', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(24, 31, 'POS', STR_TO_DATE('2025-01-20 11:02:58', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(20, 33, 'gotovina', STR_TO_DATE('2025-01-19 16:07:23', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(21, 32, 'POS', STR_TO_DATE('2025-01-10 14:00:56', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(19, 28, 'POS', STR_TO_DATE('2025-01-11 13:54:58', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(23, 30, 'POS', STR_TO_DATE('2025-01-18 11:07:08', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 33, 'POS', STR_TO_DATE('2025-01-02 14:37:34', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 34, 'POS', STR_TO_DATE('2025-01-02 11:14:57', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(23, 31, 'POS', STR_TO_DATE('2025-01-26 10:41:58', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 29, 'POS', STR_TO_DATE('2025-01-21 09:50:05', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 33, 'POS', STR_TO_DATE('2025-01-11 12:13:17', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 33, 'POS', STR_TO_DATE('2025-01-22 15:11:55', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(22, 32, 'POS', STR_TO_DATE('2025-01-10 20:03:47', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 29, 'POS', STR_TO_DATE('2025-01-22 15:01:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(20, 32, 'POS', STR_TO_DATE('2025-01-20 22:24:56', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(19, 34, 'POS', STR_TO_DATE('2025-01-19 11:10:23', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(23, 28, 'POS', STR_TO_DATE('2025-01-10 10:45:30', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(23, 32, 'POS', STR_TO_DATE('2025-01-23 13:02:45', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(22, 33, 'gotovina', STR_TO_DATE('2025-01-10 09:06:05', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 32, 'POS', STR_TO_DATE('2025-01-01 19:53:27', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(19, 28, 'POS', STR_TO_DATE('2025-01-24 19:47:14', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 30, 'POS', STR_TO_DATE('2025-01-27 17:33:18', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 31, 'POS', STR_TO_DATE('2025-01-17 21:47:40', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(20, 31, 'gotovina', STR_TO_DATE('2025-01-24 22:38:58', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(22, 29, 'POS', STR_TO_DATE('2025-01-04 13:21:20', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(20, 31, 'POS', STR_TO_DATE('2025-01-02 20:10:52', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 33, 'POS', STR_TO_DATE('2025-01-17 09:42:56', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(24, 31, 'POS', STR_TO_DATE('2025-01-17 19:18:52', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(24, 32, 'gotovina', STR_TO_DATE('2025-01-18 13:36:11', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 30, 'POS', STR_TO_DATE('2025-01-03 09:53:43', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(23, 30, 'POS', STR_TO_DATE('2025-01-15 17:19:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(22, 32, 'POS', STR_TO_DATE('2025-01-13 08:53:53', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(21, 31, 'gotovina', STR_TO_DATE('2025-01-10 18:09:43', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 31, 'POS', STR_TO_DATE('2025-01-16 14:16:16', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 34, 'POS', STR_TO_DATE('2025-01-22 11:02:00', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 29, 'POS', STR_TO_DATE('2025-01-04 19:11:36', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(19, 34, 'POS', STR_TO_DATE('2025-01-25 10:01:58', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 34, 'POS', STR_TO_DATE('2025-01-03 15:51:05', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 32, 'POS', STR_TO_DATE('2025-01-23 12:29:27', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 31, 'POS', STR_TO_DATE('2025-01-23 13:52:01', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 32, 'POS', STR_TO_DATE('2025-01-08 20:35:23', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 30, 'POS', STR_TO_DATE('2025-01-17 13:57:38', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(23, 28, 'gotovina', STR_TO_DATE('2025-01-11 15:54:14', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 33, 'POS', STR_TO_DATE('2025-01-26 13:04:51', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 28, 'POS', STR_TO_DATE('2025-01-02 08:47:42', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 38, 'POS', STR_TO_DATE('2025-01-14 15:57:10', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(26, 39, 'POS', STR_TO_DATE('2025-01-05 10:04:59', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 39, 'POS', STR_TO_DATE('2025-01-25 09:26:02', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 36, 'POS', STR_TO_DATE('2025-01-02 08:08:30', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(27, 38, 'POS', STR_TO_DATE('2025-01-15 17:53:00', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 41, 'POS', STR_TO_DATE('2025-01-22 13:59:59', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 40, 'POS', STR_TO_DATE('2025-01-17 22:33:46', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 38, 'POS', STR_TO_DATE('2025-01-16 19:35:06', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 35, 'POS', STR_TO_DATE('2025-01-09 19:04:53', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(29, 39, 'POS', STR_TO_DATE('2025-01-15 14:23:30', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 41, 'gotovina', STR_TO_DATE('2025-01-11 20:05:40', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 37, 'POS', STR_TO_DATE('2025-01-16 15:55:43', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 37, 'POS', STR_TO_DATE('2025-01-14 09:19:39', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 41, 'POS', STR_TO_DATE('2025-01-01 10:28:51', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 40, 'POS', STR_TO_DATE('2025-01-25 09:23:47', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(25, 38, 'gotovina', STR_TO_DATE('2025-01-10 20:42:05', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 36, 'POS', STR_TO_DATE('2025-01-23 15:18:28', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 41, 'POS', STR_TO_DATE('2025-01-09 16:47:21', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 37, 'gotovina', STR_TO_DATE('2025-01-20 14:53:27', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 40, 'gotovina', STR_TO_DATE('2025-01-22 09:43:45', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(26, 40, 'POS', STR_TO_DATE('2025-01-04 11:17:01', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 40, 'POS', STR_TO_DATE('2025-01-01 21:33:50', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 35, 'POS', STR_TO_DATE('2025-01-26 18:46:48', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(25, 37, 'POS', STR_TO_DATE('2025-01-16 17:25:05', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(28, 39, 'POS', STR_TO_DATE('2025-01-09 13:42:49', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(27, 40, 'POS', STR_TO_DATE('2025-01-16 15:36:12', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 35, 'gotovina', STR_TO_DATE('2025-01-07 14:30:45', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(27, 35, 'POS', STR_TO_DATE('2025-01-18 14:20:57', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(26, 41, 'POS', STR_TO_DATE('2025-01-14 19:39:01', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 37, 'POS', STR_TO_DATE('2025-01-03 09:43:01', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 36, 'POS', STR_TO_DATE('2025-01-03 21:15:58', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 38, 'POS', STR_TO_DATE('2025-01-22 12:11:07', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 37, 'gotovina', STR_TO_DATE('2025-01-22 20:30:40', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 39, 'POS', STR_TO_DATE('2025-01-09 19:23:27', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(30, 37, 'POS', STR_TO_DATE('2025-01-17 21:43:51', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 37, 'POS', STR_TO_DATE('2025-01-21 08:25:19', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 41, 'POS', STR_TO_DATE('2025-01-25 19:52:13', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 40, 'POS', STR_TO_DATE('2025-01-06 17:04:19', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(29, 35, 'POS', STR_TO_DATE('2025-01-17 18:05:27', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 36, 'POS', STR_TO_DATE('2025-01-19 14:49:11', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(29, 39, 'POS', STR_TO_DATE('2025-01-09 15:28:13', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(29, 41, 'POS', STR_TO_DATE('2025-01-05 14:51:26', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 41, 'POS', STR_TO_DATE('2025-01-23 10:42:22', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 35, 'POS', STR_TO_DATE('2025-01-23 15:49:36', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 40, 'POS', STR_TO_DATE('2025-01-03 17:22:11', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(28, 35, 'POS', STR_TO_DATE('2025-01-13 16:09:43', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 41, 'POS', STR_TO_DATE('2025-01-17 12:43:09', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(28, 41, 'POS', STR_TO_DATE('2025-01-06 16:02:39', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 40, 'POS', STR_TO_DATE('2025-01-16 17:10:36', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(25, 36, 'POS', STR_TO_DATE('2025-01-07 14:54:31', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 41, 'POS', STR_TO_DATE('2025-01-05 18:17:31', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(29, 35, 'POS', STR_TO_DATE('2025-01-11 21:53:02', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 40, 'gotovina', STR_TO_DATE('2025-01-24 16:12:30', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(27, 41, 'POS', STR_TO_DATE('2025-01-19 11:22:42', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 37, 'POS', STR_TO_DATE('2025-01-21 18:37:52', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(29, 38, 'POS', STR_TO_DATE('2025-01-03 14:55:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(28, 41, 'POS', STR_TO_DATE('2025-01-16 12:29:11', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(30, 38, 'POS', STR_TO_DATE('2025-01-19 11:20:50', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(29, 41, 'POS', STR_TO_DATE('2025-01-20 17:37:58', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(30, 39, 'POS', STR_TO_DATE('2025-01-11 12:29:40', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(25, 39, 'POS', STR_TO_DATE('2025-01-18 22:46:12', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(30, 40, 'POS', STR_TO_DATE('2025-01-27 12:24:58', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(29, 36, 'POS', STR_TO_DATE('2025-01-01 13:11:40', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 35, 'POS', STR_TO_DATE('2025-01-13 21:42:45', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 35, 'POS', STR_TO_DATE('2025-01-15 11:38:52', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(29, 39, 'POS', STR_TO_DATE('2025-01-26 13:47:18', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 35, 'POS', STR_TO_DATE('2025-01-18 22:30:23', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(27, 41, 'gotovina', STR_TO_DATE('2025-01-13 13:16:38', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 41, 'gotovina', STR_TO_DATE('2025-01-20 22:50:59', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 39, 'POS', STR_TO_DATE('2025-01-28 12:33:30', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 36, 'POS', STR_TO_DATE('2025-01-08 08:32:54', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(28, 41, 'gotovina', STR_TO_DATE('2025-01-16 12:39:17', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(27, 40, 'gotovina', STR_TO_DATE('2025-01-18 14:12:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 36, 'POS', STR_TO_DATE('2025-01-16 22:06:15', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 38, 'POS', STR_TO_DATE('2025-01-12 11:36:55', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 40, 'POS', STR_TO_DATE('2025-01-22 21:49:07', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(27, 37, 'POS', STR_TO_DATE('2025-01-27 13:24:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(27, 35, 'gotovina', STR_TO_DATE('2025-01-14 16:39:12', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 36, 'POS', STR_TO_DATE('2025-01-03 14:18:20', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 41, 'POS', STR_TO_DATE('2025-01-03 21:05:59', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(26, 39, 'POS', STR_TO_DATE('2025-01-18 22:38:17', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(25, 35, 'gotovina', STR_TO_DATE('2025-01-24 20:37:46', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(27, 37, 'POS', STR_TO_DATE('2025-01-10 08:56:41', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 36, 'POS', STR_TO_DATE('2025-01-10 10:32:45', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(27, 39, 'POS', STR_TO_DATE('2025-01-16 11:15:34', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(29, 39, 'POS', STR_TO_DATE('2025-01-05 10:33:47', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(29, 36, 'POS', STR_TO_DATE('2025-01-23 22:23:49', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(28, 38, 'POS', STR_TO_DATE('2025-01-12 22:15:22', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 37, 'POS', STR_TO_DATE('2025-01-23 17:56:54', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(26, 41, 'gotovina', STR_TO_DATE('2025-01-20 15:34:39', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 39, 'POS', STR_TO_DATE('2025-01-28 13:54:27', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 39, 'gotovina', STR_TO_DATE('2025-01-14 20:49:49', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(25, 39, 'gotovina', STR_TO_DATE('2025-01-20 09:43:28', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(26, 38, 'POS', STR_TO_DATE('2025-01-01 19:57:58', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(30, 41, 'POS', STR_TO_DATE('2025-01-05 09:25:25', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 38, 'POS', STR_TO_DATE('2025-01-12 19:12:45', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 40, 'POS', STR_TO_DATE('2025-01-21 19:29:04', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(26, 37, 'POS', STR_TO_DATE('2025-01-20 10:54:58', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 37, 'gotovina', STR_TO_DATE('2025-01-11 15:48:04', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(26, 40, 'gotovina', STR_TO_DATE('2025-01-27 19:14:45', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(30, 38, 'gotovina', STR_TO_DATE('2025-01-01 11:53:05', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 41, 'POS', STR_TO_DATE('2025-01-02 11:46:32', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 38, 'POS', STR_TO_DATE('2025-01-19 17:40:29', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 38, 'POS', STR_TO_DATE('2025-01-20 10:57:41', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 48, 'POS', STR_TO_DATE('2025-01-27 14:53:31', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(34, 46, 'POS', STR_TO_DATE('2025-01-08 21:54:15', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 45, 'POS', STR_TO_DATE('2025-01-11 14:56:38', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 42, 'POS', STR_TO_DATE('2025-01-25 19:09:34', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(32, 42, 'POS', STR_TO_DATE('2025-01-05 14:35:55', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 46, 'gotovina', STR_TO_DATE('2025-01-20 11:40:55', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 43, 'POS', STR_TO_DATE('2025-01-20 16:58:58', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 45, 'gotovina', STR_TO_DATE('2025-01-15 17:18:49', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(36, 46, 'POS', STR_TO_DATE('2025-01-27 13:51:07', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 46, 'POS', STR_TO_DATE('2025-01-08 15:42:32', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 46, 'gotovina', STR_TO_DATE('2025-01-28 13:49:17', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 47, 'POS', STR_TO_DATE('2025-01-19 11:54:43', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 43, 'gotovina', STR_TO_DATE('2025-01-27 18:27:00', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 48, 'POS', STR_TO_DATE('2025-01-12 10:07:46', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 47, 'POS', STR_TO_DATE('2025-01-27 20:17:05', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(32, 45, 'gotovina', STR_TO_DATE('2025-01-16 15:59:45', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(31, 42, 'gotovina', STR_TO_DATE('2025-01-22 08:04:47', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 43, 'gotovina', STR_TO_DATE('2025-01-01 12:30:38', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(36, 48, 'gotovina', STR_TO_DATE('2025-01-02 10:04:11', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 46, 'POS', STR_TO_DATE('2025-01-16 11:43:17', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 46, 'POS', STR_TO_DATE('2025-01-10 09:38:15', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(31, 43, 'POS', STR_TO_DATE('2025-01-17 15:24:18', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 45, 'gotovina', STR_TO_DATE('2025-01-16 21:48:13', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 43, 'POS', STR_TO_DATE('2025-01-22 15:36:25', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 42, 'POS', STR_TO_DATE('2025-01-19 09:36:04', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 43, 'gotovina', STR_TO_DATE('2025-01-18 20:58:46', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(34, 47, 'POS', STR_TO_DATE('2025-01-16 15:02:34', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(31, 44, 'POS', STR_TO_DATE('2025-01-26 10:11:30', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(34, 45, 'POS', STR_TO_DATE('2025-01-12 18:42:33', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 47, 'gotovina', STR_TO_DATE('2025-01-23 11:25:06', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(33, 46, 'POS', STR_TO_DATE('2025-01-03 17:07:18', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(32, 47, 'gotovina', STR_TO_DATE('2025-01-06 17:45:19', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 45, 'POS', STR_TO_DATE('2025-01-02 10:21:56', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 47, 'POS', STR_TO_DATE('2025-01-24 18:10:43', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(32, 46, 'POS', STR_TO_DATE('2025-01-09 14:25:48', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(34, 45, 'gotovina', STR_TO_DATE('2025-01-07 21:00:23', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 42, 'POS', STR_TO_DATE('2025-01-08 15:47:55', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 48, 'POS', STR_TO_DATE('2025-01-10 17:31:19', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 44, 'POS', STR_TO_DATE('2025-01-27 15:57:44', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(32, 48, 'POS', STR_TO_DATE('2025-01-14 09:14:26', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 43, 'POS', STR_TO_DATE('2025-01-13 15:42:47', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(33, 46, 'POS', STR_TO_DATE('2025-01-22 18:15:44', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 46, 'POS', STR_TO_DATE('2025-01-27 22:01:26', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 47, 'POS', STR_TO_DATE('2025-01-27 21:38:55', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(35, 48, 'POS', STR_TO_DATE('2025-01-04 15:15:11', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(32, 43, 'POS', STR_TO_DATE('2025-01-04 12:11:56', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(32, 43, 'POS', STR_TO_DATE('2025-01-13 15:07:21', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 42, 'POS', STR_TO_DATE('2025-01-16 12:08:22', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 46, 'POS', STR_TO_DATE('2025-01-20 10:00:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 47, 'gotovina', STR_TO_DATE('2025-01-21 20:06:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 42, 'POS', STR_TO_DATE('2025-01-22 22:43:26', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 45, 'POS', STR_TO_DATE('2025-01-05 12:08:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 47, 'POS', STR_TO_DATE('2025-01-20 15:38:11', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 44, 'POS', STR_TO_DATE('2025-01-27 10:19:35', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 48, 'POS', STR_TO_DATE('2025-01-18 11:11:29', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 45, 'gotovina', STR_TO_DATE('2025-01-23 09:48:49', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 46, 'POS', STR_TO_DATE('2025-01-07 17:06:19', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 43, 'POS', STR_TO_DATE('2025-01-28 12:25:26', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 46, 'POS', STR_TO_DATE('2025-01-21 18:52:36', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 45, 'POS', STR_TO_DATE('2025-01-26 19:43:23', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 47, 'POS', STR_TO_DATE('2025-01-24 09:30:28', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(31, 47, 'POS', STR_TO_DATE('2025-01-23 17:10:11', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 42, 'POS', STR_TO_DATE('2025-01-07 10:05:39', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(36, 47, 'POS', STR_TO_DATE('2025-01-15 10:07:05', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 47, 'POS', STR_TO_DATE('2025-01-16 08:04:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 47, 'gotovina', STR_TO_DATE('2025-01-27 16:15:42', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(35, 45, 'POS', STR_TO_DATE('2025-01-23 18:24:36', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(31, 45, 'POS', STR_TO_DATE('2025-01-16 08:23:26', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 44, 'POS', STR_TO_DATE('2025-01-20 10:40:29', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 47, 'POS', STR_TO_DATE('2025-01-15 08:44:43', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 48, 'POS', STR_TO_DATE('2025-01-27 22:01:43', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 44, 'POS', STR_TO_DATE('2025-01-12 14:08:25', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 47, 'POS', STR_TO_DATE('2025-01-17 18:37:14', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 44, 'POS', STR_TO_DATE('2025-01-21 11:40:13', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(36, 46, 'POS', STR_TO_DATE('2025-01-23 19:53:49', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 42, 'gotovina', STR_TO_DATE('2025-01-18 14:48:41', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 42, 'POS', STR_TO_DATE('2025-01-18 22:03:28', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 44, 'POS', STR_TO_DATE('2025-01-06 16:27:36', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 44, 'POS', STR_TO_DATE('2025-01-23 22:29:26', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(34, 43, 'gotovina', STR_TO_DATE('2025-01-10 11:17:02', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 42, 'POS', STR_TO_DATE('2025-01-27 10:29:09', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(32, 44, 'POS', STR_TO_DATE('2025-01-05 13:10:22', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(33, 46, 'POS', STR_TO_DATE('2025-01-21 21:04:06', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(34, 42, 'gotovina', STR_TO_DATE('2025-01-23 16:49:17', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(36, 44, 'POS', STR_TO_DATE('2025-01-08 19:32:48', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 48, 'POS', STR_TO_DATE('2025-01-24 22:01:20', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 48, 'POS', STR_TO_DATE('2025-01-04 12:39:14', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 45, 'POS', STR_TO_DATE('2025-01-27 20:28:33', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(35, 45, 'POS', STR_TO_DATE('2025-01-06 19:27:35', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 45, 'POS', STR_TO_DATE('2025-01-04 21:51:32', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(35, 46, 'gotovina', STR_TO_DATE('2025-01-10 12:17:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(NULL, 46, 'POS', STR_TO_DATE('2025-01-26 08:43:01', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(31, 42, 'POS', STR_TO_DATE('2025-01-18 17:08:26', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(34, 44, 'POS', STR_TO_DATE('2025-01-07 11:33:21', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(33, 44, 'POS', STR_TO_DATE('2025-01-19 17:24:49', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(36, 46, 'POS', STR_TO_DATE('2025-01-10 11:49:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno');

INSERT INTO stavka(racun_id, proizvod_id, kolicina) VALUES
(2, 56, 2),
(2, 80, 3),
(3, 66, 2),
(3, 44, 1),
(6, 14, 8),
(6, 60, 3),
(6, 47, 5),
(7, 72, 2),
(7, 61, 4),
(7, 66, 4),
(7, 70, 2),
(7, 73, 1),
(7, 57, 1),
(8, 67, 1),
(8, 77, 1),
(10, 6, 1),
(10, 58, 1),
(10, 3, 2),
(10, 64, 1),
(11, 74, 2),
(11, 62, 2),
(12, 64, 1),
(12, 70, 3),
(13, 65, 1),
(13, 25, 1),
(13, 48, 2),
(14, 19, 1),
(14, 59, 3),
(14, 71, 1),
(14, 64, 1),
(16, 76, 3),
(17, 76, 1),
(17, 64, 2),
(17, 66, 3),
(18, 65, 4),
(20, 52, 1),
(21, 65, 1),
(21, 8, 1),
(22, 56, 1),
(23, 68, 1),
(23, 73, 5),
(23, 16, 2),
(24, 44, 1),
(25, 57, 2),
(25, 54, 1),
(25, 80, 5),
(26, 36, 5),
(26, 42, 7),
(26, 69, 2),
(26, 56, 3),
(27, 63, 1),
(27, 70, 3),
(27, 77, 1),
(28, 76, 3),
(28, 43, 1),
(28, 80, 2),
(28, 70, 2),
(28, 81, 1),
(28, 66, 6),
(29, 57, 1),
(30, 77, 1),
(32, 66, 1),
(32, 61, 2),
(33, 38, 1),
(33, 66, 5),
(33, 47, 1),
(33, 14, 1),
(34, 75, 1),
(34, 80, 2),
(35, 52, 1),
(36, 56, 3),
(37, 56, 3),
(37, 68, 2),
(37, 44, 4),
(38, 18, 2),
(39, 16, 1),
(39, 62, 1),
(40, 69, 2),
(40, 63, 2),
(41, 45, 10),
(43, 58, 1),
(43, 3, 1),
(43, 65, 4),
(43, 58, 1),
(43, 63, 3),
(43, 11, 6),
(44, 78, 2),
(45, 5, 1),
(46, 14, 2),
(46, 70, 1),
(47, 67, 2),
(48, 56, 5),
(49, 26, 2),
(49, 79, 1),
(49, 7, 1),
(49, 74, 9),
(49, 45, 3),
(49, 61, 8),
(50, 62, 1),
(51, 78, 1),
(52, 47, 7),
(52, 66, 4),
(53, 9, 1),
(54, 66, 1),
(54, 77, 1),
(55, 14, 2),
(56, 77, 1),
(57, 54, 4),
(58, 57, 4),
(58, 74, 1),
(58, 31, 1),
(58, 9, 1),
(60, 62, 3),
(60, 72, 1),
(61, 76, 2),
(61, 75, 3),
(61, 72, 2),
(61, 71, 5),
(61, 7, 3),
(62, 60, 1),
(62, 34, 1),
(62, 65, 1),
(62, 68, 3),
(63, 66, 4),
(64, 47, 2),
(65, 8, 1),
(65, 81, 3),
(65, 66, 1),
(65, 81, 2),
(66, 76, 2),
(67, 20, 1),
(67, 61, 2),
(67, 66, 3),
(67, 54, 6),
(67, 56, 1),
(67, 34, 1),
(68, 29, 5),
(68, 24, 1),
(68, 61, 2),
(69, 68, 1),
(70, 8, 3),
(70, 61, 2),
(70, 37, 3),
(70, 32, 2),
(70, 66, 5),
(70, 63, 2),
(70, 78, 3),
(70, 80, 1),
(71, 53, 2),
(72, 43, 4),
(72, 43, 6),
(72, 63, 1),
(72, 9, 1),
(72, 49, 2),
(72, 81, 9),
(72, 56, 1),
(72, 25, 4),
(72, 10, 4),
(73, 45, 1),
(74, 61, 6),
(74, 4, 3),
(76, 11, 1),
(77, 56, 1),
(78, 60, 1),
(78, 78, 1),
(79, 77, 1),
(80, 81, 1),
(80, 62, 2),
(80, 55, 1),
(80, 76, 2),
(80, 61, 3),
(80, 48, 1),
(80, 68, 2),
(81, 2, 1),
(81, 12, 1),
(81, 57, 1),
(82, 8, 1),
(82, 58, 1),
(83, 4, 1),
(83, 71, 2),
(84, 79, 2),
(85, 61, 3),
(86, 13, 1),
(86, 71, 6),
(86, 68, 2),
(86, 66, 1),
(86, 54, 1),
(86, 75, 8),
(87, 69, 2),
(87, 64, 2),
(87, 65, 1),
(87, 58, 1),
(87, 72, 1),
(87, 80, 1),
(87, 20, 2),
(88, 64, 1),
(88, 6, 1),
(88, 81, 2),
(88, 30, 2),
(88, 70, 1),
(88, 4, 3),
(88, 80, 1),
(88, 75, 9),
(89, 76, 4),
(89, 56, 1),
(90, 3, 3),
(90, 60, 2),
(91, 73, 1),
(91, 17, 1),
(91, 30, 1),
(91, 64, 1),
(91, 68, 1),
(91, 57, 5),
(91, 75, 1),
(92, 79, 1),
(92, 14, 2),
(92, 62, 1),
(92, 8, 5),
(92, 53, 1),
(92, 20, 1),
(92, 11, 1),
(92, 78, 2),
(92, 22, 1),
(92, 59, 1),
(93, 79, 10),
(93, 80, 1),
(98, 14, 1),
(98, 79, 1),
(98, 7, 6),
(98, 2, 5),
(98, 76, 2),
(98, 57, 2),
(98, 19, 1),
(99, 63, 2),
(101, 57, 2),
(102, 7, 3),
(103, 41, 3),
(104, 8, 1),
(105, 63, 1),
(105, 69, 7),
(107, 63, 2),
(108, 61, 1),
(108, 21, 1),
(109, 62, 2),
(110, 60, 2),
(111, 70, 1),
(111, 61, 1),
(111, 14, 3),
(111, 61, 3),
(112, 55, 2),
(113, 62, 2),
(115, 56, 2),
(115, 67, 1),
(116, 61, 1),
(116, 53, 1),
(116, 63, 1),
(116, 12, 1),
(117, 77, 8),
(117, 56, 4),
(118, 57, 7),
(119, 37, 3),
(119, 53, 1),
(120, 58, 1),
(121, 66, 3),
(121, 75, 1),
(121, 29, 1),
(122, 79, 3),
(123, 77, 1),
(123, 66, 2),
(123, 81, 2),
(124, 59, 1),
(124, 68, 1),
(125, 6, 4),
(125, 64, 1),
(126, 16, 3),
(126, 25, 1),
(126, 3, 1),
(127, 17, 4),
(127, 79, 1),
(127, 43, 1),
(127, 25, 1),
(127, 2, 5),
(127, 57, 3),
(127, 69, 1),
(129, 77, 3),
(130, 65, 1),
(131, 80, 2),
(131, 64, 2),
(132, 77, 1),
(132, 73, 6),
(132, 73, 1),
(132, 72, 1),
(132, 11, 1),
(133, 73, 2),
(134, 81, 2),
(135, 11, 1),
(135, 53, 1),
(136, 59, 1),
(136, 46, 1),
(137, 78, 5),
(138, 75, 1),
(138, 37, 2),
(138, 77, 2),
(138, 78, 2),
(139, 71, 3),
(140, 9, 3),
(141, 64, 2),
(142, 59, 9),
(144, 7, 1),
(144, 67, 1),
(144, 62, 1),
(144, 71, 5),
(144, 79, 2),
(145, 75, 2),
(145, 78, 4),
(146, 56, 1),
(146, 39, 2),
(146, 10, 4),
(146, 72, 1),
(146, 80, 2),
(146, 56, 2),
(146, 76, 3),
(147, 60, 9),
(147, 69, 2),
(147, 77, 1),
(147, 57, 2),
(147, 31, 1),
(147, 4, 1),
(149, 53, 1),
(149, 56, 10),
(150, 70, 2),
(150, 19, 1),
(150, 67, 2),
(150, 52, 2),
(150, 80, 3),
(150, 41, 1),
(150, 79, 3),
(150, 76, 3),
(151, 70, 3),
(151, 71, 4),
(151, 76, 3),
(151, 5, 2),
(151, 65, 4),
(151, 63, 1),
(151, 79, 1),
(151, 16, 1),
(152, 73, 2),
(153, 2, 1),
(154, 80, 2),
(154, 69, 2),
(154, 59, 8),
(155, 55, 2),
(155, 55, 7),
(156, 65, 1),
(157, 80, 1),
(157, 74, 4),
(158, 80, 9),
(159, 39, 6),
(160, 76, 1),
(161, 60, 1),
(162, 57, 1),
(164, 33, 2),
(165, 47, 2),
(166, 11, 2),
(167, 52, 2),
(167, 72, 1),
(167, 69, 1),
(167, 11, 2),
(168, 77, 3),
(169, 54, 5),
(170, 75, 2),
(171, 73, 2),
(172, 62, 3),
(172, 42, 1),
(173, 44, 2),
(174, 4, 4),
(174, 67, 9),
(174, 44, 3),
(174, 75, 3),
(174, 35, 1),
(174, 72, 2),
(174, 10, 6),
(174, 77, 1),
(176, 81, 2),
(176, 74, 2),
(176, 63, 1),
(176, 13, 2),
(176, 18, 1),
(176, 69, 1),
(176, 18, 3),
(176, 7, 1),
(176, 14, 1),
(177, 75, 4),
(178, 42, 2),
(178, 67, 2),
(179, 76, 1),
(179, 23, 6),
(180, 53, 6),
(181, 78, 9),
(181, 76, 1),
(181, 79, 1),
(182, 58, 3),
(182, 70, 3),
(183, 8, 1),
(184, 24, 1),
(184, 72, 4),
(185, 55, 2),
(186, 46, 4),
(186, 73, 5),
(187, 47, 3),
(188, 20, 1),
(189, 51, 1),
(189, 46, 2),
(190, 65, 1),
(190, 80, 2),
(190, 61, 6),
(191, 72, 1),
(191, 56, 1),
(192, 52, 2),
(192, 22, 1),
(192, 15, 2),
(192, 37, 1),
(192, 54, 3),
(192, 79, 1),
(192, 75, 1),
(192, 62, 1),
(192, 6, 1),
(192, 12, 9),
(193, 77, 3),
(194, 61, 3),
(195, 36, 1),
(195, 79, 1),
(195, 10, 3),
(197, 60, 1),
(197, 60, 1),
(198, 78, 1),
(198, 3, 1),
(199, 46, 1),
(200, 70, 5),
(202, 77, 1),
(202, 50, 1),
(202, 74, 2),
(203, 24, 2),
(204, 62, 2),
(204, 55, 7),
(204, 74, 3),
(205, 40, 1),
(206, 28, 4),
(206, 77, 6),
(207, 49, 3),
(207, 57, 1),
(207, 70, 1),
(207, 65, 2),
(208, 80, 2),
(208, 50, 1),
(208, 73, 1),
(208, 60, 8),
(209, 57, 2),
(209, 54, 5),
(210, 37, 3),
(213, 65, 9),
(217, 72, 3),
(217, 43, 5),
(218, 22, 5),
(219, 71, 3),
(220, 9, 1),
(220, 55, 1),
(221, 53, 1),
(221, 70, 1),
(222, 74, 1),
(222, 67, 1),
(222, 40, 2),
(222, 75, 4),
(222, 30, 1),
(223, 74, 10),
(224, 54, 1),
(225, 78, 1),
(226, 52, 1),
(226, 12, 4),
(226, 50, 1),
(226, 64, 9),
(227, 67, 4),
(227, 56, 1),
(228, 70, 1),
(229, 77, 7),
(230, 77, 2),
(231, 12, 1),
(231, 78, 1),
(231, 60, 3),
(231, 60, 2),
(231, 68, 1),
(231, 75, 1),
(232, 18, 2),
(233, 75, 1),
(233, 22, 1),
(233, 66, 1),
(234, 21, 5),
(235, 8, 2),
(235, 18, 2),
(235, 73, 1),
(235, 62, 2),
(235, 14, 8),
(236, 66, 1),
(237, 50, 2),
(238, 57, 3),
(239, 3, 2),
(240, 50, 3),
(241, 62, 2),
(242, 68, 3),
(242, 79, 1),
(243, 14, 1),
(243, 61, 2),
(244, 61, 10),
(244, 77, 1),
(244, 62, 1),
(245, 78, 8),
(245, 44, 1),
(246, 14, 4),
(246, 59, 1),
(246, 61, 4),
(247, 70, 1),
(248, 26, 1),
(248, 24, 3),
(249, 54, 6),
(250, 5, 7),
(250, 26, 5),
(250, 69, 2),
(250, 78, 1),
(250, 36, 3),
(250, 30, 3),
(251, 7, 2),
(251, 43, 9),
(251, 71, 2),
(251, 63, 3),
(251, 77, 2),
(252, 59, 4),
(252, 78, 2),
(253, 49, 1),
(253, 62, 3),
(253, 71, 2),
(254, 79, 2),
(254, 78, 1),
(255, 14, 2),
(255, 81, 1),
(256, 35, 3),
(256, 18, 10),
(256, 61, 1),
(257, 64, 2),
(258, 75, 1),
(259, 57, 1),
(259, 7, 5),
(259, 77, 3),
(259, 19, 1),
(259, 64, 1),
(260, 35, 2),
(261, 5, 1),
(262, 46, 1),
(263, 11, 2),
(264, 75, 1),
(264, 56, 1),
(264, 68, 6),
(264, 79, 1),
(264, 66, 4),
(264, 38, 1),
(265, 40, 3),
(267, 34, 3),
(268, 80, 8),
(268, 67, 1),
(268, 67, 6),
(268, 64, 2),
(268, 54, 1),
(268, 59, 3),
(268, 55, 1),
(268, 58, 1),
(268, 81, 1),
(269, 81, 6),
(269, 26, 1),
(270, 56, 1),
(270, 58, 1),
(271, 5, 2),
(271, 66, 2),
(272, 32, 1),
(272, 42, 1),
(272, 18, 5),
(272, 67, 1),
(272, 53, 4),
(272, 75, 2),
(273, 70, 2),
(273, 18, 3),
(273, 72, 6),
(273, 14, 2),
(274, 64, 2),
(275, 38, 2),
(275, 9, 1),
(275, 71, 1),
(276, 77, 1),
(277, 65, 5),
(278, 43, 1),
(278, 60, 3),
(279, 61, 1),
(279, 31, 1),
(279, 24, 2),
(279, 45, 8),
(279, 9, 4),
(279, 68, 6),
(280, 63, 1),
(281, 23, 2),
(281, 64, 5),
(282, 74, 1),
(283, 73, 1),
(283, 54, 2),
(284, 7, 1),
(284, 15, 1),
(284, 78, 9),
(284, 15, 2),
(284, 76, 2),
(284, 78, 3),
(284, 37, 2),
(284, 61, 2),
(284, 70, 3),
(285, 71, 1),
(286, 43, 1),
(286, 65, 1),
(287, 70, 1),
(287, 66, 3),
(288, 42, 1),
(289, 68, 2),
(289, 50, 2),
(290, 40, 5),
(290, 3, 2),
(290, 10, 2),
(290, 18, 8),
(290, 19, 1),
(290, 18, 1),
(290, 52, 2),
(290, 75, 1),
(291, 1, 4),
(291, 62, 1),
(292, 68, 2),
(292, 72, 1),
(292, 4, 1),
(292, 56, 2),
(292, 75, 6),
(292, 57, 1),
(292, 51, 3),
(293, 78, 1),
(293, 73, 3),
(293, 71, 1),
(294, 77, 3),
(296, 59, 6),
(296, 40, 2),
(296, 57, 1),
(296, 72, 3),
(296, 51, 1),
(297, 14, 2),
(298, 22, 2),
(299, 75, 5),
(300, 16, 3),
(301, 56, 8),
(302, 13, 3),
(302, 18, 1),
(302, 81, 3),
(302, 59, 2),
(302, 63, 4),
(302, 64, 1),
(303, 31, 4),
(303, 63, 1),
(303, 20, 1),
(303, 63, 1),
(303, 63, 2),
(303, 74, 2),
(303, 67, 1),
(303, 26, 5),
(304, 8, 5),
(304, 5, 1),
(304, 79, 3),
(305, 34, 3),
(305, 79, 1),
(306, 81, 6),
(308, 75, 7),
(311, 69, 3),
(311, 34, 7),
(311, 79, 1),
(312, 77, 1),
(312, 35, 7),
(312, 61, 1),
(312, 70, 1),
(312, 70, 3),
(312, 70, 1),
(312, 28, 1),
(315, 73, 7),
(316, 13, 5),
(317, 15, 1),
(317, 4, 2),
(317, 55, 1),
(318, 73, 1),
(318, 61, 1),
(318, 64, 1),
(318, 58, 1),
(318, 71, 2),
(319, 17, 1),
(320, 66, 4),
(320, 33, 3),
(321, 60, 9),
(322, 78, 4),
(322, 60, 4),
(322, 71, 1),
(323, 72, 1),
(324, 81, 1),
(324, 74, 2),
(325, 72, 1),
(326, 3, 2),
(327, 77, 5),
(329, 60, 3),
(330, 77, 4),
(330, 70, 1),
(331, 76, 3),
(332, 55, 4),
(333, 70, 2),
(333, 10, 3),
(334, 20, 1),
(334, 13, 2),
(334, 14, 1),
(334, 60, 6),
(334, 71, 2),
(334, 72, 6),
(335, 31, 5),
(335, 62, 1),
(336, 18, 1),
(337, 66, 8),
(337, 62, 3),
(337, 25, 2),
(337, 6, 9),
(337, 27, 2),
(337, 65, 2),
(337, 65, 3),
(338, 4, 2),
(338, 77, 4),
(338, 18, 1),
(338, 73, 2),
(338, 30, 1),
(338, 66, 7),
(338, 6, 1),
(339, 70, 6),
(339, 79, 1),
(340, 30, 9),
(340, 78, 2),
(340, 60, 1),
(340, 57, 2),
(342, 64, 3),
(342, 24, 2),
(342, 20, 1),
(342, 59, 4),
(342, 7, 2),
(343, 23, 6),
(345, 79, 1),
(346, 59, 2),
(346, 62, 2),
(346, 62, 1),
(347, 20, 3),
(347, 6, 1),
(347, 61, 2),
(348, 64, 6),
(349, 80, 1),
(349, 26, 2),
(349, 54, 1),
(349, 64, 1),
(349, 75, 1),
(350, 72, 5),
(351, 61, 1),
(351, 30, 1),
(351, 73, 1),
(351, 33, 1),
(351, 63, 1),
(352, 21, 8),
(352, 26, 1),
(353, 13, 2),
(354, 73, 1),
(354, 7, 2),
(354, 79, 1),
(356, 65, 1),
(356, 13, 3),
(357, 62, 1),
(358, 72, 1),
(358, 68, 2),
(359, 62, 4),
(359, 35, 1),
(361, 55, 1),
(362, 13, 1),
(362, 75, 2),
(362, 13, 1),
(363, 78, 1),
(364, 81, 3),
(364, 55, 3),
(364, 1, 1),
(365, 76, 2),
(365, 78, 2),
(365, 34, 3),
(365, 79, 2),
(365, 36, 1),
(365, 3, 5),
(365, 79, 3),
(366, 64, 1),
(368, 64, 7),
(369, 73, 3),
(369, 81, 6),
(369, 76, 8),
(369, 66, 2),
(369, 77, 1),
(369, 9, 3),
(369, 58, 1),
(369, 81, 2),
(369, 79, 1),
(369, 35, 1),
(370, 66, 2),
(370, 58, 2),
(370, 69, 8),
(370, 67, 3),
(370, 68, 1),
(370, 63, 3),
(370, 73, 2),
(370, 35, 1),
(370, 9, 4),
(371, 71, 6),
(371, 77, 1),
(372, 65, 3),
(372, 58, 1),
(372, 63, 5),
(373, 66, 3),
(374, 77, 4),
(374, 16, 2),
(375, 70, 2),
(377, 71, 4),
(377, 79, 1),
(378, 79, 2),
(379, 67, 1),
(379, 16, 2),
(379, 8, 5),
(380, 68, 1),
(381, 65, 1),
(382, 74, 1),
(382, 25, 1),
(382, 73, 1),
(383, 59, 1),
(383, 61, 3),
(384, 74, 5),
(384, 6, 1),
(384, 68, 2),
(384, 16, 1),
(384, 71, 1),
(384, 58, 7),
(384, 11, 1),
(384, 68, 2),
(384, 64, 1),
(384, 64, 1),
(385, 75, 2),
(385, 15, 2),
(385, 58, 1),
(387, 75, 1),
(388, 74, 1),
(388, 69, 1),
(390, 66, 6),
(390, 63, 3),
(390, 9, 6),
(390, 70, 6),
(391, 80, 4),
(391, 74, 7),
(391, 21, 3),
(391, 9, 1),
(391, 68, 2),
(391, 72, 2),
(391, 79, 2),
(391, 80, 2),
(392, 28, 1),
(393, 68, 7),
(395, 28, 4),
(396, 13, 1),
(397, 28, 1),
(397, 4, 9),
(397, 3, 3),
(397, 68, 1),
(398, 74, 4),
(398, 73, 1),
(398, 62, 1),
(399, 11, 3),
(400, 77, 6),
(400, 60, 1),
(400, 63, 1),
(400, 20, 2),
(400, 54, 2),
(400, 60, 10),
(400, 70, 2),
(400, 2, 2),
(401, 76, 3),
(402, 56, 1),
(402, 71, 2),
(403, 62, 7),
(403, 3, 3),
(404, 9, 6),
(404, 65, 2),
(406, 33, 2),
(406, 6, 4),
(406, 76, 1),
(406, 1, 6),
(406, 78, 9),
(407, 71, 1),
(407, 74, 4),
(407, 65, 1),
(410, 65, 1),
(411, 29, 1),
(411, 64, 5),
(411, 65, 1),
(411, 21, 1),
(411, 11, 3),
(412, 24, 1),
(412, 7, 1),
(412, 62, 3),
(412, 11, 1),
(412, 9, 2),
(412, 76, 2),
(413, 8, 8),
(414, 9, 1),
(415, 7, 5),
(415, 63, 2),
(415, 77, 1),
(416, 69, 1),
(416, 34, 2),
(417, 70, 2),
(418, 58, 3),
(418, 71, 1),
(418, 65, 1),
(418, 80, 1),
(419, 66, 3),
(419, 74, 2),
(419, 60, 3),
(420, 70, 2),
(420, 58, 1),
(421, 17, 1),
(422, 9, 1),
(422, 80, 1),
(423, 56, 4),
(423, 11, 4),
(423, 61, 2),
(424, 77, 1),
(425, 71, 1),
(425, 68, 1),
(425, 23, 2),
(425, 2, 6),
(425, 81, 6),
(426, 66, 2),
(427, 80, 1),
(428, 74, 2),
(428, 6, 1),
(429, 55, 5),
(429, 15, 1),
(431, 56, 2),
(433, 17, 1),
(434, 72, 2),
(434, 61, 1),
(435, 61, 2),
(435, 68, 1),
(435, 60, 2),
(436, 70, 2),
(436, 8, 9),
(436, 81, 8),
(436, 76, 2),
(437, 11, 2),
(437, 69, 1),
(437, 58, 4),
(437, 75, 3),
(438, 76, 7),
(438, 32, 3),
(439, 58, 1),
(439, 4, 8),
(439, 25, 4),
(440, 61, 5),
(440, 81, 1),
(440, 23, 1),
(442, 18, 1),
(443, 59, 2),
(443, 75, 3),
(443, 73, 1),
(443, 19, 2),
(443, 58, 2),
(443, 72, 1),
(443, 74, 2),
(443, 15, 1),
(443, 67, 1),
(443, 20, 3),
(444, 79, 4),
(445, 15, 3),
(446, 60, 1),
(447, 3, 2),
(447, 64, 1),
(447, 60, 1),
(447, 79, 4),
(447, 54, 3),
(447, 68, 6),
(447, 68, 2),
(447, 66, 1),
(448, 9, 3),
(448, 64, 2),
(449, 79, 2),
(449, 71, 1),
(450, 70, 1),
(450, 68, 1),
(451, 64, 3),
(451, 33, 1),
(451, 56, 1),
(451, 5, 1),
(451, 80, 1),
(452, 62, 3),
(453, 75, 1),
(453, 64, 5),
(454, 75, 10),
(455, 79, 1),
(455, 78, 1),
(456, 69, 1),
(456, 70, 8),
(456, 12, 8),
(456, 29, 1),
(456, 12, 6),
(456, 66, 1),
(456, 15, 1),
(457, 81, 1),
(458, 81, 1),
(459, 75, 3),
(459, 35, 1),
(459, 76, 1),
(459, 71, 2),
(459, 54, 1),
(459, 62, 2),
(460, 33, 4),
(460, 70, 2),
(461, 9, 1),
(461, 69, 1),
(462, 69, 2),
(463, 54, 2),
(463, 5, 5),
(464, 67, 1),
(465, 80, 2),
(466, 31, 1),
(466, 10, 1),
(466, 63, 2),
(467, 57, 1),
(468, 69, 1),
(468, 61, 1),
(468, 55, 2),
(468, 57, 4),
(468, 56, 1),
(468, 13, 1),
(468, 72, 4),
(468, 73, 1),
(468, 56, 2),
(469, 66, 2),
(469, 18, 3),
(469, 4, 4),
(470, 63, 9),
(470, 16, 1),
(470, 70, 2),
(470, 67, 4),
(470, 56, 5),
(471, 3, 2),
(473, 72, 2),
(474, 15, 1),
(474, 76, 4),
(474, 70, 2),
(474, 66, 1),
(474, 57, 2),
(475, 23, 1),
(476, 62, 4),
(476, 5, 2),
(477, 64, 1),
(477, 78, 1),
(477, 56, 2),
(477, 80, 5),
(477, 65, 2),
(477, 75, 2),
(478, 70, 6),
(478, 36, 1),
(479, 70, 1),
(479, 6, 2),
(479, 62, 3),
(480, 12, 2),
(480, 68, 3),
(480, 2, 1),
(481, 9, 2),
(482, 4, 1),
(482, 61, 1),
(483, 79, 7),
(484, 81, 1),
(485, 63, 2),
(485, 20, 3),
(485, 61, 1),
(485, 71, 1),
(485, 34, 1),
(486, 77, 1),
(486, 64, 3),
(487, 64, 1),
(487, 26, 5),
(487, 59, 5),
(488, 63, 1),
(489, 56, 3),
(491, 4, 1),
(491, 68, 5),
(491, 57, 2),
(492, 61, 1),
(494, 45, 1),
(495, 57, 1),
(496, 3, 1),
(498, 68, 2),
(499, 74, 2),
(499, 69, 3),
(499, 61, 2),
(500, 40, 1),
(501, 60, 10),
(502, 59, 1),
(502, 63, 7),
(503, 37, 1),
(504, 61, 1),
(505, 59, 1),
(506, 80, 3),
(507, 40, 1),
(507, 68, 1),
(507, 76, 1),
(507, 64, 8),
(508, 70, 2),
(508, 62, 2),
(509, 66, 5),
(509, 63, 1),
(509, 39, 1),
(509, 74, 1),
(509, 13, 2),
(511, 41, 6),
(512, 79, 8),
(513, 52, 3),
(513, 54, 1),
(514, 57, 2),
(516, 76, 1),
(517, 60, 1),
(518, 18, 1),
(520, 72, 2),
(520, 12, 1),
(520, 56, 5),
(520, 11, 3),
(520, 46, 2),
(520, 61, 2),
(521, 57, 1),
(521, 78, 5),
(521, 74, 1),
(521, 78, 2),
(521, 68, 6),
(522, 70, 1),
(522, 54, 2),
(522, 60, 2),
(522, 69, 3),
(523, 75, 3),
(523, 63, 1),
(523, 57, 5),
(523, 69, 3),
(523, 76, 3),
(523, 72, 1),
(524, 59, 3),
(525, 66, 1),
(525, 50, 4),
(525, 48, 3),
(525, 80, 8),
(526, 66, 1),
(527, 72, 3),
(528, 70, 7),
(529, 39, 1),
(531, 62, 9),
(532, 79, 3),
(532, 71, 1),
(532, 81, 1),
(532, 69, 1),
(532, 72, 1),
(532, 59, 4),
(533, 81, 1),
(533, 76, 1),
(533, 54, 6),
(534, 3, 2),
(534, 43, 1),
(534, 77, 6),
(535, 72, 1),
(535, 8, 1),
(535, 7, 1),
(535, 41, 1),
(535, 54, 1),
(535, 72, 1),
(535, 41, 1),
(536, 42, 1),
(536, 61, 2),
(536, 57, 1),
(537, 75, 2),
(538, 81, 2),
(539, 69, 2),
(540, 81, 3),
(540, 80, 3),
(541, 73, 2),
(541, 64, 4),
(541, 61, 1),
(541, 72, 2),
(541, 75, 5),
(541, 66, 3),
(541, 80, 5),
(542, 69, 1),
(543, 59, 1),
(544, 65, 2),
(544, 45, 5),
(544, 76, 1),
(545, 65, 2),
(545, 57, 1),
(546, 69, 2),
(546, 53, 2),
(546, 48, 2),
(546, 45, 1),
(546, 73, 1),
(546, 80, 2),
(547, 62, 1),
(547, 62, 1),
(547, 52, 2),
(548, 67, 2),
(548, 73, 1),
(548, 47, 2),
(548, 77, 1),
(548, 8, 6),
(549, 69, 1),
(549, 76, 1),
(549, 79, 5),
(549, 74, 1),
(550, 57, 1),
(550, 60, 3),
(550, 68, 5),
(550, 43, 3),
(550, 8, 1),
(551, 65, 1),
(551, 68, 7),
(551, 56, 2),
(552, 81, 6),
(553, 5, 1),
(553, 79, 1),
(553, 64, 7),
(553, 73, 1),
(554, 57, 1),
(554, 71, 3),
(554, 56, 1),
(554, 42, 1),
(555, 56, 4),
(556, 71, 1),
(556, 77, 2),
(556, 64, 1),
(556, 68, 6),
(556, 8, 5),
(557, 79, 5),
(557, 65, 1),
(558, 76, 2),
(558, 59, 1),
(558, 72, 1),
(558, 53, 1),
(558, 81, 1),
(558, 42, 2),
(558, 61, 3),
(559, 58, 1),
(560, 79, 3),
(560, 71, 6),
(560, 12, 1),
(561, 77, 5),
(562, 69, 1),
(562, 65, 1),
(562, 59, 1),
(563, 4, 1),
(564, 6, 3),
(564, 81, 2),
(565, 45, 1),
(565, 62, 2),
(566, 10, 1),
(567, 73, 2),
(567, 1, 3),
(568, 49, 2),
(568, 80, 5),
(569, 78, 1),
(570, 56, 1),
(570, 73, 8),
(572, 70, 10),
(572, 13, 1),
(573, 9, 7),
(573, 51, 1),
(573, 55, 2),
(573, 62, 2),
(573, 13, 1),
(574, 63, 1),
(574, 60, 2),
(574, 71, 7),
(574, 41, 4),
(574, 53, 1),
(575, 71, 2),
(575, 6, 1),
(576, 62, 2),
(576, 17, 1),
(576, 62, 1),
(576, 73, 3),
(576, 80, 2),
(576, 54, 2),
(576, 55, 2),
(577, 79, 4),
(577, 55, 2),
(578, 70, 5),
(578, 66, 1),
(578, 37, 1),
(579, 66, 1),
(579, 80, 5),
(579, 56, 1),
(579, 78, 2),
(579, 3, 1),
(580, 6, 3),
(580, 65, 8),
(581, 65, 2),
(582, 47, 1),
(582, 57, 1),
(584, 72, 1);

INSERT INTO narudzba(lokacija_id, kupac_id, datum, status) VALUES
(1, 1, STR_TO_DATE('2025-01-28 22:11:41', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(1, 1, STR_TO_DATE('2025-01-08 11:31:34', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(1, 1, STR_TO_DATE('2025-01-15 15:13:24', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(1, 5, STR_TO_DATE('2025-01-05 17:21:09', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(1, 5, STR_TO_DATE('2025-01-08 12:02:08', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(2, 12, STR_TO_DATE('2025-01-20 06:12:01', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(2, 7, STR_TO_DATE('2025-01-18 15:23:43', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(2, 8, STR_TO_DATE('2025-01-19 05:30:17', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(2, 12, STR_TO_DATE('2025-01-08 16:47:28', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(2, 7, STR_TO_DATE('2025-01-26 17:45:34', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(3, 18, STR_TO_DATE('2025-01-28 17:33:38', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(3, 17, STR_TO_DATE('2025-01-05 11:06:12', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(3, 17, STR_TO_DATE('2025-01-25 10:02:24', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(3, 18, STR_TO_DATE('2025-01-07 14:06:00', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(3, 15, STR_TO_DATE('2025-01-04 16:02:45', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(4, 23, STR_TO_DATE('2025-01-27 17:45:23', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(4, 21, STR_TO_DATE('2025-01-17 17:53:01', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(4, 20, STR_TO_DATE('2025-01-12 14:31:49', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(4, 23, STR_TO_DATE('2025-01-23 13:57:47', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(4, 22, STR_TO_DATE('2025-01-01 10:51:40', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(5, 26, STR_TO_DATE('2025-01-05 08:04:59', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(5, 27, STR_TO_DATE('2025-01-15 14:53:00', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(5, 29, STR_TO_DATE('2025-01-15 12:23:30', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(5, 26, STR_TO_DATE('2025-01-04 09:17:01', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(5, 25, STR_TO_DATE('2025-01-16 13:25:05', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(6, 34, STR_TO_DATE('2025-01-08 17:54:15', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(6, 32, STR_TO_DATE('2025-01-05 10:35:55', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(6, 36, STR_TO_DATE('2025-01-27 11:51:07', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(6, 31, STR_TO_DATE('2025-01-17 12:24:18', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(6, 34, STR_TO_DATE('2025-01-16 13:01:24', '%Y-%m-%d %H:%i:%s'), "izvrseno");

INSERT INTO stavka(narudzba_id, racun_id, proizvod_id, kolicina) VALUES
(1, 1, 51, 2),
(1, 1, 72, 1),
(1, 1, 81, 1),
(1, 1, 29, 3),
(1, 1, 56, 1),
(2, 4, 78, 3),
(3, 9, 16, 3),
(3, 9, 61, 1),
(4, 15, 78, 1),
(5, 19, 60, 2),
(5, 19, 67, 1),
(6, 94, 15, 1),
(7, 95, 65, 1),
(7, 95, 73, 1),
(7, 95, 7, 2),
(8, 96, 61, 1),
(9, 97, 31, 1),
(9, 97, 59, 1),
(9, 97, 5, 2),
(9, 97, 75, 10),
(9, 97, 63, 1),
(9, 97, 55, 1),
(9, 97, 69, 1),
(9, 97, 3, 3),
(10, 100, 58, 2),
(11, 211, 62, 1),
(11, 211, 6, 3),
(11, 211, 14, 1),
(11, 211, 59, 1),
(12, 212, 76, 1),
(13, 214, 81, 8),
(13, 214, 73, 4),
(13, 214, 26, 1),
(13, 214, 69, 1),
(13, 214, 79, 2),
(14, 215, 62, 5),
(14, 215, 59, 1),
(14, 215, 45, 1),
(15, 216, 58, 1),
(16, 307, 58, 7),
(16, 307, 74, 7),
(16, 307, 36, 1),
(17, 309, 14, 1),
(18, 310, 58, 1),
(18, 310, 31, 2),
(18, 310, 13, 4),
(18, 310, 62, 5),
(18, 310, 14, 1),
(18, 310, 80, 1),
(18, 310, 25, 1),
(18, 310, 77, 5),
(18, 310, 2, 5),
(19, 313, 73, 1),
(19, 313, 57, 1),
(19, 313, 55, 3),
(20, 314, 80, 3),
(20, 314, 80, 1),
(21, 386, 4, 1),
(22, 389, 56, 1),
(23, 394, 74, 2),
(23, 394, 72, 2),
(23, 394, 25, 1),
(23, 394, 30, 3),
(23, 394, 66, 3),
(24, 405, 61, 1),
(25, 408, 77, 1),
(26, 490, 69, 6),
(27, 493, 7, 5),
(27, 493, 76, 2),
(28, 497, 68, 2),
(28, 497, 7, 5),
(28, 497, 75, 2),
(28, 497, 81, 1),
(28, 497, 77, 3),
(29, 510, 73, 2),
(30, 515, 58, 3);

INSERT INTO predracun(kupac_id, zaposlenik_id, datum, status) VALUES
(4, 2, STR_TO_DATE('2025-01-14 09:05:06', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(4, 6, STR_TO_DATE('2025-01-10 19:56:28', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(4, 9, STR_TO_DATE('2025-01-04 21:46:47', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(4, 5, STR_TO_DATE('2025-01-17 09:10:28', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(4, 4, STR_TO_DATE('2025-01-01 21:05:03', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(9, 18, STR_TO_DATE('2025-01-11 21:41:01', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(9, 10, STR_TO_DATE('2025-01-14 14:46:28', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(9, 15, STR_TO_DATE('2025-01-05 14:19:38', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(9, 10, STR_TO_DATE('2025-01-01 09:27:11', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(9, 18, STR_TO_DATE('2025-01-17 10:55:04', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(9, 18, STR_TO_DATE('2025-01-07 21:26:00', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(9, 11, STR_TO_DATE('2025-01-10 20:38:58', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(9, 18, STR_TO_DATE('2025-01-02 10:35:31', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(14, 20, STR_TO_DATE('2025-01-20 14:19:25', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(14, 19, STR_TO_DATE('2025-01-24 14:32:10', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(14, 21, STR_TO_DATE('2025-01-22 16:07:07', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(24, 34, STR_TO_DATE('2025-01-12 17:10:02', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(24, 31, STR_TO_DATE('2025-01-17 11:02:58', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(19, 28, STR_TO_DATE('2025-01-09 13:54:58', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(19, 34, STR_TO_DATE('2025-01-16 11:10:23', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(19, 28, STR_TO_DATE('2025-01-23 19:47:14', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(24, 31, STR_TO_DATE('2025-01-16 19:18:52', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(19, 34, STR_TO_DATE('2025-01-23 10:01:58', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(28, 39, STR_TO_DATE('2025-01-07 13:42:49', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(28, 35, STR_TO_DATE('2025-01-12 16:09:43', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(28, 41, STR_TO_DATE('2025-01-05 16:02:39', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(28, 41, STR_TO_DATE('2025-01-14 12:29:11', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(28, 38, STR_TO_DATE('2025-01-11 22:15:22', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(33, 46, STR_TO_DATE('2025-01-01 17:07:18', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(33, 46, STR_TO_DATE('2025-01-20 18:15:44', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(33, 46, STR_TO_DATE('2025-01-20 21:04:06', '%Y-%m-%d %H:%i:%s'), "izvrseno"),
(33, 44, STR_TO_DATE('2025-01-17 17:24:49', '%Y-%m-%d %H:%i:%s'), "izvrseno");

INSERT INTO stavka(predracun_id, racun_id, proizvod_id, kolicina) VALUES
(1, 5, 56, 3),
(1, 5, 68, 1),
(2, 31, 75, 2),
(2, 31, 81, 3),
(3, 42, 55, 1),
(3, 42, 4, 2),
(3, 42, 63, 1),
(4, 59, 58, 1),
(5, 75, 49, 4),
(6, 106, 57, 4),
(7, 114, 32, 1),
(8, 128, 69, 1),
(9, 143, 10, 2),
(10, 148, 63, 1),
(10, 148, 51, 1),
(10, 148, 55, 2),
(10, 148, 40, 3),
(11, 163, 58, 2),
(12, 175, 23, 5),
(13, 196, 78, 1),
(14, 201, 41, 1),
(15, 266, 68, 2),
(15, 266, 78, 2),
(15, 266, 73, 3),
(15, 266, 2, 4),
(15, 266, 54, 6),
(16, 295, 73, 1),
(17, 328, 77, 7),
(17, 328, 65, 1),
(17, 328, 19, 1),
(18, 341, 24, 5),
(19, 344, 55, 3),
(19, 344, 81, 1),
(19, 344, 61, 1),
(19, 344, 56, 2),
(20, 355, 72, 1),
(20, 355, 70, 2),
(21, 360, 60, 1),
(21, 360, 62, 1),
(22, 367, 57, 3),
(22, 367, 69, 2),
(23, 376, 54, 1),
(23, 376, 58, 1),
(23, 376, 3, 1),
(24, 409, 64, 1),
(24, 409, 62, 1),
(25, 430, 69, 2),
(26, 432, 8, 1),
(26, 432, 58, 2),
(27, 441, 18, 1),
(27, 441, 74, 1),
(27, 441, 71, 1),
(28, 472, 17, 2),
(29, 519, 2, 1),
(30, 530, 51, 1),
(30, 530, 61, 2),
(31, 571, 71, 1),
(32, 583, 77, 1);

INSERT INTO nabava(lokacija_id, datum, status) VALUES
(1, STR_TO_DATE('2025-01-15 11:52:38', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(1, STR_TO_DATE('2025-01-25 14:53:38', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(1, STR_TO_DATE('2025-01-28 13:43:53', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(1, STR_TO_DATE('2025-01-22 14:49:40', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(2, STR_TO_DATE('2025-01-16 08:24:38', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(2, STR_TO_DATE('2025-01-13 09:37:13', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(2, STR_TO_DATE('2025-01-29 14:27:36', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(2, STR_TO_DATE('2025-01-15 12:25:24', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(2, STR_TO_DATE('2025-01-05 09:27:20', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(3, STR_TO_DATE('2025-01-28 11:22:57', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(3, STR_TO_DATE('2025-01-03 13:25:01', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(3, STR_TO_DATE('2025-01-06 08:53:21', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(3, STR_TO_DATE('2025-01-13 10:07:42', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(3, STR_TO_DATE('2025-01-24 11:54:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(3, STR_TO_DATE('2025-01-27 08:26:43', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(4, STR_TO_DATE('2025-01-21 10:02:35', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(4, STR_TO_DATE('2025-01-23 13:50:31', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(4, STR_TO_DATE('2025-01-10 10:37:15', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(4, STR_TO_DATE('2025-01-12 09:29:03', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(4, STR_TO_DATE('2025-01-08 10:57:36', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(4, STR_TO_DATE('2025-01-20 11:50:15', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(5, STR_TO_DATE('2025-01-21 12:09:13', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(5, STR_TO_DATE('2025-01-05 10:55:23', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(5, STR_TO_DATE('2025-01-11 09:00:26', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(5, STR_TO_DATE('2025-01-25 10:23:54', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(5, STR_TO_DATE('2025-01-27 09:33:26', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(5, STR_TO_DATE('2025-01-23 08:25:49', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(6, STR_TO_DATE('2025-01-07 10:32:24', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(6, STR_TO_DATE('2025-01-08 11:40:12', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(6, STR_TO_DATE('2025-01-15 11:58:33', '%Y-%m-%d %H:%i:%s'), 'izvrseno'),
(6, STR_TO_DATE('2025-01-21 12:37:26', '%Y-%m-%d %H:%i:%s'), 'izvrseno');

INSERT INTO stavka(nabava_id, proizvod_id, kolicina) VALUES
(1, 76, 100),
(1, 37, 100),
(1, 52, 50),
(1, 36, 30),
(1, 29, 40),
(1, 33, 20),
(1, 17, 100),
(1, 4, 70),
(1, 9, 50),
(2, 11, 100),
(2, 9, 30),
(2, 34, 40),
(2, 25, 50),
(2, 26, 20),
(2, 38, 100),
(2, 55, 150),
(3, 72, 75),
(3, 54, 75),
(3, 41, 30),
(3, 22, 30),
(3, 5, 50),
(3, 2, 30),
(3, 10, 50),
(4, 2, 70),
(4, 13, 100),
(4, 18, 30),
(4, 1, 100),
(4, 28, 50),
(4, 20, 20),
(4, 75, 150),
(4, 40, 30),
(4, 52, 50),
(4, 37, 30),
(5, 79, 150),
(5, 77, 100),
(5, 38, 30),
(5, 40, 100),
(5, 35, 20),
(5, 6, 30),
(5, 8, 50),
(6, 3, 30),
(6, 9, 30),
(6, 11, 100),
(6, 10, 30),
(6, 2, 100),
(6, 1, 70),
(6, 17, 30),
(6, 7, 100),
(6, 26, 20),
(6, 44, 50),
(6, 45, 100),
(6, 73, 75),
(7, 72, 150),
(7, 75, 100),
(7, 58, 150),
(7, 70, 200),
(7, 71, 150),
(7, 65, 200),
(7, 41, 30),
(7, 52, 50),
(7, 20, 30),
(7, 20, 50),
(7, 24, 30),
(7, 13, 30),
(7, 7, 50),
(8, 17, 70),
(8, 11, 50),
(8, 2, 50),
(8, 14, 50),
(8, 24, 20),
(8, 51, 70),
(8, 62, 150),
(9, 65, 200),
(9, 45, 30),
(9, 26, 20),
(9, 12, 70),
(10, 9, 100),
(10, 9, 50),
(10, 7, 70),
(10, 8, 50),
(10, 10, 70),
(10, 32, 20),
(10, 35, 50),
(10, 47, 30),
(10, 40, 100),
(10, 38, 100),
(10, 76, 200),
(11, 65, 100),
(11, 54, 150),
(11, 38, 50),
(11, 37, 50),
(11, 27, 30),
(11, 24, 50),
(11, 9, 70),
(12, 17, 30),
(12, 11, 70),
(12, 31, 20),
(12, 45, 50),
(12, 51, 50),
(12, 59, 75),
(13, 63, 75),
(13, 81, 100),
(13, 55, 200),
(13, 39, 100),
(13, 34, 40),
(13, 26, 20),
(13, 7, 50),
(14, 1, 100),
(14, 27, 40),
(14, 26, 40),
(14, 19, 20),
(14, 44, 100),
(14, 50, 50),
(14, 48, 50),
(14, 76, 150),
(14, 60, 150),
(14, 67, 100),
(14, 74, 100),
(14, 67, 200),
(15, 67, 75),
(15, 44, 70),
(15, 41, 50),
(15, 37, 30),
(15, 53, 100),
(15, 28, 20),
(15, 30, 20),
(15, 15, 100),
(15, 9, 30),
(16, 8, 70),
(16, 11, 70),
(16, 34, 30),
(16, 33, 20),
(16, 21, 20),
(16, 25, 40),
(16, 24, 50),
(16, 24, 20),
(16, 79, 200),
(16, 59, 75),
(16, 70, 75),
(17, 63, 100),
(17, 60, 200),
(17, 19, 30),
(17, 4, 30),
(18, 15, 50),
(18, 21, 50),
(18, 26, 30),
(18, 78, 100),
(18, 60, 150),
(18, 81, 100),
(18, 75, 150),
(19, 67, 200),
(19, 30, 30),
(19, 29, 20),
(19, 36, 20),
(19, 21, 50),
(19, 25, 20),
(19, 19, 30),
(19, 7, 70),
(19, 16, 50),
(19, 8, 30),
(19, 14, 30),
(19, 10, 30),
(20, 11, 100),
(20, 60, 100),
(20, 71, 75),
(20, 70, 200),
(20, 79, 100),
(20, 54, 150),
(20, 74, 150),
(20, 56, 200),
(20, 75, 100),
(20, 35, 20),
(21, 26, 40),
(21, 34, 30),
(21, 23, 40),
(21, 76, 150),
(21, 59, 200),
(21, 57, 150),
(21, 73, 100),
(21, 71, 75),
(21, 59, 150),
(21, 79, 75),
(21, 54, 75),
(21, 74, 75),
(21, 2, 100),
(21, 16, 30),
(21, 11, 30),
(21, 10, 30),
(21, 12, 30),
(21, 13, 30),
(21, 8, 70),
(21, 17, 50),
(22, 6, 100),
(22, 16, 30),
(22, 68, 150),
(22, 28, 30),
(22, 24, 20),
(23, 21, 30),
(23, 69, 150),
(23, 58, 150),
(23, 58, 200),
(23, 3, 70),
(24, 16, 30),
(24, 58, 150),
(24, 57, 100),
(24, 66, 200),
(24, 54, 200),
(24, 69, 150),
(24, 19, 20),
(24, 26, 40),
(25, 25, 30),
(25, 61, 75),
(25, 18, 50),
(26, 3, 70),
(26, 54, 100),
(26, 78, 150),
(26, 56, 150),
(26, 70, 200),
(26, 75, 200),
(26, 23, 30),
(26, 32, 40),
(26, 30, 20),
(27, 35, 40),
(27, 62, 200),
(27, 11, 50),
(27, 7, 70),
(27, 18, 30),
(27, 5, 100),
(27, 12, 70),
(27, 14, 50),
(27, 6, 100),
(27, 3, 100),
(28, 16, 30),
(28, 60, 100),
(28, 79, 200),
(28, 67, 200),
(28, 59, 150),
(28, 55, 150),
(28, 75, 150),
(28, 71, 150),
(28, 49, 30),
(29, 48, 30),
(29, 40, 30),
(29, 41, 100),
(29, 39, 100),
(29, 47, 70),
(29, 63, 200),
(29, 60, 75),
(29, 2, 100),
(30, 9, 70),
(30, 70, 75),
(30, 50, 50),
(31, 45, 30),
(31, 42, 30),
(31, 46, 50),
(31, 75, 100),
(31, 3, 70),
(31, 16, 70),
(31, 6, 70);

INSERT INTO inventar VALUES
(1, 1, 72),
(1, 2, 31),
(1, 3, 51),
(1, 4, 67),
(1, 5, 30),
(1, 6, 67),
(1, 7, 33),
(1, 8, 31),
(1, 9, 31),
(1, 10, 33),
(1, 11, 31),
(1, 12, 33),
(1, 13, 50),
(1, 14, 50),
(1, 15, 30),
(1, 16, 51),
(1, 17, 49),
(1, 18, 30),
(1, 19, 31),
(1, 20, 28),
(1, 21, 32),
(1, 22, 38),
(1, 23, 21),
(1, 24, 18),
(1, 25, 30),
(1, 26, 37),
(1, 27, 20),
(1, 28, 23),
(1, 29, 40),
(1, 30, 31),
(1, 31, 53),
(1, 32, 31),
(1, 33, 19),
(1, 34, 23),
(1, 35, 28),
(1, 36, 42),
(1, 37, 28),
(1, 38, 39),
(1, 39, 17),
(1, 40, 17),
(1, 41, 52),
(1, 42, 22),
(1, 43, 17),
(1, 44, 48),
(1, 45, 22),
(1, 46, 39),
(1, 47, 50),
(1, 48, 17),
(1, 49, 37),
(1, 50, 19),
(1, 51, 29),
(1, 52, 22),
(1, 53, 49),
(1, 54, 73),
(1, 55, 48),
(1, 56, 93),
(1, 57, 78),
(1, 58, 75),
(1, 59, 48),
(1, 60, 47),
(1, 61, 48),
(1, 62, 72),
(1, 63, 48),
(1, 64, 115),
(1, 65, 78),
(1, 66, 47),
(1, 67, 95),
(1, 68, 76),
(1, 69, 96),
(1, 70, 76),
(1, 71, 93),
(1, 72, 116),
(1, 73, 74),
(1, 74, 93),
(1, 75, 93),
(1, 76, 49),
(1, 77, 48),
(1, 78, 53),
(1, 79, 50),
(1, 80, 50),
(1, 81, 76),
(2, 1, 29),
(2, 2, 101),
(2, 3, 29),
(2, 4, 72),
(2, 5, 28),
(2, 6, 33),
(2, 7, 30),
(2, 8, 68),
(2, 9, 30),
(2, 10, 69),
(2, 11, 47),
(2, 12, 72),
(2, 13, 31),
(2, 14, 67),
(2, 15, 67),
(2, 16, 27),
(2, 17, 32),
(2, 18, 43),
(2, 19, 41),
(2, 20, 29),
(2, 21, 19),
(2, 22, 37),
(2, 23, 47),
(2, 24, 33),
(2, 25, 43),
(2, 26, 52),
(2, 27, 17),
(2, 28, 17),
(2, 29, 20),
(2, 30, 42),
(2, 31, 43),
(2, 32, 27),
(2, 33, 21),
(2, 34, 23),
(2, 35, 30),
(2, 36, 52),
(2, 37, 20),
(2, 38, 21),
(2, 39, 30),
(2, 40, 40),
(2, 41, 19),
(2, 42, 29),
(2, 43, 22),
(2, 44, 30),
(2, 45, 22),
(2, 46, 42),
(2, 47, 41),
(2, 48, 51),
(2, 49, 40),
(2, 50, 22),
(2, 51, 50),
(2, 52, 27),
(2, 53, 49),
(2, 54, 48),
(2, 55, 94),
(2, 56, 72),
(2, 57, 52),
(2, 58, 53),
(2, 59, 77),
(2, 60, 76),
(2, 61, 97),
(2, 62, 47),
(2, 63, 94),
(2, 64, 75),
(2, 65, 96),
(2, 66, 52),
(2, 67, 53),
(2, 68, 98),
(2, 69, 73),
(2, 70, 53),
(2, 71, 47),
(2, 72, 78),
(2, 73, 49),
(2, 74, 50),
(2, 75, 93),
(2, 76, 78),
(2, 77, 72),
(2, 78, 48),
(2, 79, 96),
(2, 80, 92),
(2, 81, 96),
(3, 1, 28),
(3, 2, 51),
(3, 3, 53),
(3, 4, 32),
(3, 5, 103),
(3, 6, 48),
(3, 7, 29),
(3, 8, 33),
(3, 9, 33),
(3, 10, 50),
(3, 11, 70),
(3, 12, 29),
(3, 13, 32),
(3, 14, 30),
(3, 15, 50),
(3, 16, 49),
(3, 17, 69),
(3, 18, 38),
(3, 19, 17),
(3, 20, 39),
(3, 21, 22),
(3, 22, 32),
(3, 23, 20),
(3, 24, 29),
(3, 25, 18),
(3, 26, 29),
(3, 27, 40),
(3, 28, 40),
(3, 29, 51),
(3, 30, 38),
(3, 31, 18),
(3, 32, 27),
(3, 33, 22),
(3, 34, 18),
(3, 35, 17),
(3, 36, 37),
(3, 37, 33),
(3, 38, 38),
(3, 39, 32),
(3, 40, 53),
(3, 41, 53),
(3, 42, 27),
(3, 43, 53),
(3, 44, 27),
(3, 45, 29),
(3, 46, 33),
(3, 47, 17),
(3, 48, 23),
(3, 49, 40),
(3, 50, 29),
(3, 51, 38),
(3, 52, 29),
(3, 53, 73),
(3, 54, 97),
(3, 55, 52),
(3, 56, 47),
(3, 57, 76),
(3, 58, 72),
(3, 59, 49),
(3, 60, 50),
(3, 61, 53),
(3, 62, 114),
(3, 63, 95),
(3, 64, 49),
(3, 65, 47),
(3, 66, 72),
(3, 67, 117),
(3, 68, 116),
(3, 69, 52),
(3, 70, 49),
(3, 71, 75),
(3, 72, 53),
(3, 73, 51),
(3, 74, 114),
(3, 75, 74),
(3, 76, 96),
(3, 77, 51),
(3, 78, 47),
(3, 79, 92),
(3, 80, 52),
(3, 81, 72),
(4, 1, 52),
(4, 2, 51),
(4, 3, 32),
(4, 4, 52),
(4, 5, 52),
(4, 6, 30),
(4, 7, 29),
(4, 8, 73),
(4, 9, 30),
(4, 10, 50),
(4, 11, 30),
(4, 12, 27),
(4, 13, 31),
(4, 14, 98),
(4, 15, 33),
(4, 16, 53),
(4, 17, 70),
(4, 18, 37),
(4, 19, 42),
(4, 20, 40),
(4, 21, 21),
(4, 22, 42),
(4, 23, 43),
(4, 24, 42),
(4, 25, 20),
(4, 26, 21),
(4, 27, 27),
(4, 28, 28),
(4, 29, 20),
(4, 30, 20),
(4, 31, 32),
(4, 32, 27),
(4, 33, 17),
(4, 34, 23),
(4, 35, 21),
(4, 53, 97),
(4, 54, 94),
(4, 55, 78),
(4, 56, 74),
(4, 57, 98),
(4, 58, 47),
(4, 59, 92),
(4, 60, 76),
(4, 61, 48),
(4, 62, 93),
(4, 63, 47),
(4, 64, 114),
(4, 65, 72),
(4, 66, 52),
(4, 67, 116),
(4, 68, 78),
(4, 69, 49),
(4, 70, 50),
(4, 71, 75),
(4, 72, 47),
(4, 73, 93),
(4, 74, 93),
(4, 75, 72),
(4, 76, 98),
(4, 77, 48),
(4, 78, 98),
(4, 79, 78),
(4, 80, 92),
(4, 81, 50),
(5, 1, 50),
(5, 2, 31),
(5, 3, 32),
(5, 4, 30),
(5, 5, 28),
(5, 6, 53),
(5, 7, 30),
(5, 8, 53),
(5, 9, 33),
(5, 10, 98),
(5, 11, 71),
(5, 12, 72),
(5, 13, 67),
(5, 14, 27),
(5, 15, 48),
(5, 16, 29),
(5, 17, 49),
(5, 18, 21),
(5, 19, 21),
(5, 20, 27),
(5, 21, 39),
(5, 22, 21),
(5, 23, 22),
(5, 24, 40),
(5, 25, 17),
(5, 26, 18),
(5, 27, 20),
(5, 28, 19),
(5, 29, 18),
(5, 30, 23),
(5, 31, 38),
(5, 32, 33),
(5, 33, 22),
(5, 34, 41),
(5, 35, 30),
(5, 53, 53),
(5, 54, 50),
(5, 55, 51),
(5, 56, 76),
(5, 57, 73),
(5, 58, 97),
(5, 59, 47),
(5, 60, 52),
(5, 61, 77),
(5, 62, 51),
(5, 63, 52),
(5, 64, 50),
(5, 65, 77),
(5, 66, 73),
(5, 67, 73),
(5, 68, 92),
(5, 69, 116),
(5, 70, 47),
(5, 71, 73),
(5, 72, 53),
(5, 73, 51),
(5, 74, 50),
(5, 75, 47),
(5, 76, 74),
(5, 77, 49),
(5, 78, 116),
(5, 79, 51),
(5, 80, 75),
(5, 81, 49),
(6, 1, 98),
(6, 2, 27),
(6, 3, 101),
(6, 4, 32),
(6, 5, 31),
(6, 6, 28),
(6, 7, 29),
(6, 8, 33),
(6, 9, 69),
(6, 10, 53),
(6, 11, 27),
(6, 12, 97),
(6, 13, 70),
(6, 14, 48),
(6, 15, 67),
(6, 16, 49),
(6, 17, 72),
(6, 36, 23),
(6, 37, 23),
(6, 38, 33),
(6, 39, 20),
(6, 40, 32),
(6, 41, 39),
(6, 42, 21),
(6, 43, 31),
(6, 44, 19),
(6, 45, 28),
(6, 46, 31),
(6, 47, 28),
(6, 48, 47),
(6, 49, 18),
(6, 50, 42),
(6, 51, 17),
(6, 52, 17),
(6, 53, 74),
(6, 54, 50),
(6, 55, 49),
(6, 56, 47),
(6, 57, 95),
(6, 58, 49),
(6, 59, 78),
(6, 60, 47),
(6, 61, 50),
(6, 62, 50),
(6, 63, 94),
(6, 64, 53),
(6, 65, 50),
(6, 66, 117),
(6, 67, 50),
(6, 68, 97),
(6, 69, 50),
(6, 70, 116),
(6, 71, 78),
(6, 72, 53),
(6, 73, 48),
(6, 74, 51),
(6, 75, 92),
(6, 76, 50),
(6, 77, 47),
(6, 78, 76),
(6, 79, 96),
(6, 80, 72),
(6, 81, 47);



/*******************************************************************************
		TESTIRANJE
*******************************************************************************/
