<template>
  <q-page class="q-pa-md">
    <div class="row items-center q-mb-md q-gutter-sm">
      <q-input v-model="search" dense outlined placeholder="Cerca..." clearable class="col-3">
        <template #prepend><q-icon name="search"/></template>
      </q-input>
      <q-select v-model="filtroBackend" :options="['','BAREOS','RESTIC_S3','ENTRAMBI']" label="Backend" outlined dense clearable class="col-2"/>
      <q-space/>
      <q-btn color="primary" icon="add" label="Nuovo cliente" unelevated @click="apriDialog()"/>
    </div>

    <q-table :rows="filtrati" :columns="cols" row-key="id" flat bordered :loading="store.loading">
      <template #body-cell-backup_backend="{row}">
        <q-td>
          <q-badge :color="backendColor(row.backup_backend)" :label="row.backup_backend"/>
        </q-td>
      </template>
      <template #body-cell-stato="{row}">
        <q-td><q-badge :color="statoColor(row)" :label="statoLabel(row)"/></q-td>
      </template>
      <template #body-cell-sync="{row}">
        <q-td>
          <q-icon v-if="row.crm_external_id" name="person" color="info" size="xs" title="CRM collegato"/>
          <q-icon v-if="row.glpi_entity_id"  name="computer" color="secondary" size="xs" title="GLPI collegato"/>
        </q-td>
      </template>
      <template #body-cell-azioni="{row}">
        <q-td>
          <q-btn flat dense round icon="rotate_right" title="Rotazione" @click.stop="ruota(row)" v-if="row.backup_backend!=='RESTIC_S3'"/>
          <q-btn flat dense round icon="notifications" @click.stop="store.inviaAlert(row.id)"/>
          <q-btn flat dense round icon="edit" @click.stop="apriDialog(row)"/>
        </q-td>
      </template>
    </q-table>

    <q-dialog v-model="dialog" persistent>
      <q-card style="min-width:560px;max-height:90vh" class="scroll">
        <q-card-section class="text-h6">{{ form.id ? 'Modifica' : 'Nuovo cliente' }}</q-card-section>
        <q-card-section class="q-gutter-sm">
          <div class="text-caption text-grey">Dati anagrafici</div>
          <q-input v-model="form.ragione_sociale"    label="Ragione sociale *" outlined dense/>
          <q-input v-model="form.partita_iva"        label="P. IVA"            outlined dense/>
          <q-input v-model="form.email_referente"    label="Email referente *" outlined dense type="email"/>
          <q-input v-model="form.nome_referente"     label="Nome referente"    outlined dense/>
          <q-input v-model="form.telefono_referente" label="Telefono"          outlined dense/>
          <q-separator class="q-my-sm"/>
          <div class="text-caption text-grey">Luogo terzo (CEO / off-site)</div>
          <q-input v-model="form.nome_luogo_terzo"      label="Descrizione / nome" outlined dense/>
          <q-input v-model="form.indirizzo_luogo_terzo" label="Indirizzo"          outlined dense/>
          <q-input v-model="form.email_luogo_terzo"     label="Email"              outlined dense type="email"/>
          <q-input v-model="form.telefono_luogo_terzo"  label="Telefono"           outlined dense/>
          <q-separator class="q-my-sm"/>
          <div class="text-caption text-grey">Backup</div>
          <q-select v-model="form.backup_backend" :options="['BAREOS','RESTIC_S3','ENTRAMBI']" label="Backend *" outlined dense/>
          <q-select v-model="form.periodo_giorni" :options="[7,15,30]" label="Periodo rotazione (gg)" outlined dense emit-value map-options
            v-if="form.backup_backend!=='RESTIC_S3'"/>
          <q-input v-if="form.backup_backend!=='RESTIC_S3'" v-model="form.bareos_pool_name"   label="Pool Bareos"   outlined dense/>
          <q-input v-if="form.backup_backend!=='RESTIC_S3'" v-model="form.bareos_client_name" label="Client Bareos" outlined dense/>
          <q-separator class="q-my-sm"/>
          <div class="text-caption text-grey">Integrazione esterna</div>
          <q-input v-model="form.crm_external_id" label="ID CRM esterno"   outlined dense/>
          <q-input v-model="form.glpi_entity_id"  label="Entity ID GLPI"   outlined dense/>
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Annulla" v-close-popup/>
          <q-btn unelevated color="primary" label="Salva" @click="salva"/>
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

const store  = useBackupStore();
const $q     = useQuasar();
const search = ref(''); const filtroBackend = ref(''); const dialog = ref(false); const form = ref({});

const cols = [
  {name:'ragione_sociale', label:'Cliente',  field:'ragione_sociale', sortable:true, align:'left'},
  {name:'backup_backend',  label:'Backend',  field:'backup_backend',  align:'center'},
  {name:'periodo_giorni',  label:'Periodo',  field:r=>r.periodo_giorni?r.periodo_giorni+'gg':'—', align:'center'},
  {name:'prossima_rotazione', label:'Prossima rot.', field:r=>fmt(r.prossima_rotazione), sortable:true},
  {name:'stato',           label:'Stato',    field:'id'},
  {name:'sync',            label:'Sync',     field:'id', align:'center'},
  {name:'azioni',          label:'',         field:'id', align:'right'},
];

onMounted(() => store.fetchClienti());

const fmt = d => { try { return format(parseISO(d),'d MMM yyyy',{locale:it}); } catch { return '—'; } };

const filtrati = computed(() => store.clienti.filter(c => {
  const matchSearch = !search.value || c.ragione_sociale.toLowerCase().includes(search.value.toLowerCase());
  const matchBack   = !filtroBackend.value || c.backup_backend === filtroBackend.value;
  return matchSearch && matchBack;
}));

const backendColor = b => ({BAREOS:'teal',RESTIC_S3:'blue',ENTRAMBI:'purple'}[b]||'grey');

const statoLabel = c => {
  if (c.backup_backend === 'RESTIC_S3') return 'S3';
  const d = (new Date(c.prossima_rotazione) - new Date()) / 86400000;
  return d < 0 ? 'Scaduto' : d <= 3 ? 'In scadenza' : 'OK';
};

const statoColor = c => {
  if (c.backup_backend === 'RESTIC_S3') return 'blue';
  const d = (new Date(c.prossima_rotazione) - new Date()) / 86400000;
  return d < 0 ? 'negative' : d <= 3 ? 'warning' : 'positive';
};

function apriDialog(c={}) { form.value = {periodo_giorni:7, backup_backend:'BAREOS', ...c}; dialog.value=true; }

async function salva() {
  try {
    if (form.value.id) await store.updateCliente(form.value.id, form.value);
    else await store.addCliente(form.value);
    dialog.value = false; $q.notify({type:'positive',message:'Cliente salvato'});
  } catch(e) { $q.notify({type:'negative',message:e.message}); }
}

async function ruota(c) {
  $q.dialog({title:'Conferma rotazione',message:`Eseguire rotazione per <b>${c.ragione_sociale}</b>?`,html:true,cancel:true}).onOk(async()=>{
    $q.loading.show();
    try { await store.eseguiRotazione(c.id); $q.notify({type:'positive',message:'Rotazione completata'}); }
    catch(e){ $q.notify({type:'negative',message:e.message}); }
    finally { $q.loading.hide(); }
  });
}
</script>
