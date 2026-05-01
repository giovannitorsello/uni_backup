<template>
  <q-page class="q-pa-md">
    <div class="row items-center q-mb-md">
      <q-select v-model="filtroCliente" :options="opzioniClienti" label="Filtra per cliente"
        outlined dense clearable emit-value map-options class="col-4" @update:model-value="carica"/>
      <q-space/>
      <q-btn color="primary" icon="add" label="Aggiungi device" unelevated @click="openDialog()"/>
    </div>

    <q-table :rows="store.dispositiviCliente" :columns="cols" row-key="id" flat bordered :loading="store.loading">
      <template #body-cell-bareos_fd_status="{row}">
        <q-td>
          <q-badge :color="statusColor(row.bareos_fd_status)" :label="row.bareos_fd_status"/>
        </q-td>
      </template>
      <template #body-cell-restic_enabled="{row}">
        <q-td><q-icon :name="row.restic_enabled ? 'cloud_done' : 'cloud_off'" :color="row.restic_enabled ? 'positive':'grey'"/></q-td>
      </template>
      <template #body-cell-azioni="{row}">
        <q-td>
          <q-btn flat dense round icon="wifi_tethering" title="Test connessione Bareos" @click="testBareos(row)" v-if="row.bareos_fd_name"/>
          <q-btn flat dense round icon="edit"  @click="openDialog(row)"/>
          <q-btn flat dense round icon="delete" color="negative" @click="elimina(row)"/>
        </q-td>
      </template>
    </q-table>

    <q-dialog v-model="dialog" persistent>
      <q-card style="min-width:540px">
        <q-card-section class="text-h6">{{ form.id ? 'Modifica device' : 'Nuovo device cliente' }}</q-card-section>
        <q-card-section class="q-gutter-sm">
          <q-select v-model="form.cliente_id" :options="opzioniClienti" label="Cliente *" outlined dense emit-value map-options/>
          <q-input v-model="form.nome"              label="Nome descrittivo *"    outlined dense/>
          <q-input v-model="form.hostname"          label="Hostname / IP *"       outlined dense/>
          <q-input v-model="form.ip_address"        label="IP address"            outlined dense/>
          <q-select v-model="form.tipo_device" :options="['SERVER','WORKSTATION','NAS','VM']" label="Tipo" outlined dense/>
          <q-input v-model="form.sistema_operativo" label="Sistema operativo"     outlined dense/>
          <q-separator class="q-my-sm"/>
          <div class="text-caption text-grey">Bareos File Daemon</div>
          <q-input v-model="form.bareos_fd_name"     label="Nome FD Bareos"       outlined dense/>
          <q-input v-model="form.bareos_fd_port"     label="Porta FD"             outlined dense type="number"/>
          <q-input v-model="form.bareos_fd_password" label="Password FD"          outlined dense type="password"/>
          <q-separator class="q-my-sm"/>
          <div class="text-caption text-grey">Restic / S3</div>
          <q-toggle v-model="form.restic_enabled" label="Backup Restic abilitato"/>
          <q-input v-if="form.restic_enabled" v-model="form.restic_backup_paths" label="Path backup (JSON array)" outlined dense/>
          <q-input v-if="form.restic_enabled" v-model="form.restic_cron"         label="Cron backup restic"       outlined dense/>
          <q-separator class="q-my-sm"/>
          <div class="text-caption text-grey">Integrazione GLPI</div>
          <q-input v-model="form.glpi_computer_id" label="ID Computer GLPI" outlined dense/>
          <q-input v-model="form.note"             label="Note"              outlined dense type="textarea" rows="2"/>
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
import { api }            from 'boot/axios';

const store  = useBackupStore();
const $q     = useQuasar();
const dialog = ref(false);
const filtroCliente = ref(null);
const form   = ref({});

const cols = [
  { name:'ragione_sociale', label:'Cliente',   field:'ragione_sociale', sortable:true, align:'left' },
  { name:'nome',            label:'Device',    field:'nome',            sortable:true, align:'left' },
  { name:'hostname',        label:'Hostname',  field:'hostname',        align:'left'  },
  { name:'tipo_device',     label:'Tipo',      field:'tipo_device',     align:'center'},
  { name:'bareos_fd_status',label:'Bareos FD', field:'bareos_fd_status',align:'center'},
  { name:'restic_enabled',  label:'Restic',    field:'restic_enabled',  align:'center'},
  { name:'azioni',          label:'',          field:'id',              align:'right' },
];

onMounted(async () => {
  await Promise.all([store.fetchClienti(), store.fetchDispositiviCliente()]);
});

const opzioniClienti = computed(() =>
  store.clienti.map(c => ({ label: c.ragione_sociale, value: c.id }))
);

const statusColor = s => ({ ONLINE:'positive', OFFLINE:'negative', SCONOSCIUTO:'grey' }[s] || 'grey');

function carica() { store.fetchDispositiviCliente(filtroCliente.value ? { cliente_id: filtroCliente.value } : {}); }

function openDialog(d = {}) { form.value = { tipo_device:'SERVER', bareos_fd_port:9102, restic_enabled:false, ...d }; dialog.value = true; }

async function salva() {
  try {
    if (form.value.id) await store.updateDispositivoCliente(form.value.id, form.value);
    else await store.addDispositivoCliente(form.value);
    dialog.value = false;
    $q.notify({ type:'positive', message:'Device salvato' });
  } catch (e) { $q.notify({ type:'negative', message:e.message }); }
}

async function testBareos(d) {
  try {
    const { data } = await api.get(`/dispositivi-cliente/${d.id}/bareos-status`);
    $q.notify({ type: data.online ? 'positive' : 'warning', message: data.online ? `${d.hostname}: Bareos FD online` : `${d.hostname}: FD non raggiungibile` });
    await store.fetchDispositiviCliente();
  } catch (e) { $q.notify({ type:'negative', message:e.message }); }
}

async function elimina(d) {
  $q.dialog({ title:'Conferma', message:`Rimuovere ${d.nome}?`, cancel:true }).onOk(async () => {
    await api.delete(`/dispositivi-cliente/${d.id}`);
    await store.fetchDispositiviCliente();
  });
}
</script>
