document.addEventListener('DOMContentLoaded', () => {
    const buttons = document.querySelectorAll('.data-fetch-button');
    const tableContainer = document.getElementById('table-container');
    const noviRacunContainer = document.getElementById('novi-racun-container');
    const noviRacunForm = document.getElementById('novi-racun-form');
    const popup = document.getElementById('popup');
    const closePopup = document.getElementById('close-popup');
    const stavkeContainer = document.getElementById('stavke-container');
    const addStavkaButton = document.getElementById('add-stavka');
    const loginForm = document.getElementById('login-form');
    const kupacView = document.getElementById('kupac-view'); 
    const adminView = document.getElementById('admin-view');
    const loginView = document.getElementById('login-view');
    const loginButton = document.getElementById('login-button');
    const sortBySelect = document.getElementById('sort-by');
    const locationSelect = document.getElementById('location-select');
    const proizvodiContainer = document.getElementById('proizvodi-na-lokacijama-container');
    const dodajNabavuButton = document.getElementById('dodaj-nabavu-button');
  
    let currentRacunId = null;
    let proizvodi = [];
    let odabrani_proizvodi = [];
    let currentFilter = null;
  
    // Show kupac view initially
    kupacView.style.display = 'block';
  
    // Hide the buttons initially 
    dodajNabavuButton.style.display = 'none';
  
    // Fetch and display data for routes
    buttons.forEach((button) => {
      button.addEventListener('click', async () => {
        const route = button.id;
  
        // Hide the location select dropdown initially
        locationSelect.style.display = 'none';
        
        // Hide all special forms by default
        document.getElementById('novi-predracun-container').style.display = 'none';
  
        if (route === 'pregled_racuna') {
          noviRacunContainer.classList.add('active');
        } else {
          noviRacunContainer.classList.remove('active');
        }
  
        if (route === 'pregled_predracuna') {
          document.getElementById('novi-predracun-container').style.display = 'block';
        }
  
        // Show the products container only if the "Proizvodi" button is clicked
        if (route === 'pregled_proizvoda') {
          proizvodiContainer.style.display = 'block'; // Show the products container
          locationSelect.style.display = 'block'; // Show the dropdown for location selection
          
          // Show the tables for najprodavaniji proizvodi and najbolja zarada
          document.querySelector('.tables-container').style.display = 'flex'; // Show the tables container

          // Show the "Dodaj Proizvod" form
          document.getElementById('dodaj-proizvod-container').style.display = 'block';

          // Fetch and display data
          await fetchAndDisplayData(route);
          fetchNajprodavanijiProizvodi(); // Fetch best-selling products
          fetchNajboljaZarada(); // Fetch best profit products
        } else {
          proizvodiContainer.style.display = 'none'; // Hide the products container
          document.querySelector('.tables-container').style.display = 'none'; // Hide the tables container
          document.getElementById('dodaj-proizvod-container').style.display = 'none'; // Hide the "Dodaj Proizvod" form
          await fetchAndDisplayData(route);
        }

        // Hide the buttons by default
        dodajNabavuButton.style.display = 'none';

        // Show the products container only if the "Proizvodi" button is clicked
        if (route === 'pregled_narudzba') { 
        } else if (route === 'pregled_nabava') {  
            dodajNabavuButton.style.display = 'block'; // Show the "Dodaj Nabavu" button
        } else {
            // Hide the forms and buttons for other sections
            dodajNabavuButton.style.display = 'none';
            document.getElementById('dodaj-nabavu-container').style.display = 'none';
        }
      });
    });
  
    async function fetchAndDisplayData(route) {
      try {
        const response = await fetch(`http://127.00.1:5000/${route}`);
        if (!response.ok) {
          throw new Error(`Failed to fetch data from /${route}`);
        }
  
        const data = await response.json();
        renderTable(data, route);
      } catch (error) {
        console.error(error);
        tableContainer.innerHTML = `<p>Error loading data: ${error.message}</p>`;
      }
    }
  
    function renderTable(data, route) {
      if (!data.length) {
        tableContainer.innerHTML = `<p>No data available for this table.</p>`;
        return;
      }
  
      const table = document.createElement('table');
      const thead = document.createElement('thead');
      const headerRow = document.createElement('tr');
  
      Object.keys(data[0]).forEach((key) => {
        const th = document.createElement('th');
        th.textContent = key;
        headerRow.appendChild(th);
      });
      // Add an empty header for action buttons
      const actionTh = document.createElement('th');
      actionTh.textContent = 'Akcije';
      headerRow.appendChild(actionTh);
      thead.appendChild(headerRow);
      table.appendChild(thead);
  
      const tbody = document.createElement('tbody');
      data.forEach((row) => {
        const tr = document.createElement('tr');
        let status = '';
        
        // First pass: find the status
        Object.entries(row).forEach(([key, value]) => {
          if (key.toLowerCase() === 'status') {
            status = value ? value.toString().toLowerCase() : '';
          }
        });

        // Second pass: create table cells
        Object.entries(row).forEach(([key, value]) => {
          const td = document.createElement('td');
          td.textContent = value || '';
          tr.appendChild(td);
        });
  
        // Add action column
        const actionTd = document.createElement('td');
        actionTd.style.display = 'flex';
        actionTd.style.gap = '5px';
        
        if (route === 'pregled_racuna') {
          tr.addEventListener('click', () => fetchRacunDetalji(row.racun_id || row.id));
          
          // Add a "Ponisti" button only if status is not "poništeno"
          if (status !== 'poništeno' && status !== 'ponisteno') {
            const ponistiButton = document.createElement('button');
            ponistiButton.textContent = 'Ponisti';
            ponistiButton.style.backgroundColor = '#f44336';
            ponistiButton.style.color = 'white';
            ponistiButton.style.border = 'none';
            ponistiButton.style.padding = '5px 10px';
            ponistiButton.style.borderRadius = '5px';
            ponistiButton.style.cursor = 'pointer';
            ponistiButton.addEventListener('click', (e) => {
              e.stopPropagation();
              const adminPassword = prompt('Unesite admin lozinku za poništavanje računa:');
              if (adminPassword) {
                ponistiRacun(row.racun_id || row.id, adminPassword);
              }
            });
            actionTd.appendChild(ponistiButton);
          }
        } else if (route === 'pregled_nabava') {
          tr.addEventListener('click', () => fetchNabavaDetalji(row.nabava_id || row.id));
          
          // Add buttons based on status
          if (status === 'na cekanju') {
            // Add "Procesiraj" button
            const procesirajButton = document.createElement('button');
            procesirajButton.textContent = 'Procesiraj';
            procesirajButton.style.backgroundColor = '#4CAF50';
            procesirajButton.style.color = 'white';
            procesirajButton.style.border = 'none';
            procesirajButton.style.padding = '5px 10px';
            procesirajButton.style.borderRadius = '5px';
            procesirajButton.style.cursor = 'pointer';
            procesirajButton.addEventListener('click', (e) => {
              e.stopPropagation();
              procesirajNabavu(row.nabava_id || row.id);
            });
            actionTd.appendChild(procesirajButton);

            // Add "Ponisti" button
            const ponistiButton = document.createElement('button');
            ponistiButton.textContent = 'Ponisti';
            ponistiButton.style.backgroundColor = '#f44336';
            ponistiButton.style.color = 'white';
            ponistiButton.style.border = 'none';
            ponistiButton.style.padding = '5px 10px';
            ponistiButton.style.borderRadius = '5px';
            ponistiButton.style.cursor = 'pointer';
            ponistiButton.addEventListener('click', (e) => {
              e.stopPropagation();
              ponistiNabavu(row.nabava_id || row.id);
            });
            actionTd.appendChild(ponistiButton);
          }
        } else if (route === 'pregled_predracuna') {
          tr.addEventListener('click', () => fetchPredracunDetalji(row.predracun_id || row.id));
          
          // Add buttons based on status
          if (status !== 'ponisteno' && status !== 'izvrseno') {
            // Add "Procesiraj" button
            const procesirajButton = document.createElement('button');
            procesirajButton.textContent = 'Procesiraj';
            procesirajButton.style.backgroundColor = '#4CAF50';
            procesirajButton.style.color = 'white';
            procesirajButton.style.border = 'none';
            procesirajButton.style.padding = '5px 10px';
            procesirajButton.style.borderRadius = '5px';
            procesirajButton.style.cursor = 'pointer';
            procesirajButton.addEventListener('click', (e) => {
              e.stopPropagation();
              procesirajPredracun(row.predracun_id || row.id);
            });
            actionTd.appendChild(procesirajButton);

            // Add "Ponisti" button
            const ponistiButton = document.createElement('button');
            ponistiButton.textContent = 'Ponisti';
            ponistiButton.style.backgroundColor = '#f44336';
            ponistiButton.style.color = 'white';
            ponistiButton.style.border = 'none';
            ponistiButton.style.padding = '5px 10px';
            ponistiButton.style.borderRadius = '5px';
            ponistiButton.style.cursor = 'pointer';
            ponistiButton.addEventListener('click', (e) => {
              e.stopPropagation();
              ponistiPredracun(row.predracun_id || row.id);
            });
            actionTd.appendChild(ponistiButton);
          }
        } else if (route === 'pregled_narudzba') {
          tr.addEventListener('click', () => fetchNarudzbaDetalji(row.narudzba_id || row.id));
          
          // Add buttons based on status
          if (status === 'na cekanju') {
            // Add "Procesiraj" button
            const procesirajButton = document.createElement('button');
            procesirajButton.textContent = 'Procesiraj';
            procesirajButton.style.backgroundColor = '#4CAF50';
            procesirajButton.style.color = 'white';
            procesirajButton.style.border = 'none';
            procesirajButton.style.padding = '5px 10px';
            procesirajButton.style.borderRadius = '5px';
            procesirajButton.style.cursor = 'pointer';
            procesirajButton.addEventListener('click', (e) => {
                e.stopPropagation();
                procesirajNarudzbu(row.narudzba_id || row.id);
            });
            actionTd.appendChild(procesirajButton);

            // Add "Ponisti" button
            const ponistiButton = document.createElement('button');
            ponistiButton.textContent = 'Ponisti';
            ponistiButton.style.backgroundColor = '#f44336';
            ponistiButton.style.color = 'white';
            ponistiButton.style.border = 'none';
            ponistiButton.style.padding = '5px 10px';
            ponistiButton.style.borderRadius = '5px';
            ponistiButton.style.cursor = 'pointer';
            ponistiButton.addEventListener('click', (e) => {
                e.stopPropagation();
                ponistiNarudzbu(row.narudzba_id || row.id);
            });
            actionTd.appendChild(ponistiButton);
          }
        }
        
        tr.appendChild(actionTd);
        tbody.appendChild(tr);
      });
  
      table.appendChild(tbody);
      tableContainer.innerHTML = '';
      tableContainer.appendChild(table);
    }
  
    async function fetchRacunDetalji(racunId) {
      try {
        const response = await fetch(`http://127.0.0.1:5000/racun_detalji/${racunId}`);
        if (!response.ok) {
          throw new Error('Failed to fetch racun details');
        }
  
        const data = await response.json();
        if (data.success) {
          renderReceiptPopup(data.racun);
        } else {
          alert(`Error: ${data.error}`);
        }
      } catch (error) {
        console.error(error);
        alert('Error fetching racun details.');
      }
    }
  
    function renderReceiptPopup(racunDetails) {
      if (!racunDetails.length) {
        alert('No details available for this racun.');
        return;
      }
  
      const racunInfo = racunDetails[0]; // Assuming the first entry contains general racun info
      const stavkeList = racunDetails.map(stavka => `
        <tr>
          <td>${stavka.proizvod_naziv || '-'}</td>
          <td>${stavka.kolicina || '-'}</td>
          <td>${stavka.cijena + ' €' || '-'}</td>
          <td>${stavka.popust || '-'}</td>
          <td>${stavka.nakon_popusta + ' €' || '-'}</td>
        </tr>
      `).join('');
  
      const popupContent = `
        <h2>Račun ID: ${racunInfo.racun_id}</h2>
        <p>Datum: ${new Date(racunInfo.datum).toLocaleString()}</p>
        <p>Kupac: ${racunInfo.kupac_ime}</p>
        <p>Zaposlenik: ${racunInfo.zaposlenik_ime}</p>
        <table class="receipt-table">
          <thead>
            <tr>
              <th>Proizvod</th>
              <th>Količina</th>
              <th>Cijena</th>
              <th>Popust</th>
              <th>Nakon Popusta</th>
            </tr>
          </thead>
          <tbody>
            ${stavkeList}
          </tbody>
        </table>
        <table class="total-table" style="margin-top: 10px;">
          <tr>
            <td><strong>Ukupno:</strong></td>
            <td>${racunInfo.ukupan_iznos + ' €' || '-'}</td>
          </tr>
        </table>
        <button class="close-popup" id="close-popup">Zatvori</button>
      `;
  
      const overlay = document.getElementById('overlay');
      overlay.style.display = 'block';
  
      popup.innerHTML = popupContent;
      popup.style.display = 'flex';
  
      document.getElementById('close-popup').addEventListener('click', () => {
        popup.style.display = 'none';
        overlay.style.display = 'none';
      });
    }
  
    // Handle Novi Račun form submission
    noviRacunForm.addEventListener('submit', async (e) => {
        e.preventDefault();
      
        let kupacId = document.getElementById('kupac-id').value;
        const zaposlenikId = document.getElementById('zaposlenik-id').value;
        const nacinPlacanja = document.getElementById('nacin-placanja').value;
      
        if (kupacId === '') {
          kupacId = null;
        }
      
        try {
          const response = await fetch('http://127.0.0.1:5000/novi_racun', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ kupac_id: kupacId, zaposlenik_id: zaposlenikId, nacin_placanja: nacinPlacanja }),
          });
      
          const data = await response.json();
          if (data.success) {
            currentRacunId = data.racun_id;
            alert(`Račun kreiran s ID: ${currentRacunId}`);
            // Show the popup for adding stavke
            popup.innerHTML = `
              <h2>Dodaj Stavke za Račun ID: ${currentRacunId}</h2>
              <form id="dodaj-stavke-form">
                <div id="stavke-container">
                  <div class="stavka">
                    <label>Proizvod ID:</label>
                    <input type="number" class="proizvod-id" required min="0" value="0"  />
                    <label>Količina:</label>
                    <input type="number" class="kolicina" required min="0" value="0" />
                  </div>
                </div>
                <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 20px;">
                  <button type="button" id="add-stavka">Dodaj Još</button>
                  <button id="close-popup" type="submit">Pošalji Stavke</button>
                </div>
              </form> 
            `;
            popup.style.display = 'flex';

            // Attach event listeners after the form is created
            document.getElementById('close-popup').addEventListener('click', () => {
              popup.style.display = 'none';
            });

            document.getElementById('add-stavka').addEventListener('click', () => {
              const stavkeContainer = document.getElementById('stavke-container');
              const stavkaDiv = document.createElement('div');
              stavkaDiv.classList.add('stavka');
              stavkaDiv.innerHTML = `
                <label>Proizvod ID:</label>
                <input type="number" class="proizvod-id" required min="0" value="0"  />
                <label>Količina:</label>
                <input type="number" class="kolicina" required min="0" value="0"  />
              `;
              stavkeContainer.appendChild(stavkaDiv);
            });

            document.getElementById('dodaj-stavke-form').addEventListener('submit', async (e) => {
              e.preventDefault();
              
              const stavke = Array.from(document.querySelectorAll('#stavke-container .stavka')).map((stavka) => ({
                proizvod_id: stavka.querySelector('.proizvod-id').value,
                kolicina: stavka.querySelector('.kolicina').value,
              }));

              try {
                const response = await fetch('http://127.0.0.1:5000/dodaj_stavke', {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({ 
                    stavke: stavke.map(stavka => ({
                      ...stavka,
                      racun_id: currentRacunId
                    }))
                  }),
                });

                const data = await response.json();
                if (data.success) {
                  alert('Stavke uspješno dodane!');
                  popup.style.display = 'none';
                  document.getElementById('dodaj-stavke-form').reset();
                  document.getElementById('stavke-container').innerHTML = '';
                  // Reload the "račun" table
                  await fetchAndDisplayData('pregled_racuna');
                } else {
                  alert(`Greška: ${data.error}`);
                  try {
                    const response = await fetch('http://127.0.0.1:5000/ponisti_racun_bez', {
                      method: 'POST',
                      headers: { 'Content-Type': 'application/json' },
                      body: JSON.stringify({ racun_id: currentRacunId}),
                    });
            
                    const data = await response.json();
                    if (data.success) {
                      alert('Račun uspješno poništen!');
                      await fetchAndDisplayData('pregled_racuna');
                    } else {
                      alert(`Greška: ${data.error}`);
                    }
                  } catch (error) {
                    console.error(error);
                    alert('Greška pri poništavanju računa.');
                  }
                }
              } catch (error) {
                console.error(error);
                alert('Greška pri dodavanju stavki.');
              }
            });
          } else {
            alert(`Greška: ${data.error}`);
          }
        } catch (error) {
          console.error(error);
          alert('Greška pri kreiranju računa.');
        }
      });
      
    // Add items dynamically
    addStavkaButton.addEventListener('click', () => {
      const stavkaDiv = document.createElement('div');
      stavkaDiv.classList.add('stavka');
      stavkaDiv.innerHTML = `
        <label>Proizvod ID:</label>
        <input type="number" class="proizvod-id" required value="0"  />
        <label>Količina:</label>
        <input type="number" class="kolicina" required value="0" />
      `;
      stavkeContainer.appendChild(stavkaDiv);
    });
   

    // Handle the form submission
    document.getElementById('dodaj-proizvod-form').addEventListener('submit', async (event) => {
        event.preventDefault();
  
      const naziv = document.getElementById('naziv').value;
      const nabavnaCijena = document.getElementById('nabavna-cijena').value;
      const prodajnaCijena = document.getElementById('prodajna-cijena').value;
      const kategorijaId = document.getElementById('kategorija-id').value;
  
        // Send the data to the server
      try {
        const response = await fetch('http://127.0.0.1:5000/dodaj_proizvod', {
          method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    naziv,
                    n_cijena: nabavnaCijena,
                    p_cijena: prodajnaCijena,
                    kategorija_id: kategorijaId,
                }),
            });

            const result = await response.json();
            if (result.success) {
                alert('Proizvod je uspješno dodan!');
                // Reset the form but don't hide it
                document.getElementById('dodaj-proizvod-form').reset();
                // Reload the products table
                await fetchAndDisplayData('pregled_proizvoda');
        } else {
                alert('Greška: ' + result.error);
        }
      } catch (error) {
            console.error('Error adding product:', error);
        alert('Greška pri dodavanju proizvoda.');
      }
    });
  
    // Show or hide OIB field based on the selected tip
    document.getElementById('tip').addEventListener('change', (e) => {
        // Check if oibContainer exists before trying to access it
        const oibContainer = document.getElementById('oib-container');
        if (oibContainer) {
            if (e.target.value === 'poslovni') {
                oibContainer.style.display = 'block';
                document.getElementById('oib-firme').setAttribute('required', 'required'); // Make OIB required
            } else if (e.target.value === 'privatni') {
                oibContainer.style.display = 'none';
                document.getElementById('oib-firme').removeAttribute('required'); // Remove required attribute
            }
        }
    });
    // Fetch Kupac Data button
    document.getElementById('kupaci').addEventListener('click', async () => {
        // Show the add kupac form
        document.getElementById('dodaj-kupca-container').style.display = 'block';

        // Show the data containers for kupci
        document.getElementById('najcesci-kupci-container').style.display = 'block';
        document.getElementById('najbolji-kupci-container').style.display = 'block';

        // Hide other data containers
        document.getElementById('dodaj-zaposlenika-container').style.display = 'none'; // Hide add zaposlenik form
        document.getElementById('najbolji-zaposlenik-racuni-container').style.display = 'none'; // Hide zaposlenik data
        document.getElementById('najbolji-zaposlenik-zarada-container').style.display = 'none'; // Hide zaposlenik data

        try {
            const response = await fetch('http://127.0.0.1:5000/kupaci');
            const data = await response.json();
            renderKupacTable(data);

            // Fetch data from views
            const najcesciResponse = await fetch('http://127.0.0.1:5000/najcesci_kupci');
            const najcesciData = await najcesciResponse.json();
            renderNajcesciKupci(najcesciData);

            const najboljiResponse = await fetch('http://127.0.0.1:5000/najbolji_kupci');
            const najboljiData = await najboljiResponse.json();
            renderNajboljiKupci(najboljiData);
        } catch (error) {
            console.error(error);
            alert('Greška pri učitavanju podataka o kupcima.');
        }
    });

    function renderNajcesciKupci(data) {
        const najcesciContainer = document.getElementById('najcesci-kupci-container');
        // Clear previous data but keep the title
        const contentContainer = document.createElement('div');
        data.forEach((kupac) => {
            const div = document.createElement('div');
            div.textContent = `${kupac.kupac} - Broj Računa: ${kupac.broj_racuna}`;
            contentContainer.appendChild(div);
        });
        najcesciContainer.innerHTML = ''; // Clear previous content
        najcesciContainer.appendChild(contentContainer); // Append new content
    }

    function renderNajboljiKupci(data) {
        const najboljiContainer = document.getElementById('najbolji-kupci-container');
        // Clear previous data but keep the title
        const contentContainer = document.createElement('div');
        data.forEach((kupac) => {
            const div = document.createElement('div');
            div.textContent = `${kupac.kupac} - Ukupan Iznos: ${kupac.ukupan_iznos}`;
            contentContainer.appendChild(div);
        });
        najboljiContainer.innerHTML = ''; // Clear previous content
        najboljiContainer.appendChild(contentContainer); // Append new content
    }

    // Hide the add kupac form and data containers when other buttons are clicked
    const otherButtons = ['klub', 'lokacija', 'pregled_proizvoda', 'pregled_racuna', 'zaposlenici', 'pregled_narudzba', 'pregled_nabava', 'evidencija'];
    otherButtons.forEach(buttonId => {
        document.getElementById(buttonId).addEventListener('click', () => {
            document.getElementById('dodaj-kupca-container').style.display = 'none';
            document.getElementById('najcesci-kupci-container').style.display = 'none';
            document.getElementById('najbolji-kupci-container').style.display = 'none';
            document.getElementById('dodaj-zaposlenika-container').style.display = 'none';
            document.getElementById('najbolji-zaposlenik-racuni-container').style.display = 'none';
            document.getElementById('najbolji-zaposlenik-zarada-container').style.display = 'none';
        });
    });

    // Handle Dodaj Kupca form submission
    document.getElementById('dodaj-kupca-form').addEventListener('submit', async (e) => {
        e.preventDefault();

        const ime = document.getElementById('ime').value;
        const prezime = document.getElementById('prezime').value;
        const spol = document.getElementById('spol').value;
        const adresa = document.getElementById('adresa').value;
        const email = document.getElementById('email').value;
        const tip = document.getElementById('tip').value;
        const oibFirme = document.getElementById('oib-firme').value || null;

        // Disable the submit button to prevent multiple submissions
        const submitButton = document.querySelector('#dodaj-kupca-form button[type="submit"]');
        submitButton.disabled = true;

        try {
            const response = await fetch('http://127.0.0.1:5000/dodaj_kupca', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ ime, prezime, spol, adresa, email, tip, oib_firme: oibFirme }),
            });

            const data = await response.json();
            if (data.success) {
                alert('Kupac uspješno dodan!');
                document.getElementById('dodaj-kupca-form').reset();
                // Optionally, refresh the kupac table
                const kupacResponse = await fetch('http://127.0.0.1:5000/kupaci');
                const kupacData = await kupacResponse.json();
                renderKupacTable(kupacData);
            } else {
                alert(`Greška: ${data.error}`);
            }
        } catch (error) {
            console.error(error);
            alert('Greška pri dodavanju kupca.');
        } finally {
            // Re-enable the submit button after the operation is complete
            submitButton.disabled = false;
        }
    });
   
  
    const cartButton = document.querySelector('.floating-cart-button');

    function showLogin() {
        document.getElementById('kupac-view').style.display = 'none';
        document.getElementById('login-view').style.display = 'block';
        cartButton.style.display = 'none'; // Hide cart button
    }

    function logout() {
        loginButton.textContent = 'Login';
        loginButton.onclick = showLogin;
        adminView.style.display = 'none'; 
        document.getElementById('restricted-view').style.display = 'none';
        kupacView.style.display = 'block';
        cartButton.style.display = 'flex'; // Show cart button
    }

    loginForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const userId = document.getElementById('user-id').value;
        const password = document.getElementById('password').value;

        try {
            const response = await fetch('http://127.0.0.1:5000/login', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ user_id: userId, password }),
            });

            const data = await response.json();
            if (data.success) {
                loginView.style.display = 'none';
                loginButton.textContent = 'Logout';
                loginButton.onclick = logout;
                cartButton.style.display = 'none'; // Hide cart button
                if (data.role === 'admin' || data.role === 'zaposlenik') {
                    document.getElementById('restricted-view').style.display = 'block';
                }
                if (data.role === 'admin') {
                    adminView.style.display = 'block';
                }  
            } else {
                alert('Invalid credentials');
            }
        } catch (error) {
            console.error(error);
            alert('Error during login');
        }
    });

    // Fetch and display odjeli, kategorije, and proizvodi
    async function fetchAndDisplayOdjeliKategorijeProizvodi() {
      try {
        const response = await fetch('http://127.0.0.1:5000/odjeli_kategorije_proizvodi');
        if (!response.ok) {
          throw new Error('Failed to fetch odjeli, kategorije, and proizvodi');
        }

        const data = await response.json();
        proizvodi = data.proizvodi;
        renderOdjeliKategorije(data.odjeliKategorije);
        renderProizvodi(proizvodi);
      } catch (error) {
        console.error(error);
      }
    }

    function renderOdjeliKategorije(odjeliKategorije) {
      const list = document.getElementById('odjeli-kategorije-list');
      list.innerHTML = '';
      odjeliKategorije.forEach((item) => {
        const odjelLi = document.createElement('li');
        odjelLi.textContent = item.odjel;
        odjelLi.classList.add('clickable');
        odjelLi.addEventListener('click', () => filterProizvodi('odjel', item.odjel));
        list.appendChild(odjelLi);

        const kategorijaUl = document.createElement('ul');
        item.kategorije.forEach((kategorija) => {
          const kategorijaLi = document.createElement('li');
          kategorijaLi.textContent = kategorija;
          kategorijaLi.classList.add('clickable');
          kategorijaLi.addEventListener('click', () => filterProizvodi('kategorija', kategorija));
          kategorijaUl.appendChild(kategorijaLi);
        });
        list.appendChild(kategorijaUl);
      });
    }

    function filterProizvodi(type, value) {
        // Store the current filter
        currentFilter = { type, value };
        const filteredProizvodi = proizvodi.filter((proizvod) => proizvod[type] === value);
        // Apply current sort order to filtered products
        const currentSortOrder = sortBySelect.value;
        renderProizvodi(sortProizvodi(filteredProizvodi, currentSortOrder));
    }

    function sortProizvodi(productsToSort, order) {
        return [...productsToSort].sort((a, b) => {
            const priceA = parseFloat(a.prodajna_cijena);
            const priceB = parseFloat(b.prodajna_cijena);
            return order === 'asc' ? priceA - priceB : priceB - priceA;
        });
    }

    function updateCartCount() {
      const cartCount = document.querySelector('.cart-count');
      cartCount.textContent = odabrani_proizvodi.length;
    }

    function renderProizvodi(proizvodiData) {
      const grid = document.getElementById('proizvodi-grid');
      grid.innerHTML = '';
      proizvodiData.forEach((proizvod) => {
        const div = document.createElement('div');
        div.classList.add('product-box');
        div.innerHTML = `
          <img src="assets/${proizvod.id}.jpg" alt="${proizvod.naziv}" />
          <h4>${proizvod.naziv}</h4> 
          <p>Prodajna Cijena: ${proizvod.prodajna_cijena} €</p> 
          <button class="add-product" data-id="${proizvod.id}" style="width: 50px; height: 50px; border-radius: 50%; margin:0 auto;">+</button>
        `;
        grid.appendChild(div);
      });

      // Update add button event listener to update cart count
      grid.querySelectorAll('.add-product').forEach(button => {
        button.addEventListener('click', () => { 
          const proizvodId = button.getAttribute('data-id');
          odabrani_proizvodi.push(proizvodId); // Add the proizvod id to the proizvodi array
          updateCartCount(); // Update the cart count display 
        });
      });
    }

    sortBySelect.addEventListener('change', () => {
        const sortOrder = sortBySelect.value;
        if (currentFilter) {
            // If there's a current filter, apply sort to filtered products
            const filteredProizvodi = proizvodi.filter(
                (proizvod) => proizvod[currentFilter.type] === currentFilter.value
            );
            renderProizvodi(sortProizvodi(filteredProizvodi, sortOrder));
        } else {
            // If no filter, sort all products
            renderProizvodi(sortProizvodi(proizvodi, sortOrder));
        }
    });

    // Call the function to fetch and display data
    fetchAndDisplayOdjeliKategorijeProizvodi();

    async function ponistiRacun(racunId, adminPassword) {
      try {
        const response = await fetch('http://127.0.0.1:5000/ponisti_racun', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ racun_id: racunId, admin_password: adminPassword }),
        });

        const data = await response.json();
        if (data.success) {
          alert('Račun uspješno poništen!');
          await fetchAndDisplayData('pregled_racuna');
        } else {
          alert(`Greška: ${data.error}`);
        }
      } catch (error) {
        console.error(error);
        alert('Greška pri poništavanju računa.');
      }
    }

    function renderKupacTable(data) {
        if (!data.length) {
            tableContainer.innerHTML = `<p>No data available for kupci.</p>`;
            return;
        }

        const table = document.createElement('table');
        const thead = document.createElement('thead');
        const headerRow = document.createElement('tr');

        // Create headers based on the keys of the first object
        Object.keys(data[0]).forEach((key) => {
            const th = document.createElement('th');
            th.textContent = key;
            headerRow.appendChild(th);
        });

        thead.appendChild(headerRow);
        table.appendChild(thead);

        const tbody = document.createElement('tbody');
        data.forEach((row) => {
            const tr = document.createElement('tr');
            Object.values(row).forEach((value) => {
                const td = document.createElement('td');
                td.textContent = value;
                tr.appendChild(td);
            });
            tbody.appendChild(tr);
        });

        table.appendChild(tbody);
        tableContainer.innerHTML = ''; // Clear previous content
        tableContainer.appendChild(table); // Append new table
    }

    // Fetch Zaposlenici Data button
    document.getElementById('zaposlenici').addEventListener('click', async () => {
        // Show the add zaposlenik form
        document.getElementById('dodaj-zaposlenika-container').style.display = 'block';

        // Show the data containers for zaposlenici
        document.getElementById('najbolji-zaposlenik-racuni-container').style.display = 'block';
        document.getElementById('najbolji-zaposlenik-zarada-container').style.display = 'block';

        // Hide other data containers
        document.getElementById('dodaj-kupca-container').style.display = 'none'; // Hide add kupac form
        document.getElementById('najcesci-kupci-container').style.display = 'none'; // Hide kupac data
        document.getElementById('najbolji-kupci-container').style.display = 'none'; // Hide kupac data

        try {
            // Fetch data for najbolji zaposlenik
            const najboljiZaposlenikRacuniResponse = await fetch('http://127.0.0.1:5000/najbolji_zaposlenik_racuni');
            const najboljiZaposlenikRacuniData = await najboljiZaposlenikRacuniResponse.json();
            renderNajboljiZaposlenikRacuni(najboljiZaposlenikRacuniData);

            const najboljiZaposlenikZaradaResponse = await fetch('http://127.0.0.1:5000/najbolji_zaposlenik_zarada');
            const najboljiZaposlenikZaradaData = await najboljiZaposlenikZaradaResponse.json();
            renderNajboljiZaposlenikZarada(najboljiZaposlenikZaradaData);
        } catch (error) {
            console.error(error);
            alert('Greška pri učitavanju podataka o zaposlenicima.');
        }
    });

    function renderNajboljiZaposlenikRacuni(data) {
        const najboljiContainer = document.getElementById('najbolji-zaposlenik-racuni-container');
        // Clear previous data but keep the title
        const contentContainer = document.createElement('div');
        data.forEach((zaposlenik) => {
            const div = document.createElement('div');
            div.textContent = `${zaposlenik.zaposlenik} - Broj Računa: ${zaposlenik.broj_racuna}`;
            contentContainer.appendChild(div);
        });
        najboljiContainer.innerHTML = ''; // Clear previous content
        najboljiContainer.appendChild(contentContainer); // Append new content
    }

    function renderNajboljiZaposlenikZarada(data) {
        const najboljiContainer = document.getElementById('najbolji-zaposlenik-zarada-container');
        // Clear previous data but keep the title
        const contentContainer = document.createElement('div');
        data.forEach((zaposlenik) => {
            const div = document.createElement('div');
            div.textContent = `${zaposlenik.zaposlenik} - Ukupan Iznos: ${zaposlenik.ukupan_iznos}`;
            contentContainer.appendChild(div);
        });
        najboljiContainer.innerHTML = ''; // Clear previous content
        najboljiContainer.appendChild(contentContainer); // Append new content
    }

    // Handle Dodaj Zaposlenika form submission
    document.getElementById('dodaj-zaposlenika-form').addEventListener('submit', async (e) => {
        e.preventDefault();

        const ime = document.getElementById('ime-zaposlenika').value;
        const prezime = document.getElementById('prezime-zaposlenika').value;
        const mjesto_rada = document.getElementById('mjesto_rada').value;
        const placa = document.getElementById('placa').value;
        const spol = document.getElementById('spol').value;

        // Disable the submit button to prevent multiple submissions
        const submitButton = document.querySelector('#dodaj-zaposlenika-form button[type="submit"]');
        submitButton.disabled = true;

        try {
            const response = await fetch('http://127.0.0.1:5000/dodaj_zaposlenika', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ ime, prezime, mjesto_rada, placa, spol }),
            });

            const data = await response.json();
            if (data.success) {
                alert('Zaposlenik uspješno dodan!');
                document.getElementById('dodaj-zaposlenika-form').reset();
                // Optionally, refresh the zaposlenici table
                await fetchAndDisplayZaposlenici();
            } else {
                alert(`Greška: ${data.error}`);
            }
        } catch (error) {
            console.error(error);
            alert('Greška pri dodavanju zaposlenika.');
        } finally {
            // Re-enable the submit button after the operation is complete
            submitButton.disabled = false;
        }
    });

    async function fetchAndDisplayZaposlenici() {
        try {
            const response = await fetch('http://127.0.0.1:5000/zaposlenici');
            const data = await response.json();
            renderZaposleniciTable(data);
        } catch (error) {
            console.error(error);
            alert('Greška pri učitavanju podataka o zaposlenicima.');
        }
    }

    function renderZaposleniciTable(data) {
        const tableContainer = document.getElementById('table-container');
        if (!data.length) {
            tableContainer.innerHTML = `<p>No data available for zaposlenici.</p>`;
            return;
        }

        const table = document.createElement('table');
        const thead = document.createElement('thead');
        const headerRow = document.createElement('tr');

        // Create headers based on the keys of the first object
        Object.keys(data[0]).forEach((key) => {
            const th = document.createElement('th');
            th.textContent = key;
            headerRow.appendChild(th);
        });

        thead.appendChild(headerRow);
        table.appendChild(thead);

        const tbody = document.createElement('tbody');
        data.forEach((row) => {
            const tr = document.createElement('tr');
            Object.values(row).forEach((value) => {
                const td = document.createElement('td');
                td.textContent = value;
                tr.appendChild(td);
            });
            tbody.appendChild(tr);
        });

        table.appendChild(tbody);
        tableContainer.innerHTML = ''; // Clear previous content
        tableContainer.appendChild(table); // Append new table
    }

    // Fetch Evidencija Data button
    document.getElementById('evidencija').addEventListener('click', async () => {
        // Hide other data containers
        document.getElementById('dodaj-kupca-container').style.display = 'none';
        document.getElementById('najcesci-kupci-container').style.display = 'none';
        document.getElementById('najbolji-kupci-container').style.display = 'none';
        document.getElementById('dodaj-zaposlenika-container').style.display = 'none';
        document.getElementById('najbolji-zaposlenik-racuni-container').style.display = 'none';
        document.getElementById('najbolji-zaposlenik-zarada-container').style.display = 'none';

        try {
            const response = await fetch('http://127.0.0.1:5000/evidencija');
            const data = await response.json();
            renderEvidencijaTable(data);
        } catch (error) {
            console.error(error);
            alert('Greška pri učitavanju podataka o evidenciji.');
        }
    });

    function renderEvidencijaTable(data) {
        const tableContainer = document.getElementById('table-container');
        if (!data.length) {
            tableContainer.innerHTML = `<p>No data available for evidencija.</p>`;
            return;
        }

        const table = document.createElement('table');
        const thead = document.createElement('thead');
        const headerRow = document.createElement('tr');

        // Create headers based on the keys of the first object
        Object.keys(data[0]).forEach((key) => {
            const th = document.createElement('th');
            th.textContent = key;
            headerRow.appendChild(th);
        });

        thead.appendChild(headerRow);
        table.appendChild(thead);

        const tbody = document.createElement('tbody');
        data.forEach((row) => {
            const tr = document.createElement('tr');
            Object.values(row).forEach((value) => {
                const td = document.createElement('td');
                td.textContent = value;
                tr.appendChild(td);
            });
            tbody.appendChild(tr);
        });

        table.appendChild(tbody);
        tableContainer.innerHTML = ''; // Clear previous content
        tableContainer.appendChild(table); // Append new table
    }

    // Fetch Proizvodi Data button
    document.getElementById('pregled_proizvoda').addEventListener('click', async () => {
        // Show the data containers for proizvodi
        document.getElementById('najprodavaniji-proizvodi-container').style.display = 'block';
        document.getElementById('najbolja-zarada-container').style.display = 'block';
        document.getElementById('proizvodi-na-lokacijama-container').style.display = 'block'; // New container
        // Hide other data containers
        document.getElementById('dodaj-kupca-container').style.display = 'none'; // Hide add kupac form
        document.getElementById('najcesci-kupci-container').style.display = 'none'; // Hide kupac data
        document.getElementById('najbolji-kupci-container').style.display = 'none'; // Hide kupac data
        document.getElementById('dodaj-zaposlenika-container').style.display = 'none'; // Hide add zaposlenik form
        document.getElementById('najbolji-zaposlenik-racuni-container').style.display = 'none'; // Hide zaposlenik data
        document.getElementById('najbolji-zaposlenik-zarada-container').style.display = 'none'; // Hide zaposlenik data
        proizvodiContainer.style.display = 'none';
        try {
            // Fetch data for proizvodi na lokacijama
            const proizvodiNaLokacijamaResponse = await fetch('http://127.0.0.1:5000/proizvodi_na_lokacijama');
            const proizvodiNaLokacijamaData = await proizvodiNaLokacijamaResponse.json();
            renderProizvodiNaLokacijama(proizvodiNaLokacijamaData);

        } catch (error) {
            console.error(error);
            alert('Greška pri učitavanju podataka o proizvodima.');
        }
    });

    // Fetch locations to populate the dropdown
    async function fetchLocations() {
        try {
            const response = await fetch('http://127.0.0.1:5000/lokacija_trgovine'); // Adjust the endpoint as needed
            const locations = await response.json();

            // Check if the response is an array
            if (Array.isArray(locations)) {
                locations.forEach(location => {
                    const option = document.createElement('option');
                    option.value = location; // Assuming 'location' is the location name
                    option.textContent = location;
                    locationSelect.appendChild(option);
                });
            } else {
                console.error('Expected an array but got:', locations);
                alert('Greška pri učitavanju lokacija.'); // Show an error message
            }
        } catch (error) {
            console.error('Error fetching locations:', error);
        }
    }

    // Fetch and display products based on selected location
    locationSelect.addEventListener('change', async () => {
        const selectedLocation = locationSelect.value;
        
        // Hide the products by location container when "Svi proizvodi" is selected
        if (selectedLocation === 'svi') {
            proizvodiContainer.style.display = 'none'; // Hide the container
        } else {
            proizvodiContainer.style.display = 'block'; // Show the container for specific locations

            // Fetch products for the selected location
            try {
                const response = await fetch(`http://127.0.0.1:5000/proizvodi_na_lokacijama?location=${selectedLocation}`);
                const data = await response.json();
                console.log('Fetched products for location:', data); // Debugging log
                renderProizvodiNaLokacijama(data);
            } catch (error) {
                console.error('Error fetching products by location:', error);
            }
        }
    });

    // Function to render Proizvodi na Lokacijama
    function renderProizvodiNaLokacijama(data) {
        const container = document.getElementById('proizvodi-table-container');
        container.innerHTML = ''; // Clear previous content

        if (data.length === 0) {
            container.innerHTML = '<p>No products available for this location.</p>';
        } else {
            const table = document.createElement('table');
            const thead = document.createElement('thead');
            const headerRow = document.createElement('tr');

            // Create table headers
            const headers = ['Proizvod', 'Lokacija', 'Količina'];
            headers.forEach(header => {
                const th = document.createElement('th');
                th.textContent = header;
                headerRow.appendChild(th);
            });
            thead.appendChild(headerRow);
            table.appendChild(thead);

            const tbody = document.createElement('tbody');
            data.forEach(item => {
                const tr = document.createElement('tr');
                tr.innerHTML = `
                    <td>${item.proizvod_naziv}</td>
                    <td>${item.lokacija}</td>
                    <td>${item.kolicina}</td>
                `;
                tbody.appendChild(tr);
            });
            table.appendChild(tbody);
            container.appendChild(table);
        }
        container.style.display = 'block'; // Show the container
    }

    // Call fetchLocations to populate the dropdown on page load
    fetchLocations();

    async function fetchNajprodavanijiProizvodi() {
        try {
            const response = await fetch('http://127.0.0.1:5000/najprodavaniji_proizvodi');
            const data = await response.json();
            renderNajprodavanijiProizvodi(data);
        } catch (error) {
            console.error('Error fetching najprodavaniji proizvodi:', error);
        }
    }

    function renderNajprodavanijiProizvodi(data) {
        const container = document.getElementById('najprodavaniji-proizvodi-container');
        container.innerHTML = ''; // Clear previous content

        if (data.length === 0) {
            container.innerHTML = '<p>No best-selling products available.</p>';
        } else {
            const table = document.createElement('table');
            const thead = document.createElement('thead');
            const headerRow = document.createElement('tr');

            // Create table headers
            const headers = ['Proizvod', 'Količina'];
            headers.forEach(header => {
                const th = document.createElement('th');
                th.textContent = header;
                headerRow.appendChild(th);
            });
            thead.appendChild(headerRow);
            table.appendChild(thead);

            const tbody = document.createElement('tbody');
            data.forEach(item => {
                const tr = document.createElement('tr');
                tr.innerHTML = `
                    <td>${item.naziv}</td>
                    <td>${item.kolicina}</td>
                `;
                tbody.appendChild(tr);
            });
            table.appendChild(tbody);
            container.appendChild(table);
        }
        container.style.display = 'block'; // Show the container
    }

    // Similar function for najbolja_zarada
    async function fetchNajboljaZarada() {
        try {
            const response = await fetch('http://127.0.0.1:5000/najbolja_zarada');
            const data = await response.json();
            renderNajboljaZarada(data);
        } catch (error) {
            console.error('Error fetching najbolja zarada:', error);
        }
    }

    function renderNajboljaZarada(data) {
        const container = document.getElementById('najbolja-zarada-container');
        container.innerHTML = ''; // Clear previous content

        if (data.length === 0) {
            container.innerHTML = '<p>No best profit products available.</p>';
        } else {
            const table = document.createElement('table');
            const thead = document.createElement('thead');
            const headerRow = document.createElement('tr');

            // Create table headers
            const headers = ['Proizvod', 'Zarada'];
            headers.forEach(header => {
                const th = document.createElement('th');
                th.textContent = header;
                headerRow.appendChild(th);
            });
            thead.appendChild(headerRow);
            table.appendChild(thead);

            const tbody = document.createElement('tbody');
            data.forEach(item => {
                const tr = document.createElement('tr');
                tr.innerHTML = `
                    <td>${item.naziv}</td>
                    <td>${item.zarada}</td>
                `;
                tbody.appendChild(tr);
            });
            table.appendChild(tbody);
            container.appendChild(table);
        }
        container.style.display = 'block'; // Show the container
    }

    // Call these functions when the page loads or when the relevant button is clicked
    fetchNajprodavanijiProizvodi();
    fetchNajboljaZarada();
 
    async function ponistiNabavu(nabavaId) {
        try {
            const response = await fetch('http://127.0.0.1:5000/ponisti_nabavu', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ nabava_id: nabavaId }),
            });

            const data = await response.json();
            if (data.success) {
                alert('Nabava uspješno poništena!');
                await fetchAndDisplayData('pregled_nabava');
            } else {
                alert(`Greška: ${data.error}`);
            }
        } catch (error) {
            console.error(error);
            alert('Greška pri poništavanju nabave.');
        }
    }

    async function fetchNabavaDetalji(nabavaId) {
        try {
            const response = await fetch(`http://127.0.0.1:5000/nabava_detalji/${nabavaId}`);
            if (!response.ok) {
                throw new Error('Failed to fetch nabava details');
            }

            const data = await response.json();
            if (data.success) {
                renderNabavaPopup(data.nabava);
            } else {
                alert(`Error: ${data.error}`);
            }
        } catch (error) {
            console.error(error);
            alert('Error fetching nabava details.');
        }
    }

    function renderNabavaPopup(nabavaDetails) {
        if (!nabavaDetails.length) {
            alert('No details available for this nabava.');
            return;
        }

        const nabavaInfo = nabavaDetails[0];
        const stavkeList = nabavaDetails.map(stavka => `
            <tr>
                <td>${stavka.proizvod_naziv || '-'}</td>
                <td>${stavka.kolicina || '-'}</td>
                <td>${stavka.nabavna_cijena + ' €' || '-'}</td>
            </tr>
        `).join('');

        const popupContent = `
            <h2>Nabava ID: ${nabavaInfo.nabava_id}</h2>
            <p>Datum: ${new Date(nabavaInfo.datum).toLocaleString()}</p>
            <p>Lokacija: ${nabavaInfo.lokacija}</p>
            <table class="receipt-table">
                <thead>
                    <tr>
                        <th>Proizvod</th>
                        <th>Količina</th>
                        <th>Cijena</th>
                    </tr>
                </thead>
                <tbody>
                    ${stavkeList}
                </tbody>
            </table>
            <table class="total-table" style="margin-top: 10px;">
                <tr>
                    <td><strong>Ukupno:</strong></td>
                    <td>${nabavaInfo.sveukupan_iznos + ' €' || '-'}</td>
                </tr>
            </table>
            <button class="close-popup" id="close-popup">Zatvori</button>
        `;

        const overlay = document.getElementById('overlay');
        overlay.style.display = 'block';
  
        popup.innerHTML = popupContent;
        popup.style.display = 'flex';
  
        document.getElementById('close-popup').addEventListener('click', () => {
            popup.style.display = 'none';
            overlay.style.display = 'none';
        });
    }

    // Add event listener for "Dodaj Nabavu" button
    dodajNabavuButton.addEventListener('click', async () => {
        try {
            // Fetch locations with IDs
            const response = await fetch('http://127.0.0.1:5000/lokacija_trgovine_id');
            const locations = await response.json();

            // Show the popup with location selection
            popup.innerHTML = `
                <h2>Nova Nabava</h2>
                <form id="odabir-lokacije-form">
                    <div style="margin-bottom: 20px;">
                        <label for="lokacija-select">Odaberite Lokaciju:</label>
                        <select id="lokacija-select" required>
                            <option value="">-- Odaberite Lokaciju --</option>
                            ${locations.map(location => `
                                <option value="${location.id}">${location.grad}</option>
                            `).join('')}
                        </select>
                    </div>
                    <div style="display: flex; justify-content: flex-end; gap: 10px;">
                        <button type="submit">Nastavi</button>
                    </div>
                </form>
                <button class="close-popup" id="close-popup">Zatvori</button>
            `;
            popup.style.display = 'flex';

            // Add event listener for closing the popup
            document.getElementById('close-popup').addEventListener('click', () => {
                popup.style.display = 'none';
            });

            // Handle location selection
            document.getElementById('odabir-lokacije-form').addEventListener('submit', async (e) => {
                e.preventDefault();
                const lokacijaId = document.getElementById('lokacija-select').value;
                const selectedLocation = locations.find(loc => loc.id === parseInt(lokacijaId));
                
                if (!lokacijaId) {
                    alert('Molimo odaberite lokaciju.');
                    return;
                }

                try {
                    // Fetch the low stock information directly using the selected location ID
                    const response = await fetch(`http://127.0.0.1:5000/nabava_ispis/${lokacijaId}`);
                    const data = await response.json();

                    if (!data || data.length === 0) {
                        alert('Nema proizvoda kojima je potrebna nabava za ovu lokaciju.');
                        return;
                    }

                    // Show the popup with the low stock information
                    popup.innerHTML = `
                        <h2>Proizvodi za Nabavu - ${selectedLocation.grad}</h2>
                        <form id="dodaj-nabavu-form">
                            <div id="nabava-proizvodi-container">
                                <table>
                                    <thead>
                                        <tr>
                                            <th>Proizvod ID</th>
                                            <th>Trenutno Stanje</th>
                                            <th>Nabavna Cijena</th>
                                            <th>Preporučena Količina</th>
                                            <th>Količina za Naručiti</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        ${data.map(item => `
                                            <tr>
                                                <td>${item.proizvod_id}</td>
                                                <td>${item.na_stanju}</td>
                                                <td>${item.nabavna_cijena} €</td>
                                                <td>${item.nabava_kolicina}</td>
                                                <td>
                                                    <input type="number" 
                                                        class="kolicina-input" 
                                                        data-proizvod-id="${item.proizvod_id}"
                                                        value="${item.nabava_kolicina}"
                                                        min="0"
                                                        required
                                                    />
                                                </td>
                                            </tr>
                                        `).join('')}
                                    </tbody>
                                </table>
                            </div>
                            <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 20px;">
                                <button type="submit">Kreiraj Nabavu</button>
                            </div>
                        </form>
                        <button class="close-popup" id="close-popup">Zatvori</button>
                    `;

                    // Add event listener for closing the popup
                    document.getElementById('close-popup').addEventListener('click', () => {
                        popup.style.display = 'none';
                    });

                    // Handle form submission
                    document.getElementById('dodaj-nabavu-form').addEventListener('submit', async (e) => {
                        e.preventDefault();

                        try {
                            // Create the nabava with the selected location ID
                            const createNabavaResponse = await fetch('http://127.0.0.1:5000/dodaj_nabavu', {
                                method: 'POST',
                                headers: { 'Content-Type': 'application/json' },
                                body: JSON.stringify({ lokacija_id: lokacijaId }),
                            });

                            const nabavaData = await createNabavaResponse.json();
                            if (nabavaData.success) {
                                const nabavaId = nabavaData.nabava_id;

                                // Get all the quantities from inputs
                                const stavke = Array.from(document.querySelectorAll('.kolicina-input'))
                                    .map(input => ({
                                        proizvod_id: input.dataset.proizvodId,
                                        kolicina: input.value,
                                        nabava_id: nabavaId
                                    }))
                                    .filter(stavka => stavka.kolicina > 0);

                                // Add the stavke
                                const addStavkeResponse = await fetch('http://127.0.0.1:5000/dodaj_stavke', {
                                    method: 'POST',
                                    headers: { 'Content-Type': 'application/json' },
                                    body: JSON.stringify({ stavke }),
                                });

                                const stavkeData = await addStavkeResponse.json();
                                if (stavkeData.success) {
                                    alert('Nabava uspješno kreirana!');
                                    popup.style.display = 'none';
                                    await fetchAndDisplayData('pregled_nabava');
                                } else {
                                    alert(`Greška pri dodavanju stavki: ${stavkeData.error}`);
                                }
                            } else {
                                alert(`Greška pri kreiranju nabave: ${nabavaData.error}`);
                            }
                        } catch (error) {
                            console.error(error);
                            alert('Greška pri kreiranju nabave.');
                        }
                    });

                } catch (error) {
                    console.error(error);
                    alert('Greška pri dohvaćanju podataka o stanju proizvoda.');
                }
            });

        } catch (error) {
            console.error(error);
            alert('Greška pri dohvaćanju lokacija.');
        }
    });

    async function procesirajNabavu(nabavaId) {
      try {
        const response = await fetch('http://127.0.0.1:5000/procesiraj_nabavu', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ nabava_id: nabavaId }),
        });

        const data = await response.json();
        if (data.success) {
          alert('Nabava uspješno procesirana!');
          await fetchAndDisplayData('pregled_nabava');
        } else {
          alert(`Greška: ${data.error}`);
        }
      } catch (error) {
        console.error(error);
        alert('Greška pri procesiranju nabave.');
      }
    }
 

    // Add event listener for "Novi Predračun" form submission
    document.getElementById('novi-predracun-form').addEventListener('submit', async (e) => {
        e.preventDefault();
      
        let kupacId = document.getElementById('kupac-id-predracun').value;
        const zaposlenikId = document.getElementById('zaposlenik-id-predracun').value;
         
        if (kupacId === '') {
          kupacId = null;
        }
      
        try {
          const response = await fetch('http://127.0.0.1:5000/novi_predracun', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ kupac_id: kupacId, zaposlenik_id: zaposlenikId }),
          });
      
          const data = await response.json();
          if (data.success) {
            currentPredracunId = data.predracun_id;
            alert(`Predračun kreiran s ID: ${currentPredracunId}`);
            // Show the popup for adding stavke
            popup.innerHTML = `
              <h2>Dodaj Stavke za Predračun ID: ${currentPredracunId}</h2>
              <form id="dodaj-stavke-form">
                <div id="stavke-container">
                  <div class="stavka">
                    <label>Proizvod ID:</label>
                    <input type="number" class="proizvod-id" required min="0" value="0"  />
                    <label>Količina:</label>
                    <input type="number" class="kolicina" required min="0" value="0"  />
                  </div>
                </div>
                <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 20px;">
                  <button type="button" id="add-stavka">Dodaj Još</button>
                  <button id="close-popup" type="submit">Pošalji Stavke</button>
                </div>
              </form> 
            `;
            popup.style.display = 'flex';

            // Attach event listeners after the form is created
            document.getElementById('close-popup').addEventListener('click', () => {
              popup.style.display = 'none';
            });

            document.getElementById('add-stavka').addEventListener('click', () => {
              const stavkeContainer = document.getElementById('stavke-container');
              const stavkaDiv = document.createElement('div');
              stavkaDiv.classList.add('stavka');
              stavkaDiv.innerHTML = `
                <label>Proizvod ID:</label>
                <input type="number" class="proizvod-id" required min="0" value="0"  />
                <label>Količina:</label>
                <input type="number" class="kolicina" required min="0" value="0"  />
              `;
              stavkeContainer.appendChild(stavkaDiv);
            });

            document.getElementById('dodaj-stavke-form').addEventListener('submit', async (e) => {
              e.preventDefault();
              
              const stavke = Array.from(document.querySelectorAll('#stavke-container .stavka')).map((stavka) => ({
                proizvod_id: stavka.querySelector('.proizvod-id').value,
                kolicina: stavka.querySelector('.kolicina').value,
              }));

              try {
                const response = await fetch('http://127.0.0.1:5000/dodaj_stavke', {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({ 
                    stavke: stavke.map(stavka => ({
                      ...stavka,
                      predracun_id: currentPredracunId
                    }))
                  }),
                });

                const data = await response.json();
                if (data.success) {
                  alert('Stavke uspješno dodane!');
                  popup.style.display = 'none';
                  document.getElementById('dodaj-stavke-form').reset();
                  document.getElementById('stavke-container').innerHTML = '';
                  // Reload the "predračun" table
                  await fetchAndDisplayData('pregled_predracuna');
                } else {
                  alert(`Greška: ${data.error}`);
                }
              } catch (error) {
                console.error(error);
                alert('Greška pri dodavanju stavki.');
              }
            });
          } else {
            alert(`Greška: ${data.error}`);
          }
        } catch (error) {
          console.error(error);
          alert('Greška pri kreiranju predračuna.');
        }
    });

    // Add function to fetch predračun details
    async function fetchPredracunDetalji(predracunId) {
      try {
        const response = await fetch(`http://127.0.0.1:5000/predracun_detalji/${predracunId}`);
        if (!response.ok) {
          throw new Error('Failed to fetch predracun details');
        }

        const data = await response.json();
        if (data.success) {
          renderPredracunPopup(data.predracun);
        } else {
          alert(`Error: ${data.error}`);
        }
      } catch (error) {
        console.error(error);
        alert('Error fetching predračun details.');
      }
    }

    // Add function to render predračun popup
    function renderPredracunPopup(predracunDetails) {
      if (!predracunDetails.length) {
        alert('No details available for this predračun.');
        return;
      }

      const predracunInfo = predracunDetails[0];
      const stavkeList = predracunDetails.map(stavka => `
        <tr>
          <td>${stavka.proizvod_naziv || '-'}</td>
          <td>${stavka.kolicina || '-'}</td>
          <td>${stavka.cijena + ' €' || '-'}</td>
          <td>${stavka.popust || '-'}</td>
          <td>${stavka.nakon_popusta + ' €' || '-'}</td>
        </tr>
      `).join('');

      const popupContent = `
        <h2>Predračun ID: ${predracunInfo.predracun_id}</h2>
        <p>Datum: ${new Date(predracunInfo.datum).toLocaleString()}</p>
        <p>Kupac: ${predracunInfo.kupac_ime}</p>
        <p>Zaposlenik: ${predracunInfo.zaposlenik_ime}</p>
        <table class="receipt-table">
          <thead>
            <tr>
              <th>Proizvod</th>
              <th>Količina</th>
              <th>Cijena</th>
              <th>Popust</th>
              <th>Nakon Popusta</th>
            </tr>
          </thead>
          <tbody>
            ${stavkeList}
          </tbody>
        </table>
        <table class="total-table" style="margin-top: 10px;">
          <tr>
            <td><strong>Ukupno:</strong></td>
            <td>${predracunInfo.ukupan_iznos + ' €' || '-'}</td>
          </tr>
        </table>
        <button class="close-popup" id="close-popup">Zatvori</button>
      `;

      const overlay = document.getElementById('overlay');
      overlay.style.display = 'block';
  
      popup.innerHTML = popupContent;
      popup.style.display = 'flex';
  
      document.getElementById('close-popup').addEventListener('click', () => {
        popup.style.display = 'none';
        overlay.style.display = 'none';
      });
    }

    // Add functions to handle predračun actions
    async function procesirajPredracun(predracunId) {
      try {
        const response = await fetch('http://127.0.0.1:5000/procesiraj_predracun', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ predracun_id: predracunId }),
        });

        const data = await response.json();
        if (data.success) {
          alert('Predračun uspješno procesiran!');
          await fetchAndDisplayData('pregled_predracuna');
        } else {
          alert(`Greška: ${data.error}`);
        }
      } catch (error) {
        console.error(error);
        alert('Greška pri procesiranju predračuna.');
      }
    }

    async function ponistiPredracun(predracunId) {
      try {
        const response = await fetch('http://127.0.0.1:5000/ponisti_predracun', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ predracun_id: predracunId }),
        });

        const data = await response.json();
        if (data.success) {
          alert('Predračun uspješno poništen!');
          await fetchAndDisplayData('pregled_predracuna');
        } else {
          alert(`Greška: ${data.error}`);
        }
      } catch (error) {
        console.error(error);
        alert('Greška pri poništavanju predračuna.');
      }
    }

    async function fetchNarudzbaDetalji(narudzbaId) {
        try {
            const response = await fetch(`http://127.0.0.1:5000/narudzba_detalji/${narudzbaId}`);
            if (!response.ok) {
                throw new Error('Failed to fetch narudzba details');
            }

            const data = await response.json();
            if (data.success) {
                renderNarudzbaPopup(data.narudzba);
            } else {
                alert(`Error: ${data.error}`);
            }
        } catch (error) {
            console.error(error);
            alert('Error fetching narudzba details.');
        }
    }

    function renderNarudzbaPopup(narudzbaDetails) {
        if (!narudzbaDetails.length) {
            alert('No details available for this narudzba.');
            return;
        }

        const narudzbaInfo = narudzbaDetails[0];
        const stavkeList = narudzbaDetails.map(stavka => `
            <tr>
                <td>${stavka.proizvod_naziv || '-'}</td>
                <td>${stavka.kolicina || '-'}</td>
                <td>${stavka.cijena + ' €' || '-'}</td>
            </tr>
        `).join('');

        const popupContent = `
            <h2>Narudžba ID: ${narudzbaInfo.narudzba_id}</h2>
            <p>Datum: ${new Date(narudzbaInfo.datum).toLocaleString()}</p> 
            <table class="receipt-table">
                <thead>
                    <tr>
                        <th>Proizvod</th>
                        <th>Količina</th>
                        <th>Cijena</th>
                    </tr>
                </thead>
                <tbody>
                    ${stavkeList}
                </tbody>
            </table>
            <table class="total-table" style="margin-top: 10px;">
                <tr>
                    <td><strong>Ukupno:</strong></td>
                    <td>${narudzbaInfo.ukupan_iznos + ' €' || '-'}</td>
                </tr>
            </table>
            <button class="close-popup" id="close-popup">Zatvori</button>
        `;

        const overlay = document.getElementById('overlay');
        overlay.style.display = 'block';
  
        popup.innerHTML = popupContent;
        popup.style.display = 'flex';
  
        document.getElementById('close-popup').addEventListener('click', () => {
            popup.style.display = 'none';
            overlay.style.display = 'none';
        });
    }

    async function procesirajNarudzbu(narudzbaId) {
        const zaposlenikId = prompt('Unesite ID zaposlenika:');
        if (!zaposlenikId) {
            return;
        }

        try {
            const response = await fetch('http://127.0.0.1:5000/procesiraj_narudzbu', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    narudzba_id: narudzbaId,
                    zaposlenik_id: zaposlenikId
                })
            });

            const data = await response.json();
            if (data.success) {
                alert('Narudžba uspješno procesirana!');
                await fetchAndDisplayData('pregled_narudzba');
            } else {
                alert(`Greška: ${data.error}`);
            }
        } catch (error) {
            console.error(error);
            alert('Greška pri procesiranju narudžbe.');
        }
    }

    async function ponistiNarudzbu(narudzbaId) {
        if (!confirm('Jeste li sigurni da želite poništiti narudžbu?')) {
            return;
        }

        try {
            const response = await fetch('http://127.0.0.1:5000/ponisti_narudzbu', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ narudzba_id: narudzbaId })
            });

            const data = await response.json();
            if (data.success) {
                alert('Narudžba uspješno poništena!');
                await fetchAndDisplayData('pregled_narudzba');
            } else {
                alert(`Greška: ${data.error}`);
            }
        } catch (error) {
            console.error(error);
            alert('Greška pri poništavanju narudžbe.');
        }
    }

    // Initialize cart count
    updateCartCount();

    // Add cart button click handler
    document.querySelector('.floating-cart-button').addEventListener('click', showCartPopup);
    document.getElementById('close-cart-popup').addEventListener('click', hideCartPopup);

    async function showCartPopup() {
        const cartPopup = document.getElementById('cart-popup');
        const cartItemsContainer = document.getElementById('cart-items');
        const overlay = document.getElementById('overlay');
        
        // Show overlay
        overlay.style.display = 'block';
        
        // Fetch locations first
        let locationsHTML = '<option value="">Odaberite lokaciju</option>';
        try {
            const response = await fetch('http://127.0.0.1:5000/lokacija_trgovine_id');
            const locations = await response.json();
            locationsHTML += locations.map(loc => 
                `<option value="${loc.id}">${loc.grad}</option>`
            ).join('');
        } catch (error) {
            console.error('Error fetching locations:', error);
        }

        // Group products by ID and count occurrences
        const groupedProducts = odabrani_proizvodi.reduce((acc, id) => {
            acc[id] = (acc[id] || 0) + 1;
            return acc;
        }, {});

        let cartHTML = '';
        
        // Add Kupac ID and Location inputs at the top
        cartHTML += `
            <div style="margin-bottom: 20px; display: flex; gap: 20px;">
                <div>
                    <label for="cart-kupac-id" style="display: block; margin-bottom: 5px;">
                        <strong>Kupac ID:</strong>
                    </label>
                    <input type="number" 
                        id="cart-kupac-id" 
                        required 
                        min="1" 
                        style="width: 200px; padding: 8px; border: 1px solid #ddd; border-radius: 5px;"
                    >
                </div>
                <div>
                    <label for="cart-location" style="display: block; margin-bottom: 5px;">
                        <strong>Lokacija:</strong>
                    </label>
                    <select 
                        id="cart-location" 
                        required
                        style="width: 200px; padding: 8px; border: 1px solid #ddd; border-radius: 5px;"
                    >
                        ${locationsHTML}
                    </select>
                </div>
            </div>
        `;

        // Create table for products
        cartHTML += '<table class="receipt-table">' +
            '<thead><tr>' +
            '<th>Proizvod ID</th>' +
            '<th>Naziv</th>' +
            '<th>Količina</th>' +
            '<th>Cijena</th>' +
            '<th>Ukupno</th>' +
            '</tr></thead><tbody>';

        let totalPrice = 0;
        
        for (const [id, count] of Object.entries(groupedProducts)) {
            const product = proizvodi.find(p => p.id.toString() === id);
            const productName = product ? product.naziv : 'Nepoznat proizvod';
            const price = product ? parseFloat(product.prodajna_cijena) : 0;
            const itemTotal = price * count;
            totalPrice += itemTotal;
            
            cartHTML += `
                <tr>
                    <td>${id}</td>
                    <td>${productName}</td>
                    <td>${count}</td>
                    <td>${price.toFixed(2)} €</td>
                    <td>${itemTotal.toFixed(2)} €</td>
                </tr>
            `;
        }

        cartHTML += '</tbody></table>';
        
        if (odabrani_proizvodi.length > 0) {
            cartHTML += `
                <table class="total-table" style="margin-top: 20px;">
                    <tr class="total-row">
                        <td style="text-align: right;"><strong>Ukupna Cijena:</strong></td>
                        <td style="text-align: right; padding-left: 20px;"><strong>${totalPrice.toFixed(2)} €</strong></td>
                    </tr>
                </table>
                <button id="submit-cart" 
                    style="background-color: #4caf50; color: white; border: none; 
                    padding: 10px 20px; border-radius: 5px; margin-top: 20px; 
                    cursor: pointer; float: right;">
                    Naruči
                </button>
            `;
        } else {
            cartHTML = '<p>Košarica je prazna</p>';
        }

        cartItemsContainer.innerHTML = cartHTML;
        cartPopup.style.display = 'flex';

        // Modify the submit button event listener
        const submitButton = document.getElementById('submit-cart');
        if (submitButton) {
            submitButton.addEventListener('click', async () => {
                const kupacId = document.getElementById('cart-kupac-id').value;
                const locationId = document.getElementById('cart-location').value;
                
                if (!kupacId) {
                    alert('Molimo unesite Kupac ID');
                    return;
                }
                if (!locationId) {
                    alert('Molimo odaberite lokaciju');
                    return;
                }

                try {
                    // First create the narudzba with selected location
                    const narudzbaResponse = await fetch('http://127.0.0.1:5000/dodaj_narudzbu', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            lokacija_id: parseInt(locationId),
                            kupac_id: kupacId
                        })
                    });

                    const narudzbaData = await narudzbaResponse.json();
                    if (narudzbaData.success) {
                        // Prepare stavke from grouped products
                        const stavke = Object.entries(groupedProducts).map(([id, count]) => ({
                            proizvod_id: parseInt(id),
                            kolicina: count,
                            narudzba_id: narudzbaData.narudzba_id  // Use the ID from the response
                        }));

                        console.log('Sending stavke:', stavke); // Debug log

                        // Add stavke to the narudzba
                        const stavkeResponse = await fetch('http://127.0.0.1:5000/dodaj_stavke', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ stavke })
                        });

                        const stavkeData = await stavkeResponse.json();
                        if (stavkeData.success) {
                            alert('Narudžba uspješno kreirana!');
                            // Clear the cart
                            odabrani_proizvodi = [];
                            updateCartCount();
                            hideCartPopup();
                        } else {
                            // If stavke failed, we should cancel the narudzba
                            alert(`Greška pri dodavanju stavki: ${stavkeData.error}`);
                            try {
                                await fetch('http://127.0.0.1:5000/ponisti_narudzbu', {
                                    method: 'POST',
                                    headers: { 'Content-Type': 'application/json' },
                                    body: JSON.stringify({ narudzba_id: narudzbaData.narudzba_id })
                                });
                            } catch (cancelError) {
                                console.error('Error canceling order:', cancelError);
                            }
                        }
                    } else {
                        alert(`Greška pri kreiranju narudžbe: ${narudzbaData.error}`);
                    }
                } catch (error) {
                    console.error('Error creating order:', error);
                    alert('Greška pri kreiranju narudžbe.');
                }
            });
        }
    }

    function hideCartPopup() {
        const cartPopup = document.getElementById('cart-popup');
        const overlay = document.getElementById('overlay');
        
        cartPopup.style.display = 'none';
        overlay.style.display = 'none';
    }

});

// Move showLogin outside the DOMContentLoaded event listener and update it
function showLogin() {
    document.getElementById('kupac-view').style.display = 'none';
    document.getElementById('login-view').style.display = 'block';
    document.querySelector('.floating-cart-button').style.display = 'none'; // Hide cart button
}
