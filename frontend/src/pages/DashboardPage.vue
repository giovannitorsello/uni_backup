<template>
  <q-page class="q-pa-md">
    <div class="row q-gutter-md q-mb-lg">
      <q-card flat bordered class="col"><q-card-section>
        <div class="text-caption text-grey">Clienti attivi</div>
        <div class="text-h4 text-weight-medium">{{ store.clienti.length }}</div>
        <div class="text-caption text-grey">{{ store.clientiBareos.length }} nastro · {{ store.clientiRestic.length }} S3</div>
      </q-card-section></q-card>

      <q-card flat bordered class="col"><q-card-section>
        <div class="text-caption text-grey">Rotazioni urgenti</div>
        <div class="text-h4 text-weight-medium text-negative">{{ store.clientiScaduti.length }}</div>
      </q-card-section></q-card>

      <q-card flat bordered class="col"><q-card-section>
        <div class="text-caption text-grey">In scadenza (3 gg)</div>
        <div class="text-h4 text-weight-medium text-warning">{{ store.clientiInScadenza.length }}</div>
      </q-card-section></q-card>

      <q-card flat bordered class="col"><q-card-section>
        <div class="text-caption text-grey">Dispositivi cliente</div>
        <div class="text-h4 text-weight-medium">{{ store.dispositiviCliente.length }}</div>
      </q-card-section></q-card>
    </div>

    <div class="row q-gutter-md">
      <div class="col-12 col-md-7">
        <div class="text-subtitle2 q-mb-sm">Alert attivi</div>
        <q-banner v-for="c in store.clientiScaduti" :key="c.id"
          class="q-mb-sm bg-red-1 text-red-9" rounded dense>
          <template #avatar><q-icon name="warning" color="negative"/></template>
          <strong>{{ c.ragione_sociale }}</strong> — scaduto il {{ fmt(c.prossima_rotazione) }}
          <q-badge :label="c.backup_backend" class="q-ml-sm" color="grey-5"/>
          <template #action>
            <q-btn flat dense label="Rotazione" @click="ruota(c)" v-if="c.backup_backend !== 'RESTIC_S3'"/>
            <q-btn flat dense label="Alert" @click="store.inviaAlert(c.id)"/>
          </template>
        </q-banner>
        <q-banner v-for="c in store.clientiInScadenza" :key="'s'+c.id"
          class="q-mb-sm bg-amber-1 text-amber-9" rounded dense>
          <template #avatar><q-icon name="schedule" color="warning"/></template>
          <strong>{{ c.ragione_sociale }}</strong> — scade {{ fmt(c.prossima_rotazione) }}
          <template #action>
            <q-btn flat dense label="Alert" @click="store.inviaAlert(c.id)"/>
          </template>
        </q-banner>
        <q-banner v-if="!store.clientiScaduti.length && !store.clientiInScadenza.length"
          class="bg-green-1 text-green-9" rounded dense>
          <template #avatar><q-icon name="check_circle" color="positive"/></template>
          Nessuna scadenza imminente
        </q-banner>
      </div>

      <div class="col-12 col-md-4">
        <div class="text-subtitle2 q-mb-sm">Prossime rotazioni</div>
        <q-list bordered separator class="rounded-borders">
          <q-item v-for="c in prossimi" :key="c.id" dense>
            <q-item-section>
              <q-item-label>{{ c.ragione_sociale }}</q-item-label>
              <q-item-label caption>{{ c.periodo_giorni }}gg · {{ c.backup_backend }}</q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-badge :color="badgeColor(c)" :label="fmt(c.prossima_rotazione)"/>
            </q-item-section>
          </q-item>
        </q-list>
      </div>
    </div>
  </q-page>
</template>

<script setup>
import { computed, onMounted } from 'vue';
import { useBackupStore } from 'stores/backup';
import { useQuasar }      from 'quasar';
import { format, parseISO } from 'date-fns';
import { it } from 'date-fns/locale';

const store = useBackupStore();
const $q    = useQuasar();

onMounted(() => Promise.all([
  store.fetchClienti(), store.fetchCassette(),
  store.fetchDispositivi(), store.fetchDispositiviCliente(),
]));

const prossimi = computed(() =>
  [...store.clienti].filter(c => c.prossima_rotazione)
    .sort((a,b) => new Date(a.prossima_rotazione) - new Date(b.prossima_rotazione)).slice(0,8)
);

const fmt = d => { try { return format(parseISO(d), 'd MMM', {locale:it}); } catch { return d||'—'; } };

const badgeColor = c => {
  const diff = (new Date(c.prossima_rotazione) - new Date()) / 86400000;
  return diff < 0 ? 'negative' : diff <= 3 ? 'warning' : 'positive';
};

async function ruota(c) {
  $q.loading.show({message:'Rotazione...'});
  try { await store.eseguiRotazione(c.id); $q.notify({type:'positive',message:'Rotazione completata'}); }
  catch (e) { $q.notify({type:'negative',message:e.message}); }
  finally { $q.loading.hide(); }
}
</script>
