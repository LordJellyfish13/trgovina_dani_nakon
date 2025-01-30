from flask import Flask, jsonify, request
from flask_mysqldb import MySQL
from flask_cors import CORS
import json

app = Flask(__name__)

# Simple CORS configuration that allows all origins
CORS(app, 
     resources={r"/*": {"origins": "*"}},
     supports_credentials=True,
     allow_headers=["Content-Type", "Authorization"],
     methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"])

app.config['MYSQL_HOST'] = 'localhost'
app.config['MYSQL_USER'] = 'web'
app.config['MYSQL_PASSWORD'] = 'web'
app.config['MYSQL_DB'] = 'trgovina'
app.config['MYSQL_CURSORCLASS'] = 'DictCursor'
mysql = MySQL(app)

# Dummy user data
users = {
    'admin': {'password': 'adminpass', 'role': 'admin'}, 
}

@app.route('/')
def hello_world():
    return 'Hello, World!'

@app.route('/klub', methods=['GET'])
def get_klub():
    cur = mysql.connection.cursor()
    cur.execute(''' SELECT * FROM klub ''')
    data = cur.fetchall()
    cur.close()
    return jsonify(data)

@app.route('/lokacija', methods=['GET'])
def get_lokacija():
    try:
        cur = mysql.connection.cursor()
        cur.execute('SELECT * FROM pregled_lokacija_sa_odjelima')  # Fetch all locations
        data = cur.fetchall()
        cur.close()
        return jsonify(data)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/lokacija_trgovine', methods=['GET'])
def get_lokacija_trgovine():
    try:
        cur = mysql.connection.cursor()
        cur.execute('SELECT grad FROM lokacija')  # Fetch all locations
        data = cur.fetchall()
        cur.close()
        # Extracting only the 'grad' values from the fetched data
        locations = [location['grad'] for location in data]
        return jsonify(locations)  # Send a JSON array of grad
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/lokacija_trgovine_id', methods=['GET'])
def get_lokacija_trgovine_id():
    try:
        cur = mysql.connection.cursor()
        cur.execute('SELECT id, grad FROM lokacija')  # Fetch all locations
        data = cur.fetchall()
        cur.close()
        return jsonify(data)  # Return the complete data
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


@app.route('/pregled_racuna', methods=['GET'])
def get_pregled_racuna():
    cur = mysql.connection.cursor()
    cur.execute(''' SELECT * FROM pregled_racuna ORDER BY datum DESC''')
    data = cur.fetchall()
    cur.close()
    return jsonify(data)

@app.route('/novi_racun', methods=['POST'])
def novi_racun():
    data = request.json
    k_id = data.get('kupac_id')
    z_id = data['zaposlenik_id']
    nacin_placanja = data['nacin_placanja']

    try:
        cur = mysql.connection.cursor()
        cur.callproc('stvori_racun', [k_id, z_id, nacin_placanja])
        cur.execute("SELECT LAST_INSERT_ID() as racun_id")
        racun_id = cur.fetchone()['racun_id']
        mysql.connection.commit()
        cur.close()
        return jsonify({'success': True, 'racun_id': racun_id})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/dodaj_stavke', methods=['POST'])
def dodaj_stavke():
    try:
        data = request.json
        if not data:
            return jsonify({'success': False, 'error': 'No data provided'}), 400
            
        if 'stavke' not in data:
            return jsonify({'success': False, 'error': 'No stavke provided'}), 400
            
        stavke = data['stavke']
        if not stavke:
            return jsonify({'success': False, 'error': 'Empty stavke array'}), 400

        cur = mysql.connection.cursor()
        try:
            # Call the procedure with JSON data
            cur.callproc('dodaj_stavke', [json.dumps(stavke)])
            mysql.connection.commit()
            return jsonify({'success': True})
        except Exception as e:
            mysql.connection.rollback()
            print('Database error in dodaj_stavke:', str(e))  # Debug log
            return jsonify({'success': False, 'error': str(e)}), 500
        finally:
            cur.close()
    except Exception as e:
        print('Error in dodaj_stavke:', str(e))  # Debug log
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/izbrisi_racun', methods=['POST'])
def izbrisi_racun():
    racun_id = request.json['racun_id']
    try:
        cur = mysql.connection.cursor()
        cur.callproc('izbrisi_racun', [racun_id])
        mysql.connection.commit()
        cur.close()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/dodaj_proizvod', methods=['POST'])
def dodaj_proizvod():
    data = request.json
    naziv = data['naziv']
    n_cijena = data['n_cijena']
    p_cijena = data['p_cijena']
    kategorija_id = data['kategorija_id']

    try:
        cur = mysql.connection.cursor()
        cur.execute('INSERT INTO proizvod (naziv, nabavna_cijena, prodajna_cijena, kategorija_id) VALUES (%s, %s, %s, %s)', 
                    (naziv, n_cijena, p_cijena, kategorija_id))
        mysql.connection.commit()
        cur.close()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/dodaj_kupca', methods=['POST'])
def dodaj_kupca():
    data = request.json
    ime = data['ime']
    prezime = data['prezime']
    spol = data['spol']
    adresa = data['adresa']
    email = data['email']
    tip = data['tip']
    oib_firme = data.get('oib_firme')

    try:
        cur = mysql.connection.cursor()
        cur.callproc('dodaj_kupca', [ime, prezime, spol, adresa, email, tip, oib_firme])
        mysql.connection.commit()
        cur.close()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    user_id = data['user_id']
    password = data['password']

    user = users.get(user_id)
    if user and user['password'] == password:
        return jsonify({'success': True, 'role': user['role']})
    else:
        return jsonify({'success': False, 'error': 'Invalid credentials'})

@app.route('/odjeli_kategorije_proizvodi', methods=['GET'])
def get_odjeli_kategorije_proizvodi():
    try:
        cur = mysql.connection.cursor()
        cur.execute('SELECT * FROM pregled_proizvoda')
        data = cur.fetchall()
        cur.close()

        odjeli_kategorije_map = {}
        proizvodi = []

        for row in data:
            odjel = row['odjel_naziv']
            kategorija = row['kategorija_naziv']
            if odjel not in odjeli_kategorije_map:
                odjeli_kategorije_map[odjel] = set()
            odjeli_kategorije_map[odjel].add(kategorija)

            proizvodi.append({
                'id': row['id'],
                'naziv': row['naziv'],
                'nabavna_cijena': row['nabavna_cijena'],
                'prodajna_cijena': row['prodajna_cijena'],
                'kategorija': kategorija,
                'odjel': odjel
            })

        odjeli_kategorije = [{'odjel': odjel, 'kategorije': list(kategorije)} for odjel, kategorije in odjeli_kategorije_map.items()]

        return jsonify({'odjeliKategorije': odjeli_kategorije, 'proizvodi': proizvodi})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/racun_detalji/<int:racun_id>', methods=['GET'])
def racun_detalji_full(racun_id):
    try:
        cur = mysql.connection.cursor()
        cur.callproc('racun_detalji', [racun_id])
        data = cur.fetchall()
        cur.close()
        return jsonify({'success': True, 'racun': data})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/ponisti_racun', methods=['POST'])
def ponisti_racun():
    data = request.json
    racun_id = data['racun_id']
    admin_password = data['admin_password']

    # Check if the admin password is correct
    if admin_password != users['admin']['password']:
        return jsonify({'success': False, 'error': 'Invalid admin password'})

    try:
        cur = mysql.connection.cursor()
        cur.callproc('ponisti_racun', [racun_id])
        mysql.connection.commit()
        cur.close()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/ponisti_racun_bez', methods=['POST'])
def ponisti_racun_bez():
    data = request.json
    racun_id = data['racun_id'] 
 
    try:
        cur = mysql.connection.cursor()
        cur.callproc('ponisti_racun', [racun_id])
        mysql.connection.commit()
        cur.close()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/kupaci', methods=['GET'])
def get_kupci():
    try:
        cur = mysql.connection.cursor()
        cur.execute('SELECT * FROM kupac')  # Adjust the query as needed
        data = cur.fetchall()
        cur.close()
        return jsonify(data)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/najcesci_kupci', methods=['GET'])
def get_najcesci_kupci():
    try:
        cur = mysql.connection.cursor()
        cur.execute('SELECT * FROM najcesci_kupci')
        data = cur.fetchall()
        cur.close()
        return jsonify(data)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/najbolji_kupci', methods=['GET'])
def get_najbolji_kupci():
    try:
        cur = mysql.connection.cursor()
        cur.execute('SELECT * FROM najbolji_kupci')
        data = cur.fetchall()
        cur.close()
        return jsonify(data)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/najbolji_zaposlenik_racuni', methods=['GET'])
def get_najbolji_zaposlenik_racuni():
    try:
        cur = mysql.connection.cursor()
        cur.execute('SELECT * FROM najbolji_zaposlenik_racuni')
        data = cur.fetchall()
        cur.close()
        return jsonify(data)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/najbolji_zaposlenik_zarada', methods=['GET'])
def get_najbolji_zaposlenik_zarada():
    try:
        cur = mysql.connection.cursor()
        cur.execute('SELECT * FROM najbolji_zaposlenik_zarada')
        data = cur.fetchall()
        cur.close()
        return jsonify(data)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/dodaj_zaposlenika', methods=['POST'])
def dodaj_zaposlenika():
    data = request.json
    ime = data['ime']
    prezime = data['prezime']
    mjesto_rada = data['mjesto_rada']
    placa = data['placa']
    spol = data['spol']

    try:
        cur = mysql.connection.cursor()
        cur.callproc('dodaj_zaposlenika', (ime, prezime, mjesto_rada, placa, spol))
        mysql.connection.commit()
        cur.close()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/zaposlenici', methods=['GET'])
def get_zaposlenici():
    try:
        cur = mysql.connection.cursor()
        cur.execute('SELECT * FROM zaposlenik')
        data = cur.fetchall()
        cur.close()
        return jsonify(data)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/evidencija', methods=['GET'])
def get_evidencija():
    try:
        cur = mysql.connection.cursor()
        cur.execute('SELECT * FROM evidencija')
        data = cur.fetchall()
        cur.close()
        return jsonify(data)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


@app.route('/proizvodi_na_lokacijama', methods=['GET'])
def get_proizvodi_na_lokacijama():
    location = request.args.get('location')
    try:
        cur = mysql.connection.cursor()
        if location and location != 'svi':
            cur.execute('SELECT * FROM proizvodi_na_lokacijama WHERE lokacija = %s', (location,))
        else:
            cur.execute('SELECT * FROM proizvodi_na_lokacijama')
        data = cur.fetchall()
        cur.close()
        return jsonify(data)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/ukupna_kolicina_proizvoda', methods=['GET'])
def get_ukupna_kolicina_proizvoda():
    try:
        cur = mysql.connection.cursor()
        cur.execute('SELECT * FROM ukupna_kolicina_proizvoda')
        data = cur.fetchall()
        cur.close()
        return jsonify(data)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/pregled_proizvoda', methods=['GET'])
def get_pregled_proizvoda():
    try:
        cur = mysql.connection.cursor()
        cur.execute('SELECT * FROM svi_proizvodi')  # Adjust the query as needed
        data = cur.fetchall()
        cur.close()
        return jsonify(data)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/najprodavaniji_proizvodi', methods=['GET'])
def get_najprodavaniji_proizvodi():
    try:
        cur = mysql.connection.cursor()
        cur.execute('SELECT * FROM najprodavaniji_proizvodi')  # Fetch from the view
        data = cur.fetchall()
        cur.close()
        return jsonify(data)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/najbolja_zarada', methods=['GET'])
def get_najbolja_zarada():
    try:
        cur = mysql.connection.cursor()
        cur.execute('SELECT * FROM najbolja_zarada')  # Fetch from the view
        data = cur.fetchall()
        cur.close()
        return jsonify(data)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/pregled_narudzba', methods=['GET'])
def get_narudzbe():
    try:
        cur = mysql.connection.cursor()
        cur.execute('SELECT * FROM narudzba ORDER BY datum DESC')  # Added ORDER BY
        data = cur.fetchall()
        cur.close()
        return jsonify(data)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/pregled_nabava', methods=['GET'])
def get_nabava():
    try:
        cur = mysql.connection.cursor()
        cur.execute('SELECT * FROM nabava ORDER BY datum DESC')  # Added ORDER BY
        data = cur.fetchall()
        cur.close()
        return jsonify(data)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/dodaj_narudzbu', methods=['POST'])
def dodaj_narudzbu():
    data = request.json
    l_id = data['lokacija_id']
    k_id = data['kupac_id']

    try:
        cur = mysql.connection.cursor()
        cur.callproc('stvori_narudzbu', [l_id, k_id])
        # Get the last inserted ID
        cur.execute("SELECT LAST_INSERT_ID() as narudzba_id")
        narudzba_id = cur.fetchone()['narudzba_id']
        mysql.connection.commit()
        cur.close()
        return jsonify({'success': True, 'narudzba_id': narudzba_id})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/dodaj_nabavu', methods=['POST'])
def dodaj_nabavu():
    data = request.json
    l_id = data['lokacija_id']

    try:
        cur = mysql.connection.cursor()
        cur.execute('CALL stvori_nabavu(%s)', (l_id,))  # Call the stored procedure
        cur.execute('SELECT LAST_INSERT_ID() as nabava_id')
        nabava_id = cur.fetchone()['nabava_id']
        mysql.connection.commit()
        cur.close()
        return jsonify({'success': True, 'nabava_id': nabava_id})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/procesiraj_narudzbu', methods=['POST'])
def process_order():
    data = request.json
    narudzba_id = data['narudzba_id']
    zaposlenik_id = data['zaposlenik_id']
    
    try:
        cur = mysql.connection.cursor()
        cur.callproc('procesiraj_narudzbu', [narudzba_id, zaposlenik_id])
        mysql.connection.commit()
        cur.close()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/procesiraj_nabavu', methods=['POST'])
def process_supply():
    data = request.json
    nabava_id = data['nabava_id']
    
    try:
        cur = mysql.connection.cursor()
        cur.callproc('procesiraj_nabavu', [nabava_id])
        mysql.connection.commit()
        cur.close()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/ponisti_narudzbu', methods=['POST'])
def cancel_order():
    data = request.json
    narudzba_id = data['narudzba_id']
    
    try:
        cur = mysql.connection.cursor()
        cur.callproc('ponisti_narudzbu', [narudzba_id])
        mysql.connection.commit()
        cur.close()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/ponisti_nabavu', methods=['POST'])
def cancel_supply():
    data = request.json
    nabava_id = data['nabava_id']
    
    try:
        cur = mysql.connection.cursor()
        cur.callproc('ponisti_nabavu', [nabava_id])
        mysql.connection.commit()
        cur.close()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/nabava_ispis/<int:lokacija_id>', methods=['GET'])
def get_supply_report(lokacija_id):
    try:
        cur = mysql.connection.cursor()
        
        # Call the stored procedure and fetch results in the same transaction
        cur.execute('CALL nabava_ispis(%s)', [lokacija_id])
        data = cur.fetchall()  # Fetch the results immediately after calling the procedure
        
        # If no data, return empty array instead of null
        if not data:
            return jsonify([])
            
        cur.close()
        return jsonify(data)
    except Exception as e:
        print('Error in get_supply_report:', str(e))  # Debug log
        return jsonify({'success': False, 'error': str(e)})

 

@app.route('/nabava_detalji/<int:nabava_id>', methods=['GET'])
def get_nabava_detalji(nabava_id):
    try:
        cur = mysql.connection.cursor()
        cur.callproc('nabava_detalji', [nabava_id])
        data = cur.fetchall()
        cur.close()
        return jsonify({'success': True, 'nabava': data})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/nabava_ispis/<int:lokacija_id>', methods=['GET'])
def get_nabava_ispis(lokacija_id):
    try:
        cur = mysql.connection.cursor()
        cur.callproc('nabava_ispis', [lokacija_id])
        data = cur.fetchall()
        cur.close()
        return jsonify(data)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/pregled_predracuna', methods=['GET'])
def get_pregled_predracuna():
    try:
        cur = mysql.connection.cursor()
        cur.execute('SELECT * FROM pregled_predracuna ORDER BY datum DESC')  # Added ORDER BY
        data = cur.fetchall()
        cur.close()
        return jsonify(data)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/novi_predracun', methods=['POST'])
def novi_predracun():
    data = request.json
    k_id = data.get('kupac_id')
    z_id = data['zaposlenik_id'] 

    try:
        cur = mysql.connection.cursor()
        cur.callproc('stvori_predracun', [k_id, z_id])
        cur.execute("SELECT LAST_INSERT_ID() as predracun_id")
        predracun_id = cur.fetchone()['predracun_id']
        mysql.connection.commit()
        cur.close()
        return jsonify({'success': True, 'predracun_id': predracun_id})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/predracun_detalji/<int:predracun_id>', methods=['GET'])
def predracun_detalji(predracun_id):
    try:
        cur = mysql.connection.cursor()
        cur.callproc('predracun_detalji', [predracun_id])
        data = cur.fetchall()
        cur.close()
        return jsonify({'success': True, 'predracun': data})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/procesiraj_predracun', methods=['POST'])
def procesiraj_predracun():
    data = request.json
    predracun_id = data['predracun_id']
    try:
        cur = mysql.connection.cursor()
        cur.callproc('procesiraj_predracun', [predracun_id])
        mysql.connection.commit()
        cur.close()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/ponisti_predracun', methods=['POST'])
def ponisti_predracun():
    data = request.json
    predracun_id = data['predracun_id']
    try:
        cur = mysql.connection.cursor()
        cur.callproc('ponisti_predracun', [predracun_id])
        mysql.connection.commit()
        cur.close()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


@app.route('/narudzba_detalji/<int:narudzba_id>', methods=['GET'])
def narudzba_detalji_full(narudzba_id):
    try:
        cur = mysql.connection.cursor()
        cur.callproc('narudzba_detalji', [narudzba_id])
        data = cur.fetchall()
        cur.close()
        return jsonify({'success': True, 'narudzba': data})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})
        
if __name__ == '__main__':
    app.run(debug=True)