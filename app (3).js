/* ===== config.js ===== */
/* ==================================================================
   BELLAVISTA REMIS — Configuración
   ================================================================== */
const CONFIG = {
  // Proyecto de Supabase (clave pública). La conexión de la app a la base se activa en el próximo paso.
  SUPABASE_URL: '',
  SUPABASE_ANON_KEY: '',

  // true = datos y usuarios de ejemplo + accesos de prueba visibles.
  // Ponelo en false antes de publicar para clientes reales.
  MODO_DEMO: true,

  // true = la app guarda todo en Supabase (cuentas, viajes, billetera, documentos).
  // false = modo demostración sin servidor (datos en el navegador).
  USAR_BASE_DE_DATOS: false,

  // Pegá acá tu clave de Google Maps (ver README: "Mapa de Google").
  // Si queda vacía, la app funciona igual pero sin mapa y con tarifa estimada.
  GOOGLE_MAPS_KEY: '',

  // Centro aproximado de Bella Vista, Tucumán: sesga las búsquedas hacia la zona
  CENTER: { lat: -27.0286, lng: -65.3036 },
  SEARCH_RADIUS_M: 50000,

  // Botones de acceso rápido en "¿A dónde vas?" (se buscan en Google al tocarlos)
  QUICK_DESTINATIONS: ['Complejo Batalla de Tucumán']
};

/* ===== storage.js ===== */
/* ==================================================================
   BELLAVISTA REMIS
   ================================================================== */
/* Modulo de datos en memoria. Reemplazar por llamadas fetch() a la API real cuando exista backend. */

/* ---------------- STORAGE (in-memory "DB") ---------------- */
const DB = {
  users: [],       // {foto, saldo, id, nombre, apellido, telefono, email, passwordHash, rol, estado, createdAt}
  drivers: [],      // {id, userId, licencia, estado, disponible, rating, ratingCount}
  vehicles: [],     // {id, driverId, marca, modelo, color, patente}
  trips: [],        // {id, code, passengerId, driverId, nombrePasajero, telefono, origen, barrio, destino, pax, obs, estado, tarifa, fecha, hora, scheduled}
  movements: [],   // {id, userId, tipo:'carga'|'viaje', monto, detalle, metodo, fecha, hora}
  ratings: [],      // {id, tripId, driverId, estrellas, comentario}
  cancellations: [],// {id, tripId, userId, motivo, fecha}
  tariffs: { por100m: 300, base: 800, porKm: 220, minima: 1200, nocturno: 15, rural: 25 },
  seq: { trip: 124 }
};

function uid(prefix){ return prefix + '_' + Math.random().toString(36).slice(2,9); }
function nowTime(){ const d = new Date(); return d.toLocaleTimeString('es-AR',{hour:'2-digit',minute:'2-digit'}); }
function todayStr(){ return new Date().toISOString().slice(0,10); }
function estimateFare(){
  const km = (2 + Math.random()*8);
  const t = DB.tariffs;
  let fare = t.base + km * t.porKm;
  const hour = new Date().getHours();
  if(hour >= 22 || hour < 6) fare *= (1 + t.nocturno/100);
  fare = Math.max(fare, t.minima);
  return Math.round(fare/50)*50;
}

/* ---------------- SEED DEMO DATA ---------------- */
(function seed(){
  if(!CONFIG.MODO_DEMO) return;   // sin modo demo no se cargan usuarios ni viajes de ejemplo
  const p1 = { id: uid('u'), nombre:'María', apellido:'López', telefono:'381 555-0000', email:'demo@bellavista.com', passwordHash:'demo123', rol:'pasajero', estado:'activo', saldo:5000, puntos:850, viajesGratis:0, foto:null, createdAt:new Date().toISOString() };
  DB.users.push(p1);
  DB.movements.push({ id: uid('m'), userId:p1.id, tipo:'carga', monto:5000, detalle:'Carga de dinero', metodo:'Mercado Pago', fecha:todayStr(), hora:'08:50' });

  const du = { id: uid('u'), nombre:'Carlos', apellido:'Gómez', telefono:'381 555-1111', email:'carlos@bellavista.com', passwordHash:'demo123', rol:'conductor', estado:'activo', createdAt:new Date().toISOString() };
  DB.users.push(du);
  const drv = { id: uid('d'), userId: du.id, licencia:'LIC-88213', estado:'aprobado', disponible:false, rating:4.8, ratingCount:37 };
  DB.drivers.push(drv);
  DB.vehicles.push({ id: uid('v'), driverId: drv.id, marca:'Fiat', modelo:'Siena', color:'Blanco', patente:'ABC 123' });

  const du2 = { id: uid('u'), nombre:'Rosa', apellido:'Medina', telefono:'381 555-2222', email:'rosa@bellavista.com', passwordHash:'demo123', rol:'conductor', estado:'activo', createdAt:new Date().toISOString() };
  DB.users.push(du2);
  const drv2 = { id: uid('d'), userId: du2.id, licencia:'LIC-40921', estado:'pendiente', disponible:false, rating:0, ratingCount:0 };
  DB.drivers.push(drv2);
  DB.vehicles.push({ id: uid('v'), driverId: drv2.id, marca:'Renault', modelo:'Sandero', color:'Gris', patente:'XYZ 789' });

  // one finished trip for stats flavor
  DB.trips.push({
    id: uid('t'), code:'BV-000123', passengerId: p1.id, driverId: drv.id,
    nombrePasajero:'María López', telefono:p1.telefono, origen:'Av. San Martín 450', barrio:'Centro',
    destino:'Terminal de ómnibus', pax:1, obs:'', estado:'finalizado', tarifa: 1450,
    fecha: todayStr(), hora:'09:14', scheduled:false, rated:true, pago:'efectivo'
  });
  DB.movements.push({ id: uid('m'), userId:p1.id, tipo:'viaje', monto:1450, detalle:'Viaje a Terminal de ómnibus', metodo:'Efectivo', fecha:todayStr(), hora:'09:14' });

  // choferes de ejemplo con viajes de los últimos días (para el ranking)
  const ago = n => new Date(Date.now() - n * 864e5).toISOString().slice(0,10);
  const demoTrips = (drv, days, hora) => days.forEach((n, i) => DB.trips.push({
    id: uid('t'), code:'BV-' + (drv.licencia.slice(-3)) + i + n, passengerId:p1.id, driverId:drv.id,
    nombrePasajero:'María López', telefono:p1.telefono, origen:'Av. Mitre 120', barrio:'', destino:'Barrio Norte',
    pax:1, obs:'', estado:'finalizado', tarifa:1800 + i * 150, fecha:ago(n), hora, scheduled:false, rated:true, pago:'efectivo' }));
  demoTrips(drv, [2,3,4,6], '10:20');
  [['Luis','Ramos','381 555-3333','luis@bellavista.com','LIC-55120',4.6,21,'Chevrolet','Onix','Rojo','AB 123 CD',[0,0,1,2,3,5,6]],
   ['Ana','Torres','381 555-4444','ana@bellavista.com','LIC-61877',4.9,12,'Volkswagen','Gol','Negro','AC 456 EF',[1,3,5]]].forEach(x => {
    const u = { id: uid('u'), nombre:x[0], apellido:x[1], telefono:x[2], email:x[3], passwordHash:'demo123', rol:'conductor', estado:'activo', createdAt:new Date().toISOString() };
    DB.users.push(u);
    const d = { id: uid('d'), userId:u.id, licencia:x[4], estado:'aprobado', disponible:false, rating:x[5], ratingCount:x[6] };
    DB.drivers.push(d);
    DB.vehicles.push({ id: uid('v'), driverId:d.id, marca:x[7], modelo:x[8], color:x[9], patente:x[10] });
    demoTrips(d, x[11], '11:05');
  });
})();

/* ===== notifications.js ===== */
/* ==================================================================
   BELLAVISTA REMIS
   ================================================================== */
/* ---------------- SESSION ---------------- */
const Session = {
  currentUser: null, // {id, rol, ...}
  activeTripId: null,
  driverProfileId: null,
};

/* ---------------- TOAST / UI HELPERS ---------------- */
const UI = {
  toast(msg){
    const wrap = document.getElementById('toast-wrap');
    const t = document.createElement('div');
    t.className = 'toast';
    t.innerHTML = '<span class="dot"></span>' + msg;
    wrap.appendChild(t);
    setTimeout(()=>{ t.style.opacity='0'; t.style.transition='opacity .3s'; setTimeout(()=>t.remove(),300); }, 2800);
  },
  openModal(id){ document.getElementById(id).classList.add('active'); },
  closeModal(id){ document.getElementById(id).classList.remove('active'); },
  setFieldError(fieldId, show){
    const el = document.getElementById(fieldId);
    if(!el) return;
    el.classList.toggle('error', !!show);
  },
  clearErrors(ids){ ids.forEach(id => UI.setFieldError(id, false)); },
  photos: {},   // foto elegida en los formularios de registro, por id de círculo
  /* Achica la foto a 256px para que no pese (se guarda como texto) */
  resizeImage(file, cb, max = 256){
    const reader = new FileReader();
    reader.onload = e => {
      const img = new Image();
      img.onload = () => {
        const s = Math.min(1, max / Math.min(img.width, img.height));
        const w = Math.round(img.width * s), h = Math.round(img.height * s);
        const c = document.createElement('canvas');
        c.width = w; c.height = h;
        c.getContext('2d').drawImage(img, 0, 0, w, h);
        cb(c.toDataURL('image/jpeg', max > 256 ? 0.7 : 0.85));
      };
      img.src = e.target.result;
    };
    reader.readAsDataURL(file);
  },
  previewAvatar(inputEl, circleId){
    const file = inputEl.files && inputEl.files[0];
    if(!file) return;
    this.resizeImage(file, data => {
      this.photos[circleId] = data;
      document.getElementById(circleId).innerHTML = `<img src="${data}" alt="Foto de perfil">`;
    });
  }
};

/* ===== wizard.js ===== */
/* ==================================================================
   BELLAVISTA REMIS
   ================================================================== */
/* ---------------- WIZARD (formularios paso a paso) ---------------- */
/* Controlador genérico: cada formulario se registra con sus pasos,
   una etiqueta corta por paso, y un validador opcional por paso.
   Se usa en: registro de pasajero, pedir remis, registro de conductor. */
const Wizard = {
  configs: {},

  register(name, opts){
    this.configs[name] = Object.assign({ current: 1 }, opts);
  },

  init(name){
    const cfg = this.configs[name];
    cfg.current = 1;
    this.render(name);
  },

  render(name){
    const cfg = this.configs[name];
    const root = document.getElementById(cfg.container);
    if(!root) return;

    root.querySelectorAll('.step-page').forEach(p => {
      p.classList.toggle('active', parseInt(p.dataset.step, 10) === cfg.current);
    });

    const bar = document.getElementById(cfg.progressId);
    if(bar){
      bar.innerHTML = cfg.labels.map((label, i) => {
        const n = i + 1;
        const state = n < cfg.current ? 'done' : (n === cfg.current ? 'active' : '');
        const circleContent = n < cfg.current ? '✓' : n;
        const line = n < cfg.labels.length
          ? `<div class="step-line ${n < cfg.current ? 'done' : ''}"></div>`
          : '';
        return `<div class="step-node ${state}"><div class="step-circle">${circleContent}</div><div class="step-label">${label}</div></div>${line}`;
      }).join('');
    }

    const prevBtn = document.getElementById(cfg.prevId);
    const nextBtn = document.getElementById(cfg.nextId);
    if(prevBtn) prevBtn.style.visibility = cfg.current === 1 ? 'hidden' : 'visible';
    if(nextBtn) nextBtn.textContent = cfg.current === cfg.labels.length ? (cfg.finalLabel || 'Confirmar') : 'Siguiente →';

    if(cfg.onRender) cfg.onRender(cfg.current);
    const view = root.closest('.view');
    if(view) view.scrollTo ? view.scrollTo(0,0) : null;
    window.scrollTo(0, 0);
  },

  prev(name){
    const cfg = this.configs[name];
    if(cfg.current > 1){
      cfg.current -= 1;
      this.render(name);
    }
  },

  next(name){
    const cfg = this.configs[name];
    const validate = cfg.validators && cfg.validators[cfg.current];
    if(validate && !validate()) return;

    if(cfg.current < cfg.labels.length){
      cfg.current += 1;
      this.render(name);
    } else if(cfg.onFinish){
      cfg.onFinish();
    }
  }
};

/* ===== app.js ===== */
/* ==================================================================
   BELLAVISTA REMIS
   ================================================================== */
/* ---------------- VALIDATION HELPERS ---------------- */
function isFullName(str){
  const parts = (str||'').trim().split(/\s+/).filter(Boolean);
  return parts.length >= 2 && parts.every(p => p.length >= 2);
}
function isValidPhone(str){ return /^[0-9+\-\s()]{6,}$/.test((str||'').trim()); }
function isValidEmail(str){ return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test((str||'').trim()); }

/* ---------------- ROUTER ---------------- */
const Router = {
  history: ['home'],
  go(viewName, opts){
    opts = opts || {};
    document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
    const el = document.getElementById('view-' + viewName);
    if(el) el.classList.add('active');
    if(!opts.replace) this.history.push(viewName);

    // top bar role pill
    const pill = document.getElementById('topbarRolePill');
    if(Session.currentUser){
      pill.textContent = Session.currentUser.rol === 'pasajero' ? 'Pasajero' : Session.currentUser.rol === 'comercio' ? 'Comercio' : Session.currentUser.rol === 'conductor' ? 'Conductor' : 'Administrador';
    } else {
      pill.textContent = 'Invitado';
    }

    this.paintTopbar();

    // bottom nav visibility
    const nav = document.getElementById('bottomNav');
    const passengerViews = ['passengerHome','request','history','status','scheduled','wallet'];
    if(Session.currentUser && Session.currentUser.rol === 'pasajero' && passengerViews.includes(viewName)){
      nav.style.display = 'flex';
      document.querySelectorAll('.nav-item').forEach(n => n.classList.toggle('active', n.dataset.target === viewName || (viewName==='status' && n.dataset.target==='passengerHome')));
    } else {
      nav.style.display = 'none';
    }

    window.scrollTo(0,0);

    if(viewName === 'passengerHome') Passenger.renderHome();
    if(viewName === 'history') Passenger.renderHistory();
    if(viewName === 'wallet') Wallet.render();
    if(viewName === 'shop') Shop.render();
    if(viewName === 'request') Maps.onShowRequest();
    if(viewName === 'register') Auth.setRegType('pasajero');
    if(viewName === 'driverPanel') Drivers.renderPanel();
    if(viewName === 'adminPanel') Admin.render();
    if(viewName === 'status') Trips.renderStatus();
    if(viewName === 'register') Wizard.init('register');
    if(viewName === 'request') Wizard.init('request');
    if(viewName === 'driverRegister'){ Wizard.init('driverRegister'); Docs.render(); }
    Home.renderStats();
  },
  paintTopbar(){
    const u = Session.currentUser, av = document.getElementById('topbarAvatar');
    if(u && u.rol !== 'admin'){ av.innerHTML = Avatar.html(u); av.style.display = 'flex'; }
    else av.style.display = 'none';
  },
  openProfile(){ if(Session.currentUser && Session.currentUser.rol === 'pasajero') this.go('wallet'); },
  back(){
    this.history.pop();
    const prev = this.history.pop() || 'home';
    this.go(prev);
  }
};

/* ---------------- HOME STATS ---------------- */
const Home = {
  requestRemis(){
    if(Session.currentUser && Session.currentUser.rol === 'comercio'){
      Router.go('shop');
    } else if(Session.currentUser && Session.currentUser.rol === 'pasajero'){
      Router.go('request');
    } else {
      UI.toast('Primero creá tu cuenta para poder pedir un remis.');
      Router.go('register');
    }
  },
  renderStats(){
    const todayTrips = DB.trips.filter(t => t.fecha === todayStr()).length;
    const activeDrivers = DB.drivers.filter(d => d.disponible).length;
    const elT = document.getElementById('statTripsToday');
    const elD = document.getElementById('statDriversOn');
    if(elT) elT.textContent = todayTrips;
    if(elD) elD.textContent = activeDrivers;
  }
};

/* ---------------- INIT ---------------- */
window.addEventListener('DOMContentLoaded', () => { if(!CONFIG.MODO_DEMO) document.querySelectorAll('.demo-only').forEach(e => e.style.display = 'none');
  Home.renderStats(); Maps.paint(); Maps.init(); API.init(); });

/* ===== auth.js ===== */
/* ==================================================================
   BELLAVISTA REMIS
   ================================================================== */
/* ---------------- AUTH MODULE ---------------- */
const Auth = {
  regType: 'pasajero',
  setRegType(t){
    this.regType = t;
    document.querySelectorAll('#regTypeSel button').forEach(b => b.classList.toggle('on', b.dataset.t === t));
    const c = t === 'comercio';
    document.getElementById('lblRegNombre').textContent = c ? 'Nombre del supermercado o comercio' : 'Nombre';
    document.getElementById('regNombre').placeholder = c ? 'Ej: Supermercado El Sol' : 'Ej: Juan';
    document.getElementById('f-reg-apellido').style.display = c ? 'none' : '';
    document.getElementById('f-reg-dir').style.display = c ? '' : 'none';
    document.getElementById('regStep1Sub').textContent = c ? 'Tu cuenta va a tener una pantalla para que tus clientes pidan remis.' : '¿Cómo te llamás?';
  },
  registerPassenger(){
    const ids = ['f-reg-nombre','f-reg-apellido','f-reg-tel','f-reg-email','f-reg-pass'];
    UI.clearErrors(ids);
    const nombre = document.getElementById('regNombre').value.trim();
    const apellido = this.regType === 'comercio' ? '' : document.getElementById('regApellido').value.trim();
    const direccion = document.getElementById('regDireccion').value.trim();
    const telefono = document.getElementById('regTelefono').value.trim();
    const email = document.getElementById('regEmail').value.trim();
    const password = document.getElementById('regPassword').value;
    let ok = true;
    if(nombre.length < 2){ UI.setFieldError('f-reg-nombre', true); ok = false; }
    if(this.regType === 'pasajero' && apellido.length < 2){ UI.setFieldError('f-reg-apellido', true); ok = false; }
    if(this.regType === 'comercio' && direccion.length < 4){ UI.setFieldError('f-reg-dir', true); ok = false; }
    if(!isValidPhone(telefono)){ UI.setFieldError('f-reg-tel', true); ok = false; }
    if(!isValidEmail(email)){ UI.setFieldError('f-reg-email', true); ok = false; }
    if(password.length < 6){ UI.setFieldError('f-reg-pass', true); ok = false; }
    if(!ok) return;
    if(API.on){ API.run(async () => {
      const me = await API.register({ tipo: this.regType, nombre, apellido, telefono, direccion, foto: UI.photos.regAvatarWrap || null }, email, password);
      UI.photos.regAvatarWrap = null;
      UI.toast('Cuenta creada. ¡Bienvenido/a, ' + nombre + '!');
      API.enter(me);
    }); return; }
    if(DB.users.some(u => u.email === email)){
      UI.setFieldError('f-reg-email', true);
      document.querySelector('#f-reg-email .err-msg').textContent = 'Ese email ya está registrado.';
      return;
    }
    const user = { id: uid('u'), nombre, apellido, telefono, email, passwordHash: password, rol:this.regType, direccion: this.regType === 'comercio' ? direccion : undefined, estado:'activo', saldo:0, foto:UI.photos.regAvatarWrap || null, createdAt:new Date().toISOString() };
    UI.photos.regAvatarWrap = null;
    DB.users.push(user);
    Session.currentUser = user;
    UI.toast('Cuenta creada. ¡Bienvenido/a, ' + nombre + '!');
    Router.go(user.rol === 'comercio' ? 'shop' : 'passengerHome');
  },
  regStep1Valid(){
    UI.clearErrors(['f-reg-nombre','f-reg-apellido','f-reg-dir']);
    const nombre = document.getElementById('regNombre').value.trim();
    const apellido = this.regType === 'comercio' ? '' : document.getElementById('regApellido').value.trim();
    const direccion = document.getElementById('regDireccion').value.trim();
    let ok = true;
    if(nombre.length < 2){ UI.setFieldError('f-reg-nombre', true); ok = false; }
    if(this.regType === 'pasajero' && apellido.length < 2){ UI.setFieldError('f-reg-apellido', true); ok = false; }
    if(this.regType === 'comercio' && direccion.length < 4){ UI.setFieldError('f-reg-dir', true); ok = false; }
    return ok;
  },
  regStep2Valid(){
    UI.clearErrors(['f-reg-tel','f-reg-email']);
    const telefono = document.getElementById('regTelefono').value.trim();
    const email = document.getElementById('regEmail').value.trim();
    let ok = true;
    if(!isValidPhone(telefono)){ UI.setFieldError('f-reg-tel', true); ok = false; }
    if(!isValidEmail(email)){ UI.setFieldError('f-reg-email', true); ok = false; }
    if(ok && DB.users.some(u => u.email === email)){
      UI.setFieldError('f-reg-email', true);
      document.querySelector('#f-reg-email .err-msg').textContent = 'Ese email ya está registrado.';
      ok = false;
    }
    return ok;
  },
  regStep3Valid(){
    UI.clearErrors(['f-reg-pass']);
    const password = document.getElementById('regPassword').value;
    if(password.length < 6){ UI.setFieldError('f-reg-pass', true); return false; }
    this.registerPassenger();
    return true;
  },
  loginPassenger(){
    UI.clearErrors(['f-log-email','f-log-pass']);
    const email = document.getElementById('logEmail').value.trim();
    const pass = document.getElementById('logPassword').value;
    if(API.on){ API.run(async () => {
      const r = await API.login(email, pass, 'pasajero');
      if(r.err === 'creds'){ UI.setFieldError('f-log-pass', true); return; }
      if(r.err){ UI.toast(r.err); return; }
      UI.toast('¡Bienvenido/a de nuevo, ' + r.me.nombre + '!'); API.enter(r.me);
    }); return; }
    const user = DB.users.find(u => u.email === email && u.passwordHash === pass && (u.rol === 'pasajero' || u.rol === 'comercio'));
    if(!user){ UI.setFieldError('f-log-pass', true); return; }
    Session.currentUser = user;
    UI.toast('¡Bienvenido/a de nuevo, ' + user.nombre + '!');
    Router.go(user.rol === 'comercio' ? 'shop' : 'passengerHome');
  },
  loginDriver(){
    UI.clearErrors(['f-drv-email','f-drv-pass']);
    const email = document.getElementById('drvEmail').value.trim();
    const pass = document.getElementById('drvPassword').value;
    if(API.on){ API.run(async () => {
      const r = await API.login(email, pass, 'conductor');
      if(r.err === 'creds'){ UI.setFieldError('f-drv-pass', true); return; }
      if(r.err){ UI.toast(r.err); return; }
      if(API.enter(r.me)) UI.toast('¡Hola, ' + r.me.nombre + '!');
    }); return; }
    const user = DB.users.find(u => u.email === email && u.passwordHash === pass && u.rol === 'conductor');
    if(!user){ UI.setFieldError('f-drv-pass', true); return; }
    const driver = DB.drivers.find(d => d.userId === user.id);
    if(driver.estado === 'pendiente'){
      UI.toast('Tu cuenta está pendiente de aprobación del administrador.');
      return;
    }
    if(driver.estado === 'rechazado' || driver.estado === 'suspendido'){
      UI.toast('Tu cuenta de conductor no está habilitada.');
      return;
    }
    Session.currentUser = user;
    Session.driverProfileId = driver.id;
    UI.toast('¡Hola, ' + user.nombre + '!');
    Router.go('driverPanel');
  },
  registerDriver(){
    const ids = ['f-dr-nombre','f-dr-apellido','f-dr-dni','f-dr-tel','f-dr-email','f-dr-pass','f-dr-licencia','f-dr-marca','f-dr-modelo','f-dr-color','f-dr-patente'];
    UI.clearErrors(ids);
    const v = id => document.getElementById(id).value.trim();
    const nombre=v('drNombre'), apellido=v('drApellido'), dni=v('drDni'), telefono=v('drTelefono'),
          email=v('drEmail'), pass=document.getElementById('drPassword').value, licencia=v('drLicencia'),
          marca=v('drMarca'), modelo=v('drModelo'), color=v('drColor'), patente=v('drPatente').toUpperCase().replace(/\s/g,''),
          anio=parseInt(v('drAnio'),10), tipoPatente=parseInt(document.getElementById('drTipoPatente').value,10);
    let ok = true;
    if(nombre.length<2){UI.setFieldError('f-dr-nombre',true);ok=false;}
    if(apellido.length<2){UI.setFieldError('f-dr-apellido',true);ok=false;}
    if(dni.length<6){UI.setFieldError('f-dr-dni',true);ok=false;}
    if(!isValidPhone(telefono)){UI.setFieldError('f-dr-tel',true);ok=false;}
    if(!isValidEmail(email)){UI.setFieldError('f-dr-email',true);ok=false;}
    if(pass.length<6){UI.setFieldError('f-dr-pass',true);ok=false;}
    if(licencia.length<3){UI.setFieldError('f-dr-licencia',true);ok=false;}
    if(marca.length<2){UI.setFieldError('f-dr-marca',true);ok=false;}
    if(modelo.length<1){UI.setFieldError('f-dr-modelo',true);ok=false;}
    if(color.length<2){UI.setFieldError('f-dr-color',true);ok=false;}
    if(patente.length<4){UI.setFieldError('f-dr-patente',true);ok=false;}
    if(!ok) return;
    if(API.on){ API.run(async () => {
      const docs = Docs.collect();
      await API.register({ tipo: 'conductor', nombre, apellido, dni, telefono, licencia, marca, modelo, color, patente, tipo_patente_id: tipoPatente, anio, foto: UI.photos.drAvatarWrap || null },
        email, pass, async () => { for(const [tipo, d] of Object.entries(docs)) await API.rpc('subir_documento', { p: { tipo, archivo: d.archivo, numero: d.numero, entidad: d.entidad, vence_el: d.vence_el } }); });
      API.logout(); API.clear(); UI.photos.drAvatarWrap = null;
      UI.toast('Registro enviado. El administrador va a revisar tu documentación.');
      Router.go('driverLogin');
    }); return; }
    const user = { id: uid('u'), nombre, apellido, telefono, email, passwordHash:pass, rol:'conductor', estado:'activo', foto:UI.photos.drAvatarWrap || null, createdAt:new Date().toISOString() };
    UI.photos.drAvatarWrap = null;
    DB.users.push(user);
    const driver = { id: uid('d'), userId:user.id, licencia, estado:'pendiente', disponible:false, rating:0, ratingCount:0, docs: Docs.collect() };
    DB.drivers.push(driver);
    DB.vehicles.push({ id: uid('v'), driverId:driver.id, marca, modelo, color, patente, anio, tipoPatente });
    UI.toast('Registro enviado. El administrador va a revisar tu documentación.');
    Router.go('driverLogin');
  },
  drStep1Valid(){
    const ids = ['f-dr-nombre','f-dr-apellido','f-dr-dni','f-dr-tel','f-dr-licencia'];
    UI.clearErrors(ids);
    const v = id => document.getElementById(id).value.trim();
    let ok = true;
    if(v('drNombre').length<2){UI.setFieldError('f-dr-nombre',true);ok=false;}
    if(v('drApellido').length<2){UI.setFieldError('f-dr-apellido',true);ok=false;}
    if(v('drDni').length<6){UI.setFieldError('f-dr-dni',true);ok=false;}
    if(!isValidPhone(v('drTelefono'))){UI.setFieldError('f-dr-tel',true);ok=false;}
    if(v('drLicencia').length<3){UI.setFieldError('f-dr-licencia',true);ok=false;}
    return ok;
  },
  drStep2Valid(){
    const ids = ['f-dr-email','f-dr-pass'];
    UI.clearErrors(ids);
    const email = document.getElementById('drEmail').value.trim();
    const pass = document.getElementById('drPassword').value;
    let ok = true;
    if(!isValidEmail(email)){UI.setFieldError('f-dr-email',true);ok=false;}
    if(pass.length<6){UI.setFieldError('f-dr-pass',true);ok=false;}
    if(ok && DB.users.some(u => u.email === email)){
      UI.setFieldError('f-dr-email', true);
      document.querySelector('#f-dr-email .err-msg').textContent = 'Ese email ya está registrado.';
      ok = false;
    }
    return ok;
  },
  drStep3Valid(){
    const ids = ['f-dr-marca','f-dr-modelo','f-dr-color','f-dr-patente','f-dr-anio'];
    UI.clearErrors(ids);
    const v = id => document.getElementById(id).value.trim();
    let ok = true;
    if(v('drMarca').length<2){UI.setFieldError('f-dr-marca',true);ok=false;}
    if(v('drModelo').length<1){UI.setFieldError('f-dr-modelo',true);ok=false;}
    if(v('drColor').length<2){UI.setFieldError('f-dr-color',true);ok=false;}
    const pat = v('drPatente').toUpperCase().replace(/\s/g,'');
    const okPat = document.getElementById('drTipoPatente').value === '1' ? /^[A-Z]{2}\d{3}[A-Z]{2}$/.test(pat) : /^[A-Z]{3}\d{3}$/.test(pat);
    if(!okPat){UI.setFieldError('f-dr-patente',true);ok=false;}
    const anio = parseInt(v('drAnio'),10);
    if(!(anio >= 1990 && anio <= new Date().getFullYear() + 1)){UI.setFieldError('f-dr-anio',true);ok=false;}
    return ok;
  },
  drStep4Valid(){
    const msg = Docs.validate();
    document.getElementById('drDocsErr').textContent = msg;
    if(msg) return false;
    this.registerDriver();
    return true;
  },
  loginAdmin(){
    if(API.on){ UI.toast('El administrador entra por su sitio aparte (no por esta pantalla).'); return; }
    if(!CONFIG.MODO_DEMO){ UI.toast('El acceso de administrador se habilita al conectar la base de datos.'); return; }
    UI.clearErrors(['f-adm-user','f-adm-pass']);
    const user = document.getElementById('admUser').value.trim();
    const pass = document.getElementById('admPassword').value;
    if(user !== 'admin' || pass !== 'admin123'){ UI.setFieldError('f-adm-pass', true); return; }
    Session.currentUser = { id:'admin', rol:'admin', nombre:'Admin' };
    Router.go('adminPanel');
  },
  logout(){
    if(API.on){ API.logout(); API.clear(); }
    Session.currentUser = null;
    Session.driverProfileId = null;
    Session.activeTripId = null;
    UI.toast('Sesión cerrada.');
    Router.go('home');
  },
  goForgotPassword(role){
    Session._fpRole = role;
    document.getElementById('fpSub').textContent = role === 'conductor'
      ? 'Ingresá el email de tu cuenta de conductor y te enviamos instrucciones.'
      : 'Ingresá tu email y te enviamos instrucciones.';
    document.getElementById('fpBackLink').innerHTML = role === 'conductor'
      ? 'Volvé a <a onclick="Router.go(\'driverLogin\')">iniciar sesión</a>'
      : 'Volvé a <a onclick="Router.go(\'login\')">iniciar sesión</a>';
    document.getElementById('fpEmail').value = '';
    UI.clearErrors(['f-fp-email']);
    Router.go('forgotPassword');
  },
  sendPasswordReset(){
    UI.clearErrors(['f-fp-email']);
    const email = document.getElementById('fpEmail').value.trim();
    if(!isValidEmail(email)){ UI.setFieldError('f-fp-email', true); return; }
    // Demo sin backend: simulamos el envío del email de recuperación.
    UI.toast('📧 Si el email existe, te enviamos instrucciones para recuperar tu contraseña. (demo)');
    Router.go(Session._fpRole === 'conductor' ? 'driverLogin' : 'login');
  }
};

Wizard.register('register', {
  container: 'regWizard', progressId: 'regStepProgress',
  prevId: 'regPrevBtn', nextId: 'regNextBtn', finalLabel: 'Crear cuenta',
  labels: ['Datos', 'Contacto', 'Clave'],
  validators: { 1: () => Auth.regStep1Valid(), 2: () => Auth.regStep2Valid(), 3: () => Auth.regStep3Valid() }
});

Wizard.register('driverRegister', {
  container: 'drWizard', progressId: 'drStepProgress',
  prevId: 'drPrevBtn', nextId: 'drNextBtn', finalLabel: 'Enviar registro',
  labels: ['Personales', 'Cuenta', 'Vehículo', 'Documentos'],
  validators: { 1: () => Auth.drStep1Valid(), 2: () => Auth.drStep2Valid(), 3: () => Auth.drStep3Valid(), 4: () => Auth.drStep4Valid() }
});

/* ===== passenger.js ===== */
/* ==================================================================
   BELLAVISTA REMIS
   ================================================================== */
/* ---------------- PASSENGER MODULE ---------------- */
const Passenger = {
  renderHome(){
    const u = Session.currentUser;
    if(!u) return;
    document.getElementById('passengerFirstName').textContent = u.nombre;
    document.getElementById('homeWallet').innerHTML = `<div class="wallet-chip" onclick="Router.go('wallet')"><div><span>Saldo de tu billetera</span><b>${money(u.saldo || 0)}</b></div><em>Cargar →</em></div>` + Points.chip(u);
    const banner = document.getElementById('activeTripBanner');
    const activeTrip = DB.trips.find(t => t.passengerId === u.id && !['finalizado','cancelado'].includes(t.estado) && !t.scheduled);
    if(activeTrip){
      Session.activeTripId = activeTrip.id;
      banner.innerHTML = `
        <div class="screen-pad" style="padding-top:0;">
          <div class="card trip-banner st-${activeTrip.estado}" style="cursor:pointer;" onclick="Router.go('status')">
            <div class="card-title-row">
              <h4>Tenés un viaje activo</h4>
              <span class="badge badge-yellow">${Trips.stateLabel(activeTrip.estado)}</span>
            </div>
            <div class="mini-row"><span>Solicitud <b>${activeTrip.code}</b> · Ver estado →</span></div>
          </div>
        </div>`;
    } else {
      banner.innerHTML = '';
    }
  },
  renderHistory(){
    const u = Session.currentUser;
    const list = document.getElementById('historyList');
    const trips = DB.trips.filter(t => t.passengerId === u.id).sort((a,b)=> (b.fecha+b.hora).localeCompare(a.fecha+a.hora));
    if(trips.length === 0){
      list.innerHTML = `<div class="empty-state"><span class="icon">🚕</span><h4>Todavía no hiciste viajes</h4><p>Cuando pidas tu primer remis, lo vas a ver acá.</p></div>`;
      return;
    }
    list.innerHTML = trips.map(t => {
      const driver = DB.drivers.find(d => d.id === t.driverId);
      const driverUser = driver ? DB.users.find(u2 => u2.id === driver.userId) : null;
      const vehicle = driver ? DB.vehicles.find(v => v.driverId === driver.id) : null;
      return `
      <div class="card">
        <div class="card-title-row">
          <h4>${t.destino}</h4>
          ${Trips.stateBadge(t.estado)}
        </div>
        <div class="mini-row"><span>${t.fecha} · ${t.hora}</span></div>
        <div class="mini-row"><span>Desde <b>${t.origen}</b></span></div>
        ${driverUser ? `<div class="mini-row"><span>Conductor: <b>${driverUser.nombre} ${driverUser.apellido}</b>${vehicle ? ' · '+vehicle.marca+' '+vehicle.modelo : ''}</span></div>` : ''}
        <div class="mini-row"><span>${t.estado==='finalizado' ? 'Total' : 'Tarifa estimada'}: <b>$${t.tarifa}</b>${t.pago ? ' · pagado con ' + (t.pago==='billetera' ? 'billetera' : t.pago==='gratis' ? 'puntos (gratis)' : 'efectivo') : ''}</span></div>
        ${t.estado==='finalizado' && !t.rated ? `<button class="btn btn-outline btn-sm" style="margin-top:10px;" onclick="Trips.openRating('${t.id}')">⭐ Calificar viaje</button>` : ''}
        ${t.estado==='programado' ? `<button class="btn btn-danger btn-sm" style="margin-top:10px;" onclick="Trips.openCancel('${t.id}')">✕ Cancelar viaje programado</button>` : ''}
      </div>`;
    }).join('');
  }
};

/* ===== trips.js ===== */
/* ==================================================================
   BELLAVISTA REMIS
   ================================================================== */
/* ---------------- TRIPS MODULE ---------------- */
const Trips = {
  paxCount: 1,
  stepPassengers(delta){
    this.paxCount = Math.max(1, Math.min(8, this.paxCount + delta));
    document.getElementById('reqPaxCount').textContent = this.paxCount;
  },
  reqStep1Valid(){
    UI.clearErrors(['f-req-origen','f-req-destino']);
    const origen = document.getElementById('reqOrigen').value.trim();
    const destino = document.getElementById('reqDestino').value.trim();
    let ok = true;
    if(origen.length < 3){ UI.setFieldError('f-req-origen', true); ok = false; }
    const errEl = document.getElementById('reqDestErr');
    errEl.textContent = 'Ingresá el destino.';
    if(destino.length < 2){ UI.setFieldError('f-req-destino', true); ok = false; }
    else if(Maps.enabled() && !Maps.routeReady){
      errEl.textContent = 'Tocá Buscar y elegí el destino de la lista para calcular el precio.';
      UI.setFieldError('f-req-destino', true); ok = false;
    }
    return ok;
  },
  /* Cómo se va a pagar según el saldo de la billetera */
  payNote(fare){
    const u = Session.currentUser;
    return (u.saldo || 0) >= fare
      ? 'Billetera (saldo ' + money(u.saldo) + ')'
      : 'Efectivo (tu saldo no alcanza)';
  },
  renderReqSummary(){
    const el = document.getElementById('reqSummary');
    if(!el) return;
    const v = id => (document.getElementById(id).value || '').trim();
    const free = (Session.currentUser.viajesGratis || 0) > 0;
    this.pendingFare = Maps.routeReady ? Maps.fare : estimateFare();   // se calcula una sola vez: es el mismo precio que se cobra
    el.innerHTML = `
      <div class="row"><span class="k">Origen</span><span class="v">${v('reqOrigen')}</span></div>
      <div class="row"><span class="k">Destino</span><span class="v">${v('reqDestino')}</span></div>
      <div class="row"><span class="k">Pasajeros</span><span class="v">${this.paxCount}</span></div>
      ${Maps.routeReady ? `<div class="row"><span class="k">Distancia</span><span class="v">${Maps.approx ? '≈ ' : ''}${Maps.km(Maps.distance)} · ${Math.ceil(Maps.distance/100)} cuadras</span></div>` : ''}
      <div class="row"><span class="k">${Maps.routeReady ? 'Tarifa' : 'Tarifa estimada'}</span><span class="v">${free ? '<s>' + money(this.pendingFare) + '</s> GRATIS 🎁' : money(this.pendingFare)}</span></div>
      <div class="row"><span class="k">Pago</span><span class="v">${free ? 'Viaje gratis (usás tus puntos)' : this.payNote(this.pendingFare)}</span></div>
    `;
  },
  submitRequest(){
    const u = Session.currentUser;
    if(!u || u.rol !== 'pasajero'){ UI.toast('Primero creá tu cuenta para pedir un remis.'); Router.go('register'); return; }
    const origen = document.getElementById('reqOrigen').value.trim();
    const destino = document.getElementById('reqDestino').value.trim();
    const obs = document.getElementById('reqObs').value.trim();
    if(!this.reqStep1Valid()){ UI.toast('Revisá los campos marcados en rojo.'); Wizard.init('request'); return; }
    if(API.on){ API.run(async () => {
      const r = await API.rpc('pedir_viaje', { p: API.payload(origen, destino, obs, this.paxCount, this.pendingFare) });
      Session.activeTripId = r.id; this.paxCount = 1; Maps.reset();
      ['reqOrigen','reqDestino','reqObs'].forEach(id => document.getElementById(id).value = '');
      document.getElementById('reqPaxCount').textContent = '1';
      await API.refresh();
      UI.toast('Solicitud ' + r.codigo + ' creada. Buscando conductor...');
      Router.go('status');
    }); return; }

    DB.seq.trip += 1;
    const code = 'BV-' + String(DB.seq.trip).padStart(6,'0');
    const trip = {
      id: uid('t'), code, passengerId: u.id, driverId: null,
      nombrePasajero: u.nombre + ' ' + u.apellido, telefono: u.telefono, origen, barrio:'', destino,
      pax: this.paxCount, obs, estado:'buscando', tarifa: this.pendingFare || estimateFare(),
      fecha: todayStr(), hora: nowTime(), scheduled:false, rated:false
    };
    if(Maps.routeReady){ trip.origenCoords = Maps.origin; trip.destCoords = Maps.dest; trip.distanciaM = Maps.distance; }
    if((u.viajesGratis || 0) > 0){ u.viajesGratis -= 1; trip.gratis = true; }   // se reserva ahora, se devuelve si cancela
    DB.trips.push(trip);
    Session.activeTripId = trip.id;
    this.paxCount = 1;
    Maps.reset();
    ['reqOrigen','reqDestino','reqObs'].forEach(id => document.getElementById(id).value = '');
    document.getElementById('reqPaxCount').textContent = '1';

    UI.toast('Solicitud ' + code + ' creada. Buscando conductor...');
    Router.go('status');
  },
  submitScheduled(){
    const u = Session.currentUser;
    if(!u || u.rol !== 'pasajero'){ Router.go('login'); return; }
    const ids = ['f-sch-fecha','f-sch-hora','f-sch-origen','f-sch-destino'];
    UI.clearErrors(ids);
    const fecha = document.getElementById('schFecha').value;
    const hora = document.getElementById('schHora').value;
    const origen = document.getElementById('schOrigen').value.trim();
    const destino = document.getElementById('schDestino').value.trim();
    let ok = true;
    if(!fecha){ UI.setFieldError('f-sch-fecha', true); ok = false; }
    if(!hora){ UI.setFieldError('f-sch-hora', true); ok = false; }
    if(origen.length < 3){ UI.setFieldError('f-sch-origen', true); ok = false; }
    if(destino.length < 2){ UI.setFieldError('f-sch-destino', true); ok = false; }
    if(!ok) return;
    if(API.on){ API.run(async () => {
      await API.rpc('pedir_viaje', { p: { origen_direccion: origen, destino_direccion: destino, cantidad_pasajeros: 1,
        programado_para: new Date(fecha + 'T' + hora).toISOString(), tarifa_estimada: estimateFare() } });
      await API.refresh();
      UI.toast('Viaje programado para el ' + fecha + ' a las ' + hora + '.');
      Router.go('passengerHome');
    }); return; }
    DB.seq.trip += 1;
    const code = 'BV-' + String(DB.seq.trip).padStart(6,'0');
    DB.trips.push({
      id: uid('t'), code, passengerId: u.id, driverId:null,
      nombrePasajero: u.nombre + ' ' + u.apellido, telefono: u.telefono, origen, barrio:'', destino, pax:1, obs:'',
      estado:'programado', tarifa: estimateFare(), fecha, hora, scheduled:true, rated:false
    });
    UI.toast('Viaje programado para el ' + fecha + ' a las ' + hora + '.');
    Router.go('passengerHome');
  },
  stateLabel(estado){
    return {
      buscando:'Buscando conductor', asignado:'Conductor asignado', camino:'Conductor en camino',
      llego:'Conductor llegó', curso:'Viaje en curso', finalizado:'Viaje finalizado',
      cancelado:'Viaje cancelado', programado:'Programado'
    }[estado] || estado;
  },
  stateBadge(estado){
    const map = {
      buscando:'badge-yellow', asignado:'badge-green', camino:'badge-blue', llego:'badge-blue',
      curso:'badge-green', finalizado:'badge-gray', cancelado:'badge-red', programado:'badge-blue'
    };
    return `<span class="badge ${map[estado]||'badge-gray'}">${this.stateLabel(estado)}</span>`;
  },
  stateOrder: ['buscando','asignado','camino','llego','curso','finalizado'],
  timelineSteps: [
    { key:'buscando',   title:'Solicitud enviada',      desc:'Estamos buscando un conductor disponible cerca tuyo.' },
    { key:'asignado',   title:'Conductor asignado',     desc:'Un conductor aceptó tu viaje y se está preparando.' },
    { key:'camino',     title:'Conductor en camino',    desc:'El conductor va hacia el punto de encuentro.' },
    { key:'llego',      title:'Conductor llegó',        desc:'Te está esperando en el punto de encuentro.' },
    { key:'curso',      title:'Viaje en curso',         desc:'Vas camino a destino.' },
    { key:'finalizado', title:'Viaje finalizado',       desc:'Llegaste a destino. ¡Gracias por viajar con nosotros!' }
  ],
  /* Linea de tiempo vertical estilo Uber, reutilizada en el estado del
     pasajero (Trips.renderStatus) y en el panel del conductor (Drivers). */
  timelineHTML(estado){
    if(estado === 'cancelado'){
      return `<div class="timeline"><div class="tl-item cancelled"><div class="tl-rail"><div class="tl-dot">✕</div></div><div class="tl-body"><div class="tl-title">Viaje cancelado</div><div class="tl-desc">Este viaje fue cancelado.</div></div></div></div>`;
    }
    const idx = this.stateOrder.indexOf(estado);
    return `<div class="timeline">${this.timelineSteps.map((s,i) => {
      const state = i < idx ? 'done' : (i === idx ? 'active' : '');
      const dotContent = i < idx ? '✓' : (i+1);
      return `
        <div class="tl-item ${state}">
          <div class="tl-rail"><div class="tl-dot">${dotContent}</div><div class="tl-connector"></div></div>
          <div class="tl-body"><div class="tl-title">${s.title}</div><div class="tl-desc">${s.desc}</div></div>
        </div>`;
    }).join('')}</div>`;
  },
  renderStatus(){
    const trip = DB.trips.find(t => t.id === Session.activeTripId);
    const content = document.getElementById('statusContent');
    if(!trip){
      content.innerHTML = `<div class="empty-state"><span class="icon">🚕</span><h4>No tenés un viaje activo</h4><p>Pedí un remis para ver el estado acá.</p><button class="btn btn-primary" style="margin-top:16px;" onclick="Router.go('request')">Pedir un remis</button></div>`;
      return;
    }
    const idx = this.stateOrder.indexOf(trip.estado);
    const emojiMap = { buscando:'🟡', asignado:'🟢', camino:'🚕', llego:'📍', curso:'🚗', finalizado:'✅', cancelado:'🔴' };
    const segs = this.stateOrder.slice(0,5).map((s,i) => `<div class="seg ${i <= idx ? 'done':''}"></div>`).join('');

    let driverBlock = '';
    let mapBlock = '';
    if(trip.driverId){
      const driver = DB.drivers.find(d => d.id === trip.driverId);
      const du = DB.users.find(u => u.id === driver.userId);
      const vh = DB.vehicles.find(v => v.driverId === driver.id);
      driverBlock = `
        <div class="driver-card">
          <div class="driver-avatar">${Avatar.html(du)}</div>
          <div class="driver-info">
            <h4>${du.nombre} ${du.apellido}</h4>
            <div class="car">🚕 ${vh.marca} ${vh.modelo} · ${vh.color}</div>
            <div class="plate">${vh.patente}</div>
          </div>
          <div class="driver-rating">⭐ ${driver.rating.toFixed(1)}</div>
        </div>
        <div class="screen-pad" style="padding-top:0;">
          <div class="btn-row">
            <button class="btn btn-outline btn-sm" onclick="UI.toast('📞 Llamando a ${du.nombre}... (demo)')">📞 Contactar</button>
            <button class="btn btn-outline btn-sm" onclick="UI.toast('📍 Ubicación en el mapa (demo)')">🗺️ Ver ubicación</button>
          </div>
        </div>`;
      mapBlock = `
        <div class="map-box">
          <svg class="map-pin" style="left:30%; top:60%;" viewBox="0 0 24 24"><path d="M12 2C8 2 5 5.2 5 9c0 5.2 7 13 7 13s7-7.8 7-13c0-3.8-3-7-7-7z" fill="#22252A"/><circle cx="12" cy="9" r="2.4" fill="#F5B700"/></svg>
          <svg class="map-pin" style="left:68%; top:35%;" viewBox="0 0 24 24"><path d="M12 2C8 2 5 5.2 5 9c0 5.2 7 13 7 13s7-7.8 7-13c0-3.8-3-7-7-7z" fill="#D64545"/><circle cx="12" cy="9" r="2.4" fill="#fff"/></svg>
          <div class="map-badge">🚕 Vehículo en camino · mapa simulado</div>
        </div>`;
    }

    let actions = '';
    if(['buscando','asignado','camino'].includes(trip.estado)){
      actions = `<div class="screen-pad" style="padding-top:0;"><button class="btn btn-danger btn-lg" onclick="Trips.openCancel('${trip.id}')">✕ Cancelar viaje</button></div>`;
    }
    if(trip.estado === 'finalizado' && !trip.rated){
      actions = `<div class="screen-pad" style="padding-top:0;"><button class="btn btn-primary" onclick="Trips.openRating('${trip.id}')">⭐ Calificar viaje</button></div>`;
    }

    content.innerHTML = `
      <div class="status-cols"><div class="status-main">
      <div class="ticket st-${trip.estado}">
        <div class="ticket-top">
          <div class="ticket-id">SOLICITUD ${trip.code}</div>
          <div class="ticket-status">${trip.estado!=='finalizado' && trip.estado!=='cancelado' ? '<span class="pulse-dot"></span>' : ''} ${emojiMap[trip.estado]||''} ${this.stateLabel(trip.estado)}</div>
        </div>
        ${trip.estado!=='cancelado' ? `<div class="status-track">${segs}</div>` : ''}
        <div class="perforation"></div>
        <div class="ticket-body">
          <div class="ticket-row"><span class="k">Pasajero</span><span class="v">${trip.nombrePasajero}</span></div>
          <div class="ticket-row"><span class="k">Origen</span><span class="v">${trip.origen}</span></div>
          <div class="ticket-row"><span class="k">Destino</span><span class="v">${trip.destino}</span></div>
          <div class="ticket-row"><span class="k">Pasajeros</span><span class="v">${trip.pax}</span></div>
          <div class="ticket-row"><span class="k">Hora del pedido</span><span class="v">${trip.hora}</span></div>
          <div class="ticket-row"><span class="k">Tarifa estimada</span><span class="v">$${trip.tarifa}</span></div>
          ${trip.pago ? `<div class="ticket-row"><span class="k">Pago</span><span class="v">${trip.pago === 'billetera' ? 'Billetera' : trip.pago === 'gratis' ? 'Gratis (puntos)' : 'Efectivo'}</span></div>` : ''}
        </div>
      </div>
      ${mapBlock}
      ${driverBlock}
      ${actions}
      </div><div class="status-side">
      <div class="section-title">Paso a paso de tu viaje</div>
      ${this.timelineHTML(trip.estado)}
      </div></div>
    `;
  },
  cancelReasons: {
    pasajero: ['Me equivoqué de dirección','Ya no necesito el remis','Tarda demasiado','Encontré otro transporte','Otro motivo'],
    conductor: ['El pasajero no responde','El pasajero no está en el lugar','Problema con el vehículo','Emergencia personal','Otro motivo']
  },
  openCancel(tripId, by){
    by = by || 'pasajero';
    Session._cancelTripId = tripId; Session._cancelBy = by;
    document.getElementById('cancelMotivo').innerHTML = this.cancelReasons[by].map(o => `<option value="${o}">${o}</option>`).join('');
    document.getElementById('cancelDesc').textContent = by === 'conductor'
      ? 'El viaje volverá a buscar otro conductor.' : 'Contanos el motivo de la cancelación.';
    UI.openModal('modalCancel');
  },
  confirmCancel(){
    const tripId = Session._cancelTripId, by = Session._cancelBy || 'pasajero';
    const trip = DB.trips.find(t => t.id === tripId);
    const motivo = document.getElementById('cancelMotivo').value;
    if(API.on){
      UI.closeModal('modalCancel');
      API.run(async () => {
        await API.rpc('cancelar_viaje', { vid: tripId, motivo_: motivo }); await API.refresh();
        if(by === 'conductor'){ UI.toast('Cancelaste el viaje. Se busca otro conductor.'); Drivers.renderPanel(); }
        else { UI.toast('Viaje cancelado.'); Router.go('passengerHome'); }
      }); return;
    }
    DB.cancellations.push({ id: uid('c'), tripId, by, userId: Session.currentUser ? Session.currentUser.id : null, motivo, fecha: new Date().toISOString() });
    UI.closeModal('modalCancel');
    if(by === 'conductor'){
      trip.rejectedBy = (trip.rejectedBy || []).concat(trip.driverId);
      trip.driverId = null; trip.estado = 'buscando';
      UI.toast('Cancelaste el viaje. Se busca otro conductor.');
      Drivers.renderPanel();
      return;
    }
    trip.estado = 'cancelado';
    if(trip.gratis){ trip.gratis = false; const pu = DB.users.find(x => x.id === trip.passengerId); if(pu) pu.viajesGratis = (pu.viajesGratis || 0) + 1; }
    UI.toast('Viaje cancelado.');
    Router.go('passengerHome');
  },
  openRating(tripId){
    Session._ratingTripId = tripId;
    const trip = DB.trips.find(t => t.id === tripId);
    const driver = DB.drivers.find(d => d.id === trip.driverId);
    const du = driver ? DB.users.find(u => u.id === driver.userId) : null;
    document.getElementById('ratingDriverName').textContent = du ? (du.nombre + ' ' + du.apellido) : 'tu conductor';
    document.querySelectorAll('#starRow button').forEach(b => b.classList.remove('on'));
    Session._ratingValue = 0;
    UI.openModal('modalRating');
  },
  submitRating(){
    const tripId = Session._ratingTripId;
    const trip = DB.trips.find(t => t.id === tripId);
    const stars = Session._ratingValue || 5;
    const comment = document.getElementById('ratingComment').value.trim();
    if(API.on){
      API.run(async () => {
        await API.rpc('calificar_viaje', { vid: tripId, estrellas_: stars, comentario_: comment }); await API.refresh();
        document.getElementById('ratingComment').value = ''; UI.closeModal('modalRating');
        UI.toast('¡Gracias por tu calificación!'); Router.go('history');
      }); return;
    }
    DB.ratings.push({ id: uid('r'), tripId, driverId: trip.driverId, estrellas: stars, comentario: comment });
    trip.rated = true;
    if(trip.driverId){
      const driver = DB.drivers.find(d => d.id === trip.driverId);
      const totalScore = driver.rating * driver.ratingCount + stars;
      driver.ratingCount += 1;
      driver.rating = totalScore / driver.ratingCount;
      Points.awardRating(driver, stars);
    }
    document.getElementById('ratingComment').value = '';
    UI.closeModal('modalRating');
    UI.toast('¡Gracias por tu calificación!');
    Router.go('history');
  }
};

Wizard.register('request', {
  container: 'reqWizard', progressId: 'reqStepProgress',
  prevId: 'reqPrevBtn', nextId: 'reqNextBtn', finalLabel: 'SOLICITAR REMIS',
  labels: ['Recorrido', 'Confirmar'],
  validators: {
    1: () => Trips.reqStep1Valid(),
    2: () => { Trips.submitRequest(); return true; }
  },
  onRender(step){ if(step === 2) Trips.renderReqSummary(); }
});

// star rating interaction
document.getElementById('starRow').addEventListener('click', (e) => {
  const btn = e.target.closest('button');
  if(!btn) return;
  const v = parseInt(btn.dataset.v, 10);
  Session._ratingValue = v;
  document.querySelectorAll('#starRow button').forEach(b => b.classList.toggle('on', parseInt(b.dataset.v,10) <= v));
});

/* ===== driver.js ===== */
/* ==================================================================
   BELLAVISTA REMIS — Panel del conductor
   ================================================================== */
const ACTIVE_STATES = ['asignado','camino','llego','curso'];
const Drivers = {
  me(){ return DB.drivers.find(d => d.id === Session.driverProfileId); },
  activeTrip(d){ return DB.trips.find(t => t.driverId === d.id && ACTIVE_STATES.includes(t.estado)); },
  mapsUrl(t){
    const q = t.origenCoords ? t.origenCoords.lat + ',' + t.origenCoords.lng : t.origen + ', Bella Vista, Tucumán';
    return 'https://www.google.com/maps/search/?api=1&query=' + encodeURIComponent(q);
  },
  route(t){
    return `<div class="route"><div class="route-row"><i class="rd"></i><span>${t.origen}${t.barrio ? ', ' + t.barrio : ''}</span></div><div class="route-row"><i class="rd rd-d"></i><span>${t.destino}</span></div></div>`;
  },
  toggleAvailability(){
    const driver = this.me();
    if(!driver) return;
    if(this.activeTrip(driver)){ UI.toast('No podés cambiar tu disponibilidad mientras tenés un viaje en curso.'); return; }
    if(API.on){ API.run(async () => { await API.rpc('set_disponible', { d: !driver.disponible }); await API.refresh(); this.renderPanel();
      UI.toast(!driver.disponible ? '🟢 Ahora estás disponible.' : 'Ya no estás disponible.'); }); return; }
    driver.disponible = !driver.disponible;
    this.renderPanel();
    UI.toast(driver.disponible ? '🟢 Ahora estás disponible.' : 'Ya no estás disponible.');
  },
  statusCard(driver, busy){
    if(busy) return `<div class="drv-status busy"><div class="drv-lead"><span class="drv-dot"></span><div><h2>OCUPADO</h2><p>Estás en un viaje. Terminalo para recibir nuevas solicitudes.</p></div></div></div>`;
    if(driver.disponible) return `<div class="drv-status on"><div class="drv-lead"><span class="drv-dot"></span><div><h2>DISPONIBLE</h2><p>Estás recibiendo solicitudes de viaje.</p></div></div><button class="btn btn-ghost-w" onclick="Drivers.toggleAvailability()">Dejar de estar disponible</button></div>`;
    return `<div class="drv-status off"><div class="drv-lead"><span class="drv-dot"></span><div><h2>NO DISPONIBLE</h2><p>No vas a recibir solicitudes hasta que te pongas disponible.</p></div></div><button class="btn btn-success btn-lg" onclick="Drivers.toggleAvailability()">🟢 Ponerme disponible</button></div>`;
  },
  renderPanel(){
    const driver = this.me();
    const du = DB.users.find(u => u.id === driver.userId);
    const vh = DB.vehicles.find(v => v.driverId === driver.id);
    document.getElementById('driverFirstName').textContent = du.nombre;
    document.getElementById('driverVehicleLine').textContent = `${vh.marca} ${vh.modelo} · ${vh.color} · ${vh.patente}`;

    const active = this.activeTrip(driver);
    document.getElementById('driverStatusCard').innerHTML = this.statusCard(driver, !!active);

    const done = DB.trips.filter(t => t.driverId === driver.id && t.fecha === todayStr() && t.estado === 'finalizado');
    const earned = done.reduce((s, t) => s + t.tarifa, 0);
    document.getElementById('driverStats').innerHTML = `
      <div class="stat-chip"><div class="n">${done.length}</div><div class="l">VIAJES HOY</div></div>
      <div class="stat-chip"><div class="n">$${earned.toLocaleString('es-AR')}</div><div class="l">GANADO HOY</div></div>
      <div class="stat-chip"><div class="n">⭐ ${driver.rating ? driver.rating.toFixed(1) : '—'}</div><div class="l">CALIFICACIÓN</div></div>`;

    document.getElementById('driverPoints').innerHTML = Points.driverCard(driver);
    document.getElementById('driverDocs').innerHTML = Docs.driverCard(driver);
    document.getElementById('driverRanking').innerHTML = Ranking.html(false, driver.id);

    const empty = msg => `<div class="empty-state" style="padding:26px 10px;"><p>${msg}</p></div>`;

    // viaje activo
    const activeEl = document.getElementById('driverActiveTrip');
    if(active){
      const canCancel = ['asignado','camino','llego'].includes(active.estado);
      activeEl.innerHTML = `
        <div class="card trip-card active">
          <div class="card-title-row"><h4>${active.destino}</h4>${Trips.stateBadge(active.estado)}</div>
          ${this.route(active)}
          <div class="mini-row"><span>Pasajero: <b>${active.nombrePasajero}</b> · Pasajeros: <b>${active.pax}</b></span></div>
          ${active.obs ? `<div class="mini-row"><span>Obs: ${active.obs}</span></div>` : ''}
          <div class="mini-row"><span>Tarifa estimada: <b>$${active.tarifa}</b>${active.gratis ? ' · <b>VIAJE GRATIS (puntos): no cobrar</b>' : ''}</span></div>
          <div class="next-step-box"><span class="txt">👉 Tu próximo paso</span>${this.nextActionButton(active)}</div>
          <div class="btn-row wrap stack-m">
            <a class="btn btn-outline btn-sm" href="tel:${active.telefono.replace(/[^0-9+]/g,'')}">📞 Llamar</a>
            <a class="btn btn-outline btn-sm" href="${this.mapsUrl(active)}" target="_blank" rel="noopener">🗺️ Cómo llegar</a>
            ${canCancel ? `<button class="btn btn-danger btn-sm" onclick="Trips.openCancel('${active.id}','conductor')">✕ Cancelar viaje</button>` : ''}
          </div>
        </div>
        ${Trips.timelineHTML(active.estado)}`;
    } else {
      activeEl.innerHTML = empty('No tenés ningún viaje activo en este momento.');
    }

    // nuevas solicitudes
    const reqEl = document.getElementById('driverRequests');
    if(active){
      reqEl.innerHTML = empty('Terminá tu viaje actual para ver nuevas solicitudes.');
    } else if(!driver.disponible){
      reqEl.innerHTML = empty('Ponete disponible para recibir solicitudes.');
    } else {
      const pending = DB.trips.filter(t => t.estado === 'buscando' && !t.scheduled && !(t.rejectedBy || []).includes(driver.id));
      reqEl.innerHTML = pending.length === 0 ? empty('No hay solicitudes nuevas por ahora.') : pending.map(t => `
        <div class="card trip-card new">
          <div class="card-title-row"><h4>NUEVO VIAJE</h4><span class="fare">$${t.tarifa}</span></div>
          ${this.route(t)}
          <div class="mini-row"><span>Pasajero: <b>${t.nombrePasajero}</b> · Pasajeros: <b>${t.pax}</b></span></div>
          ${t.obs ? `<div class="mini-row"><span>Obs: ${t.obs}</span></div>` : ''}
          <div class="btn-row stack-m">
            <button class="btn btn-success btn-lg" onclick="Drivers.accept('${t.id}')">✓ ACEPTAR</button>
            <button class="btn btn-danger btn-lg" onclick="Drivers.reject('${t.id}')">✕ RECHAZAR</button>
          </div>
        </div>`).join('');
    }

    // viajes de hoy
    const todayEl = document.getElementById('driverTodayTrips');
    const today = DB.trips.filter(t => t.driverId === driver.id && t.fecha === todayStr() && t.estado === 'finalizado');
    todayEl.innerHTML = today.length === 0 ? empty('Todavía no completaste viajes hoy.') : today.map(t => `
      <div class="card">
        <div class="card-title-row"><h4>${t.destino}</h4>${Trips.stateBadge(t.estado)}</div>
        <div class="mini-row"><span>${t.hora} · ${t.nombrePasajero} · <b>$${t.tarifa}</b></span></div>
      </div>`).join('');
  },
  nextActionButton(trip){
    const next = { asignado:['camino','🚕 Voy en camino'], camino:['llego','📍 Ya llegué'], llego:['curso','🚗 Iniciar viaje'], curso:['finalizado','✅ Finalizar viaje'] };
    const n = next[trip.estado];
    return n ? `<button class="btn btn-primary btn-sm" onclick="Drivers.advance('${trip.id}','${n[0]}')">${n[1]}</button>` : '';
  },
  accept(tripId){
    const driver = this.me();
    if(API.on){ API.run(async () => { try{ await API.rpc('aceptar_viaje', { vid: tripId }); UI.toast('Viaje aceptado.'); }catch(e){ UI.toast(e.message); } await API.refresh(); this.renderPanel(); }); return; }
    const trip = DB.trips.find(t => t.id === tripId);
    if(trip.estado !== 'buscando'){ UI.toast('Esta solicitud ya no está disponible.'); this.renderPanel(); return; }
    trip.driverId = driver.id;
    trip.estado = 'asignado';
    UI.toast('Viaje aceptado. ' + trip.code);
    this.renderPanel();
  },
  reject(tripId){
    if(API.on){ API.run(async () => { await API.rpc('rechazar_viaje', { vid: tripId }); await API.refresh(); UI.toast('Solicitud rechazada.'); this.renderPanel(); }); return; }
    const trip = DB.trips.find(t => t.id === tripId);
    trip.rejectedBy = (trip.rejectedBy || []).concat(this.me().id);
    UI.toast('Solicitud rechazada.');
    this.renderPanel();
  },
  advance(tripId, nextState){
    if(API.on){ API.run(async () => {
      const r = await API.rpc('avanzar_viaje', { vid: tripId, nuevo: nextState });
      await API.refresh();
      if(nextState === 'finalizado'){
        const t = DB.trips.find(x => x.id === tripId) || {};
        UI.toast(r.pago === 'Puntos' ? 'Viaje finalizado. Era un viaje gratis por puntos: no le cobres al pasajero.'
          : r.pago === 'Billetera' ? 'Viaje finalizado. Ya se cobró $' + (t.tarifa || '') + ' de la billetera del pasajero.'
          : 'Viaje finalizado. Cobrale $' + (t.tarifa || '') + ' en efectivo al pasajero.');
      }
      this.renderPanel();
    }); return; }
    const trip = DB.trips.find(t => t.id === tripId);
    trip.estado = nextState;
    if(nextState === 'finalizado'){
      const pago = Wallet.chargeTrip(trip);
      const base = pago === 'gratis' ? 'Viaje finalizado. Era un viaje gratis por puntos: no le cobres al pasajero.'
        : pago === 'billetera' ? 'Viaje finalizado. Ya se cobró $' + trip.tarifa + ' de la billetera del pasajero.'
        : 'Viaje finalizado. Cobrale $' + trip.tarifa + ' en efectivo al pasajero.';
      UI.toast(base + Points.awardTrip(trip));
    }
    this.renderPanel();
  }
};

/* ===== admin.js ===== */
/* ==================================================================
   BELLAVISTA REMIS
   ================================================================== */
/* ---------------- ADMIN MODULE ---------------- */
const Admin = {
  currentTab: 'trips',
  setTab(tab){
    this.currentTab = tab;
    document.querySelectorAll('#adminTabs .tab-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === tab));
    document.getElementById('adminSearchBar').style.display = (tab === 'tariffs' || tab === 'ranking') ? 'none' : 'flex';
    document.getElementById('adminSearchInput').value = '';
    this.render();
  },
  render(){
    // stats
    const todayTrips = DB.trips.filter(t => t.fecha === todayStr() && !t.scheduled);
    document.getElementById('admTripsToday').textContent = todayTrips.length;
    document.getElementById('admDriversAvail').textContent = DB.drivers.filter(d => d.disponible).length;
    document.getElementById('admTripsOngoing').textContent = DB.trips.filter(t => ['asignado','camino','llego','curso'].includes(t.estado)).length;
    document.getElementById('admPassengers').textContent = DB.users.filter(u => u.rol==='pasajero').length;
    const revenue = DB.trips.filter(t => t.estado==='finalizado' && !t.gratis).reduce((s,t)=>s+t.tarifa,0);
    document.getElementById('admRevenue').textContent = '$' + revenue.toLocaleString('es-AR');
    document.getElementById('admCancelled').textContent = DB.trips.filter(t => t.estado==='cancelado').length;

    const q = (document.getElementById('adminSearchInput').value || '').toLowerCase();
    const el = document.getElementById('adminTabContent');

    if(this.currentTab === 'ranking'){ el.innerHTML = Ranking.html(true, null); return; }

    if(this.currentTab === 'trips'){
      let trips = DB.trips.slice().sort((a,b)=> (b.fecha+b.hora).localeCompare(a.fecha+a.hora));
      if(q) trips = trips.filter(t => (t.nombrePasajero+t.destino+t.origen+t.code).toLowerCase().includes(q));
      el.innerHTML = `<div class="table-wrap"><table class="data-table">
        <thead><tr><th>ID</th><th>Fecha</th><th>Pasajero</th><th>Conductor</th><th>Origen</th><th>Destino</th><th>Estado</th><th>Tarifa</th></tr></thead>
        <tbody>${trips.map(t => {
          const drv = DB.drivers.find(d => d.id === t.driverId);
          const du = drv ? DB.users.find(u => u.id === drv.userId) : null;
          return `<tr><td>${t.code}</td><td>${t.fecha}<br>${t.hora}</td><td>${t.nombrePasajero}</td><td>${du ? du.nombre+' '+du.apellido : '—'}</td><td>${t.origen}</td><td>${t.destino}</td><td>${Trips.stateBadge(t.estado)}</td><td>$${t.tarifa}</td></tr>`;
        }).join('') || '<tr><td colspan="8" style="text-align:center; padding:20px; color:#8A9099;">Sin resultados.</td></tr>'}</tbody>
      </table></div>`;
    }

    if(this.currentTab === 'drivers'){
      let drivers = DB.drivers.slice();
      if(q) drivers = drivers.filter(d => { const u = DB.users.find(u2=>u2.id===d.userId); return (u.nombre+u.apellido+u.telefono).toLowerCase().includes(q); });
      el.innerHTML = drivers.map(d => {
        const u = DB.users.find(u2 => u2.id === d.userId);
        const vh = DB.vehicles.find(v => v.driverId === d.id);
        const estadoBadge = { pendiente:'badge-yellow', aprobado:'badge-green', rechazado:'badge-red', suspendido:'badge-gray' }[d.estado];
        const tripsCount = DB.trips.filter(t => t.driverId === d.id && t.estado==='finalizado').length;
        return `<div class="card">
          <div class="card-title-row"><h4>${u.nombre} ${u.apellido}</h4><span class="badge ${estadoBadge}">${d.estado}</span></div>
          <div class="mini-row"><span>${u.telefono} · ${vh.marca} ${vh.modelo} · ${vh.patente}</span></div>
          <div class="mini-row"><span>Viajes: <b>${tripsCount}</b> · Calificación: <b>${d.rating ? d.rating.toFixed(1):'—'}</b> · Disponible: <b>${d.disponible?'Sí':'No'}</b></span></div>
          <div class="btn-row" style="margin-top:10px;">
            ${d.estado==='pendiente' ? `<button class="btn btn-success btn-sm" onclick="Admin.approveDriver('${d.id}')">Aprobar</button><button class="btn btn-danger btn-sm" onclick="Admin.rejectDriver('${d.id}')">Rechazar</button>` : ''}
            ${d.estado==='aprobado' ? `<button class="btn btn-outline btn-sm" onclick="Admin.suspendDriver('${d.id}')">Suspender</button>` : ''}
            ${d.estado==='suspendido' ? `<button class="btn btn-success btn-sm" onclick="Admin.approveDriver('${d.id}')">Reactivar</button>` : ''}
          </div>
        </div>`;
      }).join('') || '<div class="empty-state"><p>Sin resultados.</p></div>';
    }

    if(this.currentTab === 'passengers'){
      let passengers = DB.users.filter(u => u.rol === 'pasajero');
      if(q) passengers = passengers.filter(u => (u.nombre+u.apellido+u.telefono).toLowerCase().includes(q));
      el.innerHTML = passengers.map(u => {
        const tripsCount = DB.trips.filter(t => t.passengerId === u.id).length;
        return `<div class="card">
          <div class="card-title-row"><h4>${u.nombre} ${u.apellido}</h4><span class="badge ${u.estado==='activo'?'badge-green':'badge-red'}">${u.estado}</span></div>
          <div class="mini-row"><span>${u.telefono} · ${u.email}</span></div>
          <div class="mini-row"><span>Viajes realizados: <b>${tripsCount}</b></span></div>
          <button class="btn btn-outline btn-sm" style="margin-top:10px;" onclick="Admin.toggleBlockPassenger('${u.id}')">${u.estado==='activo' ? 'Bloquear' : 'Desbloquear'}</button>
        </div>`;
      }).join('') || '<div class="empty-state"><p>Sin resultados.</p></div>';
    }

    if(this.currentTab === 'vehicles'){
      let vehicles = DB.vehicles.slice();
      if(q) vehicles = vehicles.filter(v => (v.marca+v.modelo+v.patente).toLowerCase().includes(q));
      el.innerHTML = `<div class="table-wrap"><table class="data-table">
        <thead><tr><th>Marca</th><th>Modelo</th><th>Color</th><th>Patente</th><th>Conductor</th></tr></thead>
        <tbody>${vehicles.map(v => {
          const d = DB.drivers.find(d2 => d2.id === v.driverId);
          const u = d ? DB.users.find(u2 => u2.id === d.userId) : null;
          return `<tr><td>${v.marca}</td><td>${v.modelo}</td><td>${v.color}</td><td>${v.patente}</td><td>${u ? u.nombre+' '+u.apellido : '—'}</td></tr>`;
        }).join('') || '<tr><td colspan="5" style="text-align:center; padding:20px; color:#8A9099;">Sin resultados.</td></tr>'}</tbody>
      </table></div>`;
    }

    if(this.currentTab === 'tariffs'){
      const t = DB.tariffs;
      el.innerHTML = `
        <div class="tariff-grid">
          <div class="field"><label>Precio cada 100 metros ($) · se usa con el mapa</label><input type="number" id="tarCien" value="${t.por100m}"></div>
          <p class="sub" style="font-size:12px;">Con el mapa activo, la tarifa es: cuadras (de 100 m, redondeando hacia arriba) × este precio, con la mínima como piso. Lo de abajo (base, por km, recargos) solo se usa si no hay mapa.</p>
          <div class="field"><label>Tarifa base ($)</label><input type="number" id="tarBase" value="${t.base}"></div>
          <div class="field"><label>Tarifa por kilómetro ($)</label><input type="number" id="tarKm" value="${t.porKm}"></div>
          <div class="field"><label>Tarifa mínima ($)</label><input type="number" id="tarMin" value="${t.minima}"></div>
          <div class="field"><label>Recargo nocturno (%)</label><input type="number" id="tarNoc" value="${t.nocturno}"></div>
          <div class="field"><label>Recargo zona rural (%)</label><input type="number" id="tarRural" value="${t.rural}"></div>
          <button class="btn btn-primary" onclick="Admin.saveTariffs()">Guardar cambios</button>
        </div>`;
    }
  },
  approveDriver(id){ DB.drivers.find(d=>d.id===id).estado='aprobado'; UI.toast('Conductor aprobado.'); this.render(); },
  rejectDriver(id){ DB.drivers.find(d=>d.id===id).estado='rechazado'; UI.toast('Conductor rechazado.'); this.render(); },
  suspendDriver(id){ const d=DB.drivers.find(d=>d.id===id); d.estado='suspendido'; d.disponible=false; UI.toast('Conductor suspendido.'); this.render(); },
  toggleBlockPassenger(id){
    const u = DB.users.find(u2 => u2.id === id);
    u.estado = u.estado === 'activo' ? 'bloqueado' : 'activo';
    UI.toast(u.estado === 'activo' ? 'Pasajero desbloqueado.' : 'Pasajero bloqueado.');
    this.render();
  },
  saveTariffs(){
    DB.tariffs = {
      por100m: Number(document.getElementById('tarCien').value) || DB.tariffs.por100m,
      base: Number(document.getElementById('tarBase').value) || DB.tariffs.base,
      porKm: Number(document.getElementById('tarKm').value) || DB.tariffs.porKm,
      minima: Number(document.getElementById('tarMin').value) || DB.tariffs.minima,
      nocturno: Number(document.getElementById('tarNoc').value) || 0,
      rural: Number(document.getElementById('tarRural').value) || 0
    };
    UI.toast('Tarifas actualizadas.');
  }
};

/* ---------------- INIT ---------------- */
Home.renderStats();

/* ===== maps.js ===== */
/* ==================================================================
   BELLAVISTA REMIS — Google Maps: ubicación precisa, ruta y tarifa
   Tarifa = cada 100 metros (redondeando hacia arriba) x precio por 100 m
   (se edita en el panel admin > Tarifas; por defecto $300).
   ================================================================== */
const Maps = {
  map: null, origin: null, originText: '', dest: null, destName: '',
  distance: null, duration: null, fare: null, approx: false, routeReady: false,
  results: [], overlays: [],

  enabled(){ return !!CONFIG.GOOGLE_MAPS_KEY && !this.failed; },

  fareFor(meters){ const t = DB.tariffs; return Math.max(Math.ceil(meters / 100) * t.por100m, t.minima); },
  km(m){ return (m / 1000).toLocaleString('es-AR', { maximumFractionDigits: 1 }) + ' km'; },

  /* ---------- carga de Google Maps ---------- */
  load(){
    if(this._p) return this._p;
    this._p = new Promise((res, rej) => {
      window.__mapsReady = res;
      window.gm_authFailure = () => {
        this.failed = true; this.paint();
        UI.toast('Google Maps rechazó la clave: revisá que sea correcta y que la facturación esté activa.');
      };
      const s = document.createElement('script');
      s.src = 'https://maps.googleapis.com/maps/api/js?key=' + encodeURIComponent(CONFIG.GOOGLE_MAPS_KEY) +
              '&loading=async&v=weekly&language=es&region=AR&callback=__mapsReady';
      s.async = true;
      s.onerror = () => { this.failed = true; this.paint(); rej(new Error('No cargó Google Maps')); };
      document.head.appendChild(s);
    });
    return this._p;
  },

  /* ---------- ubicación GPS precisa ---------- */
  locate(){
    return new Promise((res, rej) => {
      if(!navigator.geolocation) return rej(new Error('Este dispositivo no tiene GPS.'));
      let best = null, done = false, id, tm;
      const stop = () => { done = true; clearTimeout(tm); navigator.geolocation.clearWatch(id); };
      const finish = () => { if(done) return; stop(); best ? res(best) : rej(new Error('No pude obtener tu ubicación.')); };
      id = navigator.geolocation.watchPosition(p => {
        if(!best || p.coords.accuracy < best.acc) best = { lat: p.coords.latitude, lng: p.coords.longitude, acc: Math.round(p.coords.accuracy) };
        if(best.acc <= 25) finish();           // ya es lo bastante precisa
      }, e => {
        if(e.code === 1 && !done){ stop(); rej(new Error('Permiso de ubicación denegado. Activalo en el navegador.')); }
      }, { enableHighAccuracy: true, maximumAge: 0, timeout: 20000 });
      tm = setTimeout(finish, 12000);          // si no mejora, usa la mejor lectura
    });
  },

  async useMyLocation(auto){
    const btn = document.getElementById('reqLocBtn');
    if(btn) btn.textContent = '📍 Buscando tu ubicación…';
    try{
      const p = await this.locate();
      this.origin = { lat: p.lat, lng: p.lng };
      let text = 'Mi ubicación (GPS ±' + p.acc + ' m)';
      if(this.enabled()){
        try{
          await this.load();
          const { Geocoder } = await google.maps.importLibrary('geocoding');
          const r = await new Geocoder().geocode({ location: this.origin });
          if(r.results && r.results[0]) text = r.results[0].formatted_address;
        }catch(e){ /* se queda con el texto del GPS */ }
      }
      this.originText = text;
      const inp = document.getElementById('reqOrigen');
      if(inp && (!auto || !inp.value.trim())) inp.value = text;
      if(!auto) UI.toast('📍 Ubicación actualizada (precisión ±' + p.acc + ' m).');
      if(this.dest) await this.computeRoute(); else await this.showOrigin();
    }catch(e){
      if(!auto) UI.toast(e.message);
    }finally{
      if(btn) btn.textContent = '📍 Usar mi ubicación actual';
    }
  },

  /* Se llama al abrir la app */
  init(){ if(Session.currentUser && Session.currentUser.rol === 'comercio') return; this.useMyLocation(true); },

  /* Se llama cada vez que se abre la pantalla "Pedir un remis" */
  async onShowRequest(){
    this.paint();
    const inp = document.getElementById('reqOrigen');
    if(inp && !inp.value.trim() && this.originText) inp.value = this.originText;
    if(!this.origin) this.useMyLocation(true);
    if(!this.enabled()) return;
    try{
      await this.ensureMap();
      google.maps.event.trigger(this.map, 'resize');
      this.dest ? await this.computeRoute() : await this.showOrigin();
    }catch(e){ /* sin mapa */ }
  },

  /* Muestra u oculta el mapa según haya clave */
  paint(){
    const on = this.enabled();
    const wrap = document.getElementById('reqMapWrap'), hint = document.getElementById('reqMapHint');
    if(wrap) wrap.style.display = on ? 'block' : 'none';
    if(hint) hint.style.display = on ? 'none' : 'block';
    const q = document.getElementById('reqQuick');
    if(q) q.innerHTML = on ? CONFIG.QUICK_DESTINATIONS.map((n, i) => `<button type="button" onclick="Maps.quick(${i})">⭐ ${n}</button>`).join('') : '';
    const b = document.getElementById('reqSearchBtn'); if(b) b.style.display = on ? '' : 'none';
  },

  async ensureMap(){
    await this.load();
    const el = document.getElementById('reqMap');
    if(!this.map || this.map.getDiv() !== el){
      const { Map } = await google.maps.importLibrary('maps');
      this.map = new Map(el, { center: this.origin || CONFIG.CENTER, zoom: 15, mapId: 'DEMO_MAP_ID',
        disableDefaultUI: true, zoomControl: true, gestureHandling: 'greedy' });
    }
    return this.map;
  },

  clearOverlays(){ this.overlays.forEach(o => { try{ o.setMap ? o.setMap(null) : (o.map = null); }catch(e){} }); this.overlays = []; },

  async pin(pos, color){
    try{
      const { AdvancedMarkerElement, PinElement } = await google.maps.importLibrary('marker');
      this.overlays.push(new AdvancedMarkerElement({ map: this.map, position: pos, content: new PinElement({ background: color, borderColor: '#22252A', glyphColor: '#fff' }).element }));
    }catch(e){ /* sin marcador */ }
  },

  async showOrigin(){
    if(!this.origin) return;
    await this.ensureMap();
    this.clearOverlays();
    this.map.setCenter(this.origin); this.map.setZoom(16);
    await this.pin(this.origin, '#F5B700');
  },

  /* ---------- destino ---------- */
  invalidate(){
    this.dest = null; this.routeReady = false; this.fare = null; this.results = [];
    const r = document.getElementById('reqResults'), i = document.getElementById('reqRouteInfo');
    if(r) r.innerHTML = ''; if(i) i.innerHTML = '';
  },

  quick(i){ document.getElementById('reqDestino').value = CONFIG.QUICK_DESTINATIONS[i]; this.search(true); },

  async search(pickFirst){
    const q = document.getElementById('reqDestino').value.trim();
    if(q.length < 3){ UI.toast('Escribí el destino y tocá Buscar.'); return; }
    if(!this.enabled()){ UI.toast('Falta la clave de Google Maps (js/config.js).'); return; }
    const box = document.getElementById('reqResults');
    box.innerHTML = '<p class="shop-wait">Buscando…</p>';
    try{
      await this.load();
      const { Place } = await google.maps.importLibrary('places');
      const { places } = await Place.searchByText({
        textQuery: q, fields: ['displayName', 'formattedAddress', 'location'], language: 'es', region: 'ar',
        maxResultCount: 5, locationBias: { center: CONFIG.CENTER, radius: CONFIG.SEARCH_RADIUS_M }
      });
      this.results = (places || []).map(p => ({ name: p.displayName, addr: p.formattedAddress, loc: { lat: p.location.lat(), lng: p.location.lng() } }));
      if(!this.results.length){ box.innerHTML = '<p class="shop-wait">No encontré ese lugar. Probá con otro nombre o dirección.</p>'; return; }
      if(pickFirst === true || this.results.length === 1){ this.choose(0); return; }
      box.innerHTML = this.results.map((r, i) => `<button type="button" class="result-btn" onclick="Maps.choose(${i})"><b>${r.name}</b><span>${r.addr}</span></button>`).join('');
    }catch(e){
      box.innerHTML = '<p class="shop-wait">No se pudo buscar el lugar. Revisá que "Places API (New)" esté habilitada en tu clave.</p>';
    }
  },

  choose(i){
    const r = this.results[i];
    this.dest = r.loc; this.destName = r.name;
    document.getElementById('reqDestino').value = r.name + ', ' + r.addr.split(',').slice(0, 2).join(',');
    document.getElementById('reqResults').innerHTML = '';
    this.computeRoute();
  },

  /* El usuario cambió a mano la dirección de salida */
  async originChanged(){
    const t = document.getElementById('reqOrigen').value.trim();
    if(!this.enabled() || t.length < 3 || t === this.originText) return;
    try{
      await this.load();
      const { Geocoder } = await google.maps.importLibrary('geocoding');
      const r = await new Geocoder().geocode({ address: t + ', Tucumán, Argentina', region: 'ar' });
      if(!r.results || !r.results[0]){ UI.toast('No encontré esa dirección de salida.'); return; }
      const l = r.results[0].geometry.location;
      this.origin = { lat: l.lat(), lng: l.lng() }; this.originText = t;
      if(this.dest) this.computeRoute(); else this.showOrigin();
    }catch(e){ UI.toast('No pude ubicar esa dirección.'); }
  },

  haversine(a, b){
    const R = 6371000, rad = d => d * Math.PI / 180;
    const x = Math.sin(rad(b.lat - a.lat) / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(rad(b.lng - a.lng) / 2) ** 2;
    return 2 * R * Math.asin(Math.sqrt(x));
  },

  /* ---------- ruta + tarifa ---------- */
  async computeRoute(){
    if(!this.origin || !this.dest) return;
    this.routeReady = false;
    const info = document.getElementById('reqRouteInfo');
    info.innerHTML = '<p class="shop-wait">Calculando recorrido…</p>';
    try{
      await this.ensureMap();
      this.clearOverlays();
      let meters, millis = null, approx = false;
      try{
        const { Route } = await google.maps.importLibrary('routes');
        const { routes } = await Route.computeRoutes({ origin: this.origin, destination: this.dest, travelMode: 'DRIVING',
          fields: ['path', 'distanceMeters', 'durationMillis'] });
        const r = routes[0];
        meters = r.distanceMeters; millis = r.durationMillis;
        (await r.createPolylines()).forEach(p => { p.setMap(this.map); this.overlays.push(p); });
      }catch(e){
        // Si falla el servicio de rutas: línea recta x 1,3 (aproximado)
        approx = true; meters = this.haversine(this.origin, this.dest) * 1.3;
        const line = new google.maps.Polyline({ path: [this.origin, this.dest], map: this.map, strokeColor: '#22252A', strokeWeight: 4 });
        this.overlays.push(line);
      }
      await this.pin(this.origin, '#F5B700'); await this.pin(this.dest, '#D64545');
      const b = new google.maps.LatLngBounds(); b.extend(this.origin); b.extend(this.dest);
      this.map.fitBounds(b, 40);

      this.distance = Math.round(meters); this.duration = millis; this.approx = approx;
      this.fare = this.fareFor(meters); this.routeReady = true;
      const cuadras = Math.ceil(meters / 100);
      info.innerHTML = `<div class="route-box"><div><b>${approx ? '≈ ' : ''}${this.km(meters)}</b> · ${cuadras} cuadras${millis ? ' · ⏱ ' + Math.max(1, Math.round(millis / 60000)) + ' min' : ''}</div>
        <div class="route-fare">${money(this.fare)}</div><small>${cuadras} × ${money(DB.tariffs.por100m)} cada 100 m${approx ? ' · distancia aproximada' : ''}</small></div>`;
    }catch(e){
      info.innerHTML = '<p class="shop-wait">No pude calcular el recorrido. Probá de nuevo.</p>';
    }
  },

  reset(){ this.invalidate(); this.destName = ''; this.clearOverlays(); }
};

/* ===== docs.js ===== */
/* ==================================================================
   BELLAVISTA REMIS — Documentación del chofer (foto del auto, patente,
   seguro, VTV, licencia...). Los revisa el super administrador.
   La lista espeja la tabla tipo_documento de la base de datos.
   ================================================================== */
const Docs = {
  types: [
    { codigo:'foto_auto',    nombre:'Foto del auto',                    hint:'Una foto clara del auto, de frente y de costado.' },
    { codigo:'foto_patente', nombre:'Foto de la patente',               hint:'Que se lea bien.' },
    { codigo:'licencia',     nombre:'Licencia de conducir profesional', vence:true },
    { codigo:'seguro',       nombre:'Seguro del vehículo (al día)',     vence:true, numero:'N° de póliza', entidad:'Aseguradora' },
    { codigo:'vtv',          nombre:'Verificación técnica (VTV)',       vence:true },
    { codigo:'cedula',       nombre:'Cédula del vehículo' },
    { codigo:'habilitacion', nombre:'Habilitación municipal de remis',  vence:true, numero:'N° de habilitación' }
  ],
  files: {},

  render(){
    this.files = {};
    const box = document.getElementById('drDocs');
    if(!box) return;
    box.innerHTML = this.types.map(t => `
      <div class="doc-card" id="doc-${t.codigo}">
        <h4>${t.nombre}</h4>${t.hint ? `<p class="sub">${t.hint}</p>` : ''}
        ${t.numero ? `<div class="field"><label>${t.numero}</label><input type="text" id="docNum-${t.codigo}"></div>` : ''}
        ${t.entidad ? `<div class="field"><label>${t.entidad}</label><input type="text" id="docEnt-${t.codigo}"></div>` : ''}
        ${t.vence ? `<div class="field"><label>Vence el</label><input type="date" id="docVence-${t.codigo}"></div>` : ''}
        <label class="doc-pick" for="docFile-${t.codigo}"><span id="docPrev-${t.codigo}">📷 Sacar o elegir foto</span></label>
        <input type="file" id="docFile-${t.codigo}" accept="image/*" style="display:none" onchange="Docs.pick('${t.codigo}', this)">
      </div>`).join('');
    document.getElementById('drDocsErr').textContent = '';
  },

  pick(codigo, input){
    const f = input.files && input.files[0];
    if(!f) return;
    UI.resizeImage(f, data => {
      this.files[codigo] = data;
      document.getElementById('docPrev-' + codigo).innerHTML = `<img src="${data}" alt="${codigo}">`;
    }, 900);
  },

  /* Devuelve '' si está todo bien, o el mensaje del primer problema */
  validate(){
    const hoy = new Date().toISOString().slice(0, 10);
    for(const t of this.types){
      if(!this.files[t.codigo]) return 'Falta la foto: ' + t.nombre + '.';
      if(t.numero && document.getElementById('docNum-' + t.codigo).value.trim().length < 2) return 'Falta el dato "' + t.numero + '".';
      if(t.entidad && document.getElementById('docEnt-' + t.codigo).value.trim().length < 2) return 'Falta el dato "' + t.entidad + '".';
      if(t.vence){
        const v = document.getElementById('docVence-' + t.codigo).value;
        if(!v) return 'Falta la fecha de vencimiento: ' + t.nombre + '.';
        if(v < hoy) return t.nombre + ' está vencido. Renovalo para poder registrarte.';
      }
    }
    return '';
  },

  collect(){
    const out = {};
    this.types.forEach(t => {
      const val = id => { const e = document.getElementById(id); return e ? e.value.trim() : null; };
      out[t.codigo] = { numero: val('docNum-' + t.codigo), entidad: val('docEnt-' + t.codigo), vence_el: val('docVence-' + t.codigo) || null,
                        archivo: this.files[t.codigo], estado: 'pendiente', observacion: null };
    });
    return out;
  },

  /* Estado de un documento ya cargado */
  info(d){
    const dias = d.vence_el ? Math.ceil((new Date(d.vence_el) - new Date(new Date().toISOString().slice(0, 10))) / 864e5) : null;
    if(dias !== null && dias < 0) return { txt: 'VENCIDO', cls: 'bad', dias };
    if(d.estado === 'rechazado') return { txt: 'RECHAZADO', cls: 'bad', dias };
    if(d.estado === 'pendiente') return { txt: 'EN REVISIÓN', cls: 'wait', dias };
    return dias !== null && dias <= 30 ? { txt: 'VENCE EN ' + dias + ' DÍAS', cls: 'wait', dias } : { txt: 'APROBADO', cls: 'ok', dias };
  },

  /* Tarjeta del panel del chofer */
  driverCard(driver){
    if(!driver.docs) return '';
    return `<div class="points-card" style="margin:14px 18px 0;"><div class="points-top"><h3>📄 Mi documentación</h3></div>
      ${this.types.map(t => { const d = driver.docs[t.codigo]; if(!d) return ''; const i = this.info(d);
        return `<div class="doc-row"><span>${t.nombre}${d.vence_el ? ' · vence ' + d.vence_el : ''}</span><b class="doc-st ${i.cls}">${i.txt}</b></div>
          ${d.observacion ? `<p class="sub" style="color:var(--red)">Motivo: ${d.observacion}</p>` : ''}`; }).join('')}
      <p>Si algún documento vence, no vas a poder recibir viajes hasta renovarlo.</p></div>`;
  }
};

/* ===== api.js ===== */
/* ==================================================================
   BELLAVISTA REMIS — Conexión con la base de datos (Supabase)
   Trae los datos del usuario y los deja en la misma forma que usa la app.
   Todo lo que escribe pasa por funciones del servidor (ver database/schema.sql).
   ================================================================== */
const API = {
  on: false, sb: null, timer: null, busy: false, _sig: '',

  init(){
    this.on = !!(CONFIG.USAR_BASE_DE_DATOS && CONFIG.SUPABASE_URL && CONFIG.SUPABASE_ANON_KEY && window.supabase);
    if(CONFIG.USAR_BASE_DE_DATOS && !this.on) setTimeout(() => UI.toast('No se pudo conectar con la base de datos. Revisá tu conexión.'), 600);
    if(!this.on) return;
    this.sb = window.supabase.createClient(CONFIG.SUPABASE_URL, CONFIG.SUPABASE_ANON_KEY);
    this.restore();
  },

  async rpc(name, args){
    const { data, error } = await this.sb.rpc(name, args || {});
    if(error) throw new Error(this.traducir(error.message));
    return data;
  },
  traducir(m){
    if(/usuario_email_key|already registered/i.test(m)) return 'Ese email ya está registrado.';
    if(/conductor_licencia_key/.test(m)) return 'Ese número de licencia ya está registrado.';
    if(/vehiculo_patente_key/.test(m)) return 'Esa patente ya está registrada.';
    if(/Failed to fetch|NetworkError|Load failed/i.test(m)) return 'Sin conexión. Probá de nuevo.';
    return m;
  },
  async run(fn){ try{ return await fn(); } catch(e){ UI.toast(e.message || 'Ocurrió un error.'); } },

  /* ---------- fechas en hora local ---------- */
  ymd(iso){ const d = new Date(iso), p = n => String(n).padStart(2, '0'); return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()); },
  hm(iso){ const d = new Date(iso), p = n => String(n).padStart(2, '0'); return p(d.getHours()) + ':' + p(d.getMinutes()); },

  /* ---------- trae todo y lo deja en DB / Session ---------- */
  async refresh(){
    const p = await this.rpc('mi_perfil');
    if(!p) return null;
    const rol = (p.rol === 'admin' || p.rol === 'superadmin') ? 'admin' : p.rol;
    const me = { id: p.id, rol, nombre: p.nombre, apellido: p.apellido || '', telefono: p.telefono, email: p.email, foto: p.foto,
                 estado: p.estado, saldo: +p.saldo || 0, puntos: p.puntos || 0, viajesGratis: p.viajes_gratis || 0, direccion: p.direccion };
    const users = [me], drivers = [], vehicles = [];
    const addVeh = (cid, v) => { if(v && !vehicles.some(x => x.driverId === cid)) vehicles.push(Object.assign({ id: 'v' + cid, driverId: cid }, v)); };
    if(p.conductor){
      const c = p.conductor;
      drivers.push({ id: c.id, userId: p.id, licencia: c.licencia, estado: c.estado, disponible: !!c.disponible, rating: +c.rating || 0,
                     ratingCount: 0, puntos: c.puntos || 0, bonos: c.bonos || 0, docs: null });
      addVeh(c.id, c.vehiculo);
    }
    const [viajes, movs, tar, docs] = await Promise.all([
      this.rpc('mis_viajes'), rol === 'pasajero' ? this.rpc('mis_movimientos') : [],
      this.rpc('tarifa_vigente'), p.conductor ? this.rpc('mis_documentos') : []]);

    const trips = (viajes || []).slice().reverse().map(t => {
      const s = t.solicitante, c = t.conductor;
      if(!users.some(u => u.id === s.id)) users.push({ id: s.id, nombre: s.nombre, apellido: s.apellido, telefono: s.telefono, rol: s.rol });
      if(c){
        if(!users.some(u => u.id === c.usuario_id)) users.push({ id: c.usuario_id, nombre: c.nombre, apellido: c.apellido, foto: c.foto, rol: 'conductor' });
        if(!drivers.some(d => d.id === c.id)) drivers.push({ id: c.id, userId: c.usuario_id, estado: 'aprobado', rating: +c.rating || 0, ratingCount: 1 });
        addVeh(c.id, c.vehiculo);
      }
      const prog = !!t.programado_para, cuando = prog ? t.programado_para : t.creado_en;
      const pago = t.estado === 'finalizado' ? ({ Billetera: 'billetera', Efectivo: 'efectivo', Puntos: 'gratis' }[t.medio_pago] || null) : null;
      const nom = s.nombre + (s.apellido ? ' ' + s.apellido : '');
      return {
        id: t.id, code: t.codigo, passengerId: s.id, driverId: c ? c.id : null,
        nombrePasajero: t.cliente_nombre ? t.cliente_nombre + ' (' + nom + ')' : nom, telefono: t.cliente_telefono || s.telefono,
        origen: t.origen_direccion, barrio: '', destino: t.destino_direccion,
        origenCoords: t.origen_lat != null ? { lat: +t.origen_lat, lng: +t.origen_lng } : undefined,
        destCoords: t.destino_lat != null ? { lat: +t.destino_lat, lng: +t.destino_lng } : undefined,
        distanciaM: t.distancia_m, pax: t.cantidad_pasajeros, obs: t.observaciones || '', estado: t.estado, tarifa: +t.tarifa,
        fecha: this.ymd(cuando), hora: this.hm(cuando), scheduled: prog, rated: !!t.calificado || s.rol === 'comercio',
        gratis: t.medio_pago === 'Puntos', pago
      };
    });

    if(p.conductor && docs){
      drivers[0].docs = {};
      docs.filter(d => d.cargado).forEach(d => { drivers[0].docs[d.tipo] = { numero: d.numero, entidad: d.entidad, vence_el: d.vence_el, estado: d.estado, observacion: d.observacion }; });
    }
    DB.users = users; DB.drivers = drivers; DB.vehicles = vehicles; DB.trips = trips;
    DB.movements = (movs || []).slice().reverse().map(m => ({ id: m.id, userId: me.id, tipo: m.tipo, monto: +m.monto, detalle: m.detalle,
                     metodo: m.medio, fecha: this.ymd(m.creado_en), hora: this.hm(m.creado_en) }));
    if(tar){ DB.tariffs.por100m = +tar.precio_100m; DB.tariffs.minima = +tar.minima; }
    Session.currentUser = me;
    if(p.conductor) Session.driverProfileId = p.conductor.id;
    if(p.conductor && p.conductor.estado === 'aprobado'){
      try{ Ranking._r = await this.rpc('ranking', { periodo: Ranking.period }); }catch(e){ /* el ranking es opcional */ }
    }
    return me;
  },

  /* ---------- sesión ---------- */
  async restore(){
    const { data } = await this.sb.auth.getSession();
    if(!data.session) return;
    const me = await this.run(() => this.refresh());
    if(me) this.enter(me);
  },
  /* Lleva a cada persona a su pantalla. Devuelve false si no puede entrar. */
  enter(me){
    const salir = async msg => { await this.sb.auth.signOut(); this.clear(); UI.toast(msg); Router.go('home'); return false; };
    if(me.estado === 'bloqueado') return salir('Tu cuenta está bloqueada. Contactá a la administración.');
    if(me.rol === 'admin') return salir('El acceso de administración es en el sitio aparte del administrador.');
    if(me.rol === 'conductor'){
      const d = DB.drivers.find(x => x.userId === me.id);
      if(d.estado === 'pendiente') return salir('Tu cuenta está pendiente: el administrador está revisando tu documentación.');
      if(d.estado === 'rechazado') return salir('Tu cuenta de conductor no fue aprobada.');
      Router.go('driverPanel');
    } else Router.go(me.rol === 'comercio' ? 'shop' : 'passengerHome');
    this.startPolling();
    return true;
  },
  clear(){ this.stop(); DB.users = []; DB.drivers = []; DB.vehicles = []; DB.trips = []; DB.movements = []; Session.currentUser = null; Session.driverProfileId = null; Session.activeTripId = null; },
  logout(){ this.stop(); if(this.sb) this.sb.auth.signOut(); },

  async login(email, pass, quien){
    const { error } = await this.sb.auth.signInWithPassword({ email, password: pass });
    if(error) return { err: 'creds' };
    const me = await this.refresh();
    if(!me){ await this.sb.auth.signOut(); return { err: 'Tu cuenta quedó incompleta. Volvé a registrarte con el mismo email.' }; }
    const ok = quien === 'conductor' ? me.rol === 'conductor' : (me.rol === 'pasajero' || me.rol === 'comercio');
    if(!ok){ await this.sb.auth.signOut(); this.clear(); return { err: quien === 'conductor' ? 'Esa cuenta no es de conductor.' : 'Esa cuenta es de conductor: ingresá por "Ingresá acá".' }; }
    return { me };
  },

  /* Crea la cuenta y el perfil. `extra` sube lo que falta (documentos del chofer). */
  async register(perfil, email, pass, extra){
    const { data, error } = await this.sb.auth.signUp({ email, password: pass });
    if(error){
      if(!/already|registered/i.test(error.message)) throw new Error(this.traducir(error.message));
      const r = await this.sb.auth.signInWithPassword({ email, password: pass });
      if(r.error) throw new Error('Ese email ya está registrado.');
      const ya = await this.rpc('mi_perfil');
      // si la cuenta de chofer quedó a medias (faltaban documentos), se completa
      if(ya){
        if(extra && ya.rol === 'conductor' && ya.conductor && ya.conductor.estado === 'pendiente'){ await extra(); return await this.refresh(); }
        throw new Error('Ese email ya está registrado.');
      }
    } else if(!data.session) throw new Error('Te mandamos un mail para confirmar la cuenta. Confirmala y después iniciá sesión.');
    await this.rpc('registrar_perfil', { p: perfil });
    if(extra) await extra();
    return await this.refresh();
  },

  /* ---------- pedidos ---------- */
  payload(origen, destino, obs, pax, tarifaEst){
    const o = { origen_direccion: origen, destino_direccion: destino, observaciones: obs || null, cantidad_pasajeros: pax || 1, tarifa_estimada: tarifaEst || null };
    if(Maps.routeReady){ o.origen_lat = Maps.origin.lat; o.origen_lng = Maps.origin.lng; o.destino_lat = Maps.dest.lat; o.destino_lng = Maps.dest.lng; o.distancia_m = Maps.distance; }
    return o;
  },

  /* ---------- actualización automática ---------- */
  startPolling(){ this.stop(); this.timer = setInterval(() => this.tick(), 4000); },
  stop(){ clearInterval(this.timer); this.timer = null; },
  async tick(){
    if(document.hidden || !Session.currentUser || this.busy) return;
    this.busy = true;
    try{ await this.refresh(); this.repaint(); }catch(e){ /* sin conexión: se reintenta */ }
    this.busy = false;
  },
  repaint(){
    const u = Session.currentUser;
    const s = JSON.stringify([DB.trips.map(t => [t.id, t.estado, t.driverId, t.pago]), u && [u.saldo, u.puntos, u.viajesGratis], DB.drivers.map(d => [d.id, d.estado, d.disponible, d.puntos])]);
    if(s === this._sig) return;
    this._sig = s;
    const v = (document.querySelector('.view.active') || {}).id;
    const f = { 'view-passengerHome': () => Passenger.renderHome(), 'view-history': () => Passenger.renderHistory(), 'view-status': () => Trips.renderStatus(),
                'view-wallet': () => Wallet.render(), 'view-driverPanel': () => Drivers.renderPanel() }[v];
    if(f) f();
    Router.paintTopbar();
  }
};

/* ===== wallet.js ===== */
/* ==================================================================
   BELLAVISTA REMIS — Perfil (foto) y Billetera virtual (simulada)
   Los pagos reales (Mercado Pago, Ualá, etc.) necesitan un backend:
   acá la carga de dinero es una simulación para demo.
   ================================================================== */
const money = n => '$' + Math.round(n).toLocaleString('es-AR');

const Avatar = {
  html(u){
    if(u && u.foto) return `<img src="${u.foto}" alt="Foto de ${u.nombre}">`;
    return `<span>${u ? (u.nombre[0] + (u.apellido ? u.apellido[0] : '')) : '?'}</span>`;
  }
};

const Wallet = {
  amount: 0,
  method: 'Mercado Pago',
  methods: ['Mercado Pago', 'Ualá', 'Transferencia', 'Tarjeta'],

  me(){ return Session.currentUser; },
  movements(){ return DB.movements.filter(m => m.userId === this.me().id).slice().reverse(); },
  add(userId, tipo, monto, detalle, metodo){
    DB.movements.push({ id: uid('m'), userId, tipo, monto, detalle, metodo, fecha: todayStr(), hora: nowTime() });
  },

  /* Se llama cuando el conductor finaliza el viaje */
  chargeTrip(trip){
    const u = DB.users.find(x => x.id === trip.passengerId);
    if(!u || u.rol !== 'pasajero'){ trip.pago = 'efectivo'; return 'efectivo'; }   // comercios: se cobra en efectivo
    const detalle = 'Viaje a ' + trip.destino;
    if(trip.gratis){
      trip.pago = 'gratis';
      this.add(u.id, 'viaje', 0, detalle + ' (viaje gratis)', 'Puntos');
      return 'gratis';
    }
    if((u.saldo || 0) >= trip.tarifa){
      u.saldo -= trip.tarifa;
      trip.pago = 'billetera';
      this.add(u.id, 'viaje', trip.tarifa, detalle, 'Billetera');
    } else {
      trip.pago = 'efectivo';
      this.add(u.id, 'viaje', trip.tarifa, detalle, 'Efectivo');
    }
    return trip.pago;
  },

  render(){
    const u = this.me();
    if(!u) return;
    document.getElementById('profilePhoto').innerHTML = Avatar.html(u);
    document.getElementById('profileName').textContent = u.nombre + ' ' + (u.apellido || '');
    document.getElementById('profileEmail').textContent = u.email || '';
    const movs = this.movements();
    const trips = movs.filter(m => m.tipo === 'viaje');
    const month = todayStr().slice(0,7);
    const spentMonth = trips.filter(m => m.fecha.slice(0,7) === month).reduce((s,m) => s + m.monto, 0);
    const spentTotal = trips.reduce((s,m) => s + m.monto, 0);
    document.getElementById('walletBody').innerHTML = `
      <div class="wallet-card">
        <div class="wallet-label">Saldo disponible</div>
        <div class="wallet-balance">${money(u.saldo || 0)}</div>
        <button class="btn btn-primary" onclick="Wallet.openTopup()">＋ Cargar dinero</button>
        <div class="wallet-note">Tus viajes se pagan solos con el saldo. Si no alcanza, se cobra en efectivo.</div>
      </div>
      ${Points.passengerCard(u)}
      <div class="stat-strip" style="padding:0 18px 6px;">
        <div class="stat-chip"><div class="n">${money(spentMonth)}</div><div class="l">GASTADO ESTE MES</div></div>
        <div class="stat-chip"><div class="n">${money(spentTotal)}</div><div class="l">GASTADO EN TOTAL</div></div>
        <div class="stat-chip"><div class="n">${trips.length}</div><div class="l">VIAJES PAGADOS</div></div>
      </div>
      <div class="section-title">Movimientos</div>
      <div class="screen-pad" style="padding-top:0;">
        ${movs.length ? movs.map(m => `
          <div class="card mov">
            <div class="mov-ico ${m.tipo}">${m.tipo === 'carga' ? '＋' : '−'}</div>
            <div class="mov-info"><h4>${m.detalle}</h4><div class="mini-row"><span>${m.fecha} · ${m.hora} · ${m.metodo}</span></div></div>
            <div class="mov-amt ${m.tipo}">${m.tipo === 'carga' ? '+' : '−'}${money(m.monto)}</div>
          </div>`).join('') :
          `<div class="empty-state"><span class="icon">👛</span><h4>Sin movimientos todavía</h4><p>Cargá dinero o hacé tu primer viaje y lo vas a ver acá.</p></div>`}
      </div>`;
  },

  openTopup(){
    this.amount = 0; this.method = this.methods[0];
    document.getElementById('topupCustom').value = '';
    document.getElementById('topupChips').innerHTML = [1000,2000,5000,10000].map(n => `<button onclick="Wallet.pick(${n})" data-n="${n}">${money(n)}</button>`).join('');
    this.paintMethods();
    UI.setFieldError('f-topup', false);
    UI.openModal('modalTopup');
  },
  pick(n){
    this.amount = n;
    document.getElementById('topupCustom').value = '';
    document.querySelectorAll('#topupChips button').forEach(b => b.classList.toggle('on', +b.dataset.n === n));
  },
  custom(v){
    this.amount = parseInt(v, 10) || 0;
    document.querySelectorAll('#topupChips button').forEach(b => b.classList.remove('on'));
  },
  setMethod(m){ this.method = m; this.paintMethods(); },
  paintMethods(){
    document.getElementById('topupMethods').innerHTML = this.methods.map(m =>
      `<button class="${m === this.method ? 'on' : ''}" onclick="Wallet.setMethod('${m}')">${m}</button>`).join('');
  },
  confirmTopup(){
    if(this.amount < 500 || this.amount > 100000){ UI.setFieldError('f-topup', true); return; }
    if(API.on){ const monto = this.amount, medio = this.method; UI.closeModal('modalTopup');
      API.run(async () => { await API.rpc('cargar_saldo', { monto_: monto, medio_: medio }); await API.refresh();
        UI.toast('Cargaste ' + money(monto) + ' con ' + medio + '.'); this.render(); Passenger.renderHome(); }); return; }
    const u = this.me();
    u.saldo = (u.saldo || 0) + this.amount;
    this.add(u.id, 'carga', this.amount, 'Carga de dinero', this.method);
    UI.closeModal('modalTopup');
    UI.toast('Cargaste ' + money(this.amount) + ' con ' + this.method + '.');
    this.render();
    Passenger.renderHome();
  },

  changePhoto(input){
    const file = input.files && input.files[0];
    if(!file) return;
    UI.resizeImage(file, data => {
      if(API.on){ API.run(async () => { await API.rpc('set_foto', { p_foto: data }); await API.refresh(); UI.toast('Foto de perfil actualizada.'); this.render(); Router.paintTopbar(); }); return; }
      this.me().foto = data;
      UI.toast('Foto de perfil actualizada.');
      this.render();
      Router.paintTopbar();
    });
  }
};

/* ===== points.js ===== */
/* ==================================================================
   BELLAVISTA REMIS — Sistema de puntos (pasajeros y conductores)
   Todo lo que se puede ajustar está en POINTS.
   ================================================================== */
const POINTS = {
  passenger: { perTrip: 150, goal: 1000 },      // cada 1000 puntos = 1 viaje gratis
  driver:    { perTrip: 100, bonus5star: 50, goal: 2000, reward: 'bono de $5.000' }
};

const Points = {
  /* Suma puntos y canjea automáticamente cada vez que se llega a la meta */
  _add(who, amount, goal, prizeKey){
    who.puntos = (who.puntos || 0) + amount;
    let won = 0;
    while(who.puntos >= goal){ who.puntos -= goal; who[prizeKey] = (who[prizeKey] || 0) + 1; won++; }
    return won;
  },

  /* Al finalizar un viaje: puntos para el pasajero y para el conductor. Devuelve un texto para el aviso. */
  awardTrip(trip){
    let msg = '';
    const u = DB.users.find(x => x.id === trip.passengerId);
    if(u && u.rol === 'pasajero'){
      const won = this._add(u, POINTS.passenger.perTrip, POINTS.passenger.goal, 'viajesGratis');
      msg += ` El pasajero suma ${POINTS.passenger.perTrip} puntos${won ? ' y ganó un viaje gratis 🎁' : ''}.`;
    }
    const d = DB.drivers.find(x => x.id === trip.driverId);
    if(d){
      const won = this._add(d, POINTS.driver.perTrip, POINTS.driver.goal, 'bonos');
      msg += ` Sumaste ${POINTS.driver.perTrip} puntos${won ? ' y ganaste un ' + POINTS.driver.reward + ' 🎉' : ''}.`;
    }
    return msg;
  },

  /* Bonus para el conductor cuando lo califican con 5 estrellas */
  awardRating(driver, stars){
    if(!driver || stars < 5) return;
    this._add(driver, POINTS.driver.bonus5star, POINTS.driver.goal, 'bonos');
  },

  bar(value, goal){ return `<div class="pbar"><i style="width:${Math.min(100, value / goal * 100)}%"></i></div>`; },

  /* Cartel chico para el inicio del pasajero */
  chip(u){
    const g = u.viajesGratis || 0, p = u.puntos || 0, goal = POINTS.passenger.goal;
    return `<div class="points-chip ${g ? 'has-free' : ''}" onclick="Router.go('wallet')">
      <b>${g ? '🎁 Tenés ' + g + (g === 1 ? ' viaje gratis' : ' viajes gratis') : '⭐ ' + p + ' puntos'}</b>
      <span>${g ? 'Se usa solo en tu próximo pedido' : 'Te faltan ' + (goal - p) + ' para un viaje gratis'}</span>
      ${g ? '' : this.bar(p, goal)}</div>`;
  },

  /* Tarjeta completa del pasajero (pantalla Billetera) */
  passengerCard(u){
    const g = u.viajesGratis || 0, p = u.puntos || 0, goal = POINTS.passenger.goal;
    return `<div class="points-card">
      <div class="points-top"><h3>⭐ Mis puntos</h3><b>${p} / ${goal}</b></div>
      ${this.bar(p, goal)}
      ${g ? `<div class="points-free">🎁 Tenés ${g} ${g === 1 ? 'viaje gratis' : 'viajes gratis'}. Se usa solo en tu próximo pedido.</div>` : ''}
      <p>Ganás ${POINTS.passenger.perTrip} puntos por cada viaje. Cada ${goal} puntos, un viaje gratis.</p></div>`;
  },

  /* Tarjeta del conductor (panel) */
  driverCard(d){
    const b = d.bonos || 0, p = d.puntos || 0, goal = POINTS.driver.goal;
    return `<div class="points-card" style="margin:14px 18px 0;">
      <div class="points-top"><h3>⭐ Mis puntos</h3><b>${p} / ${goal}</b></div>
      ${this.bar(p, goal)}
      ${b ? `<div class="points-free">🎉 Tenés ${b} ${b === 1 ? POINTS.driver.reward : 'bonos de $5.000'} para cobrar. Pedíselo al administrador.</div>` : ''}
      <p>${POINTS.driver.perTrip} puntos por viaje, +${POINTS.driver.bonus5star} si te califican con 5 estrellas. Cada ${goal} puntos: ${POINTS.driver.reward}.</p></div>`;
  }
};

/* ===== ranking.js ===== */
/* ==================================================================
   BELLAVISTA REMIS — Ranking de choferes
   Se ordena por cantidad de viajes finalizados (desempate: calificación).
   Lo ven los choferes en su panel y el administrador en su pestaña.
   ================================================================== */
const Ranking = {
  period: 'semana',   // 'hoy' | 'semana' | 'total'
  labels: { hoy: 'Hoy', semana: '7 días', total: 'Total' },

  inPeriod(t){
    if(this.period === 'hoy') return t.fecha === todayStr();
    if(this.period === 'semana') return t.fecha >= new Date(Date.now() - 6 * 864e5).toISOString().slice(0,10);
    return true;
  },

  list(){
    if(API.on) return (this._r || []).map(x => ({ d: { id: x.conductor_id, rating: +x.rating || 0, puntos: x.puntos || 0 }, u: { nombre: x.nombre, apellido: x.apellido, foto: x.foto }, viajes: x.viajes, ganado: +x.ganado || 0 }));
    return DB.drivers.filter(d => d.estado === 'aprobado').map(d => {
      const u = DB.users.find(x => x.id === d.userId);
      const trips = DB.trips.filter(t => t.driverId === d.id && t.estado === 'finalizado' && this.inPeriod(t));
      return { d, u, viajes: trips.length, ganado: trips.reduce((s, t) => s + (t.gratis ? 0 : t.tarifa), 0) };
    }).sort((a, b) => b.viajes - a.viajes || (b.d.rating || 0) - (a.d.rating || 0));
  },

  setPeriod(p){
    this.period = p;
    if(API.on){ API.run(async () => { this._r = await API.rpc('ranking', { periodo: p }); this.paint(); }); return; }
    this.paint();
  },

  /* admin = true muestra también lo ganado; los choferes ven solo viajes y calificación */
  html(admin, meId){
    const rows = this.list();
    const medals = ['🥇','🥈','🥉'];
    return `
      <div class="rk-tabs">${Object.keys(this.labels).map(k =>
        `<button class="${k === this.period ? 'on' : ''}" onclick="Ranking.setPeriod('${k}')">${this.labels[k]}</button>`).join('')}</div>
      ${rows.length ? rows.map((r, i) => `
        <div class="card rk-row ${r.d.id === meId ? 'me' : ''}">
          <div class="rk-pos">${medals[i] || (i + 1)}</div>
          <div class="driver-avatar rk-av">${Avatar.html(r.u)}</div>
          <div class="rk-info"><h4>${r.u.nombre} ${r.u.apellido}${r.d.id === meId ? ' <em>(vos)</em>' : ''}</h4>
            <div class="mini-row"><span>⭐ ${r.d.rating ? r.d.rating.toFixed(1) : '—'} · ${r.d.puntos || 0} pts${admin ? ' · ' + money(r.ganado) : ''}</span></div></div>
          <div class="rk-n"><b>${r.viajes}</b><span>${r.viajes === 1 ? 'viaje' : 'viajes'}</span></div>
        </div>`).join('') : '<p class="shop-wait">Todavía no hay choferes en el ranking.</p>'}`;
  },

  paint(){
    const el = document.getElementById('driverRanking');
    if(el && Session.driverProfileId) el.innerHTML = this.html(false, Session.driverProfileId);
    if(typeof Admin !== 'undefined' && Admin.currentTab === 'ranking' && Session.currentUser && Session.currentUser.rol === 'admin') Admin.render();
  }
};

/* ===== shop.js ===== */
/* ==================================================================
   BELLAVISTA REMIS — Modo pantalla para supermercados y comercios
   El comercio deja una tablet/PC en la puerta: el cliente pone su
   nombre y a dónde va, y el pedido sale con la dirección del comercio.
   ================================================================== */
const Shop = {
  pax: 1,
  tripId: null,
  timer: null,

  me(){ const u = Session.currentUser; return u && u.rol === 'comercio' ? u : null; },

  render(){
    const u = this.me();
    if(!u) return;
    document.getElementById('shopName').textContent = u.nombre;
    document.getElementById('shopAddr').textContent = 'Te buscamos en ' + u.direccion;
    this.renderLive();
    this.renderToday();
    clearInterval(this.timer);
    this.timer = setInterval(() => {
      if(!document.getElementById('view-shop').classList.contains('active')){ clearInterval(this.timer); return; }
      this.renderLive(); this.renderToday();
    }, 2000);
  },

  stepPax(d){
    this.pax = Math.max(1, Math.min(8, this.pax + d));
    document.getElementById('shopPax').textContent = this.pax;
  },

  submit(){
    const u = this.me();
    if(!u) return;
    UI.clearErrors(['f-shop-nombre','f-shop-tel','f-shop-destino']);
    const nombre = document.getElementById('shopCliente').value.trim();
    const tel = document.getElementById('shopTel').value.trim();
    const destino = document.getElementById('shopDestino').value.trim();
    let ok = true;
    if(nombre.length < 2){ UI.setFieldError('f-shop-nombre', true); ok = false; }
    if(tel && !isValidPhone(tel)){ UI.setFieldError('f-shop-tel', true); ok = false; }
    if(destino.length < 2){ UI.setFieldError('f-shop-destino', true); ok = false; }
    if(!ok) return;
    if(API.on){ API.run(async () => {
      const r = await API.rpc('pedir_viaje', { p: { origen_direccion: u.direccion, destino_direccion: destino, cantidad_pasajeros: this.pax,
        cliente_nombre: nombre, cliente_telefono: tel || null, observaciones: 'Pedido desde ' + u.nombre, tarifa_estimada: estimateFare() } });
      this.tripId = r.id;
      ['shopCliente','shopTel','shopDestino'].forEach(id => document.getElementById(id).value = '');
      this.pax = 1; document.getElementById('shopPax').textContent = '1';
      await API.refresh(); UI.toast('Pedido enviado. Buscando conductor...'); this.renderLive(); this.renderToday();
    }); return; }

    DB.seq.trip += 1;
    const trip = {
      id: uid('t'), code: 'BV-' + String(DB.seq.trip).padStart(6,'0'),
      passengerId: u.id, driverId: null,
      nombrePasajero: nombre + ' (' + u.nombre + ')', telefono: tel || u.telefono,
      origen: u.direccion, barrio:'', destino, pax: this.pax, obs: 'Pedido desde ' + u.nombre,
      estado:'buscando', tarifa: estimateFare(), fecha: todayStr(), hora: nowTime(),
      scheduled:false, rated:true, desdeComercio:true
    };
    DB.trips.push(trip);
    this.tripId = trip.id;
    ['shopCliente','shopTel','shopDestino'].forEach(id => document.getElementById(id).value = '');
    this.pax = 1; document.getElementById('shopPax').textContent = '1';
    UI.toast('Pedido enviado. Buscando conductor...');
    this.renderLive(); this.renderToday();
  },

  newOrder(){ this.tripId = null; this.renderLive(); document.getElementById('shopCliente').focus(); },

  renderLive(){
    const box = document.getElementById('shopLive');
    const form = document.getElementById('shopForm');
    const trip = DB.trips.find(t => t.id === this.tripId);
    form.style.display = trip ? 'none' : 'block';
    if(!trip){ box.innerHTML = ''; return; }
    let driverHtml = '<p class="shop-wait">Estamos buscando un conductor disponible…</p>';
    if(trip.driverId){
      const d = DB.drivers.find(x => x.id === trip.driverId);
      const du = DB.users.find(x => x.id === d.userId);
      const vh = DB.vehicles.find(x => x.driverId === d.id);
      driverHtml = `<div class="driver-card" style="margin:0;"><div class="driver-avatar">${Avatar.html(du)}</div>
        <div class="driver-info"><h4>${du.nombre} ${du.apellido}</h4><div class="car">🚕 ${vh.marca} ${vh.modelo} · ${vh.color}</div><div class="plate">${vh.patente}</div></div></div>`;
    }
    const cerrado = ['finalizado','cancelado'].includes(trip.estado);
    box.innerHTML = `
      <div class="ticket st-${trip.estado}" style="margin:0 0 14px;">
        <div class="ticket-top"><div class="ticket-id">${trip.code}</div>
          <div class="ticket-status">${cerrado ? '' : '<span class="pulse-dot"></span>'} ${Trips.stateLabel(trip.estado)}</div></div>
        <div class="perforation"></div>
        <div class="ticket-body">
          <div class="ticket-row"><span class="k">A nombre de</span><span class="v">${trip.nombrePasajero.split(' (')[0]}</span></div>
          <div class="ticket-row"><span class="k">Destino</span><span class="v">${trip.destino}</span></div>
          <div class="ticket-row"><span class="k">Tarifa estimada</span><span class="v">${money(trip.tarifa)} · se paga en efectivo</span></div>
        </div>
      </div>
      ${driverHtml}
      <button class="btn ${cerrado ? 'btn-primary' : 'btn-outline'}" style="margin-top:14px;" onclick="Shop.newOrder()">${cerrado ? 'Hacer otro pedido' : 'Pedir otro remis'}</button>`;
  },

  renderToday(){
    const u = this.me();
    const list = DB.trips.filter(t => t.passengerId === u.id && t.fecha === todayStr()).slice().reverse();
    document.getElementById('shopToday').innerHTML = list.length ? list.map(t => `
      <div class="card"><div class="card-title-row"><h4>${t.nombrePasajero.split(' (')[0]} → ${t.destino}</h4>${Trips.stateBadge(t.estado)}</div>
      <div class="mini-row"><span>${t.hora} · ${t.code}</span></div></div>`).join('')
      : '<p class="shop-wait">Todavía no hubo pedidos hoy.</p>';
  },

  fullscreen(){
    const el = document.documentElement;
    if(document.fullscreenElement) document.exitFullscreen();
    else if(el.requestFullscreen) el.requestFullscreen();
  }
};
