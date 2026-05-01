import { configure } from 'quasar/wrappers'
module.exports = configure(() => ({
  boot: ['axios', 'pinia'],
  css:  ['app.scss'],
  extras: ['material-icons'],
  build: {
    extendViteConf (viteConf, { isClient, isServer }) {
      // i tuoi cambiamenti qui
    },
    vueRouterMode: 'history',
    env: { API_BASE: process.env.API_BASE || '/api' },
  },
  devServer: {
    open: true,
    proxy: { '/api': { target: 'http://localhost:3000', changeOrigin: true } },
  },
  framework: {
    plugins: ['Notify', 'Dialog', 'Loading'],
  },
  sourceFiles: {
    rootComponent: 'src/App.vue', // Assicurati che sia così
    router: 'src/router/index',
    store: 'src/stores/index',
    indexHtmlTemplate: 'src/index.html'
  }
}));
