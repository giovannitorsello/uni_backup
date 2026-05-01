const routes = [
  {
    path: '/',
    // Spesso le pagine sono caricate dentro un MainLayout
    component: () => import('layouts/MainLayout.vue'),
    children: [      
      { 
        path: '', 
        component: () => import('pages/DashboardPage.vue') 
      }
    ]
  },

  // Cattura tutte le rotte non trovate (404)
  /*{
    path: '/:catchAll(.*)*',
    component: () => import('pages/ErrorNotFound.vue')
  }*/
]

export default routes