<template>
  <q-page class="q-pa-md">
    <div class="row q-gutter-md">

      <!-- CRM -->
      <div class="col-12 col-md-5">
        <q-card flat bordered>
          <q-card-section>
            <div class="text-subtitle1 text-weight-medium q-mb-md">Sincronizzazione CRM</div>
            <div class="q-gutter-sm">
              <q-btn unelevated icon="cloud_download" label="Pull CRM → TapeGuard" color="primary" @click="crmPull" :loading="loadingCrm"/>
              <div class="text-caption text-grey q-mt-sm">
                Importa / aggiorna tutti i clienti dall'API CRM esterno.<br>
                Il webhook su <code>/api/sync/crm/webhook</code> riceve aggiornamenti in tempo reale.
              </div>
            </div>
          </q-card-section>
          <q-separator/>
          <q-card-section>
            <div class="text-caption text-grey q-mb-sm">Ultimi eventi sync CRM</div>
            <q-list dense>
              <q-item v-for="l in store.syncLog.crm.slice(0,8)" :key="l.id" dense>
                <q-item-section avatar>
                  <q-icon :name="l.stato==='OK'?'check_circle':'error'" :color="l.stato==='OK'?'positive':'negative'" size="xs"/>
                </q-item-section>
                <q-item-section>
                  <q-item-label caption>{{ l.ragione_sociale || 'globale' }} — {{ l.direzione }} — {{ fmtDt(l.created_at) }}</q-item-label>
                </q-item-section>
              </q-item>
              <q-item v-if="!store.syncLog.crm.length" dense>
                <q-item-section><q-item-label caption class="text-grey">Nessun evento</q-item-label></q-item-section>
              </q-item>
            </q-list>
          </q-card-section>
        </q-card>
      </div>

      <!-- GLPI -->
      <div class="col-12 col-md-6">
        <q-card flat bordered>
          <q-card-section>
            <div class="text-subtitle1 text-weight-medium q-mb-md">Integrazione GLPI</div>
            <div class="row q-gutter-sm">
              <q-btn unelevated icon="sync" label="Verifica entity GLPI" color="secondary" @click="glpiEntities"/>
              <q-btn unelevated icon="computer" label="Sync computer cliente" color="secondary" @click="showGlpiSync=true"/>
              <q-btn unelevated icon="confirmation_number" label="Apri ticket" color="warning" @click="showTicket=true"/>
            </div>
            <div class="text-caption text-grey q-mt-sm">
              Sincronizza i computer GLPI nell'anagrafica dispositivi cliente.<br>
              Apre automaticamente ticket per le rotazioni scadute (se GLPI_URL configurato).
            </div>
          </q-card-section>
          <q-separator/>
          <q-card-section>
            <div class="text-caption text-grey q-mb-sm">Ultimi eventi GLPI</div>
            <q-list dense>
              <q-item v-for="l in store.syncLog.glpi.slice(0,8)" :key="l.id" dense>
                <q-item-section avatar>
                  <q-icon :name="l.stato==='OK'?'check_circle':'error'" :color="l.stato==='OK'?'positive':'negative'" size="xs"/>
                </q-item-section>
                <q-item-section>
                  <q-item-label caption>{{ l.ragione_sociale||'—' }} · {{ l.entity_type }} · {{ fmtDt(l.created_at) }}</q-item-label>
                </q-item-section>
              </q-item>
            </q-list>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Dialog sync computers GLPI -->
    <q-dialog v-model="showGlpiSync">
      <q-card style="min-width:360px">
        <q-card-section class="text-h6">Sync computer GLPI</q-card-section>
        <q-card-section>
          <q-select v-model="glpiSyncClienteId" :options="opzioniClienti" label="Cliente" outlined dense emit-value map-options/>
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Annulla" v-close-popup/>
          <q-btn unelevated color="primary" label="Sincronizza" @click="glpiSyncComputers"/>
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Dialog ticket GLPI -->
    <q-dialog v-model="showTicket">
      <q-card style="min-width:400px">
        <q-card-section class="text-h6">Apri ticket GLPI</q-card-section>
        <q-card-section class="q-gutter-sm">
          <q-select v-model="ticket.clienteId" :options="opzioniClienti" label="Cliente" outlined dense emit-value map-options/>
          <q-input v-model="ticket.titolo"      label="Titolo" outlined dense/>
          <q-input v-model="ticket.descrizione" label="Descrizione" outlined dense type="textarea" rows="3"/>
          <q-select v-model="ticket.urgency" :options="[{label:'Bassa',value:1},{label:'Media',value:3},{label:'Alta',value:5}]"
            label="Urgenza" outlined dense emit-value map-options/>
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Annulla" v-close-popup/>
          <q-btn unelevated color="warning" label="Apri ticket" @click="apriTicket"/>
        </q-card-actions>
      </q-card>
    </q-dialog>

  </q-page>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useBackupStore } from 'stores/backup';
import { useQuasar }      from 'quasar';
import { format, parseISO } from 'date-fns';
import { it } from 'date-fns/locale';

const store = useBackupStore();
const $q    = useQuasar();
const loadingCrm  = ref(false);
const showGlpiSync = ref(false);
const showTicket   = ref(false);
const glpiSyncClienteId = ref(null);
const ticket = ref({ urgency: 3 });

onMounted(() => Promise.all([store.fetchClienti(), store.fetchCrmLog(), store.fetchGlpiLog()]));

const opzioniClienti = computed(() => store.clienti.map(c => ({ label: c.ragione_sociale, value: c.id })));

const fmtDt = d => { try { return format(parseISO(d), 'd MMM HH:mm', {locale:it}); } catch { return d||'—'; } };

async function crmPull() {
  loadingCrm.value = true;
  try {
    const r = await store.crmPull();
    $q.notify({ type:'positive', message:`CRM pull: ${r.created} nuovi, ${r.updated} aggiornati` });
    await store.fetchClienti(); await store.fetchCrmLog();
  } catch (e) { $q.notify({ type:'negative', message:e.message }); }
  finally { loadingCrm.value = false; }
}

async function glpiEntities() {
  try {
    const data = await store.glpiSyncEntities();
    const nonLinked = data.filter(e => e.action === 'not_linked').length;
    $q.notify({ type:'info', message:`${data.length} entity trovate, ${nonLinked} non collegate a clienti TapeGuard` });
  } catch (e) { $q.notify({ type:'negative', message:e.message }); }
}

async function glpiSyncComputers() {
  if (!glpiSyncClienteId.value) return;
  try {
    const r = await store.glpiSyncComputers(glpiSyncClienteId.value);
    $q.notify({ type:'positive', message:`${r.length} computer sincronizzati` });
    showGlpiSync.value = false; await store.fetchDispositiviCliente(); await store.fetchGlpiLog();
  } catch (e) { $q.notify({ type:'negative', message:e.message }); }
}

async function apriTicket() {
  try {
    const t = await store.glpiApriTicket(ticket.value);
    $q.notify({ type:'positive', message:`Ticket #${t.id} aperto su GLPI` });
    showTicket.value = false; await store.fetchGlpiLog();
  } catch (e) { $q.notify({ type:'negative', message:e.message }); }
}
</script>
