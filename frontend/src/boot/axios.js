// ============ boot/axios.js ============
import { boot } from 'quasar/wrappers';
import axios    from 'axios';

const api = axios.create({ baseURL: process.env.API_BASE || '/api', timeout: 20000 });

api.interceptors.request.use(cfg => {
  const token = localStorage.getItem('tg_token');
  if (token) cfg.headers.Authorization = `Bearer ${token}`;
  return cfg;
});
api.interceptors.response.use(res => res, err => {
  if (err.response?.status === 401) { localStorage.removeItem('tg_token'); window.location.href = '/login'; }
  return Promise.reject(err);
});

export default boot(({ app }) => { app.config.globalProperties.$api = api; });
export { api };
