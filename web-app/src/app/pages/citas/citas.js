const API_URL = 'http://127.0.0.1:8000/api/citas/'; // Asegúrate que esta sea tu ruta real
const LOGIN_URL = 'http://127.0.0.1:8000/api/login/';

// 1. Cargar Citas (Requiere Token)
async function cargarCitas() {
    const token = localStorage.getItem('accessToken');
    
    if (!token) {
        alert("Debes iniciar sesión primero");
        return;
    }

    try {
        const response = await fetch(API_URL, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            }
        });
        
        const citas = await response.json();
        const tbody = document.getElementById('tablaCitasBody');
        tbody.innerHTML = '';
        
        citas.forEach(c => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>#${c.id}</td>
                <td>${c.usuario}</td>
                <td>${c.servicio}</td>
                <td>${new Date(c.fecha).toLocaleString()}</td>
                <td>
                    <button class="btn-delete" onclick="eliminarCita(${c.id})">Eliminar</button>
                </td>
            `;
            tbody.appendChild(row);
        });
    } catch (err) {
        console.error("Error al cargar:", err);
    }
}

// 2. Función para Iniciar Sesión (Guarda el Token)
async function iniciarSesion(username, password) {
    const res = await fetch(LOGIN_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password })
    });
    
    const data = await res.json();
    if (data.access) {
        localStorage.setItem('accessToken', data.access);
        cargarCitas(); // Recargar datos tras login
    } else {
        alert("Usuario o contraseña incorrectos");
    }
}

// 3. Eliminar Cita
async function eliminarCita(id) {
    const token = localStorage.getItem('accessToken');
    if(confirm('¿Eliminar esta cita?')) {
        await fetch(`${API_URL}${id}/`, { 
            method: 'DELETE',
            headers: { 'Authorization': `Bearer ${token}` }
        });
        cargarCitas();
    }
}

// Inicialización
cargarCitas();