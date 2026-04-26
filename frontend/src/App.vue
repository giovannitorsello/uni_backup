<template>
  <router-view />
</template>

<script setup>
/**
 * In Quasar 2 + Vite, usiamo lo <script setup> 
 * per un codice più pulito e performante.
 */
defineOptions({
  name: 'App'
});
</script>

<style>
/* Qui puoi mettere stili globali se necessario, 
  ma solitamente Quasar gestisce tutto tramite 
  i file in src/css/app.scss 
*/
</style>