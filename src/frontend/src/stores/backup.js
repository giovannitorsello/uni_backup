import { defineStore } from 'pinia'
import { api } from 'boot/axios' // Assicurati di avere axios configurato in boot

export const useBackupStore = defineStore('backup', {
  state: () => ({
    clienti:            [],
    cassette:           [],
    dispositivi:        [],     
    dispositiviCliente: [],     
    alertLog:           [],
    syncLog:            { crm: [], glpi: [] },
    loading:            false,
    error:              null,
  }),

  getters: {
    clientiScaduti: s => s.clienti.filter(c => c.prossima_rotazione && new Date(c.prossima_rotazione) < new Date()),
    clientiInScadenza: s => {
      const soglia = new Date(); soglia.setDate(soglia.getDate() + 3);
      return s.clienti.filter(c => c.prossima_rotazione &&
        new Date(c.prossima_rotazione) >= new Date() &&
        new Date(c.prossima_rotazione) <= soglia);
    },
    clientiBareos:   s => s.clienti.filter(c => ['BAREOS','ENTRAMBI'].includes(c.backup_backend)),
    clientiRestic:   s => s.clienti.filter(c => ['RESTIC_S3','ENTRAMBI'].includes(c.backup_backend)),
    dispositiviOnline: s => s.dispositivi.filter(d => d.bareos_enabled !== false).length,
  },

  actions: {
    async fetchClienti(filtri = {}) {
      this.loading = true;
      try { 
        const { data } = await api.get('/clienti', { params: filtri }); 
        this.clienti = data; 
      } catch (e) { 
        this.error = e.message; 
      } finally { 
        this.loading = false; 
      }
    },
    async fetchCassette(filtri = {}) { const { data } = await api.get('/cassette', { params: filtri }); this.cassette = data; },
    async fetchDispositivi()         { const { data } = await api.get('/dispositivi'); this.dispositivi = data; },
    async fetchDispositiviCliente(filtri = {}) { const { data } = await api.get('/dispositivi-cliente', { params: filtri }); this.dispositiviCliente = data; },
    async fetchAlertLog()            { const { data } = await api.get('/alert'); this.alertLog = data; },

    async eseguiRotazione(clienteId) {
      const { data } = await api.post(`/clienti/${clienteId}/rotazione`);
      await this.fetchClienti(); 
      await this.fetchCassette();
      return data.movimenti;
    },

    async addCliente(payload)           { const { data } = await api.post('/clienti', payload); await this.fetchClienti(); return data.id; },
    async updateCliente(id, payload)    { await api.patch(`/clienti/${id}`, payload); await this.fetchClienti(); },
    async inviaAlert(id, tipo='scadenza') { await api.post(`/alert/invia/${id}`, { tipo }); },

    async addDispositivoCliente(payload) { const { data } = await api.post('/dispositivi-cliente', payload); await this.fetchDispositiviCliente(); return data.id; },
    async updateDispositivoCliente(id, payload) { await api.patch(`/dispositivi-cliente/${id}`, payload); await this.fetchDispositiviCliente(); },

    // Restic
    async getResticSnapshots(clienteId, params = {}) { const { data } = await api.get(`/restic/${clienteId}/snapshots`, { params }); return data; },
    async getResticStats(clienteId)                   { const { data } = await api.get(`/restic/${clienteId}/stats`); return data; },
    async salvaResticConfig(clienteId, cfg)            { await api.post(`/restic/config/${clienteId}`, cfg); },

    // CRM
    async crmPull()                   { const { data } = await api.post('/sync/crm/pull'); return data; },
    async crmPush(clienteId)          { await api.post(`/sync/crm/push/${clienteId}`); },
    async fetchCrmLog()               { const { data } = await api.get('/sync/crm/log'); this.syncLog.crm = data; },

    // GLPI
    async glpiSyncComputers(clienteId) { const { data } = await api.post(`/sync/glpi/sync-computers/${clienteId}`); return data; },
    async glpiSyncEntities()           { const { data } = await api.get('/sync/glpi/sync-entities'); return data; },
    async glpiApriTicket(payload)      { const { data } = await api.post('/sync/glpi/ticket', payload); return data; },
    async fetchGlpiLog()               { const { data } = await api.get('/sync/glpi/log'); this.syncLog.glpi = data; },
  },
})
